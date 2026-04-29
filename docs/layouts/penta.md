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

See [What is a Penta tileset?](../penta-tileset.md) for the canonical term
definition.
