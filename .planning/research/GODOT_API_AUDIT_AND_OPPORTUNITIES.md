# Godot TileMap/TileSet API Audit & PentaTile v0.3 Opportunities

**Date:** 2026-04-30
**Scope:** Full review of PentaTile v0.2.0 implementation vs. Godot 4.6 official TileMap/TileSet API
**Confidence:** HIGH (all claims verified against primary sources)

---

## Executive Summary

PentaTile v0.2.0 ships 8 layouts (Penta through PixelLab), dual-grid and single-grid dispatch, synthesis machinery for Penta archetypes, and bundled fallback TileSets. The architecture uses `TileMapLayer._update_cells()` as the sole Godot entry point and maintains its own mask→slot dispatch chain independent of Godot's terrain system.

Godot 4.6's terrain system (terrain sets, peering bits, terrain modes, terrain-aware painting) offers metadata that overlaps with PentaTile's v0.3 goals: terrain identity per tile, variation candidate discovery, and per-layout terrain transitions. Per MULTITERR-07 (locked decision), PentaTile **reads** Godot terrain metadata as authoring/indexing input but keeps its own solver for generated visuals.

This audit catalogs every Godot TileMap/TileSet API surface PentaTile does or does not use, and identifies concrete opportunities for v0.3 terrain+variation work.

---

## 1. PentaTile Implementation Review

### 1.1 Architecture Summary

```
User: set_cell(logic_cell, source_id, atlas_coords)
  ↓
TileMapLayer._update_cells()  [Godot hook]
  ↓
PentaTileMapLayer._update_cells()
  ├─ Mark affected display cells (dual-grid: 4 corners; single-grid: 8 Moore)
  ├─ _paint_via_layout(display_cell, layout, source, sample_fn)
  │   ├─ layout.compute_mask(coord, sample_fn) → int
  │   ├─ layout.is_dual_grid() check + single-grid logic-painted gate
  │   ├─ layout.resolve_display_strip(coord, atlas_sample_fn) → int  [Penta AUTO_STRIP]
  │   ├─ layout.mask_to_atlas(mask, strip_index) → PentaTileAtlasSlot
  │   └─ _paint_with_slot(layer, slot, display_cell, source)
  │       └─ layer.set_cell(cell, source, slot.atlas_coords, slot.transform_flags)
  └─ Visual child TileMapLayer ("_PentaTileVisual") renders dispatched cells
```

**Key design invariants:**
- Logic layer hidden via `self_modulate.a = 0.0`, not `visible = false` (Pitfall #7)
- Synthesis cache keyed by hash of layout inputs; re-runs only on change (PENTA-SYNTH-06)
- `_queue_rebuild()` coalesces via `call_deferred` — no signal storms
- No persistent coordinate caches, no terrain peering metadata, no watcher systems

### 1.2 Godot TileMapLayer API Usage

| Godot API | Used? | How / Where |
|-----------|-------|-------------|
| `set_cell(coords, source, atlas_coords, alt_tile)` | **YES** | `_paint_with_slot()` at `penta_tile_map_layer.gd:372` — the sole write path |
| `erase_cell(coords)` | **YES** | `_paint_via_layout` at line 318 (per-cell pre-erase), `_clear_visual_layers` |
| `get_cell_source_id(coords)` | **YES** | `_has_logic_cell()` at line 378 — the neighbor presence query |
| `get_cell_atlas_coords(coords)` | **YES** | `_sample_logic_atlas_coords()` at line 388 — AUTO_STRIP strip resolution |
| `get_used_cells()` | **YES** | `rebuild()` at line 269 — full re-dispatch iteration |
| `_update_cells(coords, forced_cleanup)` | **YES** | Override at line 218 — the autotile egress point |
| `get_cell_tile_data(coords)` | **NO** | Not used (v0.2 skips per-cell TileData reads) |
| `get_cell_alternative_tile(coords)` | **NO** | Not used (no variation yet) |
| `is_cell_flipped_h/v/is_cell_transposed(coords)` | **NO** | Not used (transform flags handled by slot, not queried from painted cells) |
| `get_neighbor_cell(coords, neighbor)` | **NO** | Neighbors computed manually with Vector2i offsets |
| `get_surrounding_cells(coords)` | **NO** | Not used |
| `set_cells_terrain_connect(cells, terrain_set, terrain)` | **NO** | Blocked by MULTITERR-07 — PentaTile keeps own solver |
| `set_cells_terrain_path(path, terrain_set, terrain)` | **NO** | Blocked by MULTITERR-07 |
| `_tile_data_runtime_update()` | **NO** | Not overridden — no runtime TileData mutation |
| `_use_tile_data_runtime_update()` | **NO** | Not overridden |
| `get_used_cells_by_id(source, coords, alt)` | **NO** | Used only indirectly via `get_used_cells()` |
| `notify_runtime_tile_data_update()` | **NO** | Not needed |
| `fix_invalid_tiles()` | **NO** | Not needed |
| `local_to_map/local_position` | **NO** | Only demo painter uses it; not in addon core |
| `map_to_local/map_position` | **NO** | Not in addon core |

### 1.3 Godot TileSet API Usage (addon-side)

| Godot API | Used? | How / Where |
|-----------|-------|-------------|
| `TileSet.new()` | **YES** | `build_tile_set_from_synthesis()` (line 424), `get_fallback_tile_set()` (line 157) |
| `tile_set.tile_size` | **YES** | `_visual_layer_offset()` (line 511), synthesis tile_size propagation |
| `tile_set.add_source(src, id)` | **YES** | Synthesis at line 439, fallback at line 164 |
| `tile_set.get_source(id)` | **YES** | `_resolve_source_id()` indirectly, synthesis source reads |
| `tile_set.get_source_count()` | **YES** | `_resolve_source_id()` at line 423 |
| `tile_set.get_source_id(index)` | **YES** | `_resolve_source_id()` at line 425 (first source fallback) |
| `tile_set.has_source(id)` | **YES** | Synthesis `synthesize_strip()` at line 93 |
| `tile_set.get_physics_layers_count()` | **YES** | Synthesis layer mirroring |
| `tile_set.get_occlusion_layers_count()` | **YES** | Synthesis layer mirroring |
| `tile_set.get_navigation_layers_count()` | **YES** | Synthesis layer mirroring |
| `tile_set.add_physics_layer()` | **YES** | Synthesis at line 429 |
| `tile_set.add_occlusion_layer()` | **YES** | Synthesis at line 431 |
| `tile_set.add_navigation_layer()` | **YES** | Synthesis at line 433 |
| `TileSetAtlasSource.new()` | **YES** | Synthesis (line 436), fallback TileSet (line 158) |
| `src.texture = ...` | **YES** | Synthesis image → ImageTexture (line 437), fallback (line 159) |
| `src.texture_region_size = ...` | **YES** | Synthesis (line 438), fallback (line 160) |
| `src.get_atlas_grid_size()` | **YES** | Penta `resolve_active_mode()` + `resolve_strip_modes()` |
| `src.has_tile(coords)` | **YES** | AUTO_STRIP per-strip detection in `resolve_strip_modes()` |
| `src.create_tile(coords)` | **YES** | Synthesis (line 449), fallback (line 163) |
| `src.get_tile_data(coords, alt)` | **YES** | Synthesis polygon extraction (line 450) |

### 1.4 Godot TileSet API NOT Used (Critical for v0.3)

These APIs exist in Godot 4.6 but PentaTile v0.2.0 makes no use of them. They are the primary opportunity surfaces for v0.3 terrain+variation:

| Godot API | Why Not Used (v0.2) | v0.3 Opportunity |
|-----------|---------------------|------------------|
| `TileSet.get_terrain_sets_count()` | No terrain support | **MULTITERR-01**: Scan terrain sets for terrain-aware dispatch |
| `TileSet.get_terrain_set_mode(terrain_set)` | No terrain support | Determine if terrain set is Match Corners and Sides / Match Corners / Match Sides |
| `TileSet.get_terrains_count(terrain_set)` | No terrain support | Enumerate terrains for candidate index building |
| `TileSet.get_terrain_name(terrain_set, idx)` | No terrain support | Inspector / debug info |
| `TileSet.get_terrain_color(terrain_set, idx)` | No terrain support | Visual debugging / editor tile tint |
| `TileSet.add_terrain_set()` | Build-time only | Not used at runtime (MULTITERR-07: Godot terrain is input only) |
| `TileSet.add_terrain(terrain_set)` | Build-time only | Not used at runtime |
| `TileData.get_terrain_set(tile_data)` | Not accessed | **MULTITERR-01**: Read terrain set ID from painted cell's TileData |
| `TileData.get_terrain(tile_data)` | Not accessed | **MULTITERR-01**: Read terrain ID from painted cell's TileData |
| `TileData.get_terrain_peering_bits(tile_data)` | Not accessed | **MULTITERR-02**: Index candidates by peering bit pattern for layout-specific dispatch |
| `TileData.get_custom_data(key)` | Not accessed | Could read `penta_role` / `penta_lock_rotation` (v0.1 custom data layer mention in AGENTS.md) |
| `TileData.probability` | Not accessed | **VAR-01**: Weighted variation candidate pick from TileData |
| `TileSet.get_custom_data_layers_count()` | Not accessed | Could validate penta_role / penta_lock_rotation custom data layer |
| `TileSet.get_custom_data_layer_by_name(name)` | Not accessed | Find penta_role custom data layer by name |
| `TileSetAtlasSource.get_alternative_tiles_count(coords)` | Not accessed | **VAR-01**: Enumerate alternative tiles for variation candidates |
| `TileSetAtlasSource.get_alternative_tile_id(coords, idx)` | Not accessed | **VAR-01**: Access specific alternative tile for weighted pick |

---

## 2. Godot Terrain System Deep Dive

### 2.1 Terrain Set Architecture

Godot 4.6's terrain system is structured as:

```
TileSet
  ├── terrain_sets (0..N)
  │   ├── mode: TerrainMode { MATCH_CORNERS_AND_SIDES, MATCH_CORNERS, MATCH_SIDES }
  │   └── terrains (0..M per set)
  │       ├── name: String
  │       └── color: Color  (editor tint)
  └── TileSetAtlasSource
      └── tile (atlas_coords, alt_tile)
          └── TileData
              ├── terrain_set: int   (-1 = no terrain)
              ├── terrain: int       (terrain index within set)
              └── terrain_peering_bits: PackedInt32Array  (8 bits per terrain in set)
```

### 2.2 Terrain Peering Bits — The Core Metadata

Each tile's `TileData` stores peering bits as a `PackedInt32Array` where:
- Index in array = terrain index within the terrain set
- Value at index = 8-bit mask encoding which neighboring directions require that specific terrain

Bit layout (Godot's canonical order):

| Bit | Direction | Neighbor Offset |
|-----|-----------|-----------------|
| 0  | Top-Left  | (-1, -1) |
| 1  | Top       | (0, -1)  |
| 2  | Top-Right | (1, -1)  |
| 3  | Left      | (-1, 0)  |
| 4  | Right     | (1, 0)   |
| 5  | Bottom-Left | (-1, 1) |
| 6  | Bottom    | (0, 1)   |
| 7  | Bottom-Right | (1, 1) |

This is an **8-bit Moore neighborhood** — the same 8 positions Blob47Godot's `compute_mask` samples. Value `-1` in a bit position means "ignore this neighbor" (matches empty cells or other terrains).

### 2.3 Terrain Modes

| Mode | Description | PentaTile Layout Analog |
|------|-------------|------------------------|
| **Match Corners and Sides** (2×2) | All 8 peering bits used. Tiles must match all corners AND all edges. | Blob47Godot (8-bit Moore), Penta (4-bit corner selects 4 of 8 neighbors) |
| **Match Corners** (3×3) | Only corner bits (TL, TR, BL, BR) matter; edge bits ignored. | Wang2Corner, DualGrid16, PixelLab (all 4-bit corner) |
| **Match Sides** (3×3 minimal) | Only edge bits (T, L, R, B) matter; corner bits ignored. Uses open-side collapse logic. | Wang2Edge, Min3x3 (4-bit edge) |

**Observation:** Godot's three terrain modes directly parallel PentaTile's three mask families: 8-bit Moore (Blob47), 4-bit corner (Penta/DualGrid16/Wang2Corner/PixelLab), 4-bit edge (Wang2Edge/Min3x3).

### 2.4 Godot Terrain Painting (What PentaTile Rejects Per MULTITERR-07)

Godot's `TileMapLayer` terrain painting methods:
- `set_cells_terrain_connect(cells, terrain_set, terrain)` — fills cells, then iterates all connected neighbors updating tiles to match peering bits via Godot's internal solver
- `set_cells_terrain_path(path, terrain_set, terrain)` — path-based terrain painting that only connects within the stroke

**PentaTile deliberately does NOT call these for generated output** (MULTITERR-07). Godot's terrain solver:
- Mutates cells/neighbors it decides need updating
- Has no awareness of PentaTile's layout library or synthesis pipeline
- Would break the display-layer paint→paint pattern (PentaTile controls everything that lands on the visual child layer)

The correct pattern per MULTITERR-07: read `TileData.terrain_set`/`terrain`/`terrain_peering_bits` from the **logic layer's painted cells** as authoring metadata, then use PentaTile's own `compute_mask` + `mask_to_atlas` pipeline to select the correct tile from the candidate index.

---

## 3. Alternative Tiles & Variation

### 3.1 Godot's Alternative Tile System

Godot 4.6 `TileSetAtlasSource` supports alternative tiles per atlas coordinate:

```
TileSetAtlasSource
  ├── tile (atlas_coords)                    ← base tile (alternative_tile = 0)
  │   ├── TileData (base)                    ← collision, navigation, terrain, probability
  │   └── alternative_tiles[1..N]            ← each has its own TileData
  │       ├── alternative_id: int
  │       ├── flip_h, flip_v, transpose      ← render-time transform (separate from alt-ID)
  │       ├── TileData (custom)              ← different probability, terrain, custom data
  │       └── ...
```

Key APIs:
- `TileSetAtlasSource.get_alternative_tiles_count(atlas_coords) -> int`
- `TileSetAtlasSource.get_alternative_tile_id(atlas_coords, index) -> int`

Alternative tiles stack on the same `atlas_coords`; each can have its own `TileData` with different `probability`, `terrain_set`/`terrain`, etc.

### 3.2 Probability for Variation

`TileData.probability` (float) provides per-tile weights. Godot's built-in editor uses these for scatter/random painting. PentaTile v0.2.0 does NOT read `probability` at all.

For v0.3 variation (VAR-01), the recipe is:
1. Enumerate all alt-tiles at each atlas coordinate that match the current terrain+mask
2. Build a weighted list from their `TileData.probability` values
3. Pick via deterministic hash of `Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed` per PITFALLS.md §2
4. Use `_pack_alternative(alt_id, transform_flags)` to combine the chosen alt-ID with render-time transforms

### 3.3 Bit Packing Constraint

Per PITFALLS.md §1: `alternative_tile` shares an int with `TRANSFORM_FLIP_H/V/TRANSPOSE` flags. Alt-ID must stay < 4096. PentaTile already enforces this via `_pack_alternative()` in the layout base class (`penta_tile_layout.gd:121`). Variation candidate picking must stay within this constraint.

---

## 4. Custom Data Layers

Godot 4.6 supports per-tile custom data via named layers:

```gdscript
var idx = tile_set.get_custom_data_layer_by_name("penta_role")
var data = tile_data.get_custom_data(idx)  # returns int/float/String depending on layer type
```

PentaTile v0.1's AGENTS.md mentions `penta_role` and `penta_lock_rotation` custom data layers. These are **not used in v0.2.0 runtime** but remain viable for:
- Per-tile behavior flags (e.g., "this tile never rotates even in Penta dispatch")
- Layout-specific metadata that doesn't fit terrain semantics
- User-authored game data (damage, destructible, etc.)

---

## 5. TileSetAtlasSource API Not Currently Used (But Relevant)

| API | v0.3 Relevance |
|-----|---------------|
| `src.get_tiles_count()` | Candidate index walk (MULTITERR-02: enumerate all tiles across all sources) |
| `src.get_tile_id(index)` | Iterating tiles by index |
| `src.get_alternative_tiles_count(coords)` | VAR-01: enumerate variation candidates |
| `src.get_alternative_tile_id(coords, index)` | VAR-01: access specific alternative for weighted pick |
| `src.get_tile_data(coords, alt_tile)` | Already used for base tile (alt=0); need to extend for alt>0 |
| `TileSetAtlasSource.TRANSFORM_FLIP_H` (4096) | Already used for rotation flags |
| `TileSetAtlasSource.TRANSFORM_FLIP_V` (8192) | Already used |
| `TileSetAtlasSource.TRANSFORM_TRANSPOSE` (16384) | Already used |

### 5.1 Multi-Source TileSet Support

PentaTile v0.2.0 has `atlas_source_id` to select one source, but `_resolve_source_id()` defaults to source 0 when `atlas_source_id == -1`. MULTITERR-03 proposes removing the single-source assumption so terrain dispatch can route to different sources.

The `get_source_count()` + `get_source_id(index)` + `get_source(id)` pattern already exists in the codebase. Extending to iterate all sources for candidate discovery is straightforward.

---

## 6. Concrete v0.3 Opportunities

### 6.1 Terrain-Aware Dispatch (MULTITERR-01..05)

**What Godot provides:**
- `TileData.terrain_set` / `TileData.terrain` per tile — tells you "this cell is dirt" or "this cell is grass"
- `TileData.terrain_peering_bits` per tile — tells you "this tile wants dirt to the north and east, grass elsewhere"
- `TileSet.get_terrain_set_mode()` — tells you if peering bits are corner-only, edge-only, or both

**What PentaTile could do (per MULTITERR-01):**

1. In `_paint_via_layout()`, before computing the mask, sample the logic cell's `get_cell_tile_data()` to get `terrain_set` and `terrain`
2. Build a terrain signature per display cell: what terrain is the center cell, and what terrains are its neighbors
3. Use this signature to disambiguate which atlas source/strip/alternative to use when multiple terrains share one TileSet
4. Feed the terrain-aware candidate into `mask_to_atlas()` or a new `mask_to_atlas_for_terrain(mask, terrain_signature)` variant

**Godot API call pattern:**

```gdscript
# In PentaTileMapLayer (new terrain-aware sample function)
func _sample_logic_terrain(logic_cell: Vector2i) -> int:
    var tile_data := get_cell_tile_data(logic_cell)
    if tile_data == null:
        return -1  # empty
    return tile_data.get_terrain()  # returns -1 if no terrain assigned

# Existing sample_fn (neighbor presence) unchanged
func _has_logic_cell(logic_cell: Vector2i) -> bool:
    return get_cell_source_id(logic_cell) != -1
```

### 6.2 Candidate Index Building (MULTITERR-02)

**What Godot provides:**
- Iteration over all tiles in all `TileSetAtlasSource` sources
- Iteration over all alternative tiles per atlas coordinate
- Per-tile `terrain_set`, `terrain`, `terrain_peering_bits`, `probability`

**What PentaTile could build:**

A transient `TerrainTileIndex` built at dispatch time (no persistent cache) mapping:
```
(terrain_set, terrain, layout-specific-mask-signature) → [candidates]
```

Where each candidate is:
```gdscript
{
    "source_id": int,
    "atlas_coords": Vector2i,
    "alternative_tile": int,   # packed: alt_id | transform_flags
    "probability": float,      # from TileData.probability
}
```

**How to build it (O(all tiles), run once per rebuild):**

```gdscript
func _build_candidate_index(layout: PentaTileLayout) -> Dictionary:
    var index := {}
    var source_count := tile_set.get_source_count()
    for src_idx in source_count:
        var src_id := tile_set.get_source_id(src_idx)
        var src := tile_set.get_source(src_id) as TileSetAtlasSource
        if src == null: continue
        for tile_idx in src.get_tiles_count():
            var coords := src.get_tile_id(tile_idx)
            _index_tile(src, src_id, coords, 0, index, layout)
            var alt_count := src.get_alternative_tiles_count(coords)
            for alt_idx in alt_count:
                var alt_id := src.get_alternative_tile_id(coords, alt_idx)
                _index_tile(src, src_id, coords, alt_id, index, layout)
    return index

func _index_tile(src, src_id, coords, alt_id, index, layout):
    var tile_data := src.get_tile_data(coords, alt_id)
    if tile_data == null: return
    var terrain_set := tile_data.get_terrain_set()
    var terrain := tile_data.get_terrain()
    if terrain_set < 0 or terrain < 0: return  # skip unassigned
    var peering := tile_data.get_terrain_peering_bits()  # PackedInt32Array
    var mask_sig := layout.terrain_peering_to_mask_signature(peering, terrain)
    var key := [terrain_set, terrain, mask_sig]
    var entry := {
        "source_id": src_id,
        "atlas_coords": coords,
        "alternative_tile": _pack_alternative(alt_id, 0),
        "probability": tile_data.probability,
    }
    index[key].append(entry)
```

**Key design constraint:** The index is transient (built per full `rebuild()`, discarded after). This satisfies the "no persistent coordinate cache" identity guardrail and MULTITERR-02.

### 6.3 Terrain Mode → Layout Mapping

Godot's three `TerrainMode` values map naturally to PentaTile layouts:

| Godot TerrainMode | Peering Bits Used | Best-Fit PentaTile Layouts |
|-------------------|-------------------|---------------------------|
| MATCH_CORNERS_AND_SIDES | 8-bit Moore | Blob47Godot, Penta (4 corners only but fits subset) |
| MATCH_CORNERS | 4-bit corner | DualGrid16, Wang2Corner, PixelLab (top-down + side-scroller) |
| MATCH_SIDES | 4-bit edge | Wang2Edge, Min3x3 |

This means:
- For **MATCH_CORNERS** terrain sets, the terrain signature for a painted cell is identical to PentaTile's existing 4-bit corner `compute_mask` return value — the peering bits ARE the mask.
- For **MATCH_SIDES** terrain sets, the terrain signature matches the 4-bit edge mask topology used by Wang2Edge/Min3x3.
- For **MATCH_CORNERS_AND_SIDES**, 8 bits match Blob47Godot's raw Moore mask (before the 256→47 collapse).

### 6.4 Variation Candidate Discovery (VAR-01)

**What Godot provides:**
- Multiple alternative tiles per atlas coordinate, each with own `TileData.probability`
- `TileSetAtlasSource.get_alternative_tiles_count()` / `get_alternative_tile_id()` for enumeration

**What PentaTile could do:**

1. When `mask_to_atlas()` returns an `AtlasSlot` with `atlas_coords`, enumerate alternatives at those coords
2. Build a weighted candidate list from `TileData.probability` values
3. Use deterministic hash (PITFALLS.md §2) to select one
4. Pack `alt_id | transform_flags` into `alternative_tile`

**No terrain required for basic variation.** Variation can ship as a per-layout feature that works on any TileSet: just pick from available alternatives at the dispatched atlas coord. Terrain-aware variation (narrowing candidates to those that match the terrain signature) builds on top.

### 6.5 Per-Strip Terrain Banks (Penta MULTITERR-06)

Penta's AUTO_STRIP already supports per-strip dispatch. If each strip represents a different terrain:
- The existing `resolve_strip_modes()` + `resolve_display_strip()` infrastructure maps to terrain disambiguation
- Each strip's synthesis runs independently (already supported by `synthesize_strip(strip_index=i)`)
- The candidate index just needs to map `(terrain_set, terrain)` → `strip_index`

This is the lowest-friction terrain path for Penta layouts: terrain banks are strips, and strip dispatch already works.

---

## 7. Godot API Surfaces That PentaTile Should NOT Use

Per TRIAGE-04 scope firewall + MULTITERR-07:

| Godot API | Why NOT |
|-----------|---------|
| `set_cells_terrain_connect()` / `set_cells_terrain_path()` | Mutates cells under Godot's solver, not PentaTile's layout library. Would break the paint→paint flow. |
| `TileSet.set_terrain_set_mode()` / `add_terrain()` / `add_terrain_set()` | These are editor-authoring APIs. PentaTile reads terrain metadata, never writes it at runtime. |
| `TileMapLayer.notify_runtime_tile_data_update()` | Not needed — PentaTile controls paint timing via `_update_cells()` + `_queue_rebuild()`. |
| `TileMapLayer._tile_data_runtime_update()` | Not needed — PentaTile sets cells directly with `set_cell()`, doesn't mutate in-flight TileData. |

---

## 8. API Gaps / Godot Limitations

### 8.1 No "Terrain" Signal

Godot has no `terrain_changed` signal. PentaTile detects terrain changes implicitly because any `set_cell()` fires `_update_cells()`, which triggers the full paint pipeline. Terrain metadata changes (editing TileData in the editor) should fire `Resource.changed` on the TileSet, which PentaTile already monitors via `tile_set.changed`.

### 8.2 Peering Bits PackedInt32Array Format

`TileData.terrain_peering_bits` returns a `PackedInt32Array` where:
- Array length = number of terrains in the terrain set
- Index = terrain index, value = 8-bit bitmask
- `-1` in a bit position means "ignore"

**Important nuance:** The peering bits encode what the TILE NEEDS from its neighbors, not what the CELL IS. This is an authoring contract: "I'm a grass tile and I need grass neighbors at these positions." PentaTile needs to INVERT this for dispatch: "this display cell has neighbors at these positions; which tile matches?" The candidate index handles this inversion naturally by building a lookup keyed on mask signature.

### 8.3 Alternative Tiles Do Not Inherit Properties

Per Godot docs: "When creating an alternative tile, none of the properties from the base tile are inherited." This means alternative tiles at the same atlas coordinate may have different `terrain_set`/`terrain`/`probability` — which is the desired behavior for variation. But it also means alternatives must be explicitly terrain-tagged; PentaTile cannot assume alt-1 has the same terrain as alt-0.

### 8.4 No Programmatic Way to "Pick Weighted Tile"

Godot's scatter/paint system picks weighted tiles in the editor, but this is editor-only code. There is no `TileSetAtlasSource.pick_weighted_tile(mask)` API. PentaTile must implement weighted random pick itself — which it already designed per VAR-01's deterministic hash + `rand_weighted()` recipe.

---

## 9. Recommendations for v0.3 Implementation

### 9.1 Terrain-Type Enum / Layout Virtual

Add a virtual to `PentaTileLayout`:

```gdscript
# Returns the Godot TerrainMode this layout best maps to, or -1 if terrain-agnostic
func terrain_mode() -> int:
    return -1  # default: terrain-agnostic
```

Subclass overrides:
- Blob47Godot → `TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES`
- DualGrid16/Wang2Corner/PixelLab → `TileSet.TERRAIN_MODE_MATCH_CORNERS`
- Wang2Edge/Min3x3 → `TileSet.TERRAIN_MODE_MATCH_SIDES`
- Penta → `TileSet.TERRAIN_MODE_MATCH_CORNERS` (4-bit subset of 8-bit Moore)

This lets PentaTileMapLayer validate that the bound TileSet's terrain set mode is compatible with the active layout.

### 9.2 Terrain Mask Signature → Layout Mask Conversion

Each layout needs to know how to convert Godot peering bits into its own mask space. The key insight: for 4-bit corner layouts, peering bits 0/2/5/7 (TL/TR/BL/BR) are equivalent to the layout's mask bits (TL=1/TR=2/BL=4/BR=8). For 4-bit edge layouts, peering bits 1/3/4/6 (Top/Left/Right/Bottom) map to edge mask bits (T=1/L=4/R=8/B=4 depending on convention).

A helper on the layout base class could do this mapping:

```gdscript
func peering_to_mask(peering_bits: int, terrain_id: int) -> int:
    # Default: extract the peering value for `terrain_id` and pass through
    # Subclasses override to remap bit positions
    return peering_bits  # 8-bit Moore pass-through for Blob47Godot
```

### 9.3 Variation as an Independent Feature

Variation (VAR-01) is NOT coupled to terrain. A `PentaTileMapLayer` can do variation pick on any TileSet with alternatives — just enumerate alt-tiles at the dispatched atlas_coords and pick one via the deterministic hash. Terrain just adds a filter: "only pick from alternatives whose terrain matches."

This suggests implementation order:
1. Variation first (lowest dependency): add `variation_seed` to `PentaTileMapLayer`, enumerate alt-tiles in `_paint_with_slot()`, deterministic hash
2. Terrain candidate index second: builds the transient index, adds terrain signature to `_paint_via_layout()`
3. Terrain-filtered variation third: combine the two — index + alt-tile pick within terrain-matching candidates

### 9.4 Single-Grid First

Per MULTITERR-04, single-grid layouts should get terrain support first. The reasoning:
- Single-grid already uses `_mark_affected_single_grid_cells()` (8 Moore neighbors)
- The terrain signature at a single-grid display cell is its own terrain + neighbors' terrains
- Godot's terrain peering bits operate on exactly the same 8-Moore neighborhood
- The mapping is 1:1: peering bits → raw Moore mask → layout-specific mask → atlas slot

Dual-grid terrain (MULTITERR-05) requires four-corner terrain signatures per display cell, which is a strictly harder problem (2×2 logic cells → one display cell's terrain composition).

---

## 10. Summary Table: Godot API × PentaTile v0.3 Feature

| v0.3 Feature | Godot APIs Needed | Already In PentaTile? | New Code Required |
|--------------|-------------------|----------------------|-------------------|
| Terrain-aware dispatch | `TileData.get_terrain_set()`, `get_terrain()`, `get_terrain_peering_bits()` | No | `_sample_logic_terrain()` + terrain signature in `_paint_via_layout()` |
| Candidate index | `TileSetAtlasSource.get_tiles_count()`, `get_tile_id()`, `get_alternative_tiles_count()`, `get_alternative_tile_id()` | `get_tile_data()` exists, alt enumeration is new | `_build_candidate_index()` (transient, per-rebuild) |
| Variation (VAR-01) | `TileData.probability`, `get_alternative_tiles_count()`, `get_alternative_tile_id()` | `_pack_alternative()` exists | `_pick_weighted_alternative()` + `variation_seed` export |
| Penta terrain banks (MULTITERR-06) | `resolve_strip_modes()`, `synthesize_strip()` | Both exist | Map terrain→strip in candidate index |
| Terrain-mode validation | `TileSet.get_terrain_set_mode()` | No | `validate_terrain_compat()` on layout |
| Multi-source output (MULTITERR-03) | `TileSet.get_source_count()`, `get_source_id()` | `_resolve_source_id()` exists but returns single source | Extend `AtlasSlot` or paint path to carry `source_id` |

---

## 11. Identity Guardrail Check

All recommendations respect PentaTile's identity constraints:

| Constraint | Status |
|-----------|--------|
| No terrain peering metadata for output | Satisfied — terrain metadata is READ (input) only, never WRITTEN by PentaTile |
| No Godot terrain solver calls for generated visuals | Satisfied — MULTITERR-07 blocks `set_cells_terrain_connect/path` for output |
| No permanent coordinate caches | Satisfied — candidate index is transient, built per rebuild, discarded |
| No watcher/signal-fanout systems | Satisfied — existing `Resource.changed` + `_queue_rebuild` coalescer used |
| No custom paint API parallel to set_cell() | Satisfied — user still paints via native `set_cell()` |
| No EditorInspectorPlugin | Satisfied — no new editor UI proposed |
| No version/schema versioning machinery | Satisfied — terrain metadata already lives in TileData, not PentaTile resources |

---

## Sources

- Godot 4.6 TileMapLayer API: `class_tilemaplayer.html` (fetched 2026-04-30)
- Godot 4.6 TileSet API: `class_tileset.html` (fetched 2026-04-30)
- Godot 4.6 Using TileSets tutorial: `using_tilesets.html` (fetched 2026-04-30)
- Godot 4.6 Using TileMaps tutorial: `using_tilemaps.html` (fetched 2026-04-30)
- PentaTile source: `addons/penta_tile/**/*.gd` (13 files, read 2026-04-30)
- PentaTile planning: `.planning/REQUIREMENTS.md` MULTITERR-01..08, VAR-01, TRIAGE-01..06
- PentaTile research: `.planning/research/layouts/MASK_UNIFICATION.md`, `.planning/research/PITFALLS.md`
