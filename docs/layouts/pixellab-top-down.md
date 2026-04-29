# PixelLab Top-Down

Class: `PentaTileLayoutPixelLabTopDown`

PixelLab Top-Down reads PixelLab's 8x8 top-down tileset output. It is a
single-grid 4-bit corner-mask layout.

PixelLab outputs multiple cells for some masks. In v0.2, PentaTile picks the
row-major first cell deterministically. Variation-bank selection is deferred to
future variation work.
