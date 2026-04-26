---
status: partial
phase: 02-native-layouts
source: [02-VERIFICATION.md]
started: 2026-04-26T21:05:00Z
updated: 2026-04-26T21:05:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. DualGrid16 / Wang2Edge / Wang2Corner visual correctness (SC-1, SC-2, SC-3)
expected: All 16 mask states produce correct visual tiles for DualGrid16. Wang2Edge produces correct edge-masked visuals. Wang2Corner produces visuals identical to DualGrid16 on the same atlas (different bit convention, same silhouettes).
result: [pending]

### 2. Min3x3 open-side collapse covers all 16 states (SC-4)
expected: No broken seams. Masks 5 (T+B only) and 10 (E+W only) visually render as the center tile. Mask 0 produces no painted tile.
result: [pending]

### 3. Penta ONE/TWO/THREE/FOUR/FIVE synthesis renders without seams (SC-8, SC-9, SC-10)
expected: ONE-mode produces coherent visuals across all 4 test patterns without seams. FIVE-mode uses only authored archetypes (visually cleanest). TWO/THREE/FOUR show progressively improving visual quality. FOUR-mode rebuild hash matches BASELINE_HASH=2986698704 in a fresh demo run.
result: [pending]

### 4. AUTO and AUTO_STRIP mode detection selects correct mode (SC-6, SC-7)
expected: AUTO maps atlas axis 1/2/3/4/5 → ONE/TWO/THREE/FOUR/FIVE silently; 0 or 6+ emits inspector warning. AUTO_STRIP resolves per-strip; no global assumption.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
