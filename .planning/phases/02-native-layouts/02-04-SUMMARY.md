---
phase: 02-native-layouts
plan: 4
subsystem: layout-library
tags: [gdscript, autotile, dual-grid, wang-tiles, minimal-3x3, mask-to-atlas]

dependency_graph:
  requires:
    - phase: 02-03-PLAN
      provides: PentaTileLayoutPenta as pattern reference; PentaTileLayout base class with compute_mask/mask_to_atlas/is_dual_grid/get_fallback_tile_set virtuals
  provides:
    - PentaTileLayoutDualGrid16 (NATIVE-01): 4x4 atlas, 16 tiles, TL=1/TR=2/BL=4/BR=8 corner mask, dual-grid
    - PentaTileLayoutWang2Edge (NATIVE-02): 4x4 atlas, 16 tiles, CR31 N=1/E=2/S=4/W=8 edge mask, single-grid, Marching Squares alias
    - PentaTileLayoutWang2Corner (NATIVE-03): 4x4 atlas, 16 tiles, CR31 NE=1/SE=2/SW=4/NW=8 corner mask, single-grid
    - PentaTileLayoutMinimal3x3 (MIN3x3-01): 3x3 atlas, 9 tiles, T=1/E=2/B=4/W=8 edge mask, single-grid, open-side rule
  affects:
    - 02-05 (Wave 5 — PNG assets ship into get_fallback_tile_set() paths)
    - 02-06 (Wave 6 — demo exercises these layouts)
    - Phase 5 (documentation references all layout classes)

tech-stack:
  added: []
  patterns:
    - hand-authored-slot-table (mask-to-atlas maps mask directly to atlas_coords — no synthesis machinery; 4 native layouts only)
    - open-side-rule-for-3x3-collapse (16 mask states reduced to 9-tile palette via cardinal open-side axis selection)
    - mask-percent-4-div-4-atlas-layout (4x4 atlas: col = mask % 4, row = mask / 4; no rotation reuse)
    - dual-grid-vs-single-grid-flag (is_dual_grid() returns true for DualGrid16, false for all three single-grid layouts)
    - deferred-png-stubs (get_fallback_tile_set() loads co-located PNG; returns null until Wave 5 ships the PNGs)

key-files:
  created:
    - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd
    - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd
    - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd
    - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd
  modified: []

key-decisions:
  - "Minimal3x3 uses open-side rule: col/row = 0 if that side is exclusively open, 2 if exclusively closed on opposite, 1 (center) for both-open or both-closed — collapses masks 5 (T+B) and 10 (E+W) and all isolated-diagonal states to center tile (accepted visual loss of 9-tile minimum)"
  - "Wang2Corner samples diagonal neighbors (NE/SE/SW/NW corner cells) and is single-grid — this is NOT the 2x2 corner-quadrant scheme used by Penta's dual-grid; same mask formula (mask % 4, mask / 4) as DualGrid16 but semantically different bit-to-neighbor mapping"
  - "All four layouts commit as one atomic unit (91f69a2) — tasks are truly parallel with no inter-file dependencies; single commit avoids unnecessary 3-second-apart history noise"
  - "get_fallback_tile_set() returns null in Wave 4 intermediate state — PNGs at co-located paths ship in Wave 5; accepted per plan's known-intermediate-state note"

patterns-established:
  - "Single-variant layout skeleton: @tool + class doc-comment with mask convention + atlas layout diagram + class_name + extends PentaTileLayout + direction constants + is_dual_grid() + compute_mask() + mask_to_atlas(0->null) + get_fallback_tile_set()"
  - "4x4 atlas layout: mask % 4 = col, mask / 4 = row — no rotation reuse; every state maps to a unique authored tile"
  - "3x3 atlas open-side rule: open_w_only→col=0, open_e_only→col=2, else col=1; open_t_only→row=0, open_b_only→row=2, else row=1"

requirements-completed: [NATIVE-01, NATIVE-02, NATIVE-03, MIN3x3-01]

duration: 2min
completed: 2026-04-26
---

# Phase 2 Plan 4: Wave 4 — Four Native Single-Variant Layouts Summary

**Four hand-authored layout subclasses covering DualGrid16 (dual-grid corner), Wang2Edge/Marching Squares (edge), Wang2Corner (CR31 diagonal-corner), and Minimal3x3 (9-tile cardinal-edge minimum) — 293 LOC total across 4 files.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-26T20:22:25Z
- **Completed:** 2026-04-26T20:24:36Z
- **Tasks:** 4 (committed atomically as one unit — all parallel, no inter-dependencies)
- **Files created:** 4

## Accomplishments

- `PentaTileLayoutDualGrid16` (64 LOC): 4x4 atlas, corner mask TL=1/TR=2/BL=4/BR=8, dual-grid; matches Godot's stock dual-grid template + dandeliondino `tile_map_dual` convention
- `PentaTileLayoutWang2Edge` (63 LOC): 4x4 atlas, edge mask CR31 N=1/E=2/S=4/W=8, single-grid; "Marching Squares" alias in class doc-comment for search-term discoverability
- `PentaTileLayoutWang2Corner` (70 LOC): 4x4 atlas, corner mask CR31 NE=1/SE=2/SW=4/NW=8, single-grid; visually equivalent to DualGrid16 on same atlas data, different bit-naming convention; note explains the Wang2Corner vs DualGrid16 artist choice
- `PentaTileLayoutMinimal3x3` (96 LOC): 3x3 atlas, edge mask T=1/E=2/B=4/W=8, single-grid; open-side rule collapses 16 mask states to 9-tile palette; doc-comment explains collapse semantics and which states map to center

## LOC Per File

| File | LOC |
|------|-----|
| penta_tile_layout_dual_grid_16.gd | 64 |
| penta_tile_layout_wang_2_edge.gd | 63 |
| penta_tile_layout_wang_2_corner.gd | 70 |
| penta_tile_layout_minimal_3x3.gd | 96 |
| **Total** | **293** |

Plan estimated ~300 LOC — actual 293 LOC, within target.

## Task Commits

All four layout files committed as one atomic unit (tasks are truly independent; no ordering constraint):

1. **Tasks 4.1–4.4 (all four layouts)** — `91f69a2` (feat: ship 4 native single-variant layouts Wave 4)

**Plan metadata:** (this commit, below)

## Files Created

- `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd` — DualGrid16 (NATIVE-01)
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd` — Wang2Edge / Marching Squares (NATIVE-02)
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` — Wang2Corner (NATIVE-03)
- `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd` — Minimal3x3 (MIN3x3-01)

## Decisions Made

- **Minimal3x3 open-side rule collapse:** Masks 5 (T+B only) and 10 (E+W only) both collapse to center tile (1,1). Any mask state where both sides on an axis are simultaneously open OR closed resolves to row/col = 1. This is the inherent information loss of the 9-tile minimum — accepted per plan.

- **Wang2Corner is single-grid, samples diagonal neighbors:** The NE/SE/SW/NW bit positions sample the 4 diagonal corner-neighbor cells (Vector2i(±1, ±1)). This is distinct from Penta's dual-grid, which samples the 4 virtual sub-cells of the half-offset display grid. Same mask formula (mask % 4, mask / 4) as DualGrid16 but the semantics differ: DualGrid16 maps each bit to a 2×2 sub-cell quadrant; Wang2Corner maps each bit to "is a diagonal neighbor present."

- **All four tasks committed atomically:** The four files have zero inter-file dependencies; committed together to avoid noise in history. Each task's acceptance criteria passes independently.

## Deviations from Plan

None — plan executed exactly as written. All four files match the plan's code blocks exactly (minor doc comment elaboration in Minimal3x3's atlas layout description, no code change). All automated verify checks pass.

## Known Stubs

| Stub | File | Detail | Resolution |
|------|------|--------|------------|
| `get_fallback_tile_set()` returns null | all 4 new layouts | PNG at co-located path doesn't exist yet | Wave 5 ships `penta_tile_layout_dual_grid_16.png`, `penta_tile_layout_wang_2_edge.png`, `penta_tile_layout_wang_2_corner.png`, `penta_tile_layout_minimal_3x3.png` |

No stubs that prevent the plan's goal — the layouts are fully implemented; the fallback PNG stub is explicitly noted as the Wave 4 intermediate state in the plan's verification section.

## Typed-Picker Availability

All four `class_name PentaTileLayout*` subclasses will appear in Godot's typed Resource picker for any `@export var layout: PentaTileLayout` property (including on `PentaTileMapLayer`) once the Godot project is reloaded. Confirmed by the `extends PentaTileLayout` pattern — Godot's class_name system auto-registers all subclasses in the picker.

## Threat Flags

None. Internal addon files; no network endpoints, no auth paths, no file writes, no user-controlled input. Sole threat surface is malicious `bitmask_template` PNG (T-02-05 accepted per plan threat model — mitigated by Godot's stock Image loader).

## Self-Check: PASSED

- `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd` exists, 64 lines, contains `class_name PentaTileLayoutDualGrid16`, `extends PentaTileLayout`, `mask % 4, mask / 4`, `return true` (is_dual_grid), `penta_tile_layout_dual_grid_16.png`
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd` exists, 63 lines, contains `class_name PentaTileLayoutWang2Edge`, `extends PentaTileLayout`, `Marching Squares`, `is_dual_grid`, `penta_tile_layout_wang_2_edge.png`
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` exists, 70 lines, contains `class_name PentaTileLayoutWang2Corner`, `extends PentaTileLayout`, `_NE := Vector2i`, `is_dual_grid`, `penta_tile_layout_wang_2_corner.png`
- `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd` exists, 96 lines, contains `class_name PentaTileLayoutMinimal3x3`, `extends PentaTileLayout`, `_T := Vector2i(0, -1)`, `open_t`, `penta_tile_layout_minimal_3x3.png`
- `grep -r 'extends PentaTileLayout' addons/penta_tile/layouts/` returns 5 hits (4 new + Penta)
- Commit 91f69a2 verified in git log

---
*Phase: 02-native-layouts*
*Completed: 2026-04-26*
