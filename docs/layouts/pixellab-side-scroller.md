# PixelLab Side-Scroller

Class: `PentaTileLayoutPixelLabSideScroller`

PixelLab Side-Scroller reads PixelLab's 8x8 side-scroller tileset output. It
shares the same corner-mask behavior as the top-down layout, but uses the
side-scroller cell-to-role table.

Like the top-down layout, it currently uses deterministic first-cell selection
for masks with multiple candidate cells.

## Template

![PixelLab Side-Scroller template](../assets/templates/penta_tile_layout_pixel_lab_side_scroller.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 8 columns x 8 rows |
| Tile count | 64 cells |
| Mask bits | `TL=1`, `TR=2`, `BL=4`, `BR=8` |
| Dispatch | PixelLab side-scroller cell-to-role table, then role-to-mask cache |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Generate or import a PixelLab side-scroller tileset output.
2. Add `PentaTileMapLayer`.
3. Set `layout` to `PentaTileLayoutPixelLabSideScroller`.
4. Assign the PixelLab atlas as the layer `tile_set`, or use the fallback
   template for quick testing.

## Authoring notes

- `mask=0` dispatches to the first side-scroller role-12 cell at `(0, 0)`.
- Variation-bank picking is deterministic first-cell selection in v0.2.
- Use this variant, not Top-Down, when your PixelLab output uses the
  side-scroller cell table.
