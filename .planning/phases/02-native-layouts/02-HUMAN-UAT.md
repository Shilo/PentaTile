---
status: partial
phase: 02-native-layouts
source: [02-VERIFICATION.md]
started: 2026-04-26T21:05:00Z
updated: 2026-04-27T13:00:00Z
---

## Current Test

[3 visual items still pending human verification — programmatic dispatch coverage complete]

## Tests

### 1. DualGrid16 / Wang2Edge / Wang2Corner visual correctness (SC-1, SC-2, SC-3)
expected: All 16 mask states produce correct visual tiles for DualGrid16. Wang2Edge produces correct edge-masked visuals. Wang2Corner produces visuals identical to DualGrid16 on the same atlas (different bit convention, same silhouettes).
result: [pending — visual, requires editor]

### 2. Min3x3 open-side collapse covers all 16 states (SC-4)
expected: No broken seams. Masks 5 (T+B only) and 10 (E+W only) visually render as the center tile. Mask 0 produces no painted tile.
result: [pending — visual, requires editor]

### 3. Penta ONE/TWO/THREE/FOUR/FIVE synthesis renders without seams (SC-8, SC-9, SC-10)
expected: ONE-mode produces coherent visuals across all 4 test patterns without seams. FIVE-mode uses only authored archetypes (visually cleanest). TWO/THREE/FOUR show progressively improving visual quality. FOUR-mode rebuild hash matches BASELINE_HASH=2986698704 in a fresh demo run.
result: [partial pass — programmatic dispatch verified by `paint_test.gd` across ONE/TWO/THREE/FOUR/FIVE modes (16 mask states × 8 patterns each, ALL PASS as of commit 29cba37); FOUR-mode determinism baseline still matches BASELINE_HASH=2986698704 across 11 runs. Visual seam-quality check across the 5 modes still requires editor — demo currently binds FOUR; manually swap `penta_layout_one_horizontal.tres` / `penta_layout_five_horizontal.tres` (TWO/THREE `.tres` files do not yet exist) to inspect each mode visually. Note the documented Gate 1 OuterCorner-via-rotation tradeoff: rotating slot 0 for masks 1/2/4/8 shows the IsolatedCell's other 3 corners + edges + fill; per `02-02-PLAN.md:134` this is intentional, escape hatch is artist-authored faded slot 0 art.]

### 4. AUTO and AUTO_STRIP mode detection selects correct mode (SC-6, SC-7)
expected: AUTO maps atlas axis 1/2/3/4/5 → ONE/TWO/THREE/FOUR/FIVE silently; 0 or 6+ emits inspector warning. AUTO_STRIP resolves per-strip; no global assumption.
result: [pass — programmatic. AUTO dispatch: `paint_test.gd` AUTO mode case ALL PASS. AUTO_STRIP dispatch: 4 new cases added in commit 29cba37 — uniform [3,3], mixed [3,5], gap-with-warning-C, VERTICAL [4,2] — ALL PASS. Synthesized atlas confirmed 5×N (one row per strip), painted cells routed by first non-empty TL→TR→BL→BR neighbor's source-atlas-coord per Interpretation A. WR-03 docstring contradiction (latent since Wave 2) corrected as part of 29cba37. Gap detector bug found and fixed: `resolve_strip_modes` was treating trailing empties as malformed gaps; now only flags "empty-then-populated" patterns.]

## Summary

total: 4
passed: 1
partial: 1
pending: 2
issues: 0
skipped: 0
blocked: 0

## Gaps

- TWO-mode and THREE-mode demo `.tres` files do not yet exist. Test 3 visual UAT for those modes requires either (a) creating the .tres files manually, or (b) deferring to Phase 5 demo-refresh wave.
- Tests 1, 2, and the ONE/TWO/THREE/FIVE visual portion of test 3 require the Godot editor — cannot be fully closed by headless runs.
