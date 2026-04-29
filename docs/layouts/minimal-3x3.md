# Minimal 3x3

Class: `PentaTileLayoutMinimal3x3`

Minimal 3x3 is the 9-tile cardinal-edge minimum. It maps the 16 possible
edge-mask states onto a 3x3 grid with an open-side collapse rule.

This is the layout to try for RPG Maker A2-like ground art, legacy Godot 3.x
style atlases, and quick low-detail prototypes.

## Template

![Minimal 3x3 template](../assets/templates/penta_tile_layout_minimal_3x3.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 3 columns x 3 rows |
| Tile count | 9 |
| Mask bits | `T=1`, `E=2`, `B=4`, `W=8` |
| Dispatch | open-side collapse rule |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Add `PentaTileMapLayer`.
2. Set `layout` to `PentaTileLayoutMinimal3x3`.
3. Arrange the atlas like a classic 3x3 autotile block: exposed top row,
   center row, exposed bottom row.
4. Paint normally.

## Open-side collapse

The layout chooses a column from west/east openness and a row from top/bottom
openness:

- west open only -> column 0
- east open only -> column 2
- neither or both -> column 1
- top open only -> row 0
- bottom open only -> row 2
- neither or both -> row 1

This means some 16-state masks share the same tile. That loss is the tradeoff
that makes the 9-tile minimum possible.

## Authoring notes

- Use full-cell artwork because this is single-grid.
- `mask=0` dispatches to the center tile `(1, 1)` so isolated cells render.
- This layout is intentionally compact; use Wang 2-Edge if the 3x3 collapse is
  too lossy for your art.
