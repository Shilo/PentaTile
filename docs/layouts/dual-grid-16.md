# DualGrid 16

Class: `PentaTileLayoutDualGrid16`

DualGrid 16 uses a 4x4 atlas with one authored tile for each 4-bit corner mask.
The mask bits are `TL=1`, `TR=2`, `BL=4`, and `BR=8`.

Use it when your art already follows the common 16-tile dual-grid convention and
you want every state authored directly with no rotation reuse.
