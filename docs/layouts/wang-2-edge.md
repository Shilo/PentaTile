# Wang 2-Edge

Class: `PentaTileLayoutWang2Edge`

Wang 2-Edge is a single-grid 4x4 atlas using a cardinal-edge mask:
`N=1`, `E=2`, `S=4`, `W=8`.

Unlike dual-grid layouts, it paints directly on logic-painted cells. `mask=0`
still renders a tile, which is important for isolated single-grid cells.
