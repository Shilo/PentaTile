---
phase: 01-contract-skeleton-tetra-layouts
plan: 03
subsystem: api
tags: [godot, layout-subclass, tetra-horizontal, tetra-vertical, mask-to-atlas, dual-grid]

requires:
  - phase: 01-contract-skeleton-tetra-layouts/02
    provides: TetraTileLayout abstract base + TetraTileAtlasSlot Resource
provides:
  - TetraTileLayoutTetraHorizontal — first concrete layout (4×1 atlas, dual-grid, 4-bit corner mask, 16-state match relocated VERBATIM from v0.1 layer:116-152)
  - TetraTileLayoutTetraVertical — axis-swap subclass of horizontal (1×4 atlas, single _make_slot override)
affects: [01-04, 01-05, phase-2 (single-grid pipeline pattern reference), phase-3.5]

tech-stack:
  added: []
  patterns:
    - "Concrete-layout subclass discipline: extend TetraTileLayout, override 3 abstract virtuals + a layout-specific _make_slot helper that subclasses can axis-swap"
    - "Diagonal-overlay encoding: AtlasSlot.diagonal_complement_atlas_coords + alternative_tile (packed via _pack_alternative) carries the secondary paint info for mask 6 / 9 cases"

key-files:
  created:
    - addons/tetra_tile/layouts/tetra_tile_layout_tetra_horizontal.gd (118 LOC)
    - addons/tetra_tile/layouts/tetra_tile_layout_tetra_vertical.gd (29 LOC)
  modified: []

key-decisions:
  - "Vertical extends Horizontal (NOT the base) per locked PATTERNS anti-pattern #4 — keeps the 16-state match as a single source of truth, vertical = pure axis-swap"
  - "Mask 6 and mask 9 (diagonal cases) encode complement info as a 4-arg _make_slot call: (primary_idx, primary_transform, complement_idx, complement_transform) — Plan 04's _paint_with_slot reads diagonal_complement_atlas_coords + the packed alternative_tile to drive the overlay paint"
  - "Mask 0 returns null from mask_to_atlas — the dispatcher short-circuits to erase. Don't allocate an empty AtlasSlot."

patterns-established:
  - "Concrete layout file structure: header doc-comment → class_name + extends → constants → 3 abstract overrides → _make_slot helper. Vertical-style siblings override only _make_slot."
  - "Sample-fn Callable protocol: layouts call sample_fn.call(coord + offset) — never reach into the layer for get_cell_source_id"

requirements-completed:
  - TETRA-01
  - TETRA-02

duration: ~5min
completed: 2026-04-26
---

# Plan 01-03: Concrete Tetra Layouts Summary

**The 16-state match block from v0.1 layer:116-152 is now a method on TetraTileLayoutTetraHorizontal returning AtlasSlot instances. TetraTileLayoutTetraVertical is a 29-LOC axis-swap subclass that inherits the entire match table.**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-04-26
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- `TetraTileLayoutTetraHorizontal` shipped (TETRA-01) — extends `TetraTileLayout`, all 3 abstract virtuals overridden, 16-state match relocated VERBATIM from v0.1 layer:116-152. Diagonal-overlay encoding (masks 6/9) wired into `AtlasSlot.diagonal_complement_atlas_coords` + packed `alternative_tile`.
- `TetraTileLayoutTetraVertical` shipped (TETRA-02) — extends Horizontal, overrides ONLY `_make_slot`. 29 LOC (under the 35 budget).
- All 5 Phase 1 `.gd` files now parse together cleanly (slot + layout-base + contract + horizontal + vertical).

## Task Commits

1. **Task 2.1: TetraTileLayoutTetraHorizontal** — `54794b3` (feat) — 118 LOC, 16-state match + 4 archetype constants + 4 rotation constants + 4 corner-offset constants + `_make_slot(tile_index, transform_flags, complement_tile_index=-1, complement_transform=0)` helper
2. **Task 2.2: TetraTileLayoutTetraVertical** — `7c74087` (feat) — 29 LOC, `_make_slot` override swaps `Vector2i(tile_index, 0)` → `Vector2i(0, tile_index)`

## Files Created/Modified

- `addons/tetra_tile/layouts/tetra_tile_layout_tetra_horizontal.gd` — 118 LOC. Concrete tetra layout for the v0.1 horizontal axis. Self-contained except for the inherited `_pack_alternative` helper from the base.
- `addons/tetra_tile/layouts/tetra_tile_layout_tetra_vertical.gd` — 29 LOC. Pure axis-swap subclass; inherits the entire 16-state match unchanged.

### Diagonal-overlay encoding (masks 6 and 9)

From the horizontal `mask_to_atlas`:

```gdscript
6:
    # Diagonal: primary on _primary_layer, complement on _overlay_layer.
    return _make_slot(_OUTER_CORNER, _ROTATE_180, _OUTER_CORNER, _ROTATE_0)
9:
    # Diagonal — complement transform is _ROTATE_270 (per v0.1 line 140).
    return _make_slot(_OUTER_CORNER, _ROTATE_90, _OUTER_CORNER, _ROTATE_270)
```

The 4-argument form sets `slot.diagonal_complement_atlas_coords = Vector2i(complement_tile_index, 0)` and packs the complement transform into `slot.alternative_tile` via `_pack_alternative(0, complement_transform)`. Plan 04's dispatcher reads both halves to drive the two-layer paint.

### Combined Phase 1 file count so far

5 `.gd` files total under `addons/tetra_tile/`:

```
addons/tetra_tile/
├── tetra_tile_atlas_contract.gd       (Plan 02)
├── tetra_tile_atlas_slot.gd           (Plan 02)
├── tetra_tile_map_layer.gd            (v0.1 base + Plan 01-01 instrumentation)
└── layouts/
    ├── tetra_tile_layout.gd                        (Plan 02)
    ├── tetra_tile_layout_tetra_horizontal.gd       (this plan)
    └── tetra_tile_layout_tetra_vertical.gd         (this plan)
```

## Decisions Made

- Followed plan's verbatim content exactly. No design improvisation.
- Diagonal-overlay encoding interpretation locked: `alternative_tile` carries the complement's transform flags (packed via `_pack_alternative(0, transform)`) for the overlay-layer paint, while `transform_flags` carries the primary-layer transform. Plan 04's `_paint_with_slot` is responsible for unpacking.

## Deviations from Plan

### 1. Horizontal LOC overshoots the plan's "between 70 and 100" acceptance range

- **Found during:** Task 2.1 verification
- **Issue:** The plan specified VERBATIM file content AND required line count "between 70 and 100" / "≤ 100 LOC" in success criteria. The plan's verbatim content as provided produces 118 LOC (the comment volume + per-mask diagonal-overlay comments push it over the budget).
- **Fix:** Preserved the plan's verbatim content. Trimming comments to fit the budget would deviate from the explicit "VERBATIM" directive. The functional content matches the plan exactly: 16-state match present, all 4 constant blocks present, all 3 abstract virtuals overridden, `_make_slot` helper signature matches.
- **Files affected:** `addons/tetra_tile/layouts/tetra_tile_layout_tetra_horizontal.gd`
- **Verification:** all functional grep checks pass (`_make_slot(` count = 16 + 1 = 17, matches expected ≥17; `match mask:` count = 1; parse exits 0 with all 5 files together).
- **Acceptance impact:** Soft acceptance miss on line count only. The `<success_criteria>` "Horizontal file ≤ 100 LOC" is also missed by 18 LOC. Recommend Plan 05's LOC checkpoint factor in this 18-LOC budget delta when running the addon-wide LOC audit.

**Total deviations:** 1 plan-content vs. plan-budget contradiction. No functional deviation.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- ✅ **Plan 01-04** can now rewrite the layer dispatcher to call `layout.compute_mask` + `layout.mask_to_atlas` + a new `_paint_with_slot` helper that unpacks `transform_flags` for the primary paint, and (when `diagonal_complement_atlas_coords != Vector2i(-1, -1)`) reads `alternative_tile` for the overlay paint's transform.
- ✅ **Plan 01-05** can instantiate `TetraTileLayoutTetraHorizontal.new()` and `TetraTileLayoutTetraVertical.new()` for the bundled `.tres` files.
- ✅ **Phase 2** Wang2Edge / Wang2Corner can use this same subclass + `_make_slot` pattern (the axis-swap helper generalizes naturally to any layout that needs a column-vs-row axis variant).

---
*Phase: 01-contract-skeleton-tetra-layouts*
*Completed: 2026-04-26*
