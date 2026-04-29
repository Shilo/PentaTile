# Wang 2-Corner

Class: `PentaTileLayoutWang2Corner`

Wang 2-Corner is a single-grid 4x4 atlas using CR31 compass-corner naming:
`NE=1`, `SE=2`, `SW=4`, `NW=8`.

It is visually compatible with DualGrid 16 on the same silhouettes, but the mask
bits are named for diagonal neighbors rather than TL/TR/BL/BR quadrants.

## Template

![Wang 2-Corner template](../assets/templates/penta_tile_layout_wang_2_corner.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 4 columns x 4 rows |
| Tile count | 16 |
| Mask bits | `NE=1`, `SE=2`, `SW=4`, `NW=8` |
| Dispatch | `atlas_coords = Vector2i(mask % 4, mask / 4)` |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Add `PentaTileMapLayer`.
2. Set `layout` to `PentaTileLayoutWang2Corner`.
3. Use a 4x4 atlas ordered by mask value.
4. Paint normally.

## Authoring notes

- Wang 2-Corner samples diagonal neighbors. Straight 1-tile-wide lines can
  produce `mask=0`, and that state still renders a valid isolated tile.
- Use full-cell artwork. This is a single-grid layout, not a dual-grid
  compositor.
- Choose this over DualGrid 16 when your source art or documentation talks in
  CR31 `NE/SE/SW/NW` terms.
