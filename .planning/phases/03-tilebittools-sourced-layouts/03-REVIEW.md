---
phase: 03-tilebittools-sourced-layouts
reviewed: 2026-04-29T15:30:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - README.md
  - addons/penta_tile/_generate_bitmasks.py
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd.uid
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png.import
  - addons/penta_tile/penta_tile_map_layer.gd
  - tests/bitmask_bounds_test.gd
  - tests/blob_47_collapse_test.gd
  - tests/blob_47_collapse_test.gd.uid
  - tests/blob_47_hollow_test.gd
  - tests/blob_47_hollow_test.gd.uid
  - tests/comprehensive_bitmask_test.gd
  - tests/run_tests.ps1
  - tests/single_grid_8_moore_propagation_test.gd
  - tests/single_grid_8_moore_propagation_test.gd.uid
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: issues_found
supersedes: 2026-04-29T08:30:42Z (prior clean pass missed 3 Info nits surfaced on re-review)
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-29T15:30:00Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found (Info-level only — 0 Critical, 0 Warning, 3 Info)

## Summary

Phase 3 ships the `PentaTileLayoutBlob47Godot` layout, an 8-Moore neighbor propagation patch in `_mark_affected_single_grid_cells`, a Pillow generator extension for the bundled bitmask PNG, and three new regression tests. The matrix and bounds tests were extended to include Blob47Godot as a 6th layout under test.

Overall the code is high quality and well-aligned with project conventions. All ten Critical Pitfalls from `CLAUDE.md` were checked and the code is consistent with each:

- **Pitfall 1** (`alternative_tile` bit packing): `mask_to_atlas` sets `transform_flags = 0` and `alternative_tile = 0` — Blob47Godot does not use rotation reuse (D-77), so packing collisions are impossible.
- **Pitfall 2** (variation determinism): No variation banks (1-cell-per-mask). No `randi()` paths introduced.
- **Pitfall 3** (resource property renames): No renames in the new layout.
- **Pitfall 4** (setter loops + `Resource.changed` storms): No new `set:` blocks beyond inherited `bitmask_template`; existing idempotence guard + `_queue_rebuild` coalescer protect.
- **Pitfall 5** (non-rotating tileset table): N/A — Blob47Godot has no rotating table; `_MASK_TO_ATLAS` is a 47-entry direct lookup.
- **Pitfall 6** (top tiles): N/A — deferred to v2.
- **Pitfall 7** (`visible = false` cleanup): No change to existing `self_modulate.a` mitigation.
- **Pitfall 8** (single-grid layouts only render LOGIC-painted cells): The `_paint_via_layout` short-circuit still applies via `is_dual_grid()` returning false.
- **Pitfall 9** (`mask=0` is NOT erase for single-grid): `mask_to_atlas(0)` dispatches to `Vector2i(0, 0)` via the dict key (not the `.get` fallback) — verified by `blob_47_collapse_test`. Dual-grid short-circuit gates correctly on `active_layout.is_dual_grid()`.
- **Pitfall 10** (Penta canonical-silhouette enforcement): N/A — no rotation, no silhouette enforcement needed.

Coined-term discipline is preserved: the new class `PentaTileLayoutBlob47Godot` uses the project namespace prefix on a layout encoding the Blob format — no spurious "Penta" prefix on unrelated subsystems.

The 256→47 collapse algorithm in `_collapse_8bit_moore` is mathematically correct (a corner bit only survives if both adjacent edges are also set) and matches BorisTheBrave's published rule. The 47-mask `_MASK_TO_ATLAS` keys are exactly the values reachable via the collapse function over `[0, 256)` — verified by `blob_47_collapse_test.gd`. The 7×7 row-major packing math (`index → (col=index%7, row=index/7)`) is consistent across the layout, the Pillow generator (`BLOB_47_GODOT_MASKS`), and the bounds test's gap whitelist `[(5,6), (6,6)]`.

The `.uid`, `.png`, and `.png.import` files are auto-generated artifacts and produce no review findings.

The 8-Moore propagation in `_mark_affected_single_grid_cells` is correctly minimal — it expands the affected set to invalidate diagonal neighbors, but `_paint_via_layout`'s logic-painted-only short-circuit ensures unpainted cells in single-grid layouts still render nothing. Net behavior for the four cardinal-only layouts (Wang2Edge, Wang2Corner, Min3x3) is unchanged. The `single_grid_8_moore_propagation_test` correctly probes the regression: paint (1,1) first → mask=0 → atlas (0,0); paint diagonal (0,0) → expect (1,1) re-renders to atlas (0,2) via mask=8.

## Findings

### IN-01: Inconsistent `min()` / `max()` vs `mini()` / `maxi()` in extended test

**File:** `tests/comprehensive_bitmask_test.gd:204-207, 228-231, 239-242, 268-271`
**Severity:** Info
**Category:** Style

**Issue:** Uses Godot's polymorphic `min()` / `max()` global builtins for `int` operands. The companion test `blob_47_hollow_test.gd:102-105` uses the type-specific `mini()` / `maxi()` builtins for the same purpose. Both work in Godot 4.x; the polymorphic versions return Variant which then assign cleanly into `Vector2i` int fields. Style inconsistency, not a bug.

**Fix:** Optionally replace with the typed variants for consistency:

```gdscript
min_painted.x = mini(min_painted.x, c.x)
min_painted.y = mini(min_painted.y, c.y)
max_painted.x = maxi(max_painted.x, c.x)
max_painted.y = maxi(max_painted.y, c.y)
```

### IN-02: Dead-code dual-grid offset branch inside single-grid-only assertion

**File:** `tests/comprehensive_bitmask_test.gd:254-257`
**Severity:** Info
**Category:** Maintainability

**Issue:** The block

```gdscript
var canvas_origin := c_min * tile_size
if is_dual_grid:
    canvas_origin += Vector2i(- tile_size.x / 2, - tile_size.y / 2)
```

is inside an outer `if not is_dual_grid` guard at line 224. The `if is_dual_grid:` arm is therefore unreachable. Likely a leftover from a prior iteration where ASSERTION 5 also covered dual-grid before being scoped to single-grid only (per the comment block at lines 218-223 explaining the scope decision).

**Fix:** Remove the unreachable conditional:

```gdscript
var canvas_origin := c_min * tile_size
```

### IN-03: `mask_to_atlas` silently aliases unmapped collapsed masks to (0,0)

**File:** `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd:78-88`
**Severity:** Info
**Category:** Defensive Programming

**Issue:** The comment at lines 78-82 states the `.get(...)` fallback to `Vector2i(0, 0)` is "defensive only" because the collapse rule is total. Correct given the current `_collapse_8bit_moore` and 47-entry dict. However, if `_MASK_TO_ATLAS` is ever made non-total during future maintenance (e.g. a row deletion), an out-of-table mask silently aliases to the lonely-tile slot at `(0, 0)`, which is indistinguishable from a true `mask=0` dispatch. The `blob_47_collapse_test` would catch the test-time drift at the `dict.has(collapsed)` check, but only if the test is run.

**Fix:** Add an `assert()` so dict-vs-collapse drift surfaces at runtime in debug builds without changing release behavior:

```gdscript
var collapsed := _collapse_8bit_moore(mask)
assert(_MASK_TO_ATLAS.has(collapsed), "Blob47Godot _MASK_TO_ATLAS must cover all collapsed masks; missing key=%d" % collapsed)
var slot := PentaTileAtlasSlot.new()
slot.atlas_coords = _MASK_TO_ATLAS.get(collapsed, Vector2i(0, 0))
```

## Verification

The 5 focused test runs from the prior pass remain green for this codebase state:

- `./tests/run_tests.ps1 -NoPause -Test blob_47_collapse_test` — PASS
- `./tests/run_tests.ps1 -NoPause -Test single_grid_8_moore_propagation_test` — PASS
- `./tests/run_tests.ps1 -NoPause -Test blob_47_hollow_test` — PASS
- `./tests/run_tests.ps1 -NoPause -Test bitmask_bounds_test` — PASS
- `./tests/run_tests.ps1 -NoPause -Test comprehensive_bitmask_test` — PASS

(Test results carried forward from the 2026-04-29T08:30:42Z review pass — the 3 Info findings above are style/maintainability issues that don't affect test outcomes.)

---

_Reviewed: 2026-04-29T15:30:00Z_
_Reviewer: Claude (gsd-code-reviewer, re-review pass)_
_Depth: standard_
_Supersedes: 2026-04-29T08:30:42Z clean pass_
