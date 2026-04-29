# PixelLab Top-Down

Class: `PentaTileLayoutPixelLabTopDown`

PixelLab Top-Down reads PixelLab's 8x8 top-down tileset output. It is a
single-grid 4-bit corner-mask layout.

PixelLab outputs multiple cells for some masks. In v0.2, PentaTile picks the
row-major first cell deterministically. Variation-bank selection is deferred to
future variation work.

## Template

![PixelLab Top-Down template](../assets/templates/penta_tile_layout_pixel_lab_top_down.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 8 columns x 8 rows |
| Tile count | 64 cells |
| Mask bits | `TL=1`, `TR=2`, `BL=4`, `BR=8` |
| Dispatch | PixelLab cell-to-role table, then role-to-mask cache |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Generate or import a PixelLab top-down tileset output.
2. Add `PentaTileMapLayer`.
3. Set `layout` to `PentaTileLayoutPixelLabTopDown`.
4. Assign the PixelLab atlas as the layer `tile_set`, or use the fallback
   template for quick testing.

## Authoring notes

- The PixelLab table contains variation banks. PentaTile v0.2 deliberately uses
  the row-major first matching cell for deterministic output.
- Full variation-bank selection is deferred until the broader variation design.
- This is single-grid, so each rendered state should be a complete tile.
