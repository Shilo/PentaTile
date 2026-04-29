# Layouts Overview

PentaTile ships eight built-in layouts. A layout owns two pieces of behavior:
how a painted logic cell samples neighbors into a mask, and how that mask maps
to an atlas tile.

| Layout | Class | Grid | Use when |
| --- | --- | --- | --- |
| Penta | `PentaTileLayoutPenta` | 1-5 tile strip | You want the signature low-tile-count Penta authoring flow. |
| DualGrid 16 | `PentaTileLayoutDualGrid16` | 4x4 | Your art is a 16-tile dual-grid corner-mask atlas. |
| Wang 2-Edge | `PentaTileLayoutWang2Edge` | 4x4 | Your art is a 16-state cardinal-edge Wang atlas. |
| Wang 2-Corner | `PentaTileLayoutWang2Corner` | 4x4 | Your art uses CR31 corner naming. |
| Minimal 3x3 | `PentaTileLayoutMinimal3x3` | 3x3 | You need the 9-tile RPG Maker / legacy Godot-style minimum. |
| Blob 47 Godot | `PentaTileLayoutBlob47Godot` | 7x7 | Your art is a 47-tile blob atlas. |
| PixelLab Top-Down | `PentaTileLayoutPixelLabTopDown` | 8x8 | Your atlas is PixelLab's top-down output. |
| PixelLab Side-Scroller | `PentaTileLayoutPixelLabSideScroller` | 8x8 | Your atlas is PixelLab's side-scroller output. |

## Pick by atlas shape

| If your atlas looks like... | Start with |
| --- | --- |
| A 1-5 tile strip | [Penta](penta.md) |
| A 4x4 sheet where each cell is a corner-mask state | [DualGrid 16](dual-grid-16.md) |
| A 4x4 sheet for cardinal edge connections | [Wang 2-Edge](wang-2-edge.md) |
| A 4x4 sheet for diagonal/corner connections | [Wang 2-Corner](wang-2-corner.md) |
| A 3x3 classic autotile block | [Minimal 3x3](minimal-3x3.md) |
| A 47-tile blob packed into a 7x7 sheet | [Blob 47 Godot](blob-47-godot.md) |
| An 8x8 PixelLab top-down export | [PixelLab Top-Down](pixellab-top-down.md) |
| An 8x8 PixelLab side-scroller export | [PixelLab Side-Scroller](pixellab-side-scroller.md) |

## Runtime behavior

Dual-grid layouts paint visual cells on the half-cell-offset display grid.
Single-grid layouts paint directly on logic-painted cells.

This distinction matters when authoring art:

- Dual-grid templates can use partial-cell silhouettes because neighboring
  display cells compose the final shape.
- Single-grid templates should normally use full-cell artwork for every state,
  because each painted logic cell owns its full output tile.

Custom formats can subclass `PentaTileLayout`; see
[Authoring Custom Layouts](../custom-layouts.md).
