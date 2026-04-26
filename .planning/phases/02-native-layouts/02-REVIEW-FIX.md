---
phase: 02-native-layouts
fixed_at: 2026-04-26T00:00:00Z
review_path: .planning/phases/02-native-layouts/02-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-04-26
**Source review:** `.planning/phases/02-native-layouts/02-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (WR-01 through WR-07; CR/Info findings out of scope per `fix_scope: critical_warning`)
- Fixed: 7
- Skipped: 0

All warning-severity findings fixed (including WR-07, the HIGH-severity BLOCKER added by post-implementation audit). Info findings (IN-01 through IN-09) were out of scope per the `critical_warning` fix scope and are not addressed here.

**Logic-correctness note:** several fixes touch synthesis algorithms whose semantics are not fully covered by the existing FOUR-mode determinism baseline (`BASELINE_HASH=2986698704`). WR-01, WR-02, WR-03, and WR-07 should be considered `fixed: requires human verification` — the determinism test still needs to pass under the new code paths, and a VERTICAL-axis baseline should be captured per WR-07's verification recommendation before approving Phase 2.

## Fixed Issues

### WR-07: Synthesized atlas axis mismatch — VERTICAL renders empty (HIGH/BLOCKER)

**Files modified:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
**Commit:** `ea0ba23`
**Applied fix:** Changed `_make_slot` to always return `Vector2i(slot_index, 0)` regardless of `axis`, with a comment clarifying the contract: the synthesized atlas is ALWAYS a horizontal strip, and `axis` only governs source READS by the synthesizer. The prior conditional that returned `Vector2i(0, slot_index)` for VERTICAL hit unregistered atlas coords and rendered empty.

**Requires human verification:** YES — capture a VERTICAL-axis baseline per the review's recommendation (`_capture_baseline.gd` + `BASELINE_HASH` companion in `determinism_test.gd`) and confirm non-empty output for a known mask state. The existing HORIZONTAL baseline does not cover this code path.

### WR-01: Polygon clipper drops "outside-to-outside-through-rect" segments

**Files modified:** `addons/penta_tile/penta_tile_synthesis.gd`
**Commit:** `ae5d787`
**Applied fix:** Replaced the hand-rolled all-edges-at-once clipper with the canonical Sutherland-Hodgman algorithm — clip the polygon against each of the 4 half-planes (left, right, top, bottom) sequentially via the new `_clip_against_edge` helper. All four crossing cases (in/in, in/out, out/in, out/out-but-crossing) fall out of the per-edge logic naturally. Removed the now-unused `_clip_segment_to_rect` helper.

**Requires human verification:** YES — the determinism sub-test (b) hashes 10 invocations of `clip_polygon_to_subrect` and compares against the recorded hash. The new Sutherland-Hodgman implementation produces a different (but still deterministic) output sequence; the recorded sub-test (b) hash will need to be regenerated. Sub-test (b) compares run-to-run, not against a baseline file, so it will likely still pass, but please run the headless determinism test once to confirm.

### WR-02: Synthesis cache does not invalidate on in-place TileSet mutations under AUTO mode

**Files modified:** `addons/penta_tile/penta_tile_map_layer.gd`
**Commit:** `9ca342e`
**Applied fix:** Reordered `_ensure_synthesized_tile_set` to resolve `AUTO`/`AUTO_STRIP` to a concrete mode BEFORE building the cache signature, then included the resolved `mode` in the signature hash. AUTO + 4-tile atlas and AUTO + 5-tile atlas now produce different signatures so adding/removing tiles re-triggers synthesis. Picked the simpler "reorder + signature" fix over the `tile_set.changed` listener path (per fix guidance in the orchestrator prompt).

**Limitation:** the resolved-mode-in-signature approach catches AUTO drift but does NOT catch pixel-level mutations to existing tile content (e.g., user repaints slot 1's image while AUTO + tile_count stays 4). Catching pixel mutations would require either a `tile_set.changed` listener (matches the existing `_on_layout_changed` pattern, +1 signal hookup) or a content hash. The review explicitly flagged this trade-off; sticking with the simpler fix. Document this as a Phase 3 expansion if pixel-level invalidation becomes necessary.

**Requires human verification:** YES — verify that the FOUR-mode determinism baseline (`BASELINE_HASH=2986698704`) still matches after the reorder. The added `mode` in the signature hash changes the cache-hit conditions but should not change the synthesized output for the existing demo (which uses AUTO + 4-tile atlas, deterministically resolving to mode FOUR every time).

### WR-03: `synthesize_strip` source-coords formula assumes spacing of 5 per strip

**Files modified:** `addons/penta_tile/penta_tile_synthesis.gd`
**Commit:** `d74df0e`
**Applied fix:** Added an optional `strip_origin: Vector2i = Vector2i(-1, -1)` parameter to `synthesize_strip`. The sentinel `(-1, -1)` falls back to the legacy `strip_index * _STRIP_SLOT_COUNT` formula (preserves the strip_index=0 single-call site). When AUTO_STRIP per-strip dispatch lands, the caller computes the cumulative origin from prior strips' resolved modes and passes it explicitly. Authored slot coords now step off `slot0_coords` along the axis (no more separate authored-vs-fallback formula).

**Requires human verification:** YES — semantic refactor of the source-coord computation. Verify the FOUR-mode determinism baseline still matches: the strip_index=0 fallback path should produce identical output to the old code (both compute `slot0_coords = (0,0)` and `src_atlas_coords = (out_slot, 0)` for HORIZONTAL).

### WR-04: `_BITMASK_TEMPLATE_LOOKUP` enum values clash with axis values

**Files modified:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
**Commit:** `2ca04e0`
**Applied fix:** Added a typed accessor `_bundled_png_path(a: Axis, m: TileCountMode) -> String` with an `assert(m >= TileCountMode.ONE and m <= TileCountMode.FIVE)` precondition. AUTO/AUTO_STRIP misuse now fails loud at the assertion rather than silently returning the empty default. Routed `get_fallback_tile_set`'s lookup through the new accessor.

### WR-05: `_synthesize_slot_image` SLOT_INNER_CORNER set_pixel loop

**Files modified:** `addons/penta_tile/penta_tile_synthesis.gd`
**Commit:** `720f017`
**Applied fix:** Replaced the (half_x × half_y) tight `set_pixel` loop with a single `Image.fill_rect` call covering the TR quadrant. Equivalent output, far fewer engine crossings (256+ calls → 1 call for a 32×32 tile).

**Requires human verification:** YES — `fill_rect` is intended to be pixel-equivalent to a per-pixel `set_pixel` over the same rectangle with the same color, and Godot 4.6's documentation confirms this. The determinism test should still produce the same hash. Verify the FOUR-mode baseline still matches.

### WR-06: README drift — overlay layer + four-tile contract

**Files modified:** `README.md`
**Commit:** `79af1e3`
**Applied fix:** Rewrote four sections to match Phase 2 reality:
1. **Penta-System Template**: replaced "two transformed outer corners on an internal overlay layer" + "four essential components" with the canonical 5-slot order and the synthesis-pipeline description; clarified that masks 6 and 9 resolve to OppositeCorners (synthesized in modes ONE..FOUR or hand-authored in FIVE). Switched the showcase image from `four_horizontal.png` to `five_horizontal.png` (matches the existing top-of-README hero image).
2. **Addon Layout**: refreshed the file tree to include `layouts/`, `tests/`, `_generate_bitmasks.py`, `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, `demo_runtime_painter.gd`, the bundled per-mode PNGs, and demo `.tres` resources.
3. **Current API**: dropped the deleted `atlas_layout` property, added `layout: PentaTileLayout`, added a Penta-specific subsection documenting `axis` and `tile_count`.
4. **Implementation Notes**: rewrote the diagonal-mask paragraph to describe the OppositeCorners archetype + single-layer dispatch (no more overlay layer).
5. **Supported Layouts**: replaced "the signature 4-tile minimum" with "the signature 1–5 tile authoring scale (modes ONE through FIVE)".

The "Why PentaTile?" / "Choosing the Right Tool" sections still mention "four base tiles" / "only 4 tiles" in copy that the review did not flag specifically; left as-is for the Wave 5 README pass to handle holistically (mid-pass edits to marketing prose risk regression of phrasing not flagged for review).

---

_Fixed: 2026-04-26_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
