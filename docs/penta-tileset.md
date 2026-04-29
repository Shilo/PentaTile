# What is a Penta tileset?

A **Penta tileset** is a 5-archetype autotile format. This page intentionally
tracks the canonical README definition instead of creating a second competing
definition.

The five archetypes, in canonical slot order:

1. **IsolatedCell** - a tile with all four edges and all four corners exposed;
   source for synthesizing `OuterCorner`.
2. **Fill** - a tile with all four edges adjacent to the same terrain; the
   common interior tile.
3. **Border** - a tile on a straight terrain edge.
4. **InnerCorner** - a tile at the inside of an L-bend.
5. **OppositeCorners** - a tile with two diagonally-opposite different-terrain
   corners.

`OuterCorner` is implicit. PentaTile synthesizes it from the corners of
`IsolatedCell` at load time, so it does not occupy a dedicated slot.

For the diagram and longer explanation, see the README section:
https://github.com/Shilo/PentaTile#-what-is-a-penta-tileset
