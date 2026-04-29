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

Custom formats can subclass `PentaTileLayout`; see
[Authoring Custom Layouts](../custom-layouts.md).
