---
created: 2026-04-30T17:40:03.705Z
title: compute_mask(strip_index) signature extension
area: general
files:
  - addons/penta_tile/layouts/penta_tile_layout.gd
  - addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd
  - addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd
  - addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd
  - addons/penta_tile/penta_tile_map_layer.gd
---

## Problem

PentaTileLayout.compute_mask() currently has no terrain-awareness. For multi-terrain autotiling (spike 006), single-grid layouts need to filter neighbor sampling to same-terrain cells only, while dual-grid layouts need to use highest-precedence terrain. Without a strip_index parameter, the mask computation cannot distinguish terrain context.

## Solution

Extend PentaTileLayout.compute_mask(coord, sample_fn, strip_index: int = 0) to accept terrain strip index. Single-grid layouts filter neighbor sampling to same-terrain cells only. Dual-grid layouts use highest-precedence terrain. Default strip_index=0 preserves backward compat. Required for multi-terrain dispatch per spike 006. ~40 LOC.
