---
spike: 004
name: virtumap-integration-requirements
type: standard
validates: "Given VirtuMap's 6-terrain paint pipeline + slope tiles + fixture passthrough, when we map each requirement to PentaTile's current architecture, then we produce a concrete delta of new layouts/features needed with feasibility verdicts"
verdict: VALIDATED
related: [006, 007]
tags: [virtumap, multi-terrain, slope, passthrough, integration, gap-analysis]
---

# Spike 004: VirtuMap Integration Requirements

## What This Validates

**Given** VirtuMap's current terrain-paint pipeline (6 terrain sets, 4 canonical layers, `set_cells_terrain_connect` + `set_cell` dispatch),
**When** we map each VirtuMap API call and architectural dependency to PentaTile's v0.2.0 surface,
**Then** we produce a concrete delta: what PentaTile must add, what VirtuMap must change, and feasibility verdicts for each gap.

## Research

Source material read in full:
- `VirtuMap\.planning\references\PentaTile_Integration_Research.md` — Gap analysis
- `VirtuMap\.planning\references\PentaTile_Implementation_Plan.md` — 4-phase plan
- `VirtuMap\.planning\references\PentaTile_Detailed_Implementation_Plan.md` — Engine enhancement spec
- `VirtuMap\addons\virtumap\core\pipeline\virtumap_render_constants.gd` — Terrain set indices
- `VirtuMap\addons\virtumap\core\model\virtumap_render_batch.gd` — Batch payload structure
- `VirtuMap\addons\virtumap\core\pipeline\virtumap_pipeline.gd:2785-3041` — `_run_render` cell classification
- `VirtuMap\addons\virtumap\editor\virtumap_editor_generation_adapter.gd:195-261` — Editor dispatch
- `VirtuMap\addons\virtumap\runtime\virtumap_runtime_generation_adapter.gd:123-176` — Runtime dispatch
- `PentaTile\addons\penta_tile\penta_tile_map_layer.gd` — Full paint pipeline

### VirtuMap Dispatch Model

VirtuMap's render pipeline produces `VirtuMapRenderBatch` objects with two parallel dispatch paths:

| Path | API Call | Cell Types |
|------|----------|------------|
| `terrain_cells` | `layer.set_cells_terrain_connect(cells, terrain_set, terrain, ignore_empty)` | WALL, PLATFORM, BEAM, SLOPE |
| `atlas_cells` | `layer.set_cell(pos, source_id, atlas_coord, alternative)` | FLOOR, BULKHEAD, fixtures, decor |

6 terrain sets: FLOOR=0, WALL=1, HULL=2, SLOPE=3, PLATFORM=4, BEAM=5

4 canonical layers: BackgroundLayer, StructureLayer, FixtureLayer, OverlayLayer

### PentaTile v0.2.0 Dispatch Model

PentaTile replaces both paths with a single `set_cell(logic_coord, source_id, atlas_coords)` call. The `_update_cells()` callback:
1. Samples the logic layer at the painted coord's position
2. Computes a mask via `layout.compute_mask()`
3. Dispatches to a visual child layer via `layout.mask_to_atlas()`

## Investigation Trail

### Iteration 1: Direct Mapping Attempt

Mapped each VirtuMap API call to its PentaTile equivalent:

| VirtuMap Call | PentaTile Equivalent | Status |
|---|---|---|
| `set_cells_terrain_connect(cells, 1, 0)` | `layer.set_cell(pos, 0, Vector2i(0, 1))` | **Requires multi-strip** |
| `set_cells_terrain_connect(cells, 3, 0)` | `layer.set_cell(pos, 0, Vector2i(0, 1))` + slope layout | **Requires slope layout** |
| `set_cell(pos, 0, atlas_coord)` | `layer.set_cell(pos, 0, atlas_coord)` | **Passthrough needed** |
| `set_cell(pos, -1)` (erase) | `layer.erase_cell(pos)` | **Works** |

The WALL/FLOOR distinction currently encoded in VirtuMap's `terrain_cells` vs `atlas_cells` split must become a **multi-strip** or **terrain-ID** concept in PentaTile. VirtuMap paints `Vector2i(0, tile_index)` at logic coords — PentaTile needs to know which strip (terrain) that tile belongs to.

### Iteration 2: Gap Classification

Classified each gap into one of four categories:

| Gap | PentaTile Architecture | Category |
|-----|----------------------|----------|
| Multi-terrain dispatch | `PentaTileLayoutPenta` AUTO_STRIP already does per-strip dispatch | **Needs terrain-ID injection** |
| Slope autotiling | No slope mask system exists | **New layout subclass** |
| Atlas passthrough | `_update_cells` processes all painted cells | **Needs source-ID filtering** |
| Precedence groups | Single visual child layer | **Needs multi-layer output** |
| Dual-grid offset for passthrough | `_primary_layer` offset = `-tile_size/2` | **Needs passthrough layer** |
| `set_cells_terrain_connect` bulk API | PentaTile uses per-cell `set_cell` | **Performance concern at scale** |
| Collision on all layers | PentaTile supports generated collision | **Works** |
| Editor UndoRedo for bake | PentaTile rides native API | **No change needed** |
| Multi-batch per layer | Single-layer single-TileSet model | **Needs multi-source support** |

### Iteration 3: Feasibility Analysis

Scored each gap on implementation difficulty (1-10) and VirtuMap dependence (MUST/COULD):

| Requirement | Feasibility | Complexity | Verdict |
|---|---|---|---|
| Multi-terrain strips | Penta AUTO_STRIP already solves per-strip dispatch; needs terrain-ID → strip-index mapping injected into `set_cell` | 4/10 | **Feasible — extend existing pattern** |
| Slope layout | Requires `PentaTileLayoutSlope` subclass with 4-bit corner mask + slope-corner flag; fits existing single-grid pipeline | 5/10 | **Feasible — new layout subclass** |
| Atlas passthrough | Source-ID gating in `_update_cells`: skip cells with non-layout source_id; paint to offset-corrected passthrough layer | 3/10 | **Feasible — small pipeline change** |
| Precedence groups | Multiple visual child layers with per-terrain-group routing; significant pipeline refactor | 7/10 | **Hard — architecture change** |
| Bulk paint performance | Per-cell `set_cell` is the PentaTile contract; batch would need `set_cells()` + manual `_update_cells` trigger | 6/10 | **Medium — batch API addition** |
| Multi-batch per layer | Requires `source_id` on `PentaTileAtlasSlot` (currently global); source routing in `_paint_with_slot` | 5/10 | **Medium — slot schema change** |

## Results

### Verdict: VALIDATED

The gap analysis is complete and actionable. All six VirtuMap needs are technically feasible; none require rewriting the core architecture.

### Concrete Delta

**PentaTile features VirtuMap needs (ordered by dependency):**

1. **`source_id` on `PentaTileAtlasSlot`** — Currently `_resolve_source_id()` returns one global source. VirtuMap uses multiple tilesets/sources per ship. The slot must carry its own `source_id` (defaulting to the layer's global source). *Complexity: 2/10. This is a schema change to `PentaTileAtlasSlot` + `_paint_with_slot` routing.*

2. **Atlas Passthrough** — `_update_cells()` must skip autotiling for cells whose `source_id` doesn't match the layout's source. These cells paint directly to a NEW `_PentaTilePassthrough` child layer at `Vector2.ZERO` offset (avoiding the dual-grid `-tile_size/2` shift). *Complexity: 3/10. ~40 LOC in `_update_cells` + ~50 LOC for passthrough layer management.*

3. **Multi-Strip Terrain Dispatch** — When `set_cell(logic_coord, source, atlas_coord)` is called, the `atlas_coord.y` encodes the terrain strip index (as VirtuMap already plans: FLOOR=(0,0), WALL=(0,1), HULL=(0,2), etc.). PentaTile's `resolve_display_strip()` already samples neighbor strips; this just needs the painted strip index as input. The `compute_mask()` virtual gains a `strip_index` parameter so each terrain strip can have independent mask computation. *Complexity: 4/10. ~60 LOC across base class + Penta layout.*

4. **`PentaTileLayoutSlope`** — New single-grid layout subclass. 4-bit corner mask where each corner is either Solid or Empty. Slope transitions occur at diagonal masks (6, 9) where the triangle connects. Authored slope quadrant slots or Sutherland-Hodgman synthesis from IsolatedCell. *Complexity: 5/10. ~120 LOC new layout subclass + synthesis extension.* **(Blocked by spike 005 findings)**

5. **Precedence Groups** — When WALL and HULL overlap, HULL should paint OVER WALL. This requires multiple visual child layers (one per precedence group) OR a per-cell z-index scheme. The simplest v1 approach: one visual layer per terrain group + the Precedence Stack routes each painted cell to the highest-precedence group's layer. *Complexity: 7/10. ~150 LOC pipeline refactor + new `precedence_groups` layout property.* **(v2 target)**

6. **Batch Paint API** — `set_cells(positions: Array[Vector2i], source_id, atlas_coord)` that calls `set_cell` in a loop then triggers `_update_cells` once for the union of affected cells. Avoids per-cell `_update_cells` overhead for bulk operations (VirtuMap paints hundreds of cells per generation). *Complexity: 6/10. ~80 LOC new method + single `_update_cells` call.*

### What VirtuMap Must Change

1. **Replace `set_cells_terrain_connect` calls** with per-cell `set_cell` calls (already planned in their implementation docs)
2. **Structure terrains as atlas strips** — each terrain occupies a row in the Penta atlas: `atlas_coords.y = terrain_index`
3. **Remove terrain peering bit authoring** — PentaTile handles mask computation; VirtuMap just paints cell markers
4. **Adapt `ignore_empty_terrain` logic** — PentaTile's dual-grid already handles empty neighbors; may not be needed
5. **Phase 17 backfill** — The `set_cell(cell, 0, atlas_coord, 0)` fallback for terrain-connect misses becomes unnecessary with PentaTile's deterministic dispatch

### Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Per-cell `set_cell` too slow for bulk generation | Demo-scale only (~100-1k cells); PentaTile targets this scale | Batch API if proven slow |
| Multi-strip breaks dual-grid composition | Each strip independently composes to the visual grid; no cross-strip interaction needed | Strip isolation by design |
| Passthrough + dual-grid offset mismatch | Passthrough layer uses `Vector2.ZERO` offset; passthrough cells must be painted at visual coords, not logic coords | Explicit offset contract |
| Slope synthesis insufficient quality | Sutherland-Hodgman clip of BL quadrant may produce ugly diagonals | Fallback to authored slope slots; spike 005 determines quality floor |
| Source-ID proliferation breaks `_ensure_synthesized_tile_set` | Synthesis currently assumes single source; multi-source needs per-source synthesis | Synthesis extension in MULTITERR-02/03 scope |
