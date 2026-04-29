---
phase: 03-tilebittools-sourced-layouts
plan: 01
subsystem: pipeline
tags: [phase-3, gate, pipeline-patch, 8-moore, single-grid, blob47, tilesetter, d-86, d-87]

# Dependency graph
requires:
  - phase: 02-native-layouts
    provides: _mark_affected_single_grid_cells (4-cardinal version), Wang2Corner layout (probe), comprehensive_bitmask_test framework
provides:
  - 8-Moore single-grid propagation in penta_tile_map_layer (D-87) — unblocks 47-blob layouts
  - single_grid_8_moore_propagation_test.gd regression net (verify-the-regression cycle confirmed)
  - D-86 user decision recorded in STATE.md as TILESETTER_DECISION: b — Tilesetter layouts deferred to v0.3+
  - Phase 3 scope narrowed: only Blob47Godot (Plan 04) + audit (02) + doc rewrites (03) + closeout (06) ship
affects: [03-04, 03-06, v2-backlog, v0.3+]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Verify-the-regression cycle (CLAUDE.md Test Methodology #5) — write the test FIRST, confirm it fails on un-patched code, then apply patch and confirm it passes"
    - "Property-access pattern for internal layer probing (`layer.get(\"_primary_layer\")`) consistent with existing tests"

key-files:
  created:
    - tests/single_grid_8_moore_propagation_test.gd
    - .planning/phases/03-tilebittools-sourced-layouts/03-01-SUMMARY.md
  modified:
    - addons/penta_tile/penta_tile_map_layer.gd
    - tests/run_tests.ps1
    - .planning/STATE.md

key-decisions:
  - "D-86 RESOLVED — option (b): defer Tilesetter layouts to v0.3+. Plan 03-05 SKIPPED in Phase 3."
  - "D-87 patch landed: _mark_affected_single_grid_cells extended from 4 cardinals to 8 Moore neighbors."
  - "4-cardinal layouts (Wang2Edge / Min3x3 / Wang2Corner) intentionally unaffected — extra diagonal cells in the affected set hit the existing logic-painted-only short-circuit in _paint_via_layout."
  - "Test draft in PLAN.md used `layer.get_node(\"_primary_layer\")` — corrected to `layer.get(\"_primary_layer\")` (Rule 3, blocking) to match the property-access pattern used by all 12 prior tests (INTERNAL_MODE_FRONT children aren't reachable via get_node)."

patterns-established:
  - "8-Moore affected-cell propagation for single-grid layouts (Vector2i NE/SE/SW/NW added alongside cardinals)."
  - "TILESETTER_DECISION: <letter> sentinel line in STATE.md as a grep target for downstream gated plans."

requirements-completed: []

# Metrics
duration: ~12min
completed: 2026-04-29
---

# Phase 03 Plan 01: Wave 1 Prereqs Summary

**8-Moore single-grid propagation patch (D-87) + D-86 gate resolved as option (b) — Tilesetter layouts deferred to v0.3+, Phase 3 narrowed to Blob47Godot + audit + doc rewrites + closeout.**

## Performance

- **Duration:** ~12 min (continuation agent — Task 1 checkpoint pre-completed by prior agent)
- **Completed:** 2026-04-29
- **Tasks:** 2 of 3 (Task 1 was a checkpoint pre-resolved by user reply)
- **Files modified:** 4 (1 created, 3 modified) + 1 SUMMARY

## Accomplishments

- **8-Moore patch landed** in `_mark_affected_single_grid_cells` — the gating prerequisite for Plan 04 (Blob47Godot, whose `compute_mask` reads diagonal neighbors). Without this, an already-painted cell would keep a stale mask when a diagonal neighbor changes.
- **Regression test added** — `single_grid_8_moore_propagation_test.gd` uses Wang2Corner (single-grid, samples diagonals) as a probe: paint cell (1,1) alone (mask=0 → atlas (0,0)), then paint diagonal neighbor (0,0) and assert (1,1) re-renders to mask=8 → atlas (0,2). The atlas-coord change is the regression signal.
- **Verify-the-regression cycle executed and documented** (CLAUDE.md Test Methodology #5):
  - Step 1: ran test on un-patched code → exit 1 with the exact "8-Moore propagation broken (D-87). initial=(0, 0) post=(0, 0)" message → test catches the regression.
  - Step 2: applied the 8-Moore patch → re-ran → exit 0 with "ALL PASS" and "post atlas at (1,1) (mask=8 expected): (0, 2)" → patch resolves the bug.
  - Step 3: full suite (13 tests) → all green, no Phase 2 regressions.
- **D-86 outcome recorded** in STATE.md verbatim per the plan's option-(b) consequence sentence. `TILESETTER_DECISION: b` sentinel line present (Plan 04 / Plan 06 will grep for it).
- **Phase 3 scope narrowed** to: Plan 02 (audit, shipped), Plan 03 (D-72/D-73 doc rewrites, shipped), Plan 04 (Blob47Godot, unblocked), Plan 06 (closeout, will record TBT-01-DEFERRED / TBT-02-DEFERRED / TEMPLATE-02-DEFERRED).

## Task Commits

1. **Task 1: D-86 user gate (checkpoint:decision)** — no commit (checkpoint task; resolved by user reply `TILESETTER_DECISION: b` before continuation agent ran).
2. **Task 2 + Task 3 (atomic):** `76de69f` — `feat(03): wave 1 prereqs — 8-Moore single-grid propagation patch + D-86 gate`. Per the plan's Task 3 instructions, the pipeline patch and the STATE.md decision record were committed together as Wave 1 prereqs (single atomic Wave 1 boundary).

## Files Created/Modified

- `addons/penta_tile/penta_tile_map_layer.gd` — `_mark_affected_single_grid_cells` extended from 4 cardinals to 8 Moore neighbors. Doc-comment retitled to reference D-87 and explain the 4-cardinal-layout no-op via the line-262 short-circuit.
- `tests/single_grid_8_moore_propagation_test.gd` — NEW. ~95 LOC. Wang2Corner-probe regression test with documented strategy + bonus assertion that the post-paint atlas hits the mask=8 dispatch coord (0, 2), not just any non-(0,0) coord.
- `tests/run_tests.ps1` — appended `single_grid_8_moore_propagation_test` as the 13th entry in `$allTests`.
- `.planning/STATE.md` — Decisions section gained the `2026-04-29 (Phase 3 D-86 gate resolution)` bullet + `TILESETTER_DECISION: b` sentinel line; Current Position section gained a Wave 1 prereq note.

## Decisions Made

- **D-86 RESOLVED — option (b)** per user reply. Recorded verbatim in STATE.md. Consequence: Plan 03-05 (TilesetterWang15 + TilesetterBlob47) is dropped from Phase 3; the Tilesetter half of TEMPLATE-02 + TBT-01 + TBT-02 move to v2/v0.3+ backlog (recorded by Plan 03-06 closeout). Phase 3 narrows to 4 of 6 plans actually shipping.
- **D-87 8-Moore patch landed.** 4-cardinal layouts unaffected by design — the extra diagonal cells in `affected` hit `if not active_layout.is_dual_grid() and not sample_fn.call(display_cell): return` in `_paint_via_layout` and render nothing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test draft used wrong `_primary_layer` access pattern**

- **Found during:** Task 2 test authoring
- **Issue:** Plan-supplied test draft (lines 219, 232 of 03-01-PLAN.md) used `layer.get_node("_primary_layer")` to reach the internal visual layer. The actual node name is `_PentaTileVisual` (constant `_PRIMARY_LAYER_NAME`), and the layer is added with `Node.INTERNAL_MODE_FRONT` so `get_node` cannot see it. All 12 prior tests use `layer.get("_primary_layer")` — Object property access by the script-local variable name, which works for INTERNAL_MODE_FRONT children.
- **Fix:** Used `layer.get("_primary_layer")` in the new test (matches `comprehensive_bitmask_test.gd:114`, `paint_test.gd:232`, etc.).
- **Files modified:** `tests/single_grid_8_moore_propagation_test.gd`
- **Verification:** Test PASSES on patched code (`primary` is non-null); test FAILS on un-patched code with the exact message the plan specified — both the "did NOT re-render" branch was reached (which can only happen if `primary` was successfully resolved). Cycle confirmed.
- **Committed in:** `76de69f`

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** No scope creep. The fix preserves the plan's intent (probe `_primary_layer` to read post-paint atlas coords) using the codebase's established pattern.

## Issues Encountered

None — both verify-the-regression iterations went exactly as expected. The test failed cleanly on un-patched code with the exact diagnostic message the plan specified, then passed cleanly after the 4-line patch.

## Anti-pattern Guards Verified

- **No `ATTRIBUTION.md` created** — `test -f addons/penta_tile/ATTRIBUTION.md` returns absent (D-73 boundary).
- **No layout virtual `affected_neighbor_offsets()` introduced** — RESEARCH § 11 Q5 alternative explicitly rejected; the patch is local to the layer and adds no base-class API surface (D-77 preference).
- **No `randi()` introduced** — Pitfall #2 guard. Test is fully deterministic (paint at fixed coords, atlas-coord assertion).
- **No 16-neighbor / 2-step-diagonal expansion** — exactly 8 Moore neighbors as specified.

## Verify-the-regression Evidence

```
=== single_grid_8_moore_propagation_test === (UN-PATCHED)
  initial atlas at (1,1) (mask=0): (0, 0)
  post  atlas at (1,1) (mask=8 expected): (0, 0)
=== summary ===
FAIL (1):
  - cell (1,1) did NOT re-render after diagonal neighbor (0,0) was painted —
    8-Moore propagation broken (D-87). initial=(0, 0) post=(0, 0)
exit=1
```

```
=== single_grid_8_moore_propagation_test === (PATCHED)
  initial atlas at (1,1) (mask=0): (0, 0)
  post  atlas at (1,1) (mask=8 expected): (0, 2)
=== summary ===
ALL PASS
exit=0
```

## Full-suite Test Count

12 → 13 (added `single_grid_8_moore_propagation_test`). Full `run_tests.ps1` exits 0 with "ALL GREEN (13 tests)".

## Diff Stats

- `penta_tile_map_layer.gd`: +12 / -3 lines (4 lines of new affected-set entries; 8 lines of doc-comment rewrite vs. 4 lines of old comment).
- `single_grid_8_moore_propagation_test.gd`: +95 / -0 lines (new file).
- `run_tests.ps1`: +2 / -1 lines (added entry + comma).
- `STATE.md`: +5 / -1 lines (decision bullet + sentinel line + Current Position note).

## Self-Check: PASSED

- File `addons/penta_tile/penta_tile_map_layer.gd`: FOUND (contains `Vector2i(1, -1)`, `Vector2i(1, 1)`, `Vector2i(-1, 1)`, `Vector2i(-1, -1)`, and `D-87` comment).
- File `tests/single_grid_8_moore_propagation_test.gd`: FOUND (starts with `extends SceneTree`, contains `8-Moore propagation broken (D-87)`).
- File `tests/run_tests.ps1`: FOUND (contains `"single_grid_8_moore_propagation_test"`).
- File `.planning/STATE.md`: FOUND (contains `TILESETTER_DECISION: b`, `Phase 3 D-86 gate resolution`, `option b)`, `Phase 03` + `D-86` references in Current Position).
- Commit `76de69f`: FOUND in `git log` (`git log --oneline | grep 76de69f` succeeds; commit body contains `option (b)` AND `TILESETTER_DECISION: b` AND `8-Moore` per the plan's I-1 cross-check).
- Full test suite: 13/13 PASS.

## Next Phase Readiness

- **Plan 03-04 (Blob47Godot) — UNBLOCKED.** The 47-blob layout's `compute_mask` reads NE/SE/SW/NW; with 8-Moore propagation in place, painting now correctly re-renders diagonal neighbors. Plan 04 is a pure subclass-add of `PentaTileLayoutBlob47Godot` + bundled PNG.
- **Plan 03-05 (Tilesetter layouts) — DROPPED from Phase 3.** Per D-86 option (b). Plan 06 closeout will record `TBT-01-DEFERRED`, `TBT-02-DEFERRED`, `TEMPLATE-02-DEFERRED` in v2/v0.3+ backlog.
- **Plan 03-06 (closeout) — proceed after 03-04.** Will recompute Phase 3 scope (4 plans actually shipped: 02 audit, 03 doc rewrites, 04 Blob47Godot, 01 Wave 1 prereqs), record deferred backlog entries, and update ROADMAP.md.
- **No outstanding gates** for the rest of Phase 3.

---
*Phase: 03-tilebittools-sourced-layouts*
*Completed: 2026-04-29*
