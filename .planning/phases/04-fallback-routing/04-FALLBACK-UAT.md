---
status: pending
phase: 04-fallback-routing
source: [04-CONTEXT.md (D-04-05, D-04-06, D-04-07)]
started: 2026-04-29T13:31:50Z
updated: 2026-04-29T13:31:50Z
---

# Phase 4 Fallback-Routing Manual UAT

## Current Test

(none - all 9 tests pending Plan 03 sign-off)

## Tests

### 1. Penta fallback eyeball pass (PREVIEW-03 per D-04-05)
expected: With `layout = PentaTileLayoutPenta.new()` and no manual `tile_set`
assigned, `addons/penta_tile/demo/penta_tile_demo.tscn` paints visibly correct
tiles for a small drag-painted region. No editor errors, no empty cells.
result: pending
Signed-off: pending

### 2. DualGrid16 fallback eyeball pass (PREVIEW-03)
expected: Same shape as #1 with `layout = PentaTileLayoutDualGrid16.new()`.
result: pending
Signed-off: pending

### 3. Wang2Edge fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutWang2Edge.new()`.
result: pending
Signed-off: pending

### 4. Wang2Corner fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutWang2Corner.new()`.
result: pending
Signed-off: pending

### 5. Min3x3 fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutMinimal3x3.new()`.
result: pending
Signed-off: pending

### 6. Blob47Godot fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutBlob47Godot.new()`.
result: pending
Signed-off: pending

### 7. PixelLabTopDown fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutPixelLabTopDown.new()`.
result: pending
Signed-off: pending

### 8. PixelLabSideScroller fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutPixelLabSideScroller.new()`.
result: pending
Signed-off: pending

### 9. PREVIEW-04 user-override regression (per D-04-06 belt+suspenders)
expected: Assigning a custom `tile_set` directly flips `_tile_set_is_fallback`
to false; clearing back to null + re-assigning `layout` re-routes to fallback.
Verified via inspector and by `addons/penta_tile/tests/fallback_routing_test.gd`
sub-tests `_test_preview_04_override` + `_test_preview_04_reroute` +
`_test_preview_04_user_tileset_preserved` (SC-4 regression).
result: pending
Signed-off: pending

## Summary

total: 9
passed: 0
partial: 0
pending: 9
issues: 0
skipped: 0
blocked: 0

## Gaps

(filled in Plan 03 after the eyeball pass - listed per layout if any layout
needs follow-up)

## Closure Notes

(filled in Plan 03 - references the `fallback_routing_test.gd` headless PASS
as programmatic backing for the manual eyeball pass per D-04-06)
