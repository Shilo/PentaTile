---
phase: 05-demo-refresh-documentation-release
plan: 01
subsystem: demo-refresh
tags: [demo, scene, runtime-painter, fallback, spatial-grid, 8-layouts, breaking-change]
requires:
  - addons/penta_tile/penta_tile_map_layer.gd
  - addons/penta_tile/layouts/penta_tile_layout.gd
  - addons/penta_tile/layouts/penta_tile_layout_penta.gd
  - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd
  - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd
  - addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd
  - addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd
  - addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png
  - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.png
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.png
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png
  - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.png
  - addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png
  - addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.png
  - addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.png
provides:
  - "8-instance spatial-grid demo scene exercising every actually-shipped layout via bundled fallback"
  - "Hover-target drag-paint across N PentaTileMapLayer children"
  - "Pitfall #6 mitigation — index-0 Penta FOUR node retains literal name PentaTileMapLayer"
affects:
  - tests/run_tests.ps1 (test inventory: 18 → 17)
tech-stack:
  added: []
  patterns:
    - "Walk get_children() for PentaTileMapLayer; resolve cursor to layer whose used_rect.grow(margin) contains the mapped cell"
    - "8 SubResource layout instances, each with a bundled bitmask_template; tile_set = null + _tile_set_is_fallback = true engages get_fallback_tile_set() codegen"
key-files:
  created: []
  modified:
    - addons/penta_tile/demo/penta_tile_demo.tscn
    - addons/penta_tile/demo/demo_runtime_painter.gd
    - tests/run_tests.ps1
  deleted:
    - addons/penta_tile/demo/demo_player.gd
    - addons/penta_tile/demo/demo_player.gd.uid
    - addons/penta_tile/demo/penta_tile_ground.png
    - addons/penta_tile/demo/penta_tile_ground.png.import
    - addons/penta_tile/demo/penta_tile_ground.tres
    - addons/penta_tile/demo/_regen_demo_ground.py
    - addons/penta_tile/demo/penta_tile_dual_grid_16.tres
    - addons/penta_tile/demo/penta_tile_minimal_3x3.tres
    - addons/penta_tile/demo/penta_tile_wang_2_corner.tres
    - addons/penta_tile/demo/penta_tile_wang_2_edge.tres
    - tests/penta_ground_hollow_test.gd
    - tests/penta_ground_hollow_test.gd.uid
    - tests/_populate_bitmask_demo.gd
    - tests/_populate_bitmask_demo.gd.uid
decisions:
  - "Auto-load bitmask_template explicitly in each layout SubResource (rather than relying on PentaTileLayout._init's path-based auto-load): saves a load() at scene-instantiation and makes the binding visible in the .tscn."
  - "Camera position (1120, 384) zoom (0.4, 0.4): fits the 2240px x 832px world bounds (4 cols x 576 + 2 rows x 448) without panning."
  - "Background ColorRect spans (-64, -128) to (2304, 896) in dark slate (Color(0.12, 0.12, 0.16, 1)) so labels and labels' negative-y headroom render with contrast."
  - "Penta showcase uses FOUR mode (matches the existing convention from the prior demo and aligns with the four_horizontal.png bundled fallback)."
  - "Rule 1 deviation: deleted penta_ground_hollow_test.gd + _populate_bitmask_demo.gd because they hardcoded res://addons/penta_tile/demo/penta_tile_ground.tres which the plan retires; planner missed these dependencies."
metrics:
  completed: 2026-04-29
  duration_minutes: 8
  commits:
    - "40ad5ee chore(05-01): retire demo_player + authored ground + 4 legacy .tres orphans"
    - "d0e9849 feat(05-01): hover-target drag-paint across PentaTileMapLayer grid"
    - "8addacc feat(05-01): rewrite penta_tile_demo.tscn as 8-instance spatial grid"
---

# Phase 5 Plan 01: Demo Refresh Summary

Refreshed `penta_tile_demo.tscn` from a single-layer authored-TileSet platformer into an 8-instance spatial-grid showcase of every actually-shipped layout, each rendering exclusively through `PentaTileLayout.get_fallback_tile_set()`; rewrote `demo_runtime_painter.gd` to drag-paint into the layer under the cursor; retired the player + authored ground + four orphaned legacy `.tres` files (and the two now-orphaned tests that depended on the deleted ground asset).

## What Built

Three atomic commits, executed in plan order.

### 1. Retire demo_player + authored ground + legacy `.tres` orphans (commit `40ad5ee`)

Deleted 10 demo-directory files plus 4 newly-orphaned tests-directory files (Rule 1 deviation — see Deviations below):

| File | Reason |
|------|--------|
| `addons/penta_tile/demo/demo_player.gd` (+ `.uid`) | D-05-03: no player in pure layout showcase |
| `addons/penta_tile/demo/penta_tile_ground.{png,png.import,tres}` | D-05-02: bundled fallback only; authored TileSet retired |
| `addons/penta_tile/demo/_regen_demo_ground.py` | Python generator for the deleted ground.tres |
| `addons/penta_tile/demo/penta_tile_dual_grid_16.tres` | Pitfall #12: orphan from earlier scene iteration |
| `addons/penta_tile/demo/penta_tile_minimal_3x3.tres` | Pitfall #12: orphan |
| `addons/penta_tile/demo/penta_tile_wang_2_corner.tres` | Pitfall #12: orphan |
| `addons/penta_tile/demo/penta_tile_wang_2_edge.tres` | Pitfall #12: orphan |
| `tests/penta_ground_hollow_test.gd` (+ `.uid`) | Hardcoded `_GROUND_TS_PATH := "res://addons/penta_tile/demo/penta_tile_ground.tres"` |
| `tests/_populate_bitmask_demo.gd` (+ `.uid`) | Hardcoded `_GROUND_TRES`; utility script not in test inventory |

Test inventory in `run_tests.ps1` updated 18 → 17 (`penta_ground_hollow_test` removed).

The 8 keep-list `penta_layout_*.tres` files (one_horizontal, four_horizontal, four_vertical, five_horizontal, dual_grid_16, minimal_3x3, wang_2_corner, wang_2_edge) survived intact — `_capture_baseline.gd` references them via `--layout-path` per D-05-04.

### 2. Hover-target drag-paint (commit `d0e9849`)

Rewrote `addons/penta_tile/demo/demo_runtime_painter.gd`:

- **Removed:** `@export var map_path: NodePath`, `@onready var penta_map`, single-target NodePath resolution (no compat shim per CLAUDE.md HARD RULE).
- **Added:** `_resolve_hit_layer(canvas_position) -> PentaTileMapLayer` walks `get_children()` for `PentaTileMapLayer` instances; returns the first whose `get_used_rect().grow(_HOVER_MARGIN_CELLS)` (32 cells) contains the mapped cell.
- **Reshape:** `_apply_cell` now takes the resolved layer as a parameter; `_last_hit_layer` paired with `_last_cell` for cross-instance dedupe.

Headless `--check-only` parsed cleanly (no errors specific to the painter; the noise from the still-broken old scene file at this intermediate point was resolved by Task 3).

### 3. 8-instance spatial-grid scene (commit `8addacc`)

Replaced the entire `penta_tile_demo.tscn` contents.

**Scene tree shape:**

```
PentaTileDemo (Node2D, demo_runtime_painter.gd script)
├── Background (ColorRect, z_index=-100, Color(0.12,0.12,0.16,1))
├── Camera2D (position (1120, 384), zoom (0.4, 0.4))
├── PentaTileMapLayer (Penta FOUR; pos (0, 0))      ← Pitfall #6 node name
├── Label_Penta ("Penta (FOUR mode)", pos (0, -64))
├── Layout_DualGrid16 (pos (576, 0))
├── Label_DualGrid16
├── Layout_Wang2Edge (pos (1152, 0))
├── Label_Wang2Edge
├── Layout_Wang2Corner (pos (1728, 0))
├── Label_Wang2Corner
├── Layout_Minimal3x3 (pos (0, 448))
├── Label_Minimal3x3
├── Layout_Blob47Godot (pos (576, 448))
├── Label_Blob47Godot
├── Layout_PixelLabTopDown (pos (1152, 448))
├── Label_PixelLabTopDown
├── Layout_PixelLabSideScroller (pos (1728, 448))
└── Label_PixelLabSideScroller
```

**Grid math:** 32px tiles; per-instance footprint 16×12 cells = 512×384 px; gutters = 64 px (2 cells); world bounds ~2240 × 832 px; Camera fit-all-fixed at zoom = 0.4.

**Bundled fallback bindings (8 SubResource layouts):**

| Layout | Script ext_resource | Bitmask PNG ext_resource |
|--------|---------------------|--------------------------|
| Penta (FOUR) | `penta_tile_layout_penta.gd` | `penta_tile_layout_penta/four_horizontal.png` |
| DualGrid16 | `penta_tile_layout_dual_grid_16.gd` | `penta_tile_layout_dual_grid_16.png` |
| Wang2Edge | `penta_tile_layout_wang_2_edge.gd` | `penta_tile_layout_wang_2_edge.png` |
| Wang2Corner | `penta_tile_layout_wang_2_corner.gd` | `penta_tile_layout_wang_2_corner.png` |
| Minimal3x3 | `penta_tile_layout_minimal_3x3.gd` | `penta_tile_layout_minimal_3x3.png` |
| Blob47Godot | `penta_tile_layout_blob_47_godot.gd` | `penta_tile_layout_blob_47_godot.png` |
| PixelLabTopDown | `penta_tile_layout_pixel_lab_top_down.gd` | `penta_tile_layout_pixel_lab_top_down.png` |
| PixelLabSideScroller | `penta_tile_layout_pixel_lab_side_scroller.gd` | `penta_tile_layout_pixel_lab_side_scroller.png` |

Each TileMapLayer node has `_tile_set_is_fallback = true` and no explicit `tile_set` line — at runtime the layout setter's auto-fill chain (penta_tile_map_layer.gd:79-98) populates `tile_set` via `get_fallback_tile_set()`.

**Removed wholesale from the prior scene:**
- ext_resource references to `demo_player.gd`, `penta_tile_ground.tres`, `brand/penta_tile_icon.png`
- Player CharacterBody2D + PentaTileIcon Sprite2D + CollisionShape2D
- BitmaskDemo_BundledGreybox + BitmaskDemo_GroundTres legacy hidden TileMapLayer nodes
- All `PackedByteArray` pre-painted regions (the new scene starts empty; drag-paint populates)
- Authored TileSet / TileSetAtlasSource sub_resources (TileSet_fuyv7, TileSet_a31h3, TileSetAtlasSource_0ou8x, TileSetAtlasSource_n4gfi)

## Verification

- **Headless scene-open** (`godot --headless --quit-after 3 res://addons/penta_tile/demo/penta_tile_demo.tscn`): exit=0, **zero bytes** in stderr, zero `ERROR:` / `SCRIPT ERROR:` lines.
- **17-test suite** (`pwsh -File tests/run_tests.ps1 -NoPause -Test all`): **ALL GREEN** — paint_test, all_layouts_test, visual_render_test, strict_pixel_test, penta_one_mode_test, auto_strip_axis_test, layout_swap_test, all_layouts_swap_pixel_test, bitmask_bounds_test, comprehensive_bitmask_test, determinism_test, blob_47_collapse_test, blob_47_hollow_test, single_grid_8_moore_propagation_test, pixellab_first_cell_test, pixellab_visual_regression_test, fallback_routing_test (17/17 PASS).
- **Pitfall #6 mitigation**: `find_child("PentaTileMapLayer", true, false)` in `_capture_baseline.gd:46` still resolves — verified by running the capture utility against the new scene with `--layout-path=res://addons/penta_tile/demo/penta_layout_four_horizontal.tres`; it printed `LAYOUT_OVERRIDE=...class=Resource axis=0 tile_count=4` followed by `BASELINE_HASH=4100093049` cleanly. (The hash is naturally different from Phase 2's `2986698704` because the new scene starts with no painted cells; `BASELINE_CELLS=0` reflects the empty state. The `determinism_test.gd` self-contained baseline (`2561003017`, painted cell count `46`) is independent of the demo scene per its 2026-04-28 refactor and stays green.)

## Deviations from Plan

### Rule 1 — Auto-fixed Issue: orphaned tests retired alongside their fixture asset

**Found during:** Task 1 pre-deletion grep across the repo

**Issue:** The plan's `<read_first>` for Task 1 stated "verify [`_capture_baseline.gd`] does NOT reference any of the 4 unused legacy .tres OR penta_tile_ground.tres", which is true. But the planner also asserted "no other files reference any of the 10 deletes" — a wider claim that is **false**:

- `tests/penta_ground_hollow_test.gd` line 41 hardcodes `const _GROUND_TS_PATH := "res://addons/penta_tile/demo/penta_tile_ground.tres"`. This test IS in the 18-test inventory in `run_tests.ps1`, so deleting `penta_tile_ground.tres` would break the plan's success criterion ("All 18 tests still pass").
- `tests/_populate_bitmask_demo.gd` line 34 hardcodes `const _GROUND_TRES := "res://addons/penta_tile/demo/penta_tile_ground.tres"`. This is a utility script (not in the inventory) but it would crash at runtime if invoked.

**Fix (per CLAUDE.md HARD RULE — no compat shims, breakage is fine):**
- `git rm` both test files + their `.uid` sidecars in the same commit as the demo deletes.
- Removed `"penta_ground_hollow_test"` from the inventory in `run_tests.ps1`. Inventory is now 17 tests (still green).

**Files modified:** `tests/run_tests.ps1` (delete 1 inventory line)
**Files deleted:** `tests/penta_ground_hollow_test.gd{,.uid}`, `tests/_populate_bitmask_demo.gd{,.uid}`
**Commit:** `40ad5ee`

### No other deviations

The painter rewrite (Task 2) and scene rewrite (Task 3) followed the plan verbatim.

## Auth Gates

None. No checkpoints reached except Task 4 (auto-approved per `workflow._auto_chain_active`).

## TDD Gate Compliance

N/A — this plan is `type: execute`, not `type: tdd`.

## Self-Check: PASSED

**Files exist (key creates):**
- `addons/penta_tile/demo/penta_tile_demo.tscn` FOUND
- `addons/penta_tile/demo/demo_runtime_painter.gd` FOUND

**Files deleted (key deletes):**
- `addons/penta_tile/demo/demo_player.gd` MISSING (correctly — deleted)
- `addons/penta_tile/demo/penta_tile_ground.tres` MISSING (correctly — deleted)
- `tests/penta_ground_hollow_test.gd` MISSING (correctly — deleted)

**Commits:**
- `40ad5ee` FOUND in `git log`
- `d0e9849` FOUND in `git log`
- `8addacc` FOUND in `git log`

**Pitfall #6 mitigation:**
- `grep -c '"PentaTileMapLayer"' addons/penta_tile/demo/penta_tile_demo.tscn` = 1 (the FOUR-mode Penta node name)

**Test suite:**
- 17/17 PASS at HEAD (`8addacc`)

## Output Spec Confirmation

Per plan `<output>`:

- ✓ Final scene-tree shape recorded (8 TileMapLayer + 8 Label + Camera2D + Background ColorRect on a Node2D root).
- ✓ Camera position `Vector2(1120, 384)`, zoom `Vector2(0.4, 0.4)`.
- ✓ `_HOVER_MARGIN_CELLS` final value: **32** (unchanged from plan default; not tuned because Task 4 auto-approved).
- ✓ No visual UAT iteration (Task 4 auto-approved per `workflow._auto_chain_active = true`).
- ✓ 17 tests stayed green throughout (the test inventory dropped from 18 to 17 because `penta_ground_hollow_test` was retired alongside its fixture asset; the remaining 17 stayed green at every commit boundary).
- ✓ The 10 deleted demo files (verbatim list for the CHANGELOG) — Plan B (05-02) reads from this list:

  ```
  addons/penta_tile/demo/demo_player.gd
  addons/penta_tile/demo/demo_player.gd.uid
  addons/penta_tile/demo/penta_tile_ground.png
  addons/penta_tile/demo/penta_tile_ground.png.import
  addons/penta_tile/demo/penta_tile_ground.tres
  addons/penta_tile/demo/_regen_demo_ground.py
  addons/penta_tile/demo/penta_tile_dual_grid_16.tres
  addons/penta_tile/demo/penta_tile_minimal_3x3.tres
  addons/penta_tile/demo/penta_tile_wang_2_corner.tres
  addons/penta_tile/demo/penta_tile_wang_2_edge.tres
  ```

- Additional retirements driven by the Rule 1 deviation (also worth flagging in CHANGELOG):

  ```
  tests/penta_ground_hollow_test.gd
  tests/penta_ground_hollow_test.gd.uid
  tests/_populate_bitmask_demo.gd
  tests/_populate_bitmask_demo.gd.uid
  ```
