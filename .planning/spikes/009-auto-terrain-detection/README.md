---
spike: 009
name: auto-terrain-detection
type: standard
validates: "Given a TileSet with atlas sources, when terrain count is auto-computed from atlas grid dimensions and Godot native terrain sets are used for name/color storage, then multi-terrain dispatch works without a custom TerrainGroup Resource"
verdict: VALIDATED
related: [004, 006, 007]
tags: [terrain, auto-detection, godot-terrain-sets, godot-native, simplification, v0.3]
---

# Spike 009: Auto Terrain Detection

## What This Validates

Given a `TileSet` with `TileSetAtlasSource` entries whose `atlas_grid_size.y` yields terrain row counts, when `auto_setup_terrains()` creates `terrain_set 0` with `MATCH_CORNERS` mode and assigns `TileData.terrain = atlas_coords.y` per tile, then:

1. Terrain count is correctly derived from atlas height / tile_size
2. Godot native `terrain_set` stores names and colors (persisted with the .tres)
3. `TileData.terrain` equals the atlas row index
4. `_resolve_terrain_id()` can read `TileData.terrain` from a painted cell
5. User-set names/colors survive auto-rebuild via snapshot-old-names pattern
6. Multiple atlas sources stack terrain IDs sequentially

All 6 tests pass headless against Godot 4.6.2.

## Research

### TileMapDual Comparison (exact code references)

| Concern | TileMapDual v5.0.2 | Proposed PentaTile v0.3 |
|---|---|---|
| **Terrain count** | Hardcoded to 2 (bg `<any>` + fg). `new_terrain()` at `terrain_preset.gd:216` uses `tile_set.get_terrains_count(0)` to get next sequential ID | Auto-detected: `sum(atlas_grid_size.y across all sources)` |
| **Terrain set** | Set 0, MATCH_CORNERS mode | Same — set 0, MATCH_CORNERS mode |
| **Terrain → atlas mapping** | Atlas coordinate from PRESET template (hardcoded 16-tile grid per topology). Tiles get `data.terrain = bg/fg` only on `preset.bg` and `preset.fg` tiles. | Atlas COORDINATE directly encodes terrain: `TileData.terrain = atlas_coords.y` |
| **Name/color** | `tile_set.set_terrain_name(0, id, name)` at `terrain_preset.gd:231`. Terrain 0 = `"<any>"`, Color.VIOLET. Terrain 1+ = `"FG -<filename>"`, no color set. | Auto-name `"Terrain N"`, auto-color via deterministic hash. User can override via TileSet inspector. |
| **Name persistence** | Inherent — uses Godot native TileSet API, persisted to .tres | Inherent (same API). Plus snapshot-old-names pattern preserves user customizations across auto-rebuild. |
| **Multi-atlas** | All atlases share terrain IDs (1, 2, 3... per sequential call). `read_tileset()` at `terrain_dual.gd:140` iterates all sources into shared `terrains` dict. | Sequential stacking: source 0 rows 0..R0-1 → terrains 0..R0-1, source 1 rows 0..R1-1 → terrains R0..R0+R1-1 |
| **Peering bits** | Set via PRESET template: `data.set_terrain_peering_bit(neighbor, [bg, fg][i & 1])` at `terrain_preset.gd:289`. Bit decomposition of tile index in preset determines bg(0)/fg(1). | **NOT USED.** PentaTile's `compute_mask` → `mask_to_atlas` owns the render pipeline. Godot terrain metadata is storage-only. |
| **Render solver** | Trie-based terrain neighbor lookup in `TerrainLayer.apply_rule()` at `terrain_layer.gd:66`. Normalizes -1→0, falls back to terrain 0. Weighted random variation. | PentaTile's own `compute_mask` → `mask_to_atlas`. `_resolve_terrain_id()` reads `TileData.terrain` for cross-terrain mask filtering. |
| **Auto-detect trigger** | `AtlasWatcher._detect_autogen()`: one-shot deferred check — compares every atlas tile existence against texture opacity | `tile_set.changed` signal → queued `_auto_detect_terrains()`. Simpler: just count atlas grid rows. |

### Design Decision: Skip Godot Terrain Sets as Solver

TileMapDual uses Godot terrain sets for BOTH storage AND solving (peering bits → trie → render). PentaTile v0.3 should use them for **storage only** (names, colors, tile membership) and keep its own `compute_mask` → `mask_to_atlas` render pipeline. This matches the v0.2.0 architecture (no Godot solver delegation) and the MULTITERR research (Spike 007 + `.planning/research/STACK.md`).

### Design Decision: MATCH_CORNERS is the default terrain mode

All current v0.2.0 dual-grid layouts (Penta, DualGrid16, Wang2Corner, PixelLab) use corner-mask topologies. Wang2Edge and Min3x3 use edge-mask (MATCH_SIDES). For terrain auto-detection, MATCH_CORNERS is the safest default — it matches the dominant use case — and `terrain_mode()` on each layout subclass reports the correct mode for the terrain index builder.

### Approach Comparison

| Approach | Pros | Cons | Status |
|----------|------|------|--------|
| **Godot terrain sets (storage-only)** | Native inspector, .tres persistence, zero custom Resource code. TileMapDual precedent in same role. | Requires terrain_mode() and terrain index on layer to map to layout dispatch. | **CHOSEN** |
| Custom Resource (current Phase 10) | Full control, no Godot API coupling. | Overengineered: TerrainGroup Resource + terrain_index Dictionary + penta_terrain_id custom data layer + per-corner dual-grid dispatch. User must manually configure per-terrain layouts. | REJECTED |
| Auto-detect + Godot terrain sets (hybrid) | Combines auto-detection UX with Godot native storage. | Requires cleanup of Phase 10 code. | **CHOSEN (this spike)** |

## How To Run

```powershell
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script .planning/spikes/009-auto-terrain-detection/terrain_autodetect_test.gd
```

## What To Expect

All 6 tests PASS. Exit code 0.

## Investigation Trail

### Round 1: Understand TileMapDual's terrain system
- Read all 10 source files, extracted code references with line numbers
- Key finding: TileMapDual hardcodes 2 terrains (bg+fg) but `new_terrain()` pattern supports sequential IDs
- Key finding: Godot native `set_terrain_name/color` is the persistence layer

### Round 2: Initial test fails (no texture)
- `create_tile()` requires a texture on `TileSetAtlasSource`
- Fix: use `Image.create()` + `ImageTexture.create_from_image()` for programmatic test textures

### Round 3: All 6 pass
- Atlas grid detection: `src.get_atlas_grid_size().y` → row count
- `auto_setup_terrains()` is idempotent: snapshot old names before clearing, restore user-set names after
- Non-default name detection: `begins_with("Terrain ")` → auto, otherwise → user-set (preserve)
- Multi-atlas: sequential terrain ID assignment, source-by-source

## Results

**Verdict: VALIDATED.** The auto-detection approach is feasible and simpler than the current Phase 10 TerrainGroup Resource pattern.

### Key Findings

1. **No custom Resource needed.** Godot `TerrainSets` store names/colors, persist to .tres. The `TileSet` inspector panel surfaces them automatically. Users rename/recolor from the native UI.

2. **Atlas grid is the canonical terrain count.** `atlas_grid_size.y` = terrain rows per source. Sum across all sources = total terrain count. No manual configuration.

3. **`TileData.terrain = atlas_coords.y`** is the cleanest mapping. Each tile belongs to exactly one terrain (its atlas row). At render time, `_resolve_terrain_id()` reads `TileData.terrain` from the cell's atlas coords.

4. **Snapshot-before-clear pattern solves persistence.** Before clearing `terrain_set 0`, snapshot `name[id]` and `color[id]`. After recreating, restore non-default names. A name that starts with `"Terrain "` is auto-generated → safe to replace. Any other name is user-set → preserve.

5. **No peering bits needed.** PentaTile's own solver doesn't read Godot peering bits. The terrain metadata is purely for storage/organization. This avoids the complexity of setting peering bits correctly for multi-terrain scenarios (TileMapDual only handles binary bg/fg).

6. **How to wire into the existing dispatch:**
   - `_auto_detect_terrains()` runs in `tile_set` setter + on `tile_set.changed` signal
   - `_resolve_terrain_id(cell)` reads `TileData.terrain` from `source.get_tile_data(atlas_coords, 0)`
   - `compute_mask(cell, sample_fn, strip_index)` already exists (from Phase 10)
   - `mask_to_atlas(mask, strip_index)` dispatches to atlas row = terrain_id
   - For dual-grid: per-corner terrain IDs come from 4 logic cell neighbors (already in Phase 10 code)
   - For single-grid: logic cell's own terrain drives the strip
   - The existing `layout` on `PentaTileMapLayer` drives the schema for ALL terrains

### What Gets Deleted

- `addons/penta_tile/layouts/penta_tile_terrain_group.gd` — entire file
- `terrain_group: PentaTileTerrainGroup` export on `PentaTileMapLayer` 
- `_build_terrain_index()` — replaced by `_auto_detect_terrains()` + `TileData.terrain` reads
- `_terrain_index` Dictionary — no longer needed
- `_paint_dual_grid_terrain()` — simplified; terrain IDs from TileData, not separate layouts per terrain
- `PentaTileLayout.terrain_mode()` — still needed for index building but simpler (just reports the mask mode)
- `PentaTileLayout.compute_mask(_strip_index)` — simplified; strip_index = terrain_id, sampled from TileData.terrain

### LOC Estimate

**Removed:** ~400 LOC (TerrainGroup + terrain_index + per-corner dual-grid dispatch + per-terrain layout array plumbing)
**Added:** ~120 LOC (auto_detect_terrains + simplified _resolve_terrain_id + snapshot persistence)
**Net:** ~280 LOC savings

## Signal for the Build

1. **Use `tile_set.changed` signal** to trigger `_auto_detect_terrains()` — same deferred coalescer pattern as `_on_layout_changed`.
2. **Snapshot names before clearing** — the `begins_with("Terrain ")` heuristic correctly distinguishes auto from user-set names.
3. **Skip peering bit setup entirely** — PentaTile doesn't read them.
4. **Multiple atlas sources stack sequentially** — terrain IDs 0..N-1 span all sources.
5. **The sample_terrains.png (160×96, 32px tiles) correctly auto-detects as 3 terrains.**
