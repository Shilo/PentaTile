---
phase: 02-native-layouts
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 18
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
  - tests/determinism_test.gd
  - tests/_capture_baseline.gd
  - addons/penta_tile/demo/penta_tile_demo.tscn
  - addons/penta_tile/demo/penta_layout_four_horizontal.tres
  - addons/penta_tile/demo/penta_layout_four_vertical.tres
  - addons/penta_tile/demo/penta_layout_one_horizontal.tres
  - addons/penta_tile/demo/penta_layout_five_horizontal.tres
  - README.md
findings:
  critical: 0
  warning: 0
  info: 13
  total: 13
status: clean
---

# Phase 2: Code Review Report (Re-Review)

**Reviewed:** 2026-04-26 (re-review after 7 fix commits + 1 user-authored test commit)
**Depth:** standard
**Files Reviewed:** 17 (Phase 2 surface area + carry-over project conventions; +1 vs prior review for the new VERTICAL `.tres`)
**Status:** clean (no Critical or Warning findings; 9 Info items unchanged from prior pass and intentionally deferred per their dispositions)

## Summary

All 7 prior Critical/Warning findings (WR-01 through WR-07) have been fixed correctly:

| ID    | Fix Commit | Verified | Notes |
|-------|-----------|----------|-------|
| WR-01 | `ae5d787` | YES | Replaced hand-rolled clipper with canonical Sutherland-Hodgman (`_clip_against_edge` + `_intersect_edge` + `_point_inside_edge`). All 4 crossing cases handled per-edge. Inclusive boundary (`>=` / `<=`) naturally resolves IN-02 as a side-effect. |
| WR-02 | `9ca342e` | YES | `_ensure_synthesized_tile_set` now resolves AUTO/AUTO_STRIP via `resolve_active_mode` BEFORE building the cache signature, and includes the resolved `mode` in `hash([...])`. AUTO drift correctly invalidates. (Tile-pixel-mutation gap acknowledged — see IN-10 below — and intentionally not fixed in this pass.) |
| WR-03 | `d74df0e` | YES | `synthesize_strip` now accepts an optional `strip_origin: Vector2i = Vector2i(-1, -1)` sentinel. Authored slot coords step off `slot0_coords` along the configured axis. Default sentinel preserves the legacy uniform-stride formula for the existing single-strip caller. |
| WR-04 | `2ca04e0` | YES | `_bundled_png_path(a: Axis, m: TileCountMode)` typed accessor with `assert(m >= ONE and m <= FIVE)` keys the lookup safely. `get_fallback_tile_set` forces AUTO/AUTO_STRIP → FOUR before the call so the assert never trips on intended use. |
| WR-05 | `720f017` | YES | `SLOT_INNER_CORNER` synthesis now uses single `Image.fill_rect` for the TR-quadrant blank instead of a 256+ `set_pixel` loop. Equivalent output, far fewer engine crossings. |
| WR-06 | `79af1e3` | YES | README sections refreshed: Penta-System Template now describes the synthesis pipeline (no overlay layer); Addon Layout file tree includes `layouts/`, `tests/`, `_generate_bitmasks.py`, synthesis + atlas-slot scripts, the per-mode PNG bundle; Current API replaces the deleted `atlas_layout` row with `layout: PentaTileLayout` + Penta-specific `axis` / `tile_count`; Implementation Notes rewrites the diagonal-mask paragraph for OppositeCorners. |
| WR-07 | `ea0ba23` | YES | `_make_slot` now unconditionally returns `Vector2i(slot_index, 0)` regardless of `axis`. Comment explicitly documents the contract: synthesized atlas is always horizontal; `axis` only governs source READS. The latent VERTICAL-renders-empty BLOCKER is closed. |

The user-authored test commit `673ace0` adds:
- `addons/penta_tile/demo/penta_layout_four_vertical.tres` (NEW) — `axis=1, tile_count=4` mirror of the horizontal demo layout. Used as the WR-07 regression baseline corpus.
- `tests/_capture_baseline.gd` — `--layout-path=<res_path>` CLI flag for swapping the demo's bound layout before rebuild + explicit `_on_layout_changed()` invocation to invalidate the synthesis cache after the swap. Behavior without the flag is unchanged.
- `tests/determinism_test.gd` — sub-test (c) "VERTICAL-axis structural coverage": loads VERTICAL FOUR, asserts (1) painted cell count matches `BASELINE_CELLS=46` from HORIZONTAL, (2) every painted cell's atlas coord exists in the synthesized atlas. Catches the WR-07 failure mode without relying on a per-axis pixel-hash baseline (post-WR-07, both axes produce identical `tile_map_data` hashes since the output strip is invariant — so the bare hash cannot distinguish VERTICAL working from VERTICAL broken; the structural check fills that gap).

The test additions are clean — no `randi()` / non-deterministic patterns, no `eval`/`exec` constructs, no compat shims, no debug artifacts left in tree. The cache-invalidation comment in both files honestly explains why an explicit `_on_layout_changed()` call is needed after `layout` property assignment (the setter only calls `_queue_rebuild`; the cache nuke lives in the `Resource.changed` handler that fires on internal mutations, not on whole-property reassignment) — this is documented in the test code rather than papered over.

Project-convention compliance (CLAUDE.md):
- No `randi()` / `randf()` / `randomize()` anywhere in the addon source or tests (greppable).
- No `version` markers, schema-version constants, or migration scaffolding added by the fixes (greppable; the only `version=` string is `plugin.cfg`'s addon version, which is legitimate).
- "Penta" remains reserved for the 5-archetype format throughout — no new "Penta*" coinages outside the canonical class family.
- `_pack_alternative` helper still present with the `< 4096` assert (unused by Phase 2 layouts which all set `alternative_tile = 0`; reserved for variation-bank work in Phase 3.5).
- Setter idempotence guards preserved on `layout`, `axis`, `tile_count`.
- Disconnect-before-reconnect on `Resource.changed` preserved on the `layout` setter.

No Critical or Warning issues introduced by the fixes or by the test additions.

The 9 prior Info findings are unchanged. Their dispositions are unchanged from the prior review:
- IN-01 (`_pack_alternative` not yet called) — Phase 3.5 concern (variation banks).
- IN-02 (`Rect2.has_point` boundary) — naturally resolved as a side-effect of the WR-01 Sutherland-Hodgman rewrite (the new `_point_inside_edge` uses inclusive `>=` / `<=`); could be downgraded to "resolved" in the next pass.
- IN-03 (occlusion "discard the rest" comment) — cosmetic, deferred.
- IN-04 (slot-index const duplication across two files) — promised assert still missing; documentary risk only.
- IN-05 (substring-matching in `validate_tile_size`) — cosmetic, deferred.
- IN-06 (`resolve_active_mode` redundant guard branch) — cosmetic, deferred.
- IN-07 (baseline hash hard-coded as magic constant) — accepted trade-off.
- IN-08 (`_capture_baseline.gd` "NOT committed" comment stale) — comment is now correctly aligned with reality after the user-authored test commit, since the file is intentionally tracked AND now exposes a CLI for VERTICAL baseline regeneration. Trim to "Baseline capture utility" suggested but not blocking.
- IN-09 (`alternative_tile` field always 0) — Phase 3.5 concern.

One new Info item below (IN-10) carries the residual gap from the WR-02 fix: the cache invalidation now catches AUTO mode drift but not in-place tile pixel mutations under explicit modes. The original WR-02 finding flagged this as a trade-off; the chosen fix (option 2) is the cheaper of the two suggested approaches. Worth recording as Info so a future reviewer doesn't assume both halves were addressed.

## Info

### IN-10: WR-02 fix catches AUTO mode drift but NOT in-place tile pixel mutations

**File:** `addons/penta_tile/penta_tile_map_layer.gd:305-346`
**Issue:** The WR-02 fix (commit `9ca342e`) reorders mode resolution to land BEFORE the cache signature so AUTO/AUTO_STRIP mode drift correctly invalidates. The original WR-02 finding noted two possible fixes: (a) listen to `tile_set.changed` and invalidate from the handler — catches both mode drift AND tile pixel mutations, or (b) move `resolve_active_mode` above the cache check and include resolved mode in the signature — catches mode drift only. The implementation chose (b). A user who explicitly sets `tile_count = ONE..FIVE` (skipping AUTO) and then mutates the bound `TileSet`'s tile pixels in-place will still see stale synthesis output because the signature inputs (`instance_id`, `axis`, `tile_count`, `source_id`, resolved `mode`) all stay constant across the mutation.
**Fix:** Phase 2 demo + tests do not exercise this case (the demo never mutates the source TileSet at runtime), so this is a known latent gap rather than a present bug. Phase 3.5 (variation banks) is the natural place to revisit synthesis cache invalidation since variation banks introduce per-cell randomness that may want a finer-grained signature anyway. Until then, document the limitation in the layer's class doc-comment so a user who hits it knows to call `_on_layout_changed()` manually after a TileSet mutation. Or, if cheap enough, add a `tile_set.changed` listener using the same disconnect-before-reconnect pattern that already exists for `layout.changed`.

---

_Reviewed: 2026-04-26 (re-review)_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---

# Phase 2: Code Review Report (Third Pass)

**Reviewed:** 2026-04-26 (third pass — re-verification after the re-review marked status `clean`)
**Depth:** standard
**Files Reviewed:** 18 (full Phase 2 surface area; same scope as the re-review)
**Status:** clean (no new Critical or Warning findings; 3 small new Info items appended as IN-11 / IN-12 / IN-13)

## Summary

This third pass exists to confirm that nothing regressed under the seven WR fix commits or the user-authored test commit, and to surface any genuinely new issues missed by the re-review. The re-verification covers four explicit checks raised by the orchestrator:

**1. New Critical/Warning issues in the post-fix code?** None found.

**2. Are the test additions correct?**
- `_capture_baseline.gd`'s `--layout-path` parsing is **safe**. The flag is read via `OS.get_cmdline_user_args()`, which only returns args after the `--` sentinel — the script must be invoked with `--script` (a developer-only entry point), so command-line injection is not a meaningful threat (the user already has full code execution at that point). The value is fed to Godot's `load()`, which scopes resource resolution to `res://` by default; non-`res://` strings either fail the cast or load nothing, both handled by the explicit null guard. No path-traversal vulnerability.
- `determinism_test.gd` sub-test (c) **does** catch what it claims. Pre-WR-07, `_make_slot` for VERTICAL FOUR returned `Vector2i(0, slot_index)`. The synthesizer always builds a horizontal strip with tiles registered at `(0..4, 0)`. After paint, either (i) Godot drops cells whose atlas coords don't resolve in the source — Assertion 1 (`cell_count == 46`) catches that, or (ii) Godot keeps the cell with an unrenderable atlas reference — Assertion 2 (`source.has_tile(atlas_coord)`) catches that. Both failure modes are covered. The test correctly uses a fresh demo scene instance distinct from the main test's instance, avoiding state pollution.

**3. Did any WR fix introduce regressions missed by the re-review?**
- **WR-01 (Sutherland-Hodgman replacement):** Algorithmic correctness verified. `_clip_against_edge` uses standard per-edge clipping with the four crossing cases collapsing naturally (in/in emits curr; in/out emits intersection; out/in emits intersection + curr; out/out emits nothing). `_point_inside_edge` is inclusive at the boundary (resolves IN-02 as documented). `_intersect_edge` guards `dx == 0.0` / `dy == 0.0` for axis-aligned segments. No edge case dropped.
- **WR-04 (mode assert):** Verified the assert never trips on legitimate AUTO usage. `get_fallback_tile_set()` resolves AUTO/AUTO_STRIP → FOUR (line 366-368) BEFORE the `_bundled_png_path(axis, resolved_mode)` call (line 374), so the assert at line 350 only ever sees concrete ONE..FIVE on real call paths. Manual misuse (a future caller bypassing `get_fallback_tile_set`) is exactly what the assert is designed to catch.
- **WR-07 (`_make_slot` axis-invariance):** No downstream consumer broken. `mask_to_atlas` returns the slot from `_make_slot` for every non-zero mask; the only consumer is `_paint_with_slot` in `penta_tile_map_layer.gd`, which feeds `slot.atlas_coords` straight into `layer.set_cell()`. The synthesized strip ALWAYS uses `(slot_index, 0)` keys (`build_tile_set_from_synthesis` line 389), so axis-invariant `_make_slot` is exactly correct. No path that sets atlas coords for the synthesized atlas via the user's `axis` enum remains.

**4. New Info items?** Three small ones (IN-11 / IN-12 / IN-13), documented below. None promote to Warning.

The re-review's headline is unchanged: **fixes are correct, tests are correct, no Critical/Warning issues**. The frontmatter `info: 9 / total: 9` from the re-review undercounted by 1 (IN-10 was added in the re-review body but the count wasn't bumped); this third pass corrects to `info: 13 / total: 13` (IN-01..IN-13).

## Info

### IN-11: `--layout-path` arg parsing silently picks the last value on duplicates

**File:** `tests/_capture_baseline.gd:24-27`
**Issue:** The CLI loop iterates every cmdline user arg matching `--layout-path=` but never `break`s. If a developer accidentally passes the flag twice (e.g., `--layout-path=A --layout-path=B`), B silently wins with no warning. For a dev tool this is usually fine, but the silent-overwrite behavior is the kind of thing that wastes minutes of debug time when a CI invocation accidentally double-passes the arg.
**Fix:** Add `break` after the assignment, or print a `printerr("...duplicate --layout-path; using last value")` when a second match overrides the first. One-line change either way; not blocking.

### IN-12: `_capture_baseline.gd` LAYOUT_OVERRIDE print silently emits 0/0 for non-Penta layouts

**File:** `tests/_capture_baseline.gd:67-71`
**Issue:** The post-swap diagnostic prints `LAYOUT_OVERRIDE=%s axis=%d tile_count=%d` using `int(override_layout.get("axis"))` and `int(override_layout.get("tile_count"))`. `Resource.get(prop)` returns `null` if the property doesn't exist, and `int(null)` evaluates to `0` in GDScript without warning. So passing a non-Penta layout (e.g., `penta_tile_layout_dual_grid_16.tres` once Wave 5 ships those .tres files) prints `axis=0 tile_count=0` — visually identical to "HORIZONTAL AUTO Penta layout" output, which would mislead a reader scanning the log to confirm the swap. Phase 2's only baseline-eligible layouts are Penta-axis × Penta-mode, so this is a latent risk for Phase 3+ when more layout types ship.
**Fix:** Either (a) gate the print on `override_layout is PentaTileLayoutPenta` and emit a generic `"LAYOUT_OVERRIDE=%s class=%s" % [path, override_layout.get_class()]` for non-Penta layouts, or (b) print `null` explicitly when `get()` returns null (use `var ax = override_layout.get("axis"); var ax_str = str(ax) if ax != null else "(n/a)"`). Either keeps the diagnostic informative across all layout types.

### IN-13: `determinism_test.gd` top-of-file doc comment doesn't list sub-test (c)

**File:** `tests/determinism_test.gd:1-10`
**Issue:** The header doc-comment enumerates `Sub-test (a)`, `Sub-test (b)`, and `Main test`, but the third-pass-added `Sub-test (c) — VERTICAL-axis structural coverage` is absent from the list. The body of `_initialize()` correctly invokes all four; only the header is stale. A reader skimming the file header to understand test coverage would underestimate by one.
**Fix:** Add a fourth bullet to the header doc-comment block:
```gdscript
##   Sub-test (c) — VERTICAL-axis structural coverage (WR-07 regression net)
```
Trivial doc sync; not blocking.

---

_Reviewed: 2026-04-26 (third pass)_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
