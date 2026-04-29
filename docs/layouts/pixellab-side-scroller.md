# PixelLab Side-Scroller

Class: `PentaTileLayoutPixelLabSideScroller`

PixelLab Side-Scroller reads PixelLab's 8x8 side-scroller tileset output. It
shares the same corner-mask behavior as the top-down layout, but uses the
side-scroller cell-to-role table.

Like the top-down layout, it currently uses deterministic first-cell selection
for masks with multiple candidate cells.
