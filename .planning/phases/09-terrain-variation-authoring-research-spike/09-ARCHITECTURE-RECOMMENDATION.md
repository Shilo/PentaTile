# PentaTile Multi-Terrain & Variation Architecture Recommendation

**Version:** 1.1
**Date:** 2026-04-30
**Status:** Recommendation — implementation blocked pending user-side Godot terrain testing
**Research basis:** `.planning/phases/09-terrain-variation-authoring-research-spike/09-RESEARCH-GODOT.md`, `09-RESEARCH-EXTERNAL.md`, Godot 4.6 terrain-sets PDF specification, `C:\Programming_Files\Godot\terrain_sets_docs.pdf`, VirtuMap `PentaTile_Integration_Research.md`
**v1.1 changelog:** Cross-reference with terrain_sets_docs.pdf complete (see `09-PDF-REVIEW.md`). Fixed terrain index scan to iterate alternative tiles (GAP-01), added center bit enforcement (GAP-02), added Match Corners group-of-4 constraint note (GAP-03), clarified probability semantics as per-bitmask not per-terrain (GAP-04). No phase decisions changed.

---

## Executive Summary

**Recommendation:** Introduce a `PentaTileTerrainGroup` Resource paired with per-terrain `PentaTileLayout` instances and a `penta_terrain_id` custom data layer. PentaTile reads Godot's native `TileData.terrain_set` / `terrain` / probability / peering bits as **authoring-time input**, builds a transient terrain index at load time, and keeps its own deterministic `mask_to_atlas` solver — the same O(1) hot-path dispatch used today. Terrain boundaries auto-detect from neighbor lookups; cross-terrain transition tiles dispatch to the correct layout's atlas slot.

**Key architectural choices:**
1. **Read Godot terrain metadata; never call Godot's solver** — Godot's terrain resolution is editor-only C++ with no public GDScript API. PentaTile reads the data (terrain_set, terrain, probability, peering bits) and runs its own solver.
2. **TerrainGroup as co-owner of layouts** — one `PentaTileTerrainGroup` holds N `PentaTileLayout` instances (one per terrain), plus boundary-transition rules. The layer stores terrain IDs in a `penta_terrain_id` custom data layer.
3. **Hot-path unchanged** — `_update_cells → compute_mask → mask_to_atlas → set_cell`. Mask computation extends to read terrain from the logic cell. No trie walk, no scoring loop, no per-cell linear scan.
4. **Identity guardrails preserved** — no watcher/signal-fanout, no persistent coordinate cache, no `EditorInspectorPlugin`, no `version: int` fields, no forwards-compat hooks.

---

## 1. Problem Space

### 1.1 Current Limitation

PentaTile v0.2.0 binds a single `PentaTileLayout` per `PentaTileMapLayer`. The layout owns one `bitmask_template` (a single greyscale atlas fallback image), one `compute_mask()` method, and one `mask_to_atlas()` table. This means:
- **One terrain per layer** — a layer can only render one terrain's visual style
- **No cross-terrain transitions** — when two different terrains meet, they produce a hard edge with no transition tiles
- **No terrain-aware variation** — the existing `rand_weighted()` variation picks among alternatives for the same mask, but can't pick different variations per terrain

### 1.2 VirtuMap Requirements

VirtuMap uses 6 terrain sets: Floor (0), Wall (1), Hull (2), Slope (3), Platform (4), Beam (5). These are currently wired via Godot's `set_cells_terrain_connect` API. To integrate PentaTile, VirtuMap needs:
- **Multiple independent terrain definitions** coexisting on one `PentaTileMapLayer` (e.g., StructureLayer handles both Walls and Slopes)
- **Slope handling** — tiles that encode 3-state connections (empty, floor, wall) into sloped visuals
- **Atlas passthrough** — raw `set_cell()` calls that bypass autotiling for decorations/fixtures

### 1.3 Design Goals

1. **Multi-terrain per layer** — one `PentaTileMapLayer` can render N terrain types with correct boundary transitions
2. **Auto-detection with manual overrides** — terrains auto-detect from `TileData` metadata; per-tile override via custom data layer
3. **Works across all layout types** — dual-grid (DualGrid16, Penta) and single-grid (Wang2Edge, Wang2Corner, Min3x3, Blob47Godot, PixelLab)
4. **Variation per terrain** — different terrains can have different variation pools
5. **Slope support** — 3-state terrain (empty/floor/wall) dispatch to slope tiles
6. **Minimal LOC surface** — zero new inspector panels, zero new runtime pipeline layers, zero watchers

---

## 2. Godot Terrain Sets API (factored from terrain_sets_docs.pdf)

### 2.1 Architecture

Godot 4's terrain system consists of:

```
TileSet
  └─ TerrainSets[]           # 0-indexed
       ├─ Mode: enum (MatchSides | MatchCorners | MatchCornersAndSides)
       └─ Terrains[]          # 0-indexed within set
            ├─ Name: String
            ├─ Color: Color (editor overlay)
            └─ Tiles: implicit — any tile with matching terrain_set/terrain
```

### 2.2 TileData Terrain Properties

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `terrain_set` | int | -1 | Which terrain set (0-indexed) |
| `terrain` | int | -1 | Which terrain within set (0-indexed: the "center" terrain) |
| `probability` | float | 1.0 | Relative weight for random selection |
| `get_terrain_peering_bit(direction)` | int | -1 | Expected neighbor terrain (-1 = empty) |

Peering bits are set per-tile per-CellNeighbor direction (8 for MatchCornersAndSides, 4 for MatchSides/MatchCorners).

### 2.3 Terrain Modes

| Mode | Peering Bits | Required Tiles | Shapes Possible |
|------|-------------|---------------|-----------------|
| **Match Sides** | 4 (edges) | 16 | Straight lines, rectangles, turns. Cannot distinguish inside from outside corners. |
| **Match Corners** | 4 (corners) | 16 | Large patches, caves. Must connect tiles in groups of 4 (single-tile-wide lines impossible). |
| **Match Corners and Sides** | 8 (corners + edges) | 47 | All shapes except diagonal lines (most versatile). |

**Match Corners constraint:** Godot requires tiles to connect in groups of 4 in this mode — no 1×1 or 1×N lines. Procedural generation must operate on ≥2×2 chunks. PentaTile reading terrain metadata can safely assume no isolated 1×1 cells exist in Match Corners data, reducing mask=0 special-case surface for Wang2Corner-style single-grid dispatch.

**Match Sides inside/outside corner limitation:** Match Sides cannot distinguish inside from outside corners — the same bitmask produces identical tiles for concave and convex corners. Tilesets that need different artwork for inside vs outside corners require Match Corners and Sides mode. This means PentaTile's single-grid mask computation for Match Sides-mode tilesets doesn't need to track inside vs outside corner discrimination.

### 2.4 Multi-Terrain Transition Rules

- **Terrains in the SAME set** can transition to each other — Godot auto-computes transition tiles
- **Different terrain sets CANNOT match** — they use separate peering namespaces
- **-1 = empty space** — a special value that means "no terrain / empty cell"
- For N terrains that all transition to each other, they MUST share one terrain set

### 2.5 Godot Solver — Editor-Only

**Critical finding:** Godot's terrain resolution is **editor-only C++ code** with no public GDScript API. There is no `resolve_terrain()`, no `get_terrain_tile()`, no `paint_terrain()`. The runtime (`_update_cells`) only processes cells already placed — it never auto-computes terrain tiles. This is why PentaTile has always bypassed Godot's terrain system, and why every Godot addon (TileMapDual, BetterTerrain, etc.) implements its OWN terrain solver.

**Implication for PentaTile:** Reading `TileData.terrain_set` / `terrain` / peering bits as authoring input is architecturally sound AND unavoidable. There is no callable Godot solver to delegate to.

### 2.6 Variation via Probability

Godot's terrain painter selects tiles with matching peering bits and picks via weighted random `probability`. This is editor-only — `set_cell()` never auto-picks. PentaTile already has its own `rand_weighted()` with deterministic hashing — exactly what's needed for runtime variation.

---

## 3. External Architectures (Factored from Wave 1 Research)

### 3.1 TileMapDual — Trie-based, Single Terrain Set

- **Strengths:** Trie lookup naturally supports multiple tiles per peering-bit signature; deterministic variation via probability
- **Weaknesses:** Hard-limited to terrain_set=0; trie walk is O(depth) vs PentaTile's O(1) mask lookup; requires watcher/signal-fanout system
- **Applicable to PentaTile:** The concept of a peering-signature → tile-set mapping is sound, but the trie walk conflicts with PentaTile's identity (hot-path minimalism)

### 3.2 BetterTerrain — Category-based Scoring

- **Strengths:** Category system elegantly handles overlapping terrain groups; symmetry expansion reduces artist burden; scoring naturally handles partial matches
- **Weaknesses:** Per-cell scoring loop = O(candidate_tiles) per cell; metadata-based storage requires editor plugin; version-migration machinery violates no-forward-compat policy
- **Applicable to PentaTile:** The CATEGORY concept (terrain A "is a" member of category Ground) is the strongest multi-terrain model in the Godot ecosystem. PentaTile should adopt the concept but NOT the runtime scoring loop — replace with pre-built index.

### 3.3 TileBitTools — Pure Data Model

- **Strengths:** Clean per-coordinate terrain dictionary; CENTER=99 enum trick for unified iteration
- **Weaknesses:** No runtime solver (data only); no variation handling
- **Applicable to PentaTile:** The CENTER enum trick (treating tile's own terrain as a peering bit) is directly applicable to PentaTile's mask computation.

### 3.4 External Editor Lessons

| Feature | Tiled | LDtk | RPG Maker | Recommended for PentaTile |
|---------|-------|------|-----------|--------------------------|
| Multi-terrain model | Terrain Set (auto) | IntGrid values (manual) | Slot entries (fixed) | **TerrainGroup (auto + override)** |
| Transition computation | Engine-auto from markings | User-authored rules | Fixed mini-tile lookup | **Auto from peering bits + manual override** |
| Variation | Probability weighting | Selection-rectangle pool | Animation columns (A1) | **Deterministic hash + probability** |
| Per-cell override | Yes (each cell = different terrain) | Yes (IntGrid value) | Yes (entry index) | **Yes (custom data layer = terrain ID)** |
| Authoring effort | Medium | High | Low | **Low (auto-detect default, paint to override)** |

---

## 4. Proposed Architecture

### 4.1 Core Concepts

```
PentaTileMapLayer
  ├── logic_layer: TileMapLayer  (hidden, user paints here)
  ├── visual_layer: TileMapLayer  (visible, autotile output)
  │
  ├── terrain_group: PentaTileTerrainGroup (NEW Resource)
  │   ├── layouts: Array[PentaTileLayout]   # one per terrain
  │   │   ├── [0] PentaTileLayoutDualGrid16  (Floor)
  │   │   ├── [1] PentaTileLayoutDualGrid16  (Wall, different atlas)
  │   │   └── [2] PentaTileLayoutPenta       (Slope)
  │   └── transition_rules: Dictionary       # (terrain_a, terrain_b) → mask_override
  │
  ├── _terrain_index: Dictionary[int, TerrainEntry]  # built at load time
  │   └── terrain_id → {
  │       layout: PentaTileLayout,
  │       tiles: Array[TileData]              # all tiles in this terrain
  │   }
  │
  └── layout: PentaTileLayout (LEGACY — falls back to terrain group's first layout)
```

### 4.2 `PentaTileTerrainGroup` Resource

```gdscript
## PentaTileTerrainGroup — groups multiple PentaTileLayout instances (one per terrain)
## into a terrain set that supports automatic cross-terrain transitions.
class_name PentaTileTerrainGroup
extends Resource

## Per-terrain layouts. Index = terrain_id (0-based).
@export var layouts: Array[PentaTileLayout] = []

## Optional human-readable names for each terrain (editor labels).
@export var terrain_names: Array[String] = []

## Transition override table. Key = Vector2i(terrain_a, terrain_b) or Vector2i(terrain_b, terrain_a).
## Value = per-mask atlas slot overrides for boundary cells.
## Empty by default — terrain boundary transitions auto-compute from neighbor lookups.
@export var transition_overrides: Dictionary = {}

## If true, missing transition tiles fall back to terrain_a's border tile (default behavior).
## If false, missing transition tiles leave the cell unpainted (produces visible gaps).
@export var auto_fallback_transitions: bool = true
```

**Design rationale:**
- `layouts` is an indexed array matching terrain IDs — simple, no dictionary key management
- `terrain_names` parallel array keeps enum-pattern simplicity (no per-terrain Resource wrapping)
- `transition_overrides` is an opt-in escape hatch, not the default authoring path
- The group is small — typically 2-8 terrains per group, not 100+
- No `version: int`, no schema-version constant, no per-terrain Resource subclass — flat, inspectable, follow no-forward-compat policy

### 4.3 Per-Cell Terrain Identity

Terrain identity is stored in a **custom data layer** on the logic layer's TileSet:

```
Custom Data Layer: "penta_terrain_id"
Type: int
Default: -1 (unassigned — PentaTile auto-detects from TileData.terrain)
```

**Auto-detection flow:**
```
For each painted cell in _update_cells():
  1. Read penta_terrain_id from logic cell's custom data
  2. If penta_terrain_id >= 0: use that terrain (manual override)
  3. If penta_terrain_id == -1:
     a. Read TileData.terrain (Godot's native terrain property)
     b. If terrain >= 0: use that terrain (auto-detected)
     c. If terrain == -1: use terrain_group.layouts[0] (default/first terrain)
```

**Why custom data layer over Godot native terrain properties:**
- `penta_terrain_id` is PentaTile's namespace — doesn't compete with Godot's terrain set numbering
- Users can paint terrain via Godot's editor terrain tools AND still have PentaTile read it
- Per-cell override is natural: paint a cell, set `penta_terrain_id` in custom data, done
- Follows existing pattern: PentaTile already uses `penta_role` and `penta_lock_rotation` custom data layers

### 4.4 Terrain Index Building

Built once at `set_terrain_group()` time (editor + runtime):

```gdscript
func _build_terrain_index():
    var index := {}
    for terrain_id in terrain_group.layouts.size():
        var entry := TerrainEntry.new()
        entry.layout = terrain_group.layouts[terrain_id]
        entry.tiles = []  # populated by scanning TileSet
        
        # Scan all TileSetAtlasSources for tiles belonging to this terrain
        for source_id in tile_set.get_source_count():
            var source := tile_set.get_source(source_id) as TileSetAtlasSource
            if not source: continue
            for coord in source.get_tiles_count():
                var alt_count := source.get_alternative_tiles_count(coord)
                # Scan base tile (alt=0) AND all alternative tiles (alt>=1)
                # Godot allows alternatives to have completely different peering bit
                # assignments from the base tile — they are the Godot 4 replacement
                # for Godot 3.x "ignore bits."
                for alt_id in range(alt_count):
                    var tile_data := source.get_tile_data(coord, alt_id)
                    var td_terrain := tile_data.terrain
                    
                    # Skip tiles without a center bit — Godot's docs warn: "If you
                    # leave a tile's center bit empty, Godot will have to guess what
                    # terrain the tile belongs to. This can lead to unexpected results."
                    if td_terrain < 0:
                        continue  # tile has no center bit — skip, don't silently assign
                    
                    # Match: tile's native terrain OR tile's penta_terrain_id custom data
                    var penta_terrain := tile_data.get_custom_data("penta_terrain_id")
                    var resolved := -1
                    if typeof(penta_terrain) == TYPE_INT and penta_terrain >= 0:
                        resolved = penta_terrain
                    elif td_terrain >= 0:
                        resolved = td_terrain
                    else:
                        resolved = 0  # default terrain
                    
                    if resolved == terrain_id:
                        entry.tiles.append(coord)
        
        index[terrain_id] = entry
    _terrain_index = index
```

**Key property:** The terrain index is **transient** — rebuilt on every `terrain_group` set, never persisted. No cache invalidation, no watchers, no signal fanout.

**Alternative tile handling:** The scan iterates ALL alternative tiles (`source.get_alternative_tiles_count(coord)`), not just `alt_id=0`. This is critical because Godot allows each alternative tile to have completely different peering bit assignments from the base tile — the standard Godot 4 pattern for creating one tile with multiple bitmasks (replacing Godot 3.x "ignore bits").

**Center bit enforcement:** Tiles with `terrain == -1` (no center bit) are excluded from the terrain index. Godot's documentation explicitly warns against leaving the center bit empty: "Godot will have to guess what terrain the tile belongs to. This can lead to unexpected results." Excluding them from the index prevents ambiguous tile classification.

### 4.5 Runtime Dispatch (Hot Path)

The hot path in `_update_cells()` extends minimally:

```gdscript
func _paint_via_layout(cell: Vector2i, display_cell: Vector2i):
    # 1. Determine terrain_id for this cell
    var terrain_id := _resolve_terrain_id(cell)
    
    # 2. Get layout for this terrain
    var terrain_entry := _terrain_index.get(terrain_id)
    if not terrain_entry:
        push_warning("PentaTile: no layout for terrain_id ", terrain_id)
        return
    var layout := terrain_entry.layout
    
    # 3. Check if this is a terrain boundary cell
    var neighbor_terrains := _get_neighbor_terrains(cell)
    var is_boundary := false
    for nt in neighbor_terrains:
        if nt != terrain_id and nt >= 0:
            is_boundary = true
            break
    
    # 4. Compute mask (existing pipeline, untouched)
    var mask := layout.compute_mask(neighbor_filled_vector)
    
    # 5. If boundary cell and transition override exists, use that
    # Otherwise, dispatch to terrain's own mask_to_atlas (existing pipeline)
    var slot: PentaTileAtlasSlot
    if is_boundary and transition_overrides.has(mask):
        slot = transition_overrides[mask]
    else:
        slot = layout.mask_to_atlas(mask)
    
    # 6. Render (existing pipeline, untouched)
    visual_layer.set_cell(display_cell, source_id, slot.atlas_coords, slot.alternative_tile)
```

**LOC impact:** The terrain resolution adds ~15 lines to the hot path. The terrain index build adds ~60 lines (one-time cost). The `PentaTileTerrainGroup` class adds ~50 lines. Total runtime delta: ~125 LOC. All within PentaTile's existing single-class architecture.

### 4.6 Variation Handling

PentaTile already has deterministic variation via `rand_weighted()` with hash seeding. Multi-terrain extends this:

1. **Per-terrain variation pools:** Each `TerrainEntry.tiles` contains all atlas coordinates belonging to that terrain. At render time, tiles are further filtered by peering-bit configuration (same mask/template position). Variation selection operates among tiles that share the **same bitmask** (i.e., the same mask_to_atlas slot), matching Godot's own semantics: "Probability is only relevant when multiple tiles have the same bitmask." Tiles with different peering bit configurations are never in competition even if they share a terrain.

2. **Variation mode flag on PentaTileLayout:**
```gdscript
## How variation tiles are selected for this layout.
@export var variation_mode: VariationMode = VariationMode.SINGLE
enum VariationMode {
    SINGLE,        # One tile per mask (current behavior) — no variation
    PROBABILITY,   # Weighted random from tiles sharing the SAME bitmask/peering-bit config (reads TileData.probability)
    STRIP,         # Pick randomly from a horizontal strip in the atlas (PixelLab-style)
}
```

3. **Deterministic hash for variation:**
```gdscript
var seed_value := hash(Vector4i(cell.x, cell.y, terrain_id, _global_variation_seed))
rng.seed = seed_value
var pick := rng.rand_weighted(weights)
return candidates[pick]
```

The seed incorporates `terrain_id` so that variation is per-terrain-deterministic — same cell, same terrain = same variant. Different terrains for the same cell = different variants.

### 4.7 Slope Handling

Slopes are a **3-state terrain problem**: empty (transparent), floor (solid ground), wall (solid vertical). The slope tile's peering bits encode which neighbors are floor vs wall, and the tile art visually slopes between them.

In the proposed architecture, slopes are just another terrain type within a `PentaTileTerrainGroup`. The existing `compose_mask()` pipeline already samples a 3×3 Moore neighborhood — it can distinguish "empty" vs "floor" vs "wall" from the terrain IDs of neighbors. The layout's `mask_to_atlas()` table dispatches to the correct slope tile.

**Example slope tile mapping for a 4-bit corner mask:**
```
If center=Slope:
  TL corner: empty → 0, floor → bit_1, wall → bit_2
  TR corner: empty → 0, floor → bit_3, wall → bit_4
  (combine into mask → atlas slot)
```

This keeps slopes as a standard `PentaTileLayout` subclass — no special pipeline, no separate solver. VirtuMap's SLOPE_TERRAIN_SET maps to one entry in the `PentaTileTerrainGroup.layouts` array.

### 4.8 Atlas Passthrough

VirtuMap requires placing raw atlas cells (decorations, fixtures) that bypass autotiling. The passthrough pattern:

```gdscript
## When true, set_cell() on the logic layer places tiles directly on the visual layer
## without running the autotile solver. Decorations and fixtures use this path.
func set_cell_passthrough(cell: Vector2i, source_id: int, atlas_coords: Vector2i, alternative_tile: int = 0):
    logic_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)
    # Mark as passthrough — _update_cells skips solver for this cell
    logic_layer.set_cell_data_custom(cell, "penta_passthrough", true)
```

Cells with `penta_passthrough = true` are directly copied from logic to visual layer without `_paint_via_layout()`. This is a 3-line addition to the existing pipeline.

---

## 5. Single vs Dual Grid Considerations

### 5.1 Dual-Grid Layouts (DualGrid16, Penta)

Dual-grid layouts operate on a 2× display-cell grid per logic cell. Multi-terrain handling:
- The logic cell's terrain ID propagates to ALL four display quadrants
- At terrain boundaries, individual display cells may render tiles from different terrains (e.g., top-left quadrant = Floor tile, top-right = Wall tile)
- The existing `_paint_dual_grid()` already handles per-display-cell dispatch — terrain adds a per-display-cell terrain lookup

### 5.2 Single-Grid Layouts (Wang2Edge, Wang2Corner, Min3x3, Blob47Godot, PixelLab)

Single-grid layouts paint 1 display cell per logic cell. Multi-terrain handling:
- Each logic cell has one terrain ID
- Boundary cells (cells with neighbors of different terrains) dispatch to transition tiles
- The `mask_to_atlas()` table is per-layout, per-terrain — each terrain has its own 16-entry (or 47-entry) table
- Transition tiles can either be:
  - **Auto-computed:** The solver reads the neighbor's terrain and selects a tile whose peering bits match
  - **Explicit:** The `transition_overrides` dictionary maps `(terrain_a, terrain_b, mask)` → `AtlasSlot`

### 5.3 PixelLab Layouts

PixelLab layouts are single-grid 4-bit corner-mask layouts. Their 8×8 atlas already encodes internal variation columns. Multi-terrain for PixelLab:
- Each terrain gets its own 8×8 atlas (separate `PentaTileLayoutPixelLab` instance)
- Variation columns within the atlas remain per-terrain
- Cross-terrain transitions require explicit tiles in the atlas (or auto-fallback to border tiles)

---

## 6. Identity Guardrail Compliance

| Guardrail | Compliant? | How |
|-----------|-----------|-----|
| **Terrain peering metadata / rule tries** | ✅ Avoided | Pre-built index, O(1) mask lookup, no trie walk at runtime |
| **Multi-terrain transitions** | ✅ In-scope now | This is the point of the spike — transitions are the deliverable |
| **Watcher / signal-fanout systems** | ✅ Avoided | Transient index rebuilt on setter, no change detection |
| **Persistent coordinate caches** | ✅ Avoided | Index is per-terrain tile lists, not per-cell |
| **Custom drawing API parallel to `set_cell()`** | ✅ Avoided | `set_cell_passthrough()` is an overlay, not a parallel API |
| **`EditorInspectorPlugin` polish** | ✅ Avoided | Typed `@export` + `@export_group` on `PentaTileTerrainGroup` |
| **`version: int` fields** | ✅ Avoided | No version markers, no schema constants, no forward-compat hooks |
| **Backwards-compat shims** | ✅ Avoided | `layout` property kept, redirects to `terrain_group.layouts[0]` |
| **Penta codename discipline** | ✅ Compliant | `PentaTileTerrainGroup` — "Penta" only as project prefix, not a standalone noun |

**LOC estimate:** ~125 runtime LOC total (`PentaTileTerrainGroup` + terrain index + hot-path extension). Well within PentaTile's existing ~2884 LOC surface; no new large subsystem.

---

## 7. Comparison with Alternatives

### Option A: Multiple PentaTileMapLayer Nodes (No Code Change)

- **Description:** Use one `PentaTileMapLayer` per terrain type. VirtuMap creates 6 nodes instead of 1.
- **Pros:** Zero code changes, works today
- **Cons:** Node count explosion (6 terrains = 12 TileMapLayer children); no cross-terrain transitions; no shared logic layer; user must manually set up 6 layers

### Option B: TerrainGroup + Per-Terrain Layouts (THIS PROPOSAL)

- **Description:** `PentaTileTerrainGroup` resource groups N layouts. One PentaTileMapLayer, one logic layer, one visual layer.
- **Pros:** Minimal surface (1 new Resource class); preserves existing hot-path; cross-terrain transitions; per-terrain variation; works across all layouts
- **Cons:** ~125 LOC addition; requires user to define N layouts (authoring cost); transition tile authoring is manual without Tiled-style auto-generation

### Option C: BetterTerrain-Style Category Scoring

- **Description:** Score-first solver with category system and symmetry expansion
- **Pros:** Most flexible; handles partial matches; category system is elegant
- **Cons:** O(candidate_tiles) per cell (linear scan); ~500+ LOC; symmetry system conflicts with Penta's pre-rotated atlas design; scoring loop violates identity guardrail (hot-path minimalism)

### Option D: TileMapDual-Style Trie

- **Description:** Build a peering-bit trie; walk trie at paint time
- **Pros:** Fast lookup; naturally supports multiple tiles per signature
- **Cons:** Trie build at load time (~200 LOC); O(depth) lookup vs O(1); requires terrain set 0 limitation (or per-set tries); conflicts with identity guardrail (terrain rule tries are explicitly rejected)

**Decision: Option B.** It adds the smallest surface area, preserves the existing hot-path, and solves the multi-terrain problem without architectural compromise.

---

## 8. Implementation Blueprint

### Phase A: PentaTileTerrainGroup Resource (Estimated: 60 LOC)
- New file: `addons/penta_tile/layouts/penta_tile_terrain_group.gd`
- Exports: `layouts: Array[PentaTileLayout]`, `terrain_names: Array[String]`, `transition_overrides: Dictionary`
- No custom inspector, no `@export_group` beyond the basics
- No `version: int` field

### Phase B: Terrain Index Building (Estimated: 70 LOC)
- New method: `PentaTileMapLayer._build_terrain_index()`
- Called from `set_terrain_group()` setter
- Scans all TileSetAtlasSources for tiles matching each terrain ID
- **Must iterate ALL alternative tiles** (`get_alternative_tiles_count()`), not just alt_id=0 — Godot alternative tiles can have independent peering bit assignments
- **Must skip tiles without a center bit** (`terrain == -1`) — Godot docs warn center bit is mandatory
- Stores transient `Dictionary[int, TerrainEntry]`
- Edge case: TileSet changed externally → index rebuilt on next `_update_cells()` call (if `tile_set` was replaced)

### Phase C: Custom Data Layer Wiring (Estimated: 40 LOC)
- `_resolve_terrain_id(cell)` helper
- Reads `penta_terrain_id` custom data, falls back to `TileData.terrain`, falls back to 0
- `set_cell_passthrough()` helper for VirtuMap atlas passthrough
- Backward-compat: if `terrain_group` is null, behavior is identical to v0.2.0 (single layout)

### Phase D: Slope Layout (Estimated: 120 LOC)
- New file: `addons/penta_tile/layouts/penta_tile_layout_slope.gd`
- Extends `PentaTileLayout` base
- Single-grid, 4-bit corner mask, 3-state (empty/floor/wall) → 16-entry table
- Mask computation uses terrain IDs of neighbors (not just filled/empty boolean)
- Existing single-grid `_mark_affected_single_grid_cells()` works unchanged

### Phase E: Variation Mode Wiring (Estimated: 50 LOC)
- `PentaTileLayout.variation_mode` enum + property
- In `_paint_via_layout()`: if `PROBABILITY` mode, collect candidates per terrain, run `rand_weighted()`
- Deterministic per (cell, terrain_id, global_seed)

### Phase F: Fallback + Tests (Estimated: 100 LOC)
- `get_fallback_tile_set()` extended to support terrain group (fallback TileSet from first layout)
- Tests: terrain index correctness, boundary detection, mask dispatch per terrain, multi-terrain hollow/edge tests

**Total LOC estimate: ~440 LOC across 6 phases**
**New files: 2 (`penta_tile_terrain_group.gd`, `penta_tile_layout_slope.gd`)**
**Modified files: 3 (`penta_tile_map_layer.gd`, `penta_tile_layout.gd`, `penta_tile_atlas_slot.gd`)**

---

## 9. VirtuMap Integration Path

With the proposed architecture, VirtuMap's adapter changes:

| VirtuMap Concept | PentaTile v0.2.0 | PentaTile v0.3.0 (Proposed) |
|-----------------|-------------------|----------------------------|
| FLOOR_TERRAIN_SET (0) | Separate PentaTileMapLayer | terrain_group.layouts[0] |
| WALL_TERRAIN_SET (1) | Separate PentaTileMapLayer | terrain_group.layouts[1] |
| HULL_TERRAIN_SET (2) | Separate PentaTileMapLayer | terrain_group.layouts[2] |
| SLOPE_TERRAIN_SET (3) | Not possible | terrain_group.layouts[3] (PentaTileLayoutSlope) |
| PLATFORM_TERRAIN_SET (4) | Separate PentaTileMapLayer | terrain_group.layouts[4] |
| BEAM_TERRAIN_SET (5) | Separate PentaTileMapLayer | terrain_group.layouts[5] |
| set_cells_terrain_connect() | set_cell() per terrain layer | set_cell() with penta_terrain_id |
| Atlas passthrough | set_cell() on passthrough layer | set_cell_passthrough() |
| Adapter nodes | 6+ PentaTileMapLayer nodes | 1 PentaTileMapLayer node |

**Net win for VirtuMap:** 6x reduction in PentaTileMapLayer nodes (6 → 1). Same API surface. Cross-terrain transitions between Floor/Wall appear automatically.

---

## 10. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Terrain index stale when artist edits TileSet** | Medium | Rebuild on `terrain_group` setter; no watcher needed (artist re-assigns terrain_group after editing) |
| **Per-terrain mask tables increase authoring cost** | Medium | Default auto-computation from peering bits; manual override only for custom transitions |
| **Slope layout needs non-trivial mask computation** | Low | Single-grid 4-bit corner mask with terrain-ID-aware neighbors; implemented as standard layout subclass |
| **Performance regression at terrain boundaries** | Low | Pre-built index; O(1) lookup; 3×3 neighbor scan is unchanged (already happens per cell) |
| **Combinatorial explosion for N terrains in one group** | Low | Document recommendation: ≤8 terrains per group; separate groups for independent biome sets |
| **Godot changes terrain API in 4.7+** | Low | PentaTile reads TileData properties (stable since 4.0); custom data layer is PentaTile-owned |

---

## 11. What This Architecture Does NOT Do

- **Does NOT call Godot's terrain solver** — it can't; no GDScript API exists
- **Does NOT auto-generate transition tiles** — the artist must provide them (but the solver auto-selects from what's available)
- **Does NOT add EditorPlugin inspector panels** — typed `@export` only
- **Does NOT add watcher/signal-fanout systems** — transient index rebuilt on setter
- **Does NOT add `version: int` fields** — per no-forward-compat policy
- **Does NOT support per-cell per-neighbor terrain weights** — that's TileMapDual/BetterTerrain territory; deferred to v4+ if needed
- **Does NOT handle RPG Maker-style quarter-tile composition** — reserved for v0.3+ (RPGM-01/02)

---

## 12. Open Questions for Production Implementation

1. **Should `penta_terrain_id` be a custom data layer or a separate `@export` property?** Custom data layer is simpler (no new property). Separate property gives per-cell override without touching the TileSet. **Recommendation: custom data layer** — follows existing `penta_role`/`penta_lock_rotation` pattern.

2. **Can a terrain belong to MULTIPLE terrain groups?** Consider: "Grass" in both "Ground" group and "Forest" group. The proposed architecture says no (each cell has one terrain_id). If needed, virtual terrain categories (like BetterTerrain's) can be layered on top. **Recommendation: keep simple — one terrain, one group, one layout.** Categories can ship later.

3. **Should transition tiles be per-terrain-pair or shared?** The `transition_overrides` dictionary is per-pair. If transition is identical (e.g., Grass→Dirt and Dirt→Grass use the same border tile), the author defines both or uses auto-fallback. **Recommendation: keep per-pair with auto-fallback** — avoids over-automation, gives artist control.

4. **Does the terrain group need a default layout for unassigned cells?** PentaTile already falls back to `layout` property when `terrain_group` is null. With a terrain group, cells with terrain_id=-1 could either: (a) stay unpainted, or (b) paint with `layouts[0]`. **Recommendation: option (a)** — explicit assignment avoids "magic default" confusion. Cells without terrain IDs don't render.

---

## Appendix A: Godot Terrain Sets PDF — Key Extractions

The PDF `C:\Programming_Files\Godot\terrain_sets_docs.pdf` (42 pages) is the official Godot 4 documentation section on terrain sets. Key architectural facts extracted:

1. **Terrain sets are per-TileSet, not per-layer.** Multiple layers can share one TileSet with multiple terrain sets.
2. **Terrain mode determines peering bit count:** MatchSides (4 bits, 16 tiles), MatchCorners (4 bits, 16 tiles), MatchCornersAndSides (8 bits, 47 tiles).
3. **Peering bits use -1 for "empty space"** — a universal sentinel across all modes.
4. **Godot's terrain solver runs in the editor only** — "Godot chooses tiles to handle transitions between terrains automatically" but this is C++ editor code, not a GDScript API. Confirmed by the TileData class reference (no solver methods).
5. **Probability works via weighted random among tiles with matching bitmasks** — multiple tiles with the SAME peering bit configuration are all candidates, selected by probability.
6. **Alternative tiles can fill missing bitmasks** — one tile texture can have multiple alternative tiles, each with different peering bit assignments (like Godot 3.x "ignore bits").
7. **Terrains in different sets cannot match** — cross-set transitions aren't supported.
8. **Animation frames are per-terrain-tile** — terrain tiles can be animated, with frames sharing the same terrain bitmask.
9. **Alternative tiles can have independent peering bit assignments** — one source tile can have multiple alternative tiles (alt_id > 0), each with completely different terrain/peering configurations. This is Godot 4's replacement for Godot 3.x "ignore bits" and means terrain indexes must scan ALL alternative tiles, not just alt_id=0.
10. **Center bit is mandatory** — Godot docs warn: "If you leave a tile's center bit empty, Godot will have to guess what terrain the tile belongs to. This can lead to unexpected results." Tiles without a center bit (terrain == -1) should be excluded from terrain indexes.
11. **Probability only matters when multiple tiles share the same bitmask** — it's not a per-terrain weight but a per-bitmask-configuration weight. Tiles with different peering bit assignments never compete for the same slot.

These facts are fully accounted for in the proposed architecture. PentaTile reads the data model (tile properties) without depending on the editor-only solver.

---

## Appendix B: Cross-Reference with Phase 8 Multi-Terrain Research

Phase 8's `08-MULTI-TERRAIN-RESEARCH.md` established the hard firewall: "do not call Godot's terrain solver for generated visuals." The PDF confirms this firewall is architecturally correct — the solver literally doesn't exist as a callable API.

Phase 8 also recommended:
- Single-grid layouts land first ✓ (proposed architecture handles all layouts)
- Dual-grid gets four-corner terrain signatures second ✓ (proposed architecture works identically for both)
- Penta layouts get terrain banks first ✓ (proposed architecture's terrain index is layout-agnostic)

Phase 8's MULTITERR-01..08 requirements are all addressable by this architecture. No conflict.

---

*Recommendation complete. Next step: user-side Godot terrain testing (manual painting of multi-terrain sets in the Godot editor to validate peering bit behavior); then production planning against this recommendation.*
