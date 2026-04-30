---
phase: 10-multi-terrain-variation-implementation
plan: 02
subsystem: terrain
tags: [godot, gdscript, terrain-index, terrain-dispatch, autotile]

# Dependency graph
requires:
  - phase: 10-01
    provides: PentaTileTerrainGroup Resource class, terrain_group @export skeleton
provides:
  - terrain_group setter with idempotence guard and _queue_rebuild
  - transient terrain index (_terrain_index) mapping terrain_id -> {layout, tiles}
  - _resolve_terrain_id() following D-04 resolution order
  - terrain-aware single-grid dispatch in _paint_via_layout()
  - automated terrain index correctness tests
  - automated single-grid cross-terrain boundary tests
affects:
  - 10-03 (variation)
  - 10-04 (fallback routing)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@export var terrain_group with disconnect-before-reconnect setter (matching layout pattern)"
    - "Transient Dictionary index (_terrain_index) — never persisted, never a Resource"
    - "GAP-01: scan ALL alternative tiles in terrain index building"
    - "GAP-02: exclude tiles with terrain == -1 (no center bit)"
    - "D-04 resolution order: custom data -> atlas_coords.y -> TileData.terrain -> default"
    - "D-05: atlas_coords.y encodes terrain identity at paint time"

key-files:
  created:
    - tests/terrain_index_test.gd (7 sub-tests: index building, alt scan, center bit, multi-source, reassign, resolution)
    - tests/single_grid_cross_terrain_test.gd (3 sub-tests: boundary, inner cells, null group)
    - tests/terrain_index_test.gd.uid
    - addons/penta_tile/layouts/penta_tile_terrain_group.gd.uid
  modified:
    - addons/penta_tile/penta_tile_map_layer.gd (terrain_group setter + _build_terrain_index + _resolve_terrain_id + _paint_via_layout terrain-aware dispatch)

key-decisions:
  - "Terrain index is transient Dictionary (not Resource, not persisted) — rebuilt on every terrain_group/tile_set change"
  - "terrain_group setter follows layout setter pattern exactly: idempotence, disconnect-before-reconnect, _queue_rebuild"
  - "Null terrain_group preserves v0.2.0 single-layout behavior unchanged"
  - "_resolve_terrain_id resolution order: custom data -> atlas_coords.y -> TileData.terrain -> 0 (D-04)"
  - "compute_mask receives terrain_id as strip_index for cross-terrain neighbor filtering (D-10)"

requirements-completed: []

# Metrics
duration: 45min
completed: 2026-04-30
---

# Phase 10 Plan 02: Terrain Index + Single-Grid Dispatch Summary

**Terrain index building and terrain-aware single-grid dispatch — one PentaTileMapLayer renders multiple terrains with correct boundary transitions via D-04 resolution and D-10 cross-terrain mask filtering.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-30
- **Completed:** 2026-04-30
- **Tasks:** 2 (TDD)
- **Files modified:** 1 (modified) + 4 (created)

## Accomplishments

- `terrain_group: PentaTileTerrainGroup` @export property with idempotence-guarded setter wired to `_build_terrain_index()` and `_queue_rebuild()`
- Transient `_terrain_index` Dictionary mapping terrain_id to `{layout, tiles}` — scanned across all TileSetAtlasSources, all alternative tiles (GAP-01), excluding center-bit-less tiles (GAP-02)
- `_resolve_terrain_id(cell)` implementing D-04 resolution order: custom data `penta_terrain_id` → atlas_coords.y (D-05) → TileData.terrain → default 0
- Terrain-aware `_paint_via_layout()` branching: when `terrain_group != null`, resolves terrain, looks up terrain's layout, recomputes mask with cross-terrain filtering via `strip_index`
- Null terrain_group path completely unchanged from v0.2.0 — all 17 existing tests remain green

## Task Commits

Each task was committed atomically (TDD: RED → GREEN → REFACTOR):

1. **Task 1 RED** - `bf616f0` (test): add failing test for terrain_group setter and _build_terrain_index()
2. **Task 1 GREEN** - `81b6896` (feat): implement terrain_group setter and _build_terrain_index()
3. **Task 2 RED** - `96cfed7` (test): add failing tests for _resolve_terrain_id and cross-terrain dispatch
4. **Task 2 GREEN** - `c38431a` (feat): implement _resolve_terrain_id and terrain-aware single-grid dispatch
5. **Task 2 REFACTOR** - `3b30082` (refactor): remove debug prints from terrain_index_test.gd

## Files Created/Modified

- `addons/penta_tile/penta_tile_map_layer.gd` — Added terrain_group @export setter (~20 LOC), _build_terrain_index() (~45 LOC), _resolve_terrain_id() (~35 LOC), _on_terrain_group_changed() (~5 LOC), modified _paint_via_layout() for terrain-aware dispatch (~30 LOC delta)
- `tests/terrain_index_test.gd` — 7 automated sub-tests covering: two-terrain index building, null terrain_group, alternative tile scanning (GAP-01), center bit exclusion (GAP-02), multi-source scanning, reassign rebuild, terrain ID resolution
- `tests/single_grid_cross_terrain_test.gd` — 3 automated sub-tests: cross-terrain boundary dispatch, single-terrain inner cells, null terrain_group fallback
- `tests/terrain_index_test.gd.uid` — Godot UID sidecar
- `addons/penta_tile/layouts/penta_tile_terrain_group.gd.uid` — Godot UID sidecar for terrain group resource

## Decisions Made

- Terrain index is a transient `Dictionary[int, Dictionary]` — never persisted, never a Resource. Rebuilt on every terrain_group/tile_set change. The `tiles` array stores atlas coords (stable), not TileData references (transient).
- `terrain_group` setter follows the existing `layout` setter pattern: idempotence guard, disconnect-before-reconnect on `Resource.changed`, `emit_changed`, `_queue_rebuild`.
- `_resolve_terrain_id()` resolution order per D-04 prioritizes the most specific source: custom data layer (user-authored override) → atlas_coords.y (paint-time encoding, D-05) → TileData.terrain (Godot native) → 0 (default terrain).
- `compute_mask()` receives `terrain_id` as the `strip_index` parameter (D-10) — layouts' mask computation uses this to filter neighbors by terrain, making Wall cells see Floor neighbors as "empty."
- Null terrain_group preserves single-layout v0.2.0 behavior — setter returns early, index is cleared, paint_via_layout skips the terrain-aware branch entirely.
- `penta_terrain_id` custom data layer is user-authored (not auto-created) — matches the existing `penta_role`/`penta_lock_rotation` pattern. `_resolve_terrain_id()` handles the case where the layer doesn't exist via `typeof` guard.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed terrain_set ordering in _build_tile_set_simple — Godot requires terrain_set >= 0 before setting terrain**
- **Found during:** Task 1 RED phase — terrain index test helper
- **Issue:** Setting `td.terrain = 0` before `td.terrain_set = 0` caused Godot to reject the terrain assignment with `Condition "terrain_set < 0 && p_terrain != -1" is true`, leaving tiles with terrain=-1
- **Fix:** Set `td.terrain_set = 0` before `td.terrain = terrain_id` in both `_build_tile_set_simple` and `_build_tile_set_multi_alt` helpers, plus add `ts.add_terrain_set(0)` to register the terrain set with the TileSet
- **Files modified:** tests/terrain_index_test.gd
- **Committed in:** bf616f0 (Task 1 RED commit — fixed before GREEN implementation)

**2. [Rule 3 - Blocking] PentaTileTerrainGroup class_name not resolvable in headless — missing .uid file**
- **Found during:** Task 1 GREEN phase — Godot could not load penta_tile_map_layer.gd
- **Issue:** `PentaTileTerrainGroup` class_name could not be found in the current scope at parse time
- **Fix:** Preloaded `_TerrainGroupScript` constant in penta_tile_map_layer.gd; ran `godot --headless --import` to generate `penta_tile_terrain_group.gd.uid`
- **Files modified:** addons/penta_tile/penta_tile_map_layer.gd (added `_TerrainGroupScript` preload), addons/penta_tile/layouts/penta_tile_terrain_group.gd.uid (generated)
- **Committed in:** 81b6896 (Task 1 GREEN)

**3. [Rule 3 - Blocking] GDScript strict typing — `:=` inferred from Variant in test helpers**
- **Found during:** Task 1 RED and Task 2 RED phases — parse errors on `tval := entry.get(...)` and `tid := layer.call(...)`
- **Issue:** Godot 4.6 treats warnings as errors; `:=` from Variant-returning expressions (`Dictionary.get()`, `Object.call()`) triggers "variable type inferred from Variant" warning
- **Fix:** Changed to explicit type annotations: `var tval: int = ...` and `var tid: int = ...`
- **Files modified:** tests/terrain_index_test.gd
- **Committed in:** bf616f0 and 96cfed7 (respective RED commits)

**4. [Rule 1 - Bug] Variable scope issue — `mask` declared inside if/else blocks**
- **Found during:** Task 2 GREEN phase — initial implementation
- **Issue:** `var mask := ...` declared inside `if` and `else` blocks has block-level scope in GDScript, making it inaccessible for the `is_dual_grid() and mask == 0` check below
- **Fix:** Declared `var mask := 0` before the if/else block, then assigned inside each branch
- **Files modified:** addons/penta_tile/penta_tile_map_layer.gd
- **Committed in:** c38431a (Task 2 GREEN — fixed inline before commit)

---

**Total deviations:** 4 auto-fixed (2 bugs, 2 blocking)
**Impact on plan:** All auto-fixes necessary for correctness and successful compilation. No scope creep.

## Issues Encountered

- **terrain_set validation:** Godot's C++ engine requires `terrain_set >= 0` before setting `terrain` on TileData. Test helpers had to be updated to set terrain_set first and register terrain sets on the TileSet. This is Godot API behavior, not a PentaTile bug.
- **Class registry in headless mode:** Godot's headless mode doesn't always pre-build the class_name registry. Preloading the terrain group script fixed the parse error. Generated `.uid` file ensures future sessions don't regress.

## Next Phase Readiness

- Terrain index built and verified — ready for variation wiring (Plan 03) and fallback routing (Plan 04)
- _resolve_terrain_id() resolution chain is complete and tested
- Single-grid terrain dispatch is wired — boundary cells route to correct terrain's layout
- Null terrain_group path is fully backward-compatible
- New tests (terrain_index_test + single_grid_cross_terrain_test) ready for inclusion in run_tests.ps1

---

*Phase: 10-multi-terrain-variation-implementation*
*Completed: 2026-04-30*
