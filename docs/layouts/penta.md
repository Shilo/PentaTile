# Penta

Class: `PentaTileLayoutPenta`

Penta is the addon's signature 5-archetype dual-grid format. It supports
horizontal and vertical strips and a progressive tile count: ONE, TWO, THREE,
FOUR, or FIVE. `AUTO` detects a strip size from the atlas; `AUTO_STRIP` detects
each strip independently.

The canonical slot order is:

1. `IsolatedCell`
2. `Fill`
3. `Border`
4. `InnerCorner`
5. `OppositeCorners`

`OuterCorner` is implicit. PentaTile synthesizes it from `IsolatedCell` at load
time instead of giving it a dedicated slot.

## Template

FIVE mode template:

![Penta FIVE horizontal template](../assets/templates/penta_tile_layout_penta_five_horizontal.png)

ONE mode template:

![Penta ONE horizontal template](../assets/templates/penta_tile_layout_penta_one_horizontal.png)

## When to use it

Use Penta when you want the smallest useful authored atlas. ONE mode is enough
for quick prototypes, while FIVE mode gives an artist explicit control over all
five archetypes.

Penta is a dual-grid layout, so it works best for ground, walls, blobs, and
terrain-like fills where the visible shape can be assembled from corner
connectivity.

## Setup

1. Add a `PentaTileMapLayer`.
2. Set `layout` to a `PentaTileLayoutPenta` Resource.
3. Set `axis` to `HORIZONTAL` for a strip across X, or `VERTICAL` for a strip
   down Y.
4. Leave `tile_count` at `AUTO` for normal one-strip atlases, or choose an
   explicit mode if you want the inspector preview to show that authoring tier.
5. Assign your `TileSet`, or leave `tile_set` empty to use the bundled fallback.

## Tile count modes

| Mode | Authored slots | What PentaTile synthesizes |
| --- | --- | --- |
| `ONE` | `IsolatedCell` | Fill, Border, InnerCorner, OppositeCorners, OuterCorner |
| `TWO` | `IsolatedCell`, `Fill` | Border, InnerCorner, OppositeCorners, OuterCorner |
| `THREE` | `IsolatedCell`, `Fill`, `Border` | InnerCorner, OppositeCorners, OuterCorner |
| `FOUR` | `IsolatedCell`, `Fill`, `Border`, `InnerCorner` | OppositeCorners, OuterCorner |
| `FIVE` | all five slots | OuterCorner only |
| `AUTO` | detected from atlas strip length | depends on detected mode |
| `AUTO_STRIP` | detected per strip | depends on each strip |

## Authoring notes

- Keep pixels inside each archetype's expected silhouette. PentaTile enforces a
  canonical silhouette during synthesis so rotated pixels do not bleed into
  adjacent cells.
- `OppositeCorners` anchors mask `9` (`TL + BR`) as the unrotated case. If art
  made for another tool appears diagonally swapped, flip that tile horizontally.
- `AUTO_STRIP` is useful when one atlas source contains several Penta strips,
  but it is not multi-terrain blending. Mixed terrain transitions are future
  work.

See [What is a Penta tileset?](../penta-tileset.md) for the canonical term
definition.
