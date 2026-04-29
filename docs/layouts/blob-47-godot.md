# Blob 47 Godot

Class: `PentaTileLayoutBlob47Godot`

Blob 47 Godot is a single-grid layout using an 8-bit Moore-neighborhood mask.
PentaTile collapses the 256 raw masks to 47 reachable blob states using the
standard rule: a corner bit matters only when both adjacent edge bits are set.

The bundled fallback atlas is packed into a 7x7 grid with two unused cells.

## Template

![Blob 47 Godot template](../assets/templates/penta_tile_layout_blob_47_godot.png)

## Atlas contract

| Property | Value |
| --- | --- |
| Grid | 7 columns x 7 rows |
| Tile count | 47 used cells plus 2 unused cells |
| Mask bits | `N=1`, `E=2`, `S=4`, `W=8`, `NE=16`, `SE=32`, `SW=64`, `NW=128` |
| Dispatch | raw 8-bit mask collapses to one of 47 masks, then row-major lookup |
| Grid type | single-grid |
| Rotation reuse | none |

## Setup

1. Add `PentaTileMapLayer`.
2. Set `layout` to `PentaTileLayoutBlob47Godot`.
3. Use a 7x7 atlas that matches the bundled template packing.
4. Leave the two unused cells transparent or unused.

## Collapse rule

The raw 8-bit mask is reduced before lookup: a diagonal corner bit only matters
when both adjacent cardinal edge bits are present. For example, `NE` only
survives if both `N` and `E` are also set.

## Authoring notes

- This is the most detailed shipped single-grid layout. Use it when your art
  already exists as a 47-blob set.
- Empty-looking isolated cells still render through mask `0`; do not treat
  `mask=0` as erase in custom variants.
- The bundled order follows the 47 reachable masks sorted ascending and packed
  row-major.
