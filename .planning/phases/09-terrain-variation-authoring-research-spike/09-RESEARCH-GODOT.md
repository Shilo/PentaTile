# Phase 09: Godot & Addons Research — Terrains & Variations

**Audit date:** 2026-04-30
**Sources audited:** Godot 4.6 docs (using_tilemaps, using_tilesets, class_ref TileData), TileMapDual v5.0.2, TileBitTools (dandeliondino/MIT), BetterTerrain v0.2

---

## Godot Native Terrains & Variations

### Terrain System Architecture

Godot 4's terrain system replaces the Godot 3.x autotile system with a more powerful set of properties on `TileData`. Terrains are **not** a distinct tile type — any atlas tile can be assigned terrain metadata and painted in terrain mode or as a single tile.

**Terrain sets** group related terrains (e.g., "grass", "dirt", "water"). Each terrain set has:
- A **mode** that controls how terrains match neighbors: `Match Corners and Sides` (2×2, 8 bits), `Match Corners` (3×3, 4 bits), or `Match Sides` (3×3 minimal, 4 bits).
- One or more **terrains** within the set, each with an ID (0-based).

### Per-Tile Terrain Properties

Each `TileData` carries three terrain-related properties:

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `terrain_set` | int | -1 | Which terrain set this tile belongs to |
| `terrain` | int | -1 | Which terrain within the set (the "center" terrain) |
| `probability` | float | 1.0 | Relative weight when Godot picks randomly among terrain-matching tiles |

**Peering bits** are set per-tile per-direction via `set_terrain_peering_bit(peering_bit: CellNeighbor, terrain: int)`. Each of the 8 neighbor directions (or 4 for Corner-only/Side-only modes) stores a terrain ID. `-1` means "empty space" — the tile will only appear if that neighbor cell is empty (or non-terrain). The 8 `CellNeighbor` directions are:
- `TOP_LEFT_CORNER` (0), `TOP_SIDE` (1), `TOP_RIGHT_CORNER` (2)
- `RIGHT_SIDE` (3), `BOTTOM_RIGHT_CORNER` (4)
- `BOTTOM_SIDE` (5), `BOTTOM_LEFT_CORNER` (6), `LEFT_SIDE` (7)

### How Godot Evaluates Terrains at Runtime

When painting in **Connect** or **Path** mode, Godot's editor (NOT exposed as a public runtime API) performs a two-stage resolution:

1. **Candidate selection:** For each painted cell, scan the terrain set for all tiles whose peering bits match the actual neighbor cell terrains. Tiles with `probability > 0` are included; tiles with mismatched peering bits are excluded.
2. **Random weighted selection:** From matching candidates, select one using weighted random based on `probability`. Godot's `probability` is a **float** (default 1.0) — this means multiple candidates can have 1.0 and Godot will uniformly random among them.

**Critical architectural note:** Godot's terrain solver is **editor-only and closed-source** (C++ engine code, not exposed to GDScript). There is no public `resolve_terrain()` API on `TileMapLayer` or `TileSet`. The runtime (project) gets pre-resolved cells from the editor save data. `_update_cells()` does NOT run terrain logic — it only applies transforms to cells already placed.

This is the key reason PentaTile has always bypassed Godot's terrain system: you cannot call Godot's terrain solver at runtime from GDScript. PentaTile's approach of reading `TileData` terrain metadata as **authoring/indexing input** (the "per-tile flag" approach used for `penta_role` custom data) while keeping its own deterministic solver is architecturally unavoidable — there is no callable Godot solver to delegate to.

### Variation via Alternative Tiles + Probability

Godot's variation system is built on two orthogonal mechanisms:

1. **Alternative tiles** — Each atlas tile can have multiple "alternatives" (different `flip_h`, `flip_v`, `transpose`, `modulate`, `material`, `z_index`). Alternatives share the same source image region but with different transforms or rendering properties. Alternatives have their own `probability`, independent from the base tile.
2. **Probability** — When the terrain solver has multiple matching candidates (including alternatives), it picks via weighted random. Probabilities are **relative**, not absolute. A tile with `probability=2.0` is twice as likely as one with `probability=1.0`.

**Godot does NOT auto-pick alternatives at `set_cell()` time.** `set_cell()` always places the exact alternative specified (or alt_id=0 if no alternative). The weighted random selection only happens inside the **editor terrain painter** (Connect/Path modes). For runtime random variation, you must implement your own `rand_weighted()` call — exactly what PentaTile already does.

### Practical Implications for PentaTile

- **`terrain_set` and `terrain`** are suitable as authoring-time metadata: an artist tags tiles in the Godot editor ("this tile is Grass", "this tile is Water"), and PentaTile reads those tags at runtime via `TileData.terrain` / `TileData.terrain_set`.
- **`probability`** is a read-only float on `TileData` that PentaTile already uses as a weight in its own deterministic `rand_weighted()`.
- **Peering bits** (`get_terrain_peering_bit()`) are the authoring language for "this tile expects neighbor cell N to have terrain T." PentaTile can read these to understand which terrain boundaries are expected — but PentaTile must still run its own solver, since Godot's is editor-only.
- **Multi-terrain in a single TileSet** is fully supported: a single `TileSetAtlasSource` can have tiles with different `terrain` values. PentaTile needs to scan all tiles from all sources, index by terrain, and select from the index.

---

## TileMapDual Architecture

### Overview

TileMapDual (pablogila, MIT) is the closest Godot addon to PentaTile's architecture — dual-grid autotiling with the world layer hidden and display layers visible. It supports Square, Isometric, Half-Offset, and Hex grid shapes.

**Core classes:**
- `TileMapDual` — extends `TileMapLayer`, the main node. Uses ghost shader to hide world layer.
- `Display` — manages up to 2 child `DisplayLayer` nodes (different grid shapes need different display layouts).
- `DisplayLayer` — a `TileMapLayer` child that renders the computed display tiles.
- `TerrainDual` — reads TileSet, builds terrain rules.
- `TerrainLayer` — one per display layer, stores a rule trie and applies it.
- `TileCache` — caches computed world cell neighborhoods.
- `TileSetWatcher` — watches TileSet changes and triggers rebuild.

### Terrain Data Model

TileMapDual reads Godot's native terrain metadata directly:

```
TileMapDual world layer
  └─ TileSet (with terrain peering bits on TileData)
      └─ TerrainDual.read_tileset(tile_set)
          ├─ terrains: Dictionary[int, Dictionary]  # terrain_id → {sid, tile}
          └─ layers: Array[TerrainLayer]
              └─ _rules: trie (peering_bit_sequence → {mappings: [{sid, tile, prob}]})
```

**Key design decisions:**

1. **Only terrain_set 0 is supported** — any tile with `terrain_set != 0` triggers a warning and is skipped. This is a hard limitation: multi-terrain scenarios must co-exist in a single terrain set, using peering bit differences to distinguish.

2. **`data.terrain` as "terrain type ID"** — the terrain value on each tile is used as a key to lookup which default tile to place when painting. `terrains[terrain]` stores the first tile found with that terrain ID. `draw_cell(cell, terrain=1)` places the default tile for that terrain.

3. **Peering bits drive the rule trie** — each `TerrainLayer` has a `terrain_neighborhood` (which CellNeighbor directions to check). For Square grids, it checks the 4 corners: TOP_LEFT_CORNER, TOP_RIGHT_CORNER, BOTTOM_LEFT_CORNER, BOTTOM_RIGHT_CORNER. For each tile, it reads the peering bits for those directions, forms a tuple (e.g., `[0, 1, -1, -1]`), and stores it in the trie.

4. **Empty cells** — Normalized to terrain 0. `apply_rule()` coerces `-1` (empty) to `0` before trie lookup.

5. **Probability for variation** — `data.probability` is stored per mapping as `mapping.prob`. During resolution, `apply_rule()` collects all matching mappings (multiple tiles can match the same peering-bit sequence), extracts their probabilities, and does `rand_weighted()` with deterministic seeding (`hash(str(cell) + str(global_seed))`).

6. **Trie-based rule application** — When applying rules, `TerrainLayer.apply_rule(terrain_neighbors, cell)` walks the trie. For each step:
   - If the branch for the neighbor's terrain exists, follow it
   - Otherwise, try branch for terrain 0 (empty/normalized)
   - If neither exists, return TILE_EMPTY
   - At leaf node, return weighted random from `node.mappings`

### Variation Handling

TileMapDual's variation system is a **weighted random pick among all tiles matching the same peering-bit signature**:

```gdscript
# In TerrainLayer.apply_rule():
rand.seed = hash(str(cell) + str(global_seed))
index = rand.rand_weighted(weights)
return node.mappings[index]
```

This means:
- Multiple tiles with identical peering bits but different source images become visual variations.
- Variation is deterministic per cell (seeded by cell coordinates + global_seed).
- `global_seed` is hardcoded to 707 — any rebuild produces identical results.
- No hierarchical variation (no "pick tile, then pick alternative" — alternatives map to separate trie entries).

**Key difference from PentaTile:** TileMapDual uses the trie directly rather than pre-computing a mask-to-atlas table. PentaTile's `mask_to_atlas()` is faster (O(1) lookup) but less flexible (one tile per mask). TileMapDual's trie walk is O(depth) but supports multiple tiles per peering-bit tuple natively.

### How TileMapDual Avoids/Mitigates Multi-Terrain Complexity

1. **Hard limit to terrain_set 0** — refuses to handle multiple terrain sets.
2. **All terrains share one peering-bit namespace** — there's no concept of "terrain A peers with terrain B at edge X." Peering bits are just terrain IDs; any terrain can peer with any other.
3. **No transition-tile concept** — TileMapDual does not special-case terrain boundaries. If a tile's peering bits match the actual neighbor terrains, it's a candidate.
4. **No multi-terrain painting modes** — `draw_cell(cell, terrain)` just stamps one tile. There's no "paint terrain boundary" tool.

---

## TileBitTools Architecture

### Overview

TileBitTools (dandeliondino, MIT) is a pure **editor authoring tool** — it does not solve terrains at runtime. Its purpose is to define, visualize, and export bitmask-to-terrain mappings for atlas tiles.

**Core classes:**
- `BitData` (Resource) — the core data model for terrain bits
- `EditorBitData` — editor-time extension of BitData
- `TemplateBitData` — template format (saved/loaded resources)
- `TemplateTagData` — metadata tags for templates

### Terrain Data Model

`BitData` stores terrain information in a dictionary keyed by atlas coordinates:

```
_tiles[coord: Vector2i] = {
    TERRAIN: int,           # terrain index at this tile
    PEERING_BITS: {         # Dictionary of CellNeighbor → terrain_index
        TOP_LEFT_CORNER: 0,
        TOP_SIDE: 0,
        ...
    }
}
```

The `TerrainBits` enum extends `TileSet.CellNeighbor` with a synthetic `CENTER=99` value, allowing the center tile's own terrain to be treated identically to peering bits in iteration:

```gdscript
enum TerrainBits {
    CENTER=99,
    TOP_LEFT_CORNER=TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
    ...
}
```

### Key Design Decisions

1. **Terrain-mode-aware neighbor lists** — `CellNeighborsByMode` maps each `TileSet.TerrainMode` to the relevant CellNeighbor directions. Functions like `get_terrain_bits_list(include_center_bit)` return the list filtered by the current terrain_set's mode.

2. **Frequency-based terrain renumbering** — `TemplateBitData._get_terrain_mapping()` sorts terrains by frequency (most-used terrain → 0, second-most → 1, etc.). This normalizes terrain indices across different user-painted bitmasks so templates are comparable.

3. **Built-in + custom template support** — Templates have `version`, `template_name`, `template_description`, `template_terrain_count`, `_custom_tags`, and an associated sample image. A tag system allows metadata annotations.

4. **Project Settings for terrain colors** — Up to 4 terrain colors can be configured via `ProjectSettings` (`tile_bit_tools/colors/terrain_0X`). Beyond 4, falls back to an `additional_colors` array.

5. **Pure data, no solver** — TileBitTools never writes to a `TileMapLayer`. It defines which atlas tile corresponds to which terrain bitmask, but leaves the actual rendering to other tools (or manual authoring). This is fundamentally different from both PentaTile and TileMapDual, which are runtime solvers.

### Variation Handling

TileBitTools does **not** handle variations at all. It is purely concerned with mapping atlas tiles to terrain bits. The `probability` field on `TileData` is never read or used by TileBitTools.

### Relevance to PentaTile

TileBitTools' value to PentaTile is **data, not architecture**:
- The slot tables for Tilesetter Blob47 and Tilesetter Wang15 were transcribed from TileBitTools templates (Phase 3 D-86).
- The concept of terrain-coloring for editor visualization could inform PentaTile's future editor feedback.
- The `CENTER` enum trick (treating a tile's own terrain as a "peering bit" for unified iteration) is a useful pattern PentaTile could adopt for terrain-aware mask computation.
- The frequency-based terrain renumbering is irrelevant to PentaTile (PentaTile does not renumber user terrains).

---

## BetterTerrain Architecture

### Overview

BetterTerrain (Portponky, MIT) is a **drop-in replacement for Godot 4's built-in terrain system**, providing more versatile autotiling. It works with any existing `TileMapLayer`/`TileSet` by storing all terrain metadata in Godot's `Object.set_meta()` system, bypassing the native `TileData.terrain`/`terrain_set` properties entirely.

**Core files:**
- `BetterTerrain.gd` (1160 LOC) — static functions class, the main API
- `BetterTerrainData.gd` — geometry/neighbor data helpers
- `Watcher.gd` — change detection for TileSet cache invalidation
- `TerrainPlugin.gd` — editor plugin integration
- `BetterTerrain.cs` — C# bindings (out of scope for PentaTile's GDScript-only stack)

### Terrain Data Model

BetterTerrain stores **all** terrain information in Object metadata under the key `_better_terrain`:

```gdscript
# TileSet-level metadata
ts.set_meta("_better_terrain", {
    terrains = [
        [name, color, type, categories, icon],  # per-terrain
        ...
    ],
    decoration = ["Decoration", Color.DIM_GRAY, TerrainType.DECORATION, [], {path="icon.svg"}],
    version = "0.2"
})

# TileData-level metadata
td.set_meta("_better_terrain", {
    type = 0,           # terrain type index (or NON_TERRAIN=-2)
    symmetry = 0,       # SymmetryType enum
    0: [0, 1],          # peering direction → list of matching terrain types
    1: [0],
    ...
})
```

### Terrain Types

BetterTerrain defines four `TerrainType` values:

| Type | Description |
|------|-------------|
| `MATCH_TILES` (0) | Standard tile-matching: compares neighbor terrains directly |
| `MATCH_VERTICES` (1) | Vertex-based (Wang-style): checks vertex consistency, not individual cells |
| `CATEGORY` (2) | Groups other terrains for composite matching; cannot have peering bits |
| `DECORATION` (3) | Fills empty cells by matching adjacent filled cells |

### How BetterTerrain Handles Multiple Overlapping Terrains

This is BetterTerrain's key architectural advantage over both Godot native and TileMapDual. Each terrain can be assigned a list of `CATEGORY` terrains it belongs to:

```gdscript
# Terrain "Mud" can match as "Ground" category
add_terrain(ts, "Mud", Color.BROWN, TerrainType.MATCH_TILES, [GROUND_CATEGORY_ID])
add_terrain(ts, "Ground", Color.GRAY, TerrainType.CATEGORY, [])
```

**Peering bits store lists, not single values:**

```gdscript
# In the tile metadata, peering direction 0 (TOP_LEFT) matches terrains [0, 1]
td_meta[0] = [0, 1]  # This tile peers with terrain 0 OR terrain 1 at TOP_LEFT
```

During cache building, each peering key's target list is expanded through the category system:
```gdscript
for k in types:  # types = Category → [terrain0, terrain1, ..., category_id]
    if _intersect(types[k], td_meta[key]):
        targets.push_back(k)
peering[key] = targets  # Now includes both individual terrains AND their categories
```

This means a tile with peering bit `[0]` matches terrain 0 AND any terrain whose categories include "can act as terrain 0." The intersection check means the tile system inherently supports **transitions between overlapping terrain groups**.

### Solver Architecture

BetterTerrain uses a **scoring system** for tile selection, NOT a fixed lookup table:

```gdscript
# _update_tile_tiles: for each candidate tile, compute a score
const reward := 3
var penalty := -2000 if apply_empty_probability else -10

for t in cache[type]:
    var score := 0
    for peering in t[3]:  # t[3] = peering dictionary
        score += reward if t[3][peering].has(types[neighbor_coord]) else penalty
    # Track best-scoring tiles
```

**Key features of the scoring approach:**
- **No strict mask-to-atlas table** — tiles can partially match and still be selected (just with lower scores).
- **Weighted random among best-scoring tiles** — `_weighted_selection_seeded()` picks from tiles that achieved the top score, using probability as weight.
- **Deterministic seeding** — `rng.seed = hash(coord)` ensures reproducibility.
- **Empty probability** — When `weight < 1.0` and `apply_empty_probability` is true, there's a chance no tile is placed (scatter effect for decoration).

### Symmetry System

BetterTerrain has an extensive symmetry system, automatically expanding tiles into rotated/reflected variants:

```gdscript
enum SymmetryType {
    NONE, MIRROR, FLIP, REFLECT,
    ROTATE_CLOCKWISE, ROTATE_COUNTER_CLOCKWISE, ROTATE_180,
    ROTATE_ALL, ALL  # All rotated and reflected forms
}
```

During cache building, tiles with non-NONE symmetry expand into multiple cache entries, each with the appropriate flags (FLIP_H=4096, FLIP_V=8192, TRANSPOSE=16384) and adjusted probability:

```gdscript
var adjusted_probability = td.probability / symmetry_order
for flags in data.symmetry_mapping[symmetry]:
    var symmetric_peering = data.peering_bits_after_symmetry(peering, flags)
    cache[type].push_back([source_id, coord, alternate | flags, symmetric_peering, adjusted_probability])
```

### Version Migration System

BetterTerrain explicitly tracks version in metadata and supports migration:

```gdscript
const TERRAIN_SYSTEM_VERSION = "0.2"

func _update_terrain_data(ts):
    if ts_meta.version == "0.0":
        # Add categories field to terrains
    if ts_meta.version == "0.1":
        # Add icon containers + default decoration data
```

**Note:** This is exactly the pattern PentaTile's CLAUDE.md "Breaking Changes Policy (HARD RULE)" forbids — no `version: int` fields, no schema-version constants. BetterTerrain operates under different constraints (public addon, needs backward compatibility).

### Multiprocessing Support

BetterTerrain supports threaded terrain solving via `WorkerThreadPool`:

```gdscript
func create_terrain_changeset(tm, paint):
    var placements := []
    placements.resize(cells.size())
    var work := func(n: int):
        placements[n] = _update_tile_deferred(tm, cells[n], ts_meta, types, _cache)
    return {
        "valid": true,
        "group_id": WorkerThreadPool.add_group_task(work, cells.size(), -1, false, "BetterTerrain")
    }
```

The changeset can be created, queued, checked (`is_terrain_changeset_ready`), and then applied (`apply_terrain_changeset`). This is relevant for large-map performance — a consideration PentaTile has explicitly deferred (demo-scale only).

### Variation Handling

BetterTerrain handles variation through its **weighted random selection** among best-scoring tiles. Unlike TileMapDual (which creates trie entries for every tile), BetterTerrain collects all tiles into a flat cache per terrain type, then scores them all against the current neighborhood. The probability from `TileData.probability` (adjusted for symmetry) is the weight in the weighted random pick.

### Comparison Table

| Feature | Godot Native | TileMapDual | TileBitTools | BetterTerrain |
|---------|-------------|-------------|-------------|---------------|
| **Runtime solver** | Editor-only C++ | GDScript trie | None (data only) | GDScript scoring |
| **Multi-terrain** | Yes (terrain sets) | Limited (set 0 only) | Data model supports | Yes (categories + list peering) |
| **Variation** | probability (editor only) | trie entries + prob | None | Best-score + prob |
| **Symmetry** | Manual alternatives | None | None | Full symmetry system |
| **Metadata storage** | Native TileData props | Native TileData props | Custom BitData Resource | Object.set_meta() |
| **Threading** | N/A (editor only) | None | None | WorkerThreadPool |
| **Version tracking** | N/A | None | Template version string | TERRAIN_SYSTEM_VERSION |
| **Grid shapes** | All Godot shapes | Square, ISO, Half-Off, Hex | Square only | Square only |
| **Solver type** | Peering-bit match | Trie lookup | N/A | Scoring + weighted random |
| **Editor plugin** | Built-in | Yes (complex, includes popups) | Yes (heavy, ~3800 LOC) | Yes |
| **LOC (runtime)** | C++ (N/A) | ~450 (core solver) | ~350 (data model) | ~1160 (full class) |

---

## Summary: Architecture Lessons for PentaTile

### What PentaTile Can Learn from Each

**From Godot Native:**
- The `terrain_set`/`terrain`/`probability`/`get_terrain_peering_bit()` API is well-suited as **authoring input**. PentaTile can read these at `_tile_data_runtime_update()` time to build its own terrain index, without ever calling Godot's inaccessible solver.
- Alternative tiles with probability are the standard Godot variation mechanism. PentaTile already has this wired (reads `probability` from `TileData`).

**From TileMapDual:**
- The **trie-based rule system** is more flexible than PentaTile's fixed `mask_to_atlas()` lookup — it naturally supports multiple tiles per terrain state. However, PentaTile's fixed table is O(1) and sufficient for the current scope.
- The **dual-grid display layer approach** is architecturally identical to PentaTile's logic/visual layer separation. PentaTile already solved this problem.
- The **single-terrain-set limitation** is a constraint PentaTile should avoid. PentaTile's `custom_data_layers` approach (e.g., `penta_role`) is already more flexible — it can read any metadata, not just `terrain_set=0`.
- TileMapDual's `draw_cell(cell, terrain)` API is cleaner than PentaTile's current `set_cell()` — it abstracts "which tile" behind "which terrain." PentaTile could adopt a similar API if multi-terrain support is added.

**From TileBitTools:**
- The **`BitData` Resource model** (terrain bits stored per atlas coordinate) could inform PentaTile's terrain indexing approach. Rather than computing masks from neighbor lookups at paint time, PentaTile could pre-build a terrain bit index at TileSet load time.
- The **CENTER=99 enum trick** (treat a tile's own terrain as a peering bit for unified iteration) is directly applicable to PentaTile's mask computation.

**From BetterTerrain:**
- The **category system** (terrains grouped into metacategories for peering) is the cleanest solution for multi-terrain autotiling seen in any Godot addon. A tile can say "I peer with ANY terrain in the Ground category" rather than listing specific terrain IDs.
- The **scoring-based solver** (reward matching peering bits, penalize mismatches) elegantly handles partial matches — no need for an exhaustive mask-to-atlas table.
- The **symmetry system** (automatic expansion into rotated/reflected variants with adjusted probability) eliminates the artist burden of creating alternatives for common rotations. This is particularly relevant for PentaTile's Penta layouts, which already use rotation flags at render time.
- The **metadata-based storage** (bypassing Godot's native terrain properties) gives maximum flexibility but requires an editor plugin for authoring. PentaTile could use a hybrid: read both native `TileData.terrain` AND custom data layers, choosing whichever the user has configured.
- The **version migration pattern** is explicitly rejected by PentaTile's no-forward-compat policy — but the actual migration logic (adding fields, removing old ones) documents real-world schema evolution.

### Key Architectural Fork Point

The research reveals a fundamental design choice for PentaTile's multi-terrain architecture:

**Option A: Mask-first (current PentaTile approach)**
- Compute a mask from neighbor lookups
- Index into a fixed `mask_to_atlas` table
- Fast, deterministic, limited to one terrain per layer
- Adding multi-terrain requires per-terrain mask tables

**Option B: Score-first (BetterTerrain approach)**
- Score all candidate tiles against the current neighborhood
- Pick best-scoring via weighted random
- Naturally handles multi-terrain, partial matches, and variations
- Slower (linear scan of all tiles) but adequate at demo-scale

**Option C: Trie-first (TileMapDual approach)**
- Build a decision trie from peering-bit signatures
- Walk trie to find matching tiles
- Fast lookup, naturally supports multiple tiles per signature
- Limited by peering-bit expressiveness (terrain_set 0 only in TileMapDual's case)

PentaTile's current `mask_to_atlas` is Option A with a single-terrain assumption. For multi-terrain + variation, Options B and C offer more natural extension paths without requiring the user to define 16 × N masks for N terrains.
