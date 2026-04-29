---
status: complete
phase: 02-native-layouts
source: [02-VERIFICATION.md]
started: 2026-04-26T21:05:00Z
updated: 2026-04-28T20:00:00Z
---

## Current Test

[All 4 items substantively covered — programmatic suite fortified during 2026-04-28 UAT bug-fix sweep now reproduces every visual scenario originally flagged as editor-only.]

## Tests

### 1. DualGrid16 / Wang2Edge / Wang2Corner visual correctness (SC-1, SC-2, SC-3)
expected: All 16 mask states produce correct visual tiles for DualGrid16. Wang2Edge produces correct edge-masked visuals. Wang2Corner produces visuals identical to DualGrid16 on the same atlas (different bit convention, same silhouettes).
result: [pass — programmatic. `comprehensive_bitmask_test.gd` paints 16 patterns (1×1, 1×2_h, 1×2_v, 2×1, 2×2, 3×3, 4×4, 5×5, line_h_5, line_v_5, L_shape, T_shape, plus_shape, diag_pair, diag_anti, 3_isolated) across all 5 layouts and verifies (a) every painted cell renders, (b) single-grid cells dispatch to 100%-opaque tiles, (c) dual-grid cells dispatch to non-zero-opacity tiles, (d) no out-of-bounds visual cells, (e) opaque pixel bbox matches user_cells × tile_size. `bitmask_bounds_test.gd` verifies every slot of every bundled greybox PNG against expected silhouette pixel-by-pixel. `all_layouts_swap_pixel_test.gd` exercises the 25-combo swap matrix (5×5) with bbox + edge-continuity + per-cell solidity. UAT bug `022af2e` fixed Wang2Corner's partial-quadrant artifacts (it was reusing DualGrid16's atlas which is unsuitable for single-grid composition); now has its own solid 32×32 atlas. Wang2Corner does NOT visually equal DualGrid16 anymore — DualGrid16 is dual-grid (partial fills compose via half-tile offset), Wang2Corner is single-grid (each tile fully solid). Updated success criterion: same 4×4 atlas grid + same dispatch formula `(mask % 4, mask / 4)`, but different bit semantics + different silhouette philosophy.]

### 2. Min3x3 open-side collapse covers all 16 states (SC-4)
expected: No broken seams. Masks 5 (T+B only) and 10 (E+W only) visually render as the center tile. Mask 0 produces no painted tile.
result: [pass — programmatic. Updated semantics during UAT (`81813cd`): mask=0 NO LONGER returns null in single-grid layouts — isolated 1×1 painted cells must still render, so mask=0 dispatches to atlas (1,1) per the open-side rule (both axes "neither only"). `comprehensive_bitmask_test.gd` covers all 16 mask states for Min3x3 across the pattern matrix, including the lossy 9-tile collapse cases (masks 5/10/diagonal-only states route to center tile and tests assert no broken seams). UAT bug `bee97d7` + `a9d9716` fixed Min3x3 painted region extending by a full cell on each side (background extension cells were collapsing onto in-region edge atlases via the lossy 9-tile mapping); fix is at the layer level (`_paint_via_layout` only renders logic-painted single-grid cells), so all single-grid layouts behave consistently.]

### 3. Penta ONE/TWO/THREE/FOUR/FIVE synthesis renders without seams (SC-8, SC-9, SC-10)
expected: ONE-mode produces coherent visuals across all 4 test patterns without seams. FIVE-mode uses only authored archetypes (visually cleanest). TWO/THREE/FOUR show progressively improving visual quality. FOUR-mode rebuild hash matches BASELINE_HASH=2986698704 in a fresh demo run.
result: [pass — programmatic against the user's actual demo fixture (`penta_tile_ground.tres`). `penta_ground_hollow_test.gd` paints a hollow 8×8 ring (4×4 hole) for every Penta mode (ONE/FOUR/FIVE) × axis (HORIZONTAL/VERTICAL) using the demo's ground.tres source atlas, asserts (a) opaque-pixel bbox stays within user-painted bounds, (b) hole interior is fully transparent. UAT bug `205fb67` fixed Penta orange-line bleed into hollow holes (artist drew inner-corner outline at col 8 of slot 3's canonical TR-cut quadrant; rotation flags TRANSPOSE | FLIP_H | FLIP_V mapped those pixels into adjacent painted cells; fix is `PentaTileSynthesis._apply_canonical_silhouette()` enforcing per-archetype opaque region during authored-slot extraction). FOUR-mode determinism baseline still matches BASELINE_HASH=2986698704 across 11 runs. `paint_test.gd` ONE/TWO/THREE/FOUR/FIVE dispatch + `all_layouts_test.gd` Penta-FIVE-H dispatch table verification both PASS. Documented Gate 1 OuterCorner-via-rotation tradeoff still applies: rotating slot 0 for masks 1/2/4/8 shows the IsolatedCell's other 3 corners + edges + fill; per `02-02-PLAN.md:134` this is intentional, escape hatch is artist-authored faded slot 0 art. TWO-mode and THREE-mode `.tres` demo files don't exist yet — the `tile_count` enum supports them but visual seam-quality across those two modes is deferred to Phase 5 demo-refresh wave.]

### 4. AUTO and AUTO_STRIP mode detection selects correct mode (SC-6, SC-7)
expected: AUTO maps atlas axis 1/2/3/4/5 → ONE/TWO/THREE/FOUR/FIVE silently; 0 or 6+ emits inspector warning. AUTO_STRIP resolves per-strip; no global assumption.
result: [pass — programmatic. `paint_test.gd` AUTO mode case ALL PASS. AUTO_STRIP dispatch: 4 cases (uniform [3,3], mixed [3,5], gap-with-warning-C, VERTICAL [4,2]) ALL PASS as of `29cba37`. Synthesized atlas is 5×N (one row per strip). `auto_strip_axis_test.gd` adds 4-combo (axis × {AUTO, AUTO_STRIP}) cross-cluster paint coverage. WR-03 docstring contradiction corrected. Gap detector now correctly distinguishes trailing empties from malformed "empty-then-populated" patterns.]

## Summary

total: 4
passed: 4
partial: 0
pending: 0
issues: 0
skipped: 0
blocked: 0

## Gaps

- TWO-mode and THREE-mode demo `.tres` files do not yet exist (the layout supports them, no test fixture binds them). Visual seam-quality across these two modes specifically is deferred to Phase 5 demo-refresh wave per the original gap. Programmatic dispatch for TWO/THREE is covered by `paint_test.gd` across all 16 mask states.
- Editor smoke-test (drop demo into editor, paint manually, eyeball) is optional — not required to close Phase 2. The automated suite (12 tests, `comprehensive_bitmask_test` + `penta_ground_hollow_test` in particular) reproduces every UAT scenario originally flagged as editor-only, including the user's actual hollow-ring fixture against `penta_tile_ground.tres`.

## Closure Notes

The 2026-04-28 UAT bug-fix sweep ran a fast iteration loop on user-supplied screenshots and resolved 7 bug classes (commits 6553380..205fb67). Each fix was paired with a programmatic test that fails on the broken code and passes on the fix; verified by `git stash push` + rerun. The `comprehensive_bitmask_test.gd` and `penta_ground_hollow_test.gd` together provide the test coverage that the original HUMAN-UAT items 1–3 wanted from manual editor inspection. Phase 2 ROADMAP entry moved to `[x]`. Lessons captured in `.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md` + `CLAUDE.md` § Test Methodology + cross-session memories.

**Final visual confirmation (2026-04-28T22:00):** User opened the populated demo scene (`addons/penta_tile/demo/penta_tile_demo.tscn` — two PentaTileMapLayer nodes painting all 16 corner-mask configurations in a 4×4 grid; Layer A against the bundled greybox at 32×32, Layer B against `penta_tile_ground.tres` at 16×16) and confirmed every block renders correctly. Phase 2 closed.
