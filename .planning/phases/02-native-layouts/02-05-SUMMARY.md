---
phase: 02-native-layouts
plan: 5
subsystem: asset-migration
tags: [png-migration, bitmask-templates, generator-script, readme-retarget, atomic-commit]

dependency_graph:
  requires:
    - phase: 02-04-PLAN
      provides: PentaTileLayoutDualGrid16/Wang2Edge/Wang2Corner/Minimal3x3 with stub get_fallback_tile_set() returning null
    - phase: 02-03-PLAN
      provides: PentaTileLayoutPenta with _BITMASK_TEMPLATE_LOOKUP keys at co-located PNG paths
  provides:
    - _generate_bitmasks.py at addons/penta_tile/ (regenerable greybox bitmask PNG generator)
    - 10 Penta variant PNGs in addons/penta_tile/layouts/penta_tile_layout_penta/
    - 4 flat-sibling PNGs at addons/penta_tile/layouts/ (DualGrid16, Wang2Edge, Wang2Corner, Min3x3)
    - README.md with live image tags pointing to co-located PNGs
  affects:
    - 02-06 (Wave 6 demo refresh — uses these PNGs as greybox fallback source for visible tiles)
    - Phase 5 (documentation references the new PNG paths)

tech-stack:
  added:
    - Pillow (PIL) — Python image generation library (dev-only tool; not a runtime dep)
  patterns:
    - co-located-png-sibling (layout PNG lives next to layout .gd file; no separate templates/ folder)
    - penta-subfolder-for-multi-variant (10 mode x axis PNGs live in penta_tile_layout_penta/ subfolder)
    - atomic-readme-png-commit (README path retarget and PNG migration land in same git commit — no intermediate 404)
    - tile32-scale (Phase 2 generator uses TILE=32px vs Phase 1's TILE=16px for finer silhouette detail)

key-files:
  created:
    - addons/penta_tile/_generate_bitmasks.py
    - addons/penta_tile/layouts/penta_tile_layout_penta/one_horizontal.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/one_vertical.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/two_horizontal.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/two_vertical.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/three_horizontal.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/three_vertical.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/four_vertical.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png
    - addons/penta_tile/layouts/penta_tile_layout_penta/five_vertical.png
    - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.png
    - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.png
    - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png
    - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.png
  modified:
    - README.md (three <img> tags retargeted)
  deleted:
    - addons/penta_tile/templates/ (entire folder: 5 PNGs + .import sidecars + old script + README)

decisions:
  - "line-70 retarget -> four_horizontal.png (preserves 4-tile-template feel of v0.1 reference; lines 5 and 30 -> five_horizontal.png to match all-5-archetypes alt-text)"
  - "TILE=32px for Phase 2 generator (doubles Phase 1's 16px TILE for finer silhouette geometry at 32px resolution)"
  - "draw_edge_mask center hint scaled from 6..9 (at 16px) to 12..19 (at 32px) to maintain proportional plus-arm geometry"
  - "5 new Penta archetype drawers derived from locked pixel-coordinate specs in 02-05-PLAN.md — not ported from Phase 1 (Phase 1 had no archetype-specific Penta drawers)"
  - "Task 5.3 (human-verify checkpoint) auto-approved per --auto mode; pixel geometry verified programmatically: IsolatedCell slot 0 has clear transparent gaps confirming it is not a solid rectangle (TEMPLATE-04 pass)"

metrics:
  duration_seconds: 209
  completed: 2026-04-26
  tasks_completed: 2
  tasks_total: 2
  files_created: 15
  files_modified: 1
  files_deleted: 12
---

# Phase 2 Plan 5: Wave 5 — Bitmask PNG Migration + README Retarget Summary

**Migrated 5 template PNGs to 14 co-located bitmask PNGs under `layouts/`, renamed generator to `_generate_bitmasks.py` with 5 new Penta archetype drawers, and atomically retargeted README's three `<img>` tags in the same commit — `templates/` folder fully deleted.**

## Performance

- **Duration:** ~3.5 min
- **Started:** 2026-04-26T20:06:35Z
- **Completed:** 2026-04-26T20:09:55Z
- **Tasks:** 2 (Tasks 5.1 + 5.2, committed atomically as required by the plan)
- **Files created:** 15 (1 script + 14 PNGs)
- **Files modified:** 1 (README.md)
- **Files deleted:** 12 (entire `templates/` folder contents)

## Accomplishments

### Task 5.1: Generator script renamed + updated

`addons/penta_tile/_generate_bitmasks.py` replaces the old `addons/penta_tile/templates/_generate_greybox_templates.py` with:

- **4 Phase 1 helpers ported UNCHANGED:** `new_atlas`, `draw_slot_outline`, `draw_corner_mask`, `draw_edge_mask`
- **`draw_edge_mask` rescaled for TILE=32:** center hint region moved from `6..9` (16px tile) to `12..19` (32px tile) to maintain proportional arm geometry
- **5 NEW Penta archetype drawers** per locked pixel-coordinate specs:
  - `draw_penta_isolated_cell` — 4 corner caps + 4 edge slabs + center fill (slot 0; NOT a solid rectangle; TEMPLATE-04 pass)
  - `draw_penta_fill` — solid 32×32 grey (slot 1)
  - `draw_penta_border` — bottom-half slab (slot 2)
  - `draw_penta_inner_corner` — L-shape with TR quadrant cut (slot 3)
  - `draw_penta_opposite_corners` — TL + BR diagonal quadrants (slot 4, mask-9 anchor)
- **5 strip generators:** `gen_penta(mode, axis)` produces all 10 Penta variants; `gen_dual_grid_16`, `gen_wang_2_edge`, `gen_wang_2_corner`, `gen_minimal_3x3` cover the 4 flat siblings
- Running `python addons/penta_tile/_generate_bitmasks.py` prints "Generated 14 bitmask PNGs at: ..." and exits 0

### Task 5.2: README retarget + atomic commit

Three `<img>` tags in `README.md` retargeted:
- **Line 5** (header banner): `templates/penta_horizontal.png` → `layouts/penta_tile_layout_penta/five_horizontal.png`
- **Line 30** (load-bearing "What is a Penta tileset?" canonical diagram): `templates/penta_horizontal.png` → `layouts/penta_tile_layout_penta/five_horizontal.png` — the FIVE-mode PNG shows all 5 archetypes matching the alt-text
- **Line 70** (Penta template reference): `templates/penta_horizontal.png` → `layouts/penta_tile_layout_penta/four_horizontal.png` — preserves 4-tile-template feel per plan's planner call

Both tasks land in one atomic commit `e17512e` per the CLAUDE.md Coined-Term Discipline constraint (line-30 diagram cannot 404 even momentarily).

### Task 5.3 (checkpoint): Auto-approved

Programmatic geometry verification confirms TEMPLATE-04:
- Slot 0 (IsolatedCell): transparent gaps at (6,6), (24,6), (6,24), (25,25) — clearly NOT a solid rectangle
- Slot 1 (Fill): solid grey at (38,6) — visually distinguishable from slot 0
- Center fill, all 4 corner caps, all 4 edge slabs confirmed grey

## Atomic Commit Details

| Commit | Message | Files |
|--------|---------|-------|
| `e17512e` | `feat(02-05): migrate template PNGs to co-located layouts/ + retarget README -- atomic` | +16 added, 1 modified, 12 deleted |

Commit `e17512e` contains simultaneously:
- `M README.md`
- `D addons/penta_tile/templates/penta_horizontal.png`
- `A addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png`
- `A addons/penta_tile/_generate_bitmasks.py`
- `D addons/penta_tile/templates/_generate_greybox_templates.py`
- `D addons/penta_tile/templates/README.md`

All atomic-commit acceptance criteria satisfied.

## PNG Dimensions (verified)

| PNG | Dimensions | Notes |
|-----|-----------|-------|
| one_horizontal.png | 32×32 | 1-tile strip |
| two_horizontal.png | 64×32 | 2-tile strip |
| three_horizontal.png | 96×32 | 3-tile strip |
| four_horizontal.png | 128×32 | 4-tile strip |
| five_horizontal.png | 160×32 | 5-tile strip (README lines 5+30) |
| one_vertical.png | 32×32 | 1-tile strip |
| two_vertical.png | 32×64 | 2-tile strip |
| three_vertical.png | 32×96 | 3-tile strip |
| four_vertical.png | 32×128 | 4-tile strip |
| five_vertical.png | 32×160 | 5-tile strip |
| penta_tile_layout_dual_grid_16.png | 128×128 | 4×4 corner-mask atlas |
| penta_tile_layout_wang_2_edge.png | 128×128 | 4×4 edge-mask atlas |
| penta_tile_layout_wang_2_corner.png | 128×128 | 4×4 corner-mask atlas (identical data to DualGrid16) |
| penta_tile_layout_minimal_3x3.png | 96×96 | 3×3 edge-mask atlas |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Deviation] `draw_edge_mask` center hint scaled for TILE=32**
- **Found during:** Task 5.1 implementation
- **Issue:** The plan says port `draw_edge_mask` UNCHANGED, but Phase 1's body uses hardcoded pixel coordinates `cx0=x0+6, cy0=y0+6, cx1=x0+9, cy1=y0+9` tuned for TILE=16. With TILE=32 the center hint would be a tiny 4×4 blob in the top-left quadrant rather than centered.
- **Fix:** Rescaled center region to `cx0=x0+12, cy0=y0+12, cx1=x0+19, cy1=y0+19` (doubles the Phase 1 coords, maintaining the proportional 4/16 = 1/4 tile width positioning). The arm math extends from center to tile edge — unchanged logic, just larger coordinates.
- **Files modified:** `addons/penta_tile/_generate_bitmasks.py`
- **Commit:** `e17512e`

### Notes

- **Planner call (line 70 destination):** `four_horizontal.png` — preserves 4-tile-template feel consistent with v0.1's "The Penta-System Template" section description. Could have been `five_horizontal.png` for consistency; plan gave either as valid; chose `four_horizontal.png` per the plan's guidance text.
- **Task 5.3 auto-approved** — running under `--auto` mode. Visual human verification of README rendering on GitHub is deferred to the user; the geometry verification programmatically confirms slot 0 is correctly shaped (not a solid rectangle).
- **15 PNGs total in addons/penta_tile/** (14 layout PNGs + 1 demo `penta_tile_ground.png`). The Wave 5 verification criterion "14 migration PNGs" refers to the layout PNGs only — confirmed correct.
- **1 .tres file remaining** (`addons/penta_tile/demo/penta_tile_ground.tres`) is the demo TileSet — intentional, pre-existing. The Wave 2 deletion of the contracts `.tres` files is already complete; this is the demo atlas, not a contract file.

## Stub Resolution

This wave resolves the known stubs from Wave 3 and Wave 4:

| Stub (from prior SUMMARY) | Resolution |
|---------------------------|------------|
| `get_fallback_tile_set()` returns null for all Penta modes | `_BITMASK_TEMPLATE_LOOKUP` paths now exist on disk |
| `get_fallback_tile_set()` returns null in all 4 native layouts | Co-located flat-sibling PNGs now exist |

Wave 6 wires the fallback routing so `PentaTileMapLayer` actually calls `get_fallback_tile_set()` when `tile_set == null`.

## Known Stubs

None. This plan's goal (co-located PNGs exist at expected paths) is fully achieved. Wave 6 is responsible for wiring the fallback routing.

## Threat Flags

None. Generator script runs locally with developer's Python interpreter; no network or untrusted input. Generated PNGs are committed for audit (T-02-06 accepted disposition per plan threat model).

## Self-Check: PASSED

- `addons/penta_tile/_generate_bitmasks.py` exists — CONFIRMED
- All 14 PNGs exist at documented paths — CONFIRMED (14 found, 0 missing)
- `addons/penta_tile/templates/` folder does not exist — CONFIRMED
- No `src="addons/penta_tile/templates/` references in README.md — CONFIRMED (0 hits)
- Commit `e17512e` contains `M README.md` + `D addons/penta_tile/templates/penta_horizontal.png` + `A addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png` in same commit — CONFIRMED
- No `...` ellipsis stubs in shipped script — CONFIRMED (0 found via AST walk)
- All 14 required functions present in script — CONFIRMED

---
*Phase: 02-native-layouts*
*Completed: 2026-04-26*
