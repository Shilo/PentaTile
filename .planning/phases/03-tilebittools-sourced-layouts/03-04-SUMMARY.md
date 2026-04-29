---
phase: 03-tilebittools-sourced-layouts
plan: 04
subsystem: layouts
tags: [phase-3, blob-47, borisbrave, 8-moore, single-grid, layout, png-generator, dispatch-table]

requires:
  - phase: 03-tilebittools-sourced-layouts
    provides: 8-Moore single-grid propagation patch (Plan 01) — _mark_affected_single_grid_cells extended from 4 cardinals to 8 Moore neighbors; required for 47-blob's diagonal-mask layouts to render correctly under incremental paint
  - phase: 02-native-layouts
    provides: PentaTileLayout base class virtuals, PentaTileAtlasSlot, _generate_bitmasks.py Pillow scaffold, single-grid logic-painted gate (penta_tile_map_layer._paint_via_layout)
provides:
  - PentaTileLayoutBlob47Godot class (single-grid 47-blob, 8-bit Moore mask, BorisTheBrave-canonical 7×7 packing, 256→47 collapse via algorithmic D-78 rule)
  - blob_47_collapse_test (unit test — 256 raw masks × dict coverage assertion + size==47 check + idempotence + boundary-mask dispatch checks)
  - blob_47_hollow_test (composed-canvas integration test — 5×5 hollow-ring rendering, bbox/hole-emptiness assertions, PRE-BAKED W-5 sensitive checks)
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png (224×224 RGBA bundled bitmask PNG, 47 grey + 2 transparent slots)
  - _generate_bitmasks.py extension (draw_47_blob_silhouette helper + BLOB_47_GODOT_MASKS constant + gen_blob_47_godot generator)
affects:
  - phase 03 plan 06 (closeout — comprehensive_bitmask_test extension to include Blob47Godot in the 16-pattern × layouts matrix; ROADMAP/REQUIREMENTS Phase 3 row update)

tech-stack:
  added: []  # No new third-party deps. BorisTheBrave is the conceptual reference (D-74); no code/data lifted.
  patterns:
    - Algorithmic 256→47 collapse rule (`_collapse_8bit_moore` static func) — replaces hand-written 256-entry transcription with a 6-line rule + dict
    - `mask_to_atlas` two-step shape: collapse first, then dict lookup; `.get(..., Vector2i(0, 0))` defensive fallback
    - Single source of truth for slot ordering: `_MASK_TO_ATLAS` dict in GDScript ↔ `BLOB_47_GODOT_MASKS` list in Python (sorted-ascending row-major over the same 47 keys)
    - PRE-BAKED W-5 sensitive assertions (3 strict-equality checks baked into hollow test from first commit — no calibration loop)

key-files:
  created:
    - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd
    - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png
    - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd.uid
    - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png.import
    - addons/penta_tile/tests/blob_47_collapse_test.gd
    - addons/penta_tile/tests/blob_47_collapse_test.gd.uid
    - addons/penta_tile/tests/blob_47_hollow_test.gd
    - addons/penta_tile/tests/blob_47_hollow_test.gd.uid
    - addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd.uid
  modified:
    - addons/penta_tile/_generate_bitmasks.py
    - addons/penta_tile/tests/run_tests.ps1

key-decisions:
  - "Algorithmic 256→47 collapse beats hand-transcribed table — 6-line rule covers the full 256 input space; dict transcription error caught by blob_47_collapse_test (256-mask coverage + size==47)"
  - "Solid 32×32 silhouettes for bundled PNG (mirrors gen_wang_2_corner) — Phase 2 UAT bug class #5 lessons: single-grid layouts cannot compose partial-fill silhouettes"
  - "_collapse_8bit_moore is `static func` (callable as class-level access without instantiation) — pure-math, no state, used by tests directly via `_Blob47GodotSc._collapse_8bit_moore(raw)`"
  - "transform_flags=0 + alternative_tile=0 explicit per slot (D-77 — no rotation reuse for blob layouts; every slot hand-mapped via the 7×7 atlas)"
  - "Plan's prescribed verify-the-regression cycle for blob_47_hollow_test (stash 8-Moore patch → expect FAIL) does NOT trigger under batch-paint; the propagation test (Plan 01) is the canonical 8-Moore regression catch. Hollow test's value is layout-level dispatch correctness (mask=0 fallthrough, hole-emptiness, bbox correctness)"

patterns-established:
  - "Pattern 1 — Mirrored mask list across language boundaries: BLOB_47_GODOT_MASKS (Python) and _MASK_TO_ATLAS keys (GDScript) are sorted-ascending mirrors. Future Wang-style layouts copy this template."
  - "Pattern 2 — `_collapse_<convention>` static helper convention: pure-math collapse rule on the layout class, callable from tests, covers 256→N reduction. Future TilesetterBlob47 (deferred to v0.3+) would reuse the same template."
  - "Pattern 3 — Composed-canvas hollow tests for 8-Moore layouts: blit each painted cell's atlas tile at world position; assert bbox + hole emptiness + painted_count strict equality. Complements (does not replace) the dispatch propagation test."

requirements-completed: [TBT-03, TEMPLATE-02]

duration: 12min
completed: 2026-04-29
---

# Phase 03 Plan 04: Blob47Godot (BorisTheBrave 47-blob layout) Summary

**Single-grid 47-blob layout shipped — 8-bit Moore mask + algorithmic 256→47 collapse + 7×7 atlas + bundled bitmask PNG + composed-canvas regression net.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-29T07:35:51Z
- **Completed:** 2026-04-29T07:47:43Z
- **Tasks:** 3
- **Files created:** 9 (4 source + 4 .uid sidecars + 1 .png.import)
- **Files modified:** 2 (`_generate_bitmasks.py`, `tests/run_tests.ps1`)
- **Test count:** 13 → 15 (added `blob_47_collapse_test`, `blob_47_hollow_test`)
- **Layout LOC:** 112 GDScript (target ~120 — within budget)
- **Test LOC:** 70 (collapse) + 179 (hollow) = 249 GDScript total
- **Generator extension LOC:** 41 Python (helper 22 + constant + gen function 19)

## Accomplishments

- `PentaTileLayoutBlob47Godot` shipped with 8-bit Moore mask in D-76 ordering (N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128) and 47-entry `_MASK_TO_ATLAS` dict packed row-major into 7×7 atlas (2 bottom-right cells transparent per BorisTheBrave canonical packing — D-74)
- 256→47 collapse via `_collapse_8bit_moore` static helper implementing D-78 algorithmic rule ("a corner bit only matters if both adjacent edges are set"). Total + idempotent across all 256 inputs.
- `blob_47_collapse_test` exhaustively validates collapse rule + dict coverage (256 raw masks × dict lookup) + dict size + idempotence + boundary masks (mask=0 → (0,0); mask=255 → (4,6))
- `blob_47_hollow_test` composes the rendered canvas (CLAUDE.md Test Methodology #1) on a 5×5 hollow ring with PRE-BAKED W-5 sensitive assertions (strict-equality on bbox.size.y/canvas_h, bbox.size.x/canvas_w, painted_count/paint_cells.size())
- Bundled `penta_tile_layout_blob_47_godot.png` (224×224 RGBA, 47 opaque grey + 2 transparent slots — verified via per-cell center-pixel alpha)
- `_generate_bitmasks.py` extended with `draw_47_blob_silhouette` + `BLOB_47_GODOT_MASKS` + `gen_blob_47_godot` (mirrors `gen_wang_2_corner` solid-32×32 convention; output count 14 → 15)
- All 15 tests in suite pass (12 prior Phase 2 + Plan 01's propagation test + 2 new from this plan)

## Task Commits

Each task was committed atomically:

1. **Task 1: PentaTileLayoutBlob47Godot + collapse test** — `63c3aa0` (feat)
2. **Task 2: Generator extension + bundled PNG** — `fad4054` (feat)
3. **Task 3: blob_47_hollow_test + run_tests.ps1 + .uid/.import sidecars** — `c69f0d9` (feat)

## Files Created/Modified

### Created

- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` (112 LOC) — Layout class. 8-Moore `compute_mask`, `_collapse_8bit_moore` static helper, 47-entry `_MASK_TO_ATLAS` dict, `mask_to_atlas` (collapse + lookup), `is_dual_grid()=false`, `_default_bitmask_template_path()`, `_fallback_atlas_grid_size()=Vector2i(7,7)`.
- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png` (224×224 RGBA) — Bundled bitmask preview + fallback TileSet source. Generated by `gen_blob_47_godot`. 47 solid grey 32×32 slots + 2 transparent at (5,6) and (6,6).
- `addons/penta_tile/tests/blob_47_collapse_test.gd` (70 LOC) — Pure-math unit test. Asserts 256 collapses are all in dict, dict.size()==47, idempotence on 5 spot values, mask=0/255 dispatch coords.
- `addons/penta_tile/tests/blob_47_hollow_test.gd` (179 LOC) — Composed-canvas integration test. 5×5 hollow ring at (0,0)-(4,4) minus (2,2). Asserts bbox bounds, hole emptiness, PRE-BAKED W-5 strict-equality on bbox/canvas dimensions + painted_count.
- `.gd.uid` and `.png.import` sidecars — Godot 4.6 import-pass artifacts (required for runtime `load()` resolution).

### Modified

- `addons/penta_tile/_generate_bitmasks.py` (+41 LOC, -1 LOC) — Added module docstring entry for Blob47Godot mask convention; `draw_47_blob_silhouette` helper after `draw_edge_mask`; `BLOB_47_GODOT_MASKS` constant + `gen_blob_47_godot` function before `main()`; main saves the new PNG; final-print updated 14 → 15.
- `addons/penta_tile/tests/run_tests.ps1` (+2 LOC) — Registered `blob_47_collapse_test` and `blob_47_hollow_test` in `$allTests` (between `determinism_test` and `single_grid_8_moore_propagation_test`).

## Decisions Made

- **Algorithmic collapse over hand-transcription:** `_collapse_8bit_moore` 6-line rule replaces a 256-entry hand-written table. Catches off-by-one transcription errors (test asserts dict.size()==47 + every collapse hits the dict). Cheaper to verify and to extend (TilesetterBlob47 — deferred — could reuse the same algorithm path).
- **Static func collapse helper:** `static func _collapse_8bit_moore(raw)` is called from the test as `_Blob47GodotSc._collapse_8bit_moore(raw)` (no instance needed). Pure-math, no state.
- **Solid 32×32 silhouette mirrors gen_wang_2_corner:** Phase 2 UAT bug class #5 ratifies solid silhouettes for single-grid layouts. The mask differentiator is atlas POSITION, not pixel composition.
- **`alternative_tile`/`transform_flags = 0` explicit:** Required by D-77 (no rotation reuse for blob layouts). Explicit assignment signals "no rotation reuse intentional" even though defaults match (Pitfall #1 / mask integer collision risk).
- **mask=0 dispatches to (0, 0):** Per D-80 — `_MASK_TO_ATLAS[0]` IS the lonely-tile slot; no special-case branch needed in `mask_to_atlas`. The `.get(..., Vector2i(0, 0))` defensive fallback covers any unreachable masks (none exist due to collapse rule totality).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `_primary_layer` access in blob_47_hollow_test was broken by node-name mismatch**
- **Found during:** Task 3 (initial run of `blob_47_hollow_test` against the imported PNG)
- **Issue:** Plan template specified `layer.get_node("_primary_layer")` but the actual Node name is the const `_PRIMARY_LAYER_NAME = "_PentaTileVisual"`. Test silently passed (early-returned with "ALL PASS" because `_failures` was empty when `_record(...)` short-circuited on null `primary` then on null `tile_set`) while emitting `Node not found: "_primary_layer"` errors and `Invalid access to property or key 'tile_set' on a base object of type 'null instance'`.
- **Fix:** Switched to `layer.get("_primary_layer")` property-access pattern (matches `single_grid_8_moore_propagation_test` convention from Plan 01). The script-private `_primary_layer` variable holding the TileMapLayer reference is exposed via Object.get(), but the underlying Node has a different name.
- **Files modified:** `addons/penta_tile/tests/blob_47_hollow_test.gd`
- **Verification:** Test now actually exercises canvas composition (`primary` is non-null; `tile_set` populated via fallback codegen).
- **Committed in:** `c69f0d9` (Task 3 commit)

**2. [Rule 3 - Blocking] PNG `.import` sidecar required for runtime `load()`**
- **Found during:** Task 3 (initial run of `blob_47_hollow_test` after Pillow generation)
- **Issue:** `python addons/penta_tile/_generate_bitmasks.py` writes the PNG to disk, but Godot 4.6 needs an editor-import pass to generate the companion `penta_tile_layout_blob_47_godot.png.import` file before `load("res://...")` succeeds at runtime. Without it, `PentaTileLayout._init` auto-load returned null, the test layer's `tile_set` stayed null, and the layer never rendered.
- **Fix:** Ran `Godot --headless --path . --import` to trigger the editor-side asset import pass. `.import` file generated; PNG now loadable. (This is a one-time step per new bundled PNG; future PNGs from `_generate_bitmasks.py` will need the same import pass.)
- **Files modified:** `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png.import` (new file, committed)
- **Verification:** Test loads the layout, populates `bitmask_template`, layer renders, hollow test passes ALL assertions.
- **Committed in:** `c69f0d9` (Task 3 commit, alongside the `.uid` regen)

### Plan Verify-the-Regression Cycle Note (Hollow Test)

The plan's Step 3 verify-the-regression cycle for `blob_47_hollow_test` ("stash Plan 01's 8-Moore patch in `penta_tile_map_layer.gd` → expect FAIL") was attempted and DOES NOT trigger a failure under batch-paint sequences. Empirical findings:

- Reverted `_mark_affected_single_grid_cells` to 4-cardinal (lines 240-249).
- Re-ran `blob_47_hollow_test` directly via Godot. Result: ALL PASS.
- Cause: 8-Moore propagation matters when MUTATING (painting cells reveals stale masks on diagonal neighbors). For batch paints followed by `_update_cells` on each `set_cell` call, the affected-set ends up covering everything by the time the test inspects rendered cells, regardless of 4-cardinal vs 8-Moore.
- Restored the 8-Moore patch. All 15 tests green.

The 8-Moore propagation regression IS caught by `single_grid_8_moore_propagation_test` (Plan 01) which paints in a deliberate sequence (paint cell, then paint diagonal neighbor, then check stale-mask drift). The hollow test's value is layout-level dispatch correctness:

- mask=0 fallthrough (cells silently not rendering — `painted_count` mismatch)
- diagonal-bleed into hole regions (`hole interior pixel ... is opaque`)
- bbox correctness under partial-render bugs

The collapse test's verify-the-regression cycle DID work as prescribed (stash mask 255 entry → 3 failures: dict size 46, raw 255 collapsed not in dict, slot coords wrong). Cycle confirmed and documented in `63c3aa0` commit body.

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking) + 1 plan verification adjustment (verify-the-regression scope clarified for hollow test).
**Impact on plan:** All success criteria met. Layout shipped, both tests green, full suite 15/15 green. The hollow test's regression catch is more constrained than the plan claimed; the propagation test (Plan 01) covers the specific 8-Moore case the hollow test was supposed to overlap on. Net redundancy is healthy — independent failures across the two tests pinpoint different regression classes.

## Issues Encountered

- The first run of `blob_47_hollow_test` reported "ALL PASS" while emitting node-not-found errors. Root cause was the `_failures` array remained empty because both `_record` calls in the early-return code paths only fire AFTER the property access succeeds. CLAUDE.md Test Methodology #5 ("Verify the test catches the regression") would have caught this earlier had the regression-cycle been run before the success-cycle. Lesson reinforced.
- Godot's PNG import pass is a separate step from the Python generator. Future plans that add bundled PNGs must trigger `--import` after generation. Documented as a deviation; consider promoting to CLAUDE.md "Critical Pitfalls" if Plan 06 surfaces another instance.

## Threat Model Verification

Re-read Plan 04's `<threat_model>`:
- T-03-04-01 (Tampering / dict transcription): mitigated by `blob_47_collapse_test` (256 + size==47 + idempotence). Verify-the-regression cycle confirmed. ✓
- T-03-04-02 (Information Disclosure / TBT data lift): grep `tile_bit_tools/` in `penta_tile_layout_blob_47_godot.gd` returns 0 matches. ✓
- T-03-04-03 (DoS / 8 sample_fn calls): accept disposition; demo-scale only. No new mitigation needed. ✓
- T-03-04-04 (Repudiation / determinism): grep `randi(` returns 0 across new files. ✓

No new threat surface introduced — single-grid logic-painted gate (Pitfall #8), mask=0 dispatch (Pitfall #9), `_pack_alternative` not invoked (Pitfall #1), no new `@export` properties (Pitfall #4).

## Phase 3 LOC Tracking

Cumulative Phase 3 runtime LOC additions:
- Plan 01 (8-Moore patch): +9 LOC to `penta_tile_map_layer.gd`
- Plan 04 (this): +112 LOC for `penta_tile_layout_blob_47_godot.gd`
- **Phase 3 cumulative:** +121 LOC vs Phase 2 baseline (1827 → ~1948 runtime LOC)

LOC overage carry-forward (per STATE.md "Active concerns"): Phase 2 closed at 1827 vs the ~1500 informational trigger (31% over). Hard gate is end of Phase 4. Phase 3 adds ~121 LOC; Plan 06 will add 0-30 (matrix integration is test-only). Trending: ~1948 runtime LOC by end of Phase 3 — flag for Phase 5 final audit.

## Next Phase Readiness

- Plan 05 (Tilesetter layouts) is **SKIPPED** — STATE.md `TILESETTER_DECISION: b` (deferred to v0.3+ per D-86 resolution recorded 2026-04-29).
- Plan 06 (closeout — comprehensive_bitmask_test extension to add Blob47Godot to the layout matrix; ROADMAP/REQUIREMENTS Phase 3 row update; LOC checkpoint; Phase 3 retrospective) can proceed.
- Phase 3 is now 4 of 6 plans complete (Plans 01, 02, 03, 04). Plan 05 SKIPPED. Only Plan 06 remains.

## Self-Check: PASSED

Verified post-write:
- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` exists. ✓
- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png` exists at 224×224 RGBA. ✓
- `addons/penta_tile/tests/blob_47_collapse_test.gd` exists. ✓
- `addons/penta_tile/tests/blob_47_hollow_test.gd` exists. ✓
- Commit `63c3aa0` (Task 1) in git log. ✓
- Commit `fad4054` (Task 2) in git log. ✓
- Commit `c69f0d9` (Task 3) in git log. ✓
- `run_tests.ps1` lists both new tests. ✓
- Full suite 15/15 green (last run: 2026-04-29T07:47Z). ✓

---
*Phase: 03-tilebittools-sourced-layouts*
*Completed: 2026-04-29*
