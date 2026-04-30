---
created: 2026-04-30T17:40:03.705Z
title: terrain_mode() virtual on PentaTileLayout base
area: general
files:
  - addons/penta_tile/layouts/penta_tile_layout.gd
  - addons/penta_tile/penta_tile_map_layer.gd
---

## Problem

PentaTileLayout has no way to declare which Godot TerrainMode (MATCH_CORNERS, MATCH_SIDES, MATCH_CORNERS_AND_SIDES) its autotiling scheme uses. Without this, _build_terrain_index() (spike 007) cannot know how to sample neighbor adjacency for terrain peering, blocking multi-terrain autotiling.

## Solution

Add virtual method `terrain_mode() -> int` returning a Godot TerrainMode enum value. Each layout subclass overrides: DualGrid16/Wang2Corner/PixelLab/Penta -> MATCH_CORNERS, Wang2Edge/Min3x3 -> MATCH_SIDES, Blob47Godot -> MATCH_CORNERS_AND_SIDES. Default returns -1 (no terrain integration). Used by _build_terrain_index() in spike 007. ~30 LOC.
