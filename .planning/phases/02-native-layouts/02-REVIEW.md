---
phase: 02-native-layouts
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - addons/penta_tile/penta_tile_map_layer.gd
  - addons/penta_tile/penta_tile_atlas_slot.gd
  - addons/penta_tile/penta_tile_synthesis.gd
  - addons/penta_tile/layouts/penta_tile_layout.gd
  - addons/penta_tile/layouts/penta_tile_layout_penta.gd
  - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd
  - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd
  - addons/penta_tile/_generate_bitmasks.py
  - addons/penta_tile/tests/determinism_test.gd
  - addons/penta_tile/tests/_capture_baseline.gd
  - addons/penta_tile/demo/penta_tile_demo.tscn
  - addons/penta_tile/demo/penta_layout_four_horizontal.tres
  - addons/penta_tile/demo/penta_layout_one_horizontal.tres
  - addons/penta_tile/demo/penta_layout_five_horizontal.tres
  - README.md
findings:
  critical: 0
  warning: 6
  info: 9
  total: 15
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 16 (Phase 2 surface area + carry-over project conventions)
**Status:** issues_found

## Summary

Phase 2 ships the native layout family (Penta with synthesis, DualGrid16, Wang2Edge, Wang2Corner, Minimal3x3), the synthesis machinery, and a determinism test harness. Overall code quality is high and the project conventions documented in `CLAUDE.md` are honored well:

- No `randi()` / `randf()` / `randomize()` anywhere in the addon. Determinism tests assert bit-identical re-runs.
- No version markers, schema-version constants, or compat shims on Resources.
- "Penta" is correctly reserved for the 5-archetype format throughout.
- Setter idempotence guards present on the layer's `layout` property and on Penta's `axis` / `tile_count`.
- Disconnect-before-reconnect on `Resource.changed` is correctly applied to the `layout` setter.
- `_pack_alternative` helper exists in the base class with the `< 4096` assert (PITFALLS §3 honored at the abstraction level).

Most findings are correctness gaps in the synthesis polygon clipper and latent bugs in code paths that are not exercised by current call sites (multi-strip synthesis, in-place TileSet mutations under AUTO mode). One Warning category covers stale documentation in the README that no longer matches the Phase 2 architecture (overlay layer removed, four-tile minimum is no longer accurate). README staleness is flagged because Wave 5 is explicitly the README pass — these notes give that pass a punch list.

No Critical issues found. No security issues are applicable (this is a pure GDScript editor/runtime addon with no I/O outside Godot's load() and no untrusted input).

## Warnings

### WR-01: Polygon clipper drops "outside-to-outside-through-rect" segments

**File:** `addons/penta_tile/penta_tile_synthesis.gd:175-203`
**Issue:** `clip_polygon_to_subrect` only handles three Sutherland-Hodgman cases per edge: both-in, in-out, out-in. The fourth case — both endpoints outside the sub_rect but the segment passing THROUGH it (entering one side, exiting another) — falls into the `# else: both outside → skip` branch and the two crossing points are lost. For a Penta SLOT_FILL clip (center 50% sub-rect), any source polygon edge that bridges two outside regions while crossing the sub-rect will silently drop its in-rect portion. Convex source polygons (the typical case for collision rectangles) avoid this; concave or large-radius polygons that wrap around the sub-rect are silently mis-clipped. Bug is latent on the demo's 4 simple rectangular polygons — it will surface the moment a user authors a non-convex collision shape.
**Fix:** Implement the both-outside-but-crossing case using two edge clips:
```gdscript
elif not v_i_in and not v_next_in:
    # Test if the segment crosses the sub_rect at all (Liang-Barsky parametric).
    var entry_t := -INF
    var exit_t := INF
    # ... compute t_in/t_out per axis-aligned slab; if entry_t < exit_t, segment crosses.
    # Append both crossing points to clipped[].
```
Or replace the hand-rolled clipper with the canonical Sutherland-Hodgman algorithm (clip against each of the 4 half-planes in turn). The latter is shorter and handles all four cases naturally.

### WR-02: Synthesis cache does not invalidate on in-place TileSet mutations under AUTO mode

**File:** `addons/penta_tile/penta_tile_map_layer.gd:305-342`
**Issue:** The cache signature includes `tile_set.get_instance_id()` but not any content hash of the TileSet. If a user calls `_ensure_synthesized_tile_set` once with a 4-tile atlas (mode resolves to FOUR via AUTO), then mutates the same TileSet instance to add a 5th tile, the next paint event re-uses the cached FOUR-mode synthesized TileSet because `instance_id`, `axis`, `tile_count`, and `source_id` all unchanged. The synthesized 5th archetype slot stays as the auto-synthesized OppositeCorners, never picking up the newly-authored one. The Wave 6 `resolve_active_mode` reads `get_atlas_grid_size()` fresh on each call but its result is dropped because the OUTER cache hits before that lookup runs.
**Fix:** Either listen to `tile_set.changed` and invalidate `_synthesis_signature = 0` from the handler, or move the `resolve_active_mode` call ABOVE the cache check and include the resolved mode in the signature:
```gdscript
var mode := penta_tile_count
if penta.has_method("resolve_active_mode"):
    mode = int(penta.call("resolve_active_mode", tile_set, source_id))
var sig := hash([
    penta.get_instance_id(), penta_axis, penta_tile_count,
    source_tile_set_id, source_id, mode,   # mode in signature catches AUTO drift
])
```
The second fix is cheaper but only catches mode drift, not tile pixel mutations. A `tile_set.changed` listener catches both at the cost of one signal hookup matching the existing `_on_layout_changed` pattern.

### WR-03: `synthesize_strip` source-coords formula assumes spacing of 5 per strip — wrong for AUTO modes other than FIVE

**File:** `addons/penta_tile/penta_tile_synthesis.gd:114-124`
**Issue:** `src_atlas_coords = Vector2i(strip_index * _STRIP_SLOT_COUNT + out_slot, 0)` — multiplying `strip_index` by `_STRIP_SLOT_COUNT (5)` assumes every source strip is exactly 5 tiles wide regardless of `mode`. In AUTO_STRIP detection, individual strips can be 1..5 tiles wide independently. With this formula, strip 1 in a mixed atlas is read from coord 5 onward — but if strip 0 is 4 tiles wide, strip 1 actually starts at coord 4, not 5. Latent because the only call site (`_ensure_synthesized_tile_set`) hardcodes `strip_index = 0`. Wave 6's `resolve_strip_modes` exists on the layout but is not yet wired to `synthesize_strip`. When AUTO_STRIP per-strip dispatch lands, this formula will produce off-by-one (or off-by-N) reads.
**Fix:** When AUTO_STRIP per-strip dispatch is implemented, pass an explicit `strip_origin: Vector2i` argument to `synthesize_strip` instead of computing it from `strip_index * _STRIP_SLOT_COUNT`. The caller (which knows the cumulative offset based on prior strips' resolved modes) is the only place that has correct origin information. Update the docstring's `strip_index` parameter to reflect this. For now, add a TODO above line 114 noting the formula is only valid for `strip_index = 0`.

### WR-04: `_BITMASK_TEMPLATE_LOOKUP` enum values clash with axis values

**File:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd:83-95`
**Issue:** `_BITMASK_TEMPLATE_LOOKUP` keys are `Vector2i(axis, mode)` where `axis ∈ {0, 1}` and `mode ∈ {1..5}`. `TileCountMode.AUTO_STRIP = -1` and `TileCountMode.AUTO = 0`. If a future caller invokes `get_fallback_tile_set()` without first resolving AUTO/AUTO_STRIP and a typo replaces `Vector2i(axis, mode)` with `Vector2i(mode, axis)`, key `Vector2i(0, 0)` (AUTO + HORIZONTAL) collides with itself in a way that's hard to spot. More immediately, the `Axis` enum and `TileCountMode` enum overlap in numeric range (HORIZONTAL=0 == AUTO=0; VERTICAL=1 == ONE=1). The lookup happens to work because the field POSITION in `Vector2i` distinguishes them, but a code reader has no static type signal that the first int is "axis" vs "mode."
**Fix:** Either:
1. Use a 2-key tuple-flavored Dictionary literal style `{axis_horizontal_mode_one: "...", ...}` with explicit string-named constants (verbose but typo-resistant), or
2. Wrap the lookup in a typed accessor: `func _bundled_png_path(a: Axis, m: TileCountMode) -> String:` that asserts `m >= TileCountMode.ONE` before constructing the key. Even just the assertion would catch the AUTO/AUTO_STRIP key-miss class of bug at the point of failure rather than at the empty-string return.

### WR-05: `_synthesize_slot_image` returns the original atlas image's `get_region` result without defensive copy for SLOT_INNER_CORNER

**File:** `addons/penta_tile/penta_tile_synthesis.gd:496-511`
**Issue:** `var full_img := atlas_image.get_region(full_region)` — `Image.get_region()` returns a NEW image in Godot 4.x (not a view), so the subsequent `set_pixel` calls do not mutate the source atlas. This is correct behavior — but the code reads as if it might be aliasing the source. More importantly, the `set_pixel` loop runs `(half_x * half_y)` calls per synthesis invocation. For a 32×32 tile that's 256 set_pixel calls; for a 64×64 it's 1024. `Image.fill_rect()` with a transparent color over the TR quadrant rectangle would be O(1) call count and clearer intent.
**Fix:**
```gdscript
SLOT_INNER_CORNER:
    var full_region := Rect2i(slot0_px.x, slot0_px.y, ts.x, ts.y)
    var full_img := atlas_image.get_region(full_region)
    full_img.fill_rect(
        Rect2i(ts.x / 2, 0, ts.x / 2, ts.y / 2),
        Color(0.0, 0.0, 0.0, 0.0)
    )
    return full_img
```
Equivalent output, cleaner reading, and avoids a tight `set_pixel` loop in synthesis (which runs every paint under AUTO mode if the cache is invalidated).

### WR-06: README drift — describes Phase 1's overlay layer + four-tile contract that Phase 2 deleted

**File:** `README.md:79, 113-126, 140-156, 173-183`
**Issue:** Multiple sections describe v0.1 architecture that no longer matches Phase 2:
- Line 79 ("§ Penta-System Template"): "two transformed outer corners on an internal overlay layer" — Phase 2 Wave 2 deleted the overlay layer entirely (single-layer dispatch in `penta_tile_map_layer.gd:230-251`). Diagonals now resolve to a synthesized OppositeCorners archetype.
- Lines 113-126 ("§ Addon Layout"): the file tree omits `layouts/`, `tests/`, `_generate_bitmasks.py`, `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, and the per-Penta-mode PNG bundle. It still mentions the Phase 1 `penta_tile_template.png` as if it were the only template.
- Lines 140-156 ("§ Current API"): lists `atlas_layout` as an exported property, but Phase 2 removed it entirely. The actual property is `layout: PentaTileLayout`. Misses `axis`, `tile_count` (Penta-side props that are user-facing through the inspector), and the new `bitmask_template` (auto-hidden on Penta). Also lists `atlas_source_id` purpose but not the new layout-driven dispatch.
- Lines 173-183 ("§ Implementation Notes"): mentions "drawn by placing one outer corner on the primary visual layer and the other on the internal overlay layer" — same overlay-layer staleness as line 79.

This is a documentation issue, not a code defect, and Wave 5 (the README+CHANGELOG+release pass per `ROADMAP.md`) is explicitly scoped to fix it. Flagging here so Wave 5 has an explicit punch list and so reviewers don't read the README as architectural truth in the meantime.
**Fix:** Wave 5 README pass should:
1. Replace overlay-layer prose with the synthesis pipeline (slot 0 → IsolatedCell + 4 synthesized archetypes via `PentaTileSynthesis`).
2. Refresh the file-tree to include `layouts/`, `tests/`, `_generate_bitmasks.py`, `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, the `layouts/penta_tile_layout_penta/` PNG bundle, and the four flat-sibling layout PNGs.
3. Replace the `atlas_layout` row in the API table with `layout: PentaTileLayout`. Document `axis` and `tile_count` (Penta-specific) either inline or via a dedicated Penta layout subsection.
4. Reword the "diagonal masks 6 and 9" paragraph to describe the OppositeCorners archetype (synthesized in modes ONE..FOUR; authored in mode FIVE) rather than the deleted overlay-layer composition.

## Info

### IN-01: `_pack_alternative` helper exists but no subclass uses it

**File:** `addons/penta_tile/layouts/penta_tile_layout.gd:44-46`
**Issue:** Base class defines `_pack_alternative(alt_id, transform_flags)` with the `< 4096` assert per PITFALLS §3, but every subclass `_make_slot` (Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3) sets `slot.transform_flags` and `slot.alternative_tile = 0` directly without OR-ing them via the helper. Today this is safe because all `alternative_tile` values are literally `0` — the OR is a no-op. The helper exists as a "safe-by-default" facility for the upcoming variation-bank work (Phase 3.5 PixelLab layouts), but in the meantime its only caller is itself.
**Fix:** Either (a) leave as-is and call `_pack_alternative` from variation-bank layouts when they ship, or (b) refactor `PentaTileAtlasSlot` to take `(atlas_coords, alt_id, transform_flags)` in a single setter that internally calls `_pack_alternative`, making the contract structurally enforce the rule rather than relying on each subclass to remember. (b) is the better long-term shape but a Phase 3 concern, not a Phase 2 blocker.

### IN-02: `Rect2.has_point` boundary semantics in `clip_polygon_to_subrect`

**File:** `addons/penta_tile/penta_tile_synthesis.gd:188-189`
**Issue:** `Rect2.has_point(p)` is inclusive on the rect's `position` (top-left) and exclusive on `end` (bottom-right). For a polygon vertex that lies EXACTLY on the right or bottom edge of `sub_rect`, `has_point` returns false, so the algorithm treats it as outside and computes a crossing point even though it's on the boundary. Result: a redundant duplicate vertex in the clipped polygon at that boundary point. Determinism is preserved (same inputs → same output), but the clipped polygon is sub-optimal.
**Fix:** Either accept the duplicate (it's harmless for collision/occlusion polygon rendering) or use a strict-inclusive boundary test:
```gdscript
func _point_in_or_on_rect(p: Vector2, r: Rect2) -> bool:
    return p.x >= r.position.x and p.x <= r.end.x \
        and p.y >= r.position.y and p.y <= r.end.y
```
Low-priority polish.

### IN-03: Occlusion polygon "discard the rest" comment is misleading

**File:** `addons/penta_tile/penta_tile_synthesis.gd:331-345`
**Issue:** Comment block says "no multi-polygon-per-layer API exists. We take the first polygon in the polys array (if any) and discard the rest." But `_extract_tile_polygons` only ever puts ONE polygon in the per-layer array (line 429: `occlusion_dict[layer_idx] = [occ.polygon]`), so there is never any "rest" to discard. The discard wording suggests there might be data loss; in practice there isn't.
**Fix:** Trim the comment to: "Godot 4.6 TileData supports one OccluderPolygon2D per layer. Build the new occluder from the single source polygon."

### IN-04: Magic number `_STRIP_SLOT_COUNT = 5` shared with implicit slot ordering

**File:** `addons/penta_tile/penta_tile_synthesis.gd:37, 102-106` and `addons/penta_tile/layouts/penta_tile_layout_penta.gd:102-106`
**Issue:** Two source files independently declare slot index constants (`SLOT_ISOLATED_CELL = 0` etc. in synthesis; `_SLOT_ISOLATED_CELL = 0` etc. in penta layout) with comments noting the constants must stay in sync manually. The penta layout file's comment promises "an assert in PentaTileSynthesis guards divergence" — but no such assert exists in `penta_tile_synthesis.gd` (greppable: no `assert(... == _SLOT_*)` runtime check). The two files are in sync today by inspection but nothing PREVENTS divergence.
**Fix:** Either (a) add the promised assert in `_PentaTileSynthesis` static init or `synthesize_strip` entry: `assert(SLOT_ISOLATED_CELL == 0 and SLOT_FILL == 1 ...)` is redundant on its own — what's needed is the cross-class match. The cleanest GDScript-2 option is to delete the duplicates from `penta_tile_layout_penta.gd` and reference `_PentaTileSynthesis.SLOT_*` via the same `preload()` pattern the layer uses (line 12 of `penta_tile_map_layer.gd`). Or (b) downgrade the comment to match reality: "values must stay in sync manually; no runtime guard."

### IN-05: `validate_tile_size` warning string-substring matching for hard-vs-soft errors

**File:** `addons/penta_tile/penta_tile_synthesis.gd:88-90, 220-228`
**Issue:** `synthesize_strip` distinguishes hard-stop warnings ("square tiles", "must be even") from soft warnings ("below 4 px") by substring search on the warning text:
```gdscript
for w: String in warnings:
    if "square tiles" in w or "must be even" in w:
        return {"slots": [], "tile_size": tile_size, "warnings": warnings}
```
Edit the warning text in `validate_tile_size` and the synthesis hard-stop logic silently breaks. This is a fragile coupling between human-readable strings and control flow.
**Fix:** Return structured warnings with a severity tag:
```gdscript
static func validate_tile_size(tile_size: Vector2i) -> Array:
    var warnings: Array = []
    if tile_size.x != tile_size.y:
        warnings.append({"severity": "error", "message": "...", "code": "non_square"})
    if tile_size.x % 2 != 0:
        warnings.append({"severity": "error", "message": "...", "code": "odd"})
    if tile_size.x < 4:
        warnings.append({"severity": "warning", "message": "...", "code": "small"})
    return warnings
```
Then `synthesize_strip` checks `w.severity == "error"`. Or simpler: add a separate `is_tile_size_blocking(tile_size: Vector2i) -> bool` that returns the boolean directly without round-tripping through human-readable text.

### IN-06: `resolve_active_mode` has a redundant guard branch

**File:** `addons/penta_tile/layouts/penta_tile_layout_penta.gd:219-228`
**Issue:**
```gdscript
if tile_count != TileCountMode.AUTO and tile_count != TileCountMode.AUTO_STRIP:
    return tile_count
if tile_count == TileCountMode.AUTO_STRIP:
    return TileCountMode.AUTO_STRIP
```
Reaching the second `if` requires the first `if` to have been false — which means `tile_count` IS AUTO or AUTO_STRIP. The second `if` returns AUTO_STRIP unchanged in the AUTO_STRIP case; the AUTO case falls through to the dimension-detection block. This is correct but the redundant explicit AUTO_STRIP early-return obscures that AUTO_STRIP is intentionally unresolved at this stage.
**Fix:** Either inline the AUTO_STRIP intent into the dimension branch with a comment:
```gdscript
if tile_count != TileCountMode.AUTO and tile_count != TileCountMode.AUTO_STRIP:
    return tile_count   # explicit ONE..FIVE pass through unchanged
# AUTO_STRIP intentionally unresolved here (per-strip detection lives in resolve_strip_modes).
if tile_count == TileCountMode.AUTO_STRIP:
    return TileCountMode.AUTO_STRIP
```
Or restructure:
```gdscript
match tile_count:
    TileCountMode.AUTO_STRIP:
        return TileCountMode.AUTO_STRIP
    TileCountMode.AUTO:
        # fall through to dimension detection below
        pass
    _:
        return tile_count
# dimension detection ...
```

### IN-07: Test harness baseline hash hard-coded as a magic constant

**File:** `addons/penta_tile/tests/determinism_test.gd:21`
**Issue:** `const BASELINE_HASH := 2986698704` — a hard-coded integer with no machine-readable provenance other than a comment pointing to `four_mode_5x5.txt`. If the baseline ever needs to be regenerated (e.g., synthesis algorithm legitimately changes), the developer has to manually copy the new hash from the capture script's stdout into this file. Manual coupling risks stale baselines.
**Fix:** Read the baseline from the same `four_mode_5x5.txt` artifact at test-init time:
```gdscript
var f := FileAccess.open("res://addons/penta_tile/tests/baselines/four_mode_5x5.txt", FileAccess.READ)
# Parse the first int matching /BASELINE_HASH=(\d+)/ from the file body.
```
Accepts the trade-off: test now depends on the baseline file existing and parseable, but a stale-baseline scenario surfaces as "baseline file missing" rather than "hash mismatch debugging."

### IN-08: `_capture_baseline.gd` claims "NOT committed to git" but IS tracked

**File:** `addons/penta_tile/tests/_capture_baseline.gd:1`
**Issue:** Top-of-file comment says "Temporary baseline capture script — NOT committed to git." `git ls-files` confirms it IS tracked (`addons/penta_tile/tests/_capture_baseline.gd` shows as a tracked path). Either the comment is stale or the file was committed by mistake. Underscore prefix + "Temporary" wording suggests intent to keep it untracked; the actual repo state contradicts that intent.
**Fix:** Pick one of:
1. Update the comment to match reality: "Baseline capture utility — committed for reproducibility. Run when the synthesis algorithm changes to regenerate `tests/baselines/four_mode_5x5.txt` + `BASELINE_HASH` in `determinism_test.gd`."
2. Add `addons/penta_tile/tests/_capture_baseline.gd` to `.gitignore` and `git rm --cached` it (only if intent really is local-only).

Option 1 matches the surrounding test infrastructure (which IS committed) and is the more defensible state.

### IN-09: `penta_tile_atlas_slot.gd` exports `alternative_tile` as a separate field but it's always 0 today

**File:** `addons/penta_tile/penta_tile_atlas_slot.gd:14`
**Issue:** `@export var alternative_tile: int = 0` is exposed as a slot-level field, but every layout sets it to 0 and the layer's `_paint_with_slot` does NOT consume it (line 177 in `penta_tile_map_layer.gd`: `layer.set_cell(display_cell, source, slot.atlas_coords, slot.transform_flags)` — alternative_tile is dropped). The field is dead weight in Phase 2. Either it's reserved for variation banks (Phase 3.5) and should be commented as such, or it should be deleted until variation lands.
**Fix:** Add a one-line comment above the export: `# Reserved for variation-bank wiring in Phase 3.5; ignored by the layer in Phase 2.` Alternatively, delete the field entirely until Phase 3.5 needs it (per CLAUDE.md "no forward-compat speculation" — though `PentaTileAtlasSlot` is the natural home for the field when it does land, so leaving it with a clear "reserved" note is defensible). A passing comment is the lowest-cost fix.

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
