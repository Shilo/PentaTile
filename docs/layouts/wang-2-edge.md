# Wang 2-Edge

Class: `PentaTileLayoutWang2Edge`

Wang 2-Edge is a single-grid 4x4 atlas using a cardinal-edge mask:
`N=1`, `E=2`, `S=4`, `W=8`.

Unlike dual-grid layouts, it paints directly on logic-painted cells. `mask=0`
still renders a tile, which is important for isolated single-grid cells.

## Template

![Wang 2-Edge template](../assets/templates/penta_tile_layout_wang_2_edge.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 4 columns x 4 rows |
| Tile count | 16 |
| Mask bits | `N=1`, `E=2`, `S=4`, `W=8` |
| Dispatch | `atlas_coords = Vector2i(mask % 4, mask / 4)` |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Add `PentaTileMapLayer`.
2. Set `layout` to `PentaTileLayoutWang2Edge`.
3. Use a 4x4 atlas ordered by mask value.
4. Paint logic cells directly; every painted cell renders one full tile.

## Authoring notes

- Make every tile a complete 32x32-style cell, not a partial dual-grid
  quadrant. Single-grid layouts do not rely on neighboring display cells to
  complete the visible tile.
- `mask=0` is the isolated-cell state, not erase.
- This layout is a good fit for roads, paths, pipes, fences, and edge-driven
  terrain details.
