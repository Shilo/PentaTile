---
phase: 02-native-layouts
plan: 7
subsystem: wave7-closeout
tags: [loc-checkpoint, determinism-test, identity-guardrail, design-review-gate]

dependency_graph:
  requires:
    - phase: 02-06-PLAN
      provides: BASELINE_HASH=2986698704 (FOUR-mode determinism reference)
    - phase: 02-02-PLAN
      provides: Gate 2 transform_vertex spec (8 flag combos)
  provides:
    - ".planning/phases/02-native-layouts/02-07-LOC-CHECKPOINT.md (end-of-Phase-2 LOC audit)"
    - ".planning/phases/02-native-layouts/02-07-DETERMINISM-TEST.md (determinism verdict PASS)"
    - "tests/determinism_test.gd (headless regression script)"
    - "tests/_capture_baseline.gd (baseline capture utility)"
  affects:
    - Phase 5 (LOC audit inputs for final identity guardrail comparison)
    - Phase 3 (next phase; planning unblocked by design-review outcome)

tech-stack:
  added: []
  patterns:
    - extends-SceneTree-headless-script (determinism_test.gd uses SceneTree for scene-load in --script mode)
    - preload-over-class_name (test script uses preload() to avoid class_name symbol-table failure)

key-files:
  created:
    - .planning/phases/02-native-layouts/02-07-LOC-CHECKPOINT.md
    - .planning/phases/02-native-layouts/02-07-DETERMINISM-TEST.md
    - tests/determinism_test.gd
    - tests/_capture_baseline.gd
  modified: []

decisions:
  - "LOC hard gate (>~1500) fired at 1961 total / 1827 runtime-only — Phase 2 ROADMAP marked NOT complete pending user design review"
  - "Determinism test PASS — all three sub-results green; no code changes needed"
  - "Identity guardrail AT RISK — runtime LOC exceeds TileMapDual core (~700-900 LOC); hot-path complexity still simpler but raw LOC is 2-2.6x"
  - "_capture_baseline.gd committed as test utility (was untracked from Wave 6)"

metrics:
  duration_seconds: 272
  completed: 2026-04-26
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 2 Plan 7: Wave 7 — LOC Checkpoint + Determinism Test Summary

**Phase 2 closeout: LOC audit triggered design-review gate (1961 total LOC, 31% above ~1500 hard trigger); determinism test passed all three sub-tests with BASELINE_HASH=2986698704 and Gate 2 transform_vertex spec confirmed exact; ROADMAP Phase 2 left unchecked pending user decision on LOC review.**

## Performance

- **Duration:** ~4.5 min
- **Started:** 2026-04-26T20:30:17Z
- **Completed:** 2026-04-26T20:34:49Z
- **Tasks:** 2 (Task 7.1 LOC checkpoint + Task 7.2 determinism test)
- **Files created:** 4
- **Files modified:** 0

## Accomplishments

### Task 7.1: LOC Checkpoint

Measured cumulative GDScript LOC across `addons/penta_tile/`:

| File | LOC |
|---|---|
| penta_tile_map_layer.gd | 377 |
| penta_tile_atlas_slot.gd | 14 |
| penta_tile_synthesis.gd | 685 |
| layouts/penta_tile_layout.gd | 70 |
| layouts/penta_tile_layout_penta.gd | 388 |
| layouts/penta_tile_layout_dual_grid_16.gd | 64 |
| layouts/penta_tile_layout_wang_2_edge.gd | 63 |
| layouts/penta_tile_layout_wang_2_corner.gd | 70 |
| layouts/penta_tile_layout_minimal_3x3.gd | 96 |
| demo/demo_player.gd | 17 |
| demo/demo_runtime_painter.gd | 54 |
| tests/_capture_baseline.gd | 63 |
| **Total** | **1961** |

**Baseline (Phase 1 close):** 559 LOC
**Expected range:** 1230-1530 LOC
**Actual:** 1961 LOC (31% above hard trigger of ~1500)
**Runtime-only** (excluding demo + tests): 1827 LOC

**Audit decision: REVIEW REQUIRED.** The hard gate fired. ROADMAP.md Phase 2 entry remains `[ ]` per plan rules. Overage drivers: `penta_tile_synthesis.gd` (685 LOC vs 250-400 estimate — polygon clipping is intrinsically verbose at three per-type loops each for collision/occlusion/navigation); `penta_tile_layout_penta.gd` (388 LOC — Wave 6 adds +115 LOC not back-propagated to budget); `penta_tile_map_layer.gd` (377 LOC — grew +79 vs expected -50 net).

**Identity guardrail: AT RISK.** Runtime LOC (1827) is 2-2.6× TileMapDual core (~700-900 LOC). Hot-path complexity remains simpler (no terrain-rule trie, no coordinate cache, no watcher system); raw LOC comparison is unfavorable.

### Task 7.2: Determinism Test

Ran `tests/determinism_test.gd` headlessly via Godot 4.6.2 (`--headless --path . --script`).

**Composite verdict: PASS**

- Sub-test (a) — transform_vertex worked example: **PASS** (8/8 flag combos match 02-02-PLAN.md Gate 2 table exactly)
- Sub-test (b) — clip_polygon_to_subrect determinism: **PASS** (10 invocations all produce hash=4100093049)
- Main test — rebuild loop: **PASS** (11 hashes all equal 2986698704 = BASELINE_HASH; baseline match confirmed)

The `_on_layout_changed()` + `rebuild()` round-trip between runs exercises the full synthesis path (not just the cache-hit shortcut), confirming PENTA-SYNTH-06 determinism.

## Deviations from Plan

### Design-Review Gate Triggered

**[Hard Gate] LOC audit REVIEW REQUIRED**
- **Found during:** Task 7.1
- **Issue:** Total LOC = 1961 (31% above ~1500 hard trigger). Per plan rules, ROADMAP.md Phase 2 cannot be marked `[x]` complete until user resolves the design-review questions.
- **Action taken:** Documented in `02-07-LOC-CHECKPOINT.md` with per-file overage analysis + three design-review questions for user. ROADMAP.md was NOT updated to mark Phase 2 complete.
- **User questions from LOC checkpoint:**
  1. Is polygon clipping scope appropriate? (Gate 2 required it; no over-spec detected)
  2. Exclude `tests/` from future LOC audits? (test utilities, not runtime)
  3. Accept Wave 6 AUTO/AUTO_STRIP as Phase 2 scope and close?

**[Deviation] `_capture_baseline.gd` was untracked**
- **Found during:** Task 7.1 `git status --short`
- **Issue:** `_capture_baseline.gd` was created in Wave 6 but never committed (left untracked). The LOC checkpoint counted it (63 LOC) but git history had no record of it.
- **Fix:** Staged and committed alongside `determinism_test.gd` in the Wave 7 commit (da0eb38). The file is now in git history.

## LOC Audit

| Metric | Value |
|---|---|
| Phase 1 baseline | 559 LOC |
| Phase 2 total (all .gd) | 1961 LOC |
| Phase 2 runtime-only | 1827 LOC |
| Net delta (all .gd) | +1402 LOC |
| Audit bucket | REVIEW REQUIRED (>~1500) |
| Identity guardrail | AT RISK |

## Determinism Test

| Sub-test | Verdict | Key values |
|---|---|---|
| Sub-test (a) transform_vertex | PASS | 8/8 flag combos exact match |
| Sub-test (b) clip_polygon_to_subrect | PASS | hash=4100093049 ×10 runs |
| Main rebuild loop | PASS | hash=2986698704 ×11 runs = BASELINE_HASH |

## Phase 2 Close Status

**Phase 2 is NOT marked complete in ROADMAP.md.** The LOC hard gate prevents closing without user decision on:
- Accept the LOC overage and close (if polygon clipping verbosity is acceptable)
- Identify simplification targets (e.g., reduce comments, consolidate collision/occlusion/navigation loops into a shared helper)

**Determinism test PASSES independently.** No code changes needed for determinism. If user accepts LOC overage, Phase 2 can be closed by manually updating ROADMAP.md + STATE.md without re-executing any code tasks.

**Phase 3 (TileBitTools-Decoded Layouts) planning is unblocked** — the architecture it builds on is stable and the determinism invariant is confirmed. User may choose to begin planning Phase 3 while resolving the LOC review.

## Known Stubs

None. This plan produces only planning artifacts and test scripts; no GDScript runtime code was added or stubbed.

## Threat Flags

None. Internal planning artifacts + headless test script; no network/auth/file/external input surface.

## Self-Check

- `02-07-LOC-CHECKPOINT.md` exists: CONFIRMED
- `02-07-DETERMINISM-TEST.md` exists: CONFIRMED
- `tests/determinism_test.gd` exists: CONFIRMED
- `tests/_capture_baseline.gd` exists: CONFIRMED
- Commit `da0eb38` exists: CONFIRMED
- ROADMAP.md Phase 2 remains `[ ]` (hard gate honored): CONFIRMED
- LOC checkpoint contains "Audit Decision" + "Identity Guardrail Check" sections: CONFIRMED
- Determinism report contains Results for main + sub-test (a) + sub-test (b) + Verdict: CONFIRMED

## Self-Check: PASSED

---
*Phase: 02-native-layouts*
*Completed: 2026-04-26*
