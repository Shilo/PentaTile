# 🍀 PentaTile

**Just paint your tiles.** Intuitive Godot autotiling addon that takes the pain out of tilesets, with no manual terrain setup needed. Supports [5-archetype **Penta**](#-what-is-a-penta-tileset) and [popular layouts](#-supported-layouts). Paint with Godot's normal tools and PentaTile fills in the corners, edges, and transitions for you.

<img src="addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png" width="256" alt="Penta Horizontal Tileset Template">

## 📑 Table of Contents

1. [Why PentaTile?](#-why-pentatile)
2. [What is a Penta tileset?](#-what-is-a-penta-tileset)
3. [Supported Layouts](#-supported-layouts)
4. [The Penta-System Template](#-the-penta-system-template)
5. [Comparison: PentaTile vs. TileMapDual](#-pentatile-vs-tilemapdual-api)
6. [Choosing the Right Tool](#-choosing-the-right-tool)
7. [Addon Layout](#-addon-layout)
8. [Current API](#-current-api)
9. [Demo](#-demo)
10. [Implementation Notes](#-implementation-notes)
11. [Roadmap](#-roadmap)
12. [External Resources](#-external-resources)

## 🚀 Why PentaTile?

- **Reduced Tile Requirements:** Creating 47 tiles for a single terrain type is a time-consuming task. PentaTile's signature **Penta** layout scales the requirement from as few as one tile up to five (the progressive ONE through FIVE modes), lowering the barrier for creating custom game art while maintaining professional results.
- **Efficient Visual Variation:** Authoring as few as 1–5 tiles per terrain makes iteration cheap. Instead of redrawing dozens of tiles for a single alternative set, you can quickly iterate on the small archetype set to add organic variety and reduce repetitive patterns.
- **Native Integration:** Built as a single-class subclass of `TileMapLayer`, PentaTile hooks directly into Godot's native API. It listens to standard drawing commands and updates the visual layers in real-time without requiring a custom drawing interface.

## 🍀 What is a Penta tileset?

<img src="addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png" width="256" alt="Penta archetype reference: IsolatedCell (slot 0, source of synthesized OuterCorner) + Fill / Border / InnerCorner / OppositeCorners (slots 1-4)">

A **Penta tileset** is a 5-archetype autotile format. The five archetypes, **listed in canonical slot order**:

1. **IsolatedCell** (slot 0) — a tile with all four edges and all four corners exposed; serves as the source for synthesizing OuterCorner.
2. **Fill** (slot 1) — a tile with all four edges adjacent to the same terrain; the most common interior tile.
3. **Border** (slot 2) — a tile on a straight terrain edge (one side adjacent to "different terrain").
4. **InnerCorner** (slot 3) — a tile at the inside of an L-bend (two adjacent sides adjacent to "different terrain").
5. **OppositeCorners** (slot 4) — a tile with two diagonally-opposite different-terrain corners.

**OuterCorner** is implicit — synthesized from the corners of slot 0 (IsolatedCell) at load time. It does not occupy a dedicated slot.

**Synthesis rule:** PentaTile supports a progressive 5-mode authoring scale (ONE through FIVE). Modes ONE through FOUR synthesize the missing archetypes from slot 0; mode FIVE provides all five archetypes hand-authored. Either way, every connectivity state at runtime resolves to one of the five archetypes above.

**How "Penta" relates to other tileset codenames:**

| Format | Tiles authored | Slot count | Year coined |
|--------|---------------|------------|-------------|
| Wang   | 16 / 64 / 256 | varies     | ~1986       |
| Blob   | 47            | 47         | ~2010       |
| Penta  | 1–5           | 5          | 2026        |

"Penta" is reserved for the 5-archetype format only — never for unrelated 5-tile arrangements. This rule is encoded as a project invariant in `CLAUDE.md` § Coined-Term Discipline.

## 🧩 Supported Layouts

Already have tiles in a different format? No problem. PentaTile ships with a library of layouts covering virtually every popular autotiling convention out of the box:

- **[Penta](#-the-penta-system-template)** (horizontal & vertical): the signature 1–5 tile authoring scale (modes ONE through FIVE)
- **<a href="https://www.youtube.com/watch?v=jEWFSv3ivTg" target="_blank" rel="noopener">Dual Grid ↗︎</a>**: the popular 16-tile corner-mask format
- **<a href="https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/intro.html" target="_blank" rel="noopener">Wang ↗︎</a>** (2-edge & 2-corner): the classic edge/corner-color system
- **<a href="https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/" target="_blank" rel="noopener">47-tile Blob ↗︎</a>**: the full Godot/Wang blob set
- **<a href="https://www.tilesetter.org/docs/generating_tilesets" target="_blank" rel="noopener">Tilesetter ↗︎</a>** (Wang 15 & Blob 47): atlases as exported by Tilesetter
- **<a href="https://www.pixellab.ai/docs/tools/create-tileset" target="_blank" rel="noopener">PixelLab ↗︎</a>** (top-down & side-scroller): native image outputs from the PixelLab Aseprite extension
- **Minimal 3x3**: the 9-tile match-sides format used by RPG Maker A2 and legacy Godot 3.x

Whatever convention your art was drawn for, PentaTile can paint with it. And if your favorite isn't built in, you can plug in a custom layout of your own.

## 🎨 The Penta-System Template

<img src="addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png" width="256" alt="Penta Horizontal Tileset Template">

A **Penta** atlas is a horizontal or vertical strip of 1–5 tiles (the 5-mode authoring scale: ONE, TWO, THREE, FOUR, FIVE). The slots, in canonical order:

1.  **IsolatedCell** (slot 0, always authored — also the source for synthesizing OuterCorner via render-time rotation)
2.  **Fill** (slot 1, authored at TWO mode and above)
3.  **Border** (slot 2, authored at THREE mode and above)
4.  **InnerCorner** (slot 3, authored at FOUR mode and above)
5.  **OppositeCorners** (slot 4, authored at FIVE mode)

Modes ONE through FOUR synthesize the missing archetypes from slot 0 at load time via `PentaTileSynthesis`. The two disconnected diagonal states (masks 6 and 9) resolve to the **OppositeCorners** archetype — synthesized in modes ONE..FOUR or hand-authored in mode FIVE. Single-layer dispatch only; no internal overlay layer (Phase 2 deleted that path in favor of the synthesized OppositeCorners archetype).

## ⚔️ PentaTile vs. TileMapDual API

<a href="https://github.com/pablogila/TileMapDual" target="_blank" rel="noopener">TileMapDual ↗︎</a> is an established solution for Dual Grid systems in Godot. **PentaTile** takes a narrower scope, focusing on standard orthogonal grids with a minimal authoring surface.

| Area             | PentaTile                                                                  | TileMapDual                                                            |
| ---------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Public node      | `PentaTileMapLayer`                                                        | `TileMapDual` plus supporting addon classes                            |
| Drawing API      | Native `TileMapLayer.set_cell()` / editor painting                         | Native painting plus custom helpers such as `draw_cell(cell, terrain)` |
| Update hook      | `_update_cells(coords, forced_cleanup)` directly recomputes affected masks | `_update_cells()` forwards into display/cache/watcher systems          |
| Terrain model    | Binary occupied/empty terrain for V1                                       | Terrain peering bits and terrain rules                                 |
| Tile requirement | 1–5 tiles per Penta layout (or the layout's native count: 9, 16, 47…)      | 15-16 tile dual-grid/Wang-style sets                                   |
| Internal state   | No persistent coordinate cache; direct 4-bit sampling                      | Tile caches, terrain rule tries, watchers, signals                     |
| TileSet setup    | Strict atlas order, no terrain metadata required                           | Terrain metadata and optional editor autotile setup                    |
| Grid scope       | Square orthogonal V1                                                       | Broader grid-shape handling                                            |
| Collisions       | Generated visual layers can use TileSet physics polygons                   | Display layers copy collision-related properties from the parent       |

PentaTile is smaller because it focuses on a specific subset of the multi-terrain/general-grid flexibility offered by TileMapDual.

## ⚖️ Choosing the Right Tool

### Why choose PentaTile?

- **Scalability of Variations:** Because the **Penta** layout authoring scale starts at one tile and tops out at five, creating multiple visual variations is significantly faster and more manageable.
- **Engine Purity:** PentaTile acts as a lightweight extension of the native `TileMapLayer`. It allows you to use Godot's native painting tools as intended, with the system handling the transformation logic automatically.
- **Direct Logic:** It uses direct bitwise math to determine rotations and flips, keeping the runtime path short and easy to reason about.

### Why choose <a href="https://github.com/pablogila/TileMapDual" target="_blank" rel="noopener">TileMapDual ↗︎</a>?

- **Complex Transitions:** For projects requiring complex "Grass-to-Sand-to-Rock" multi-terrain blending, TileMapDual is designed to handle that specific complexity.
- **Standard Templates:** If you are already working with 16-tile Dual Grid (Wang) tilesets, TileMapDual provides a direct solution for those templates.

## 🛠️ Addon Layout

```text
addons/penta_tile/
  plugin.cfg
  penta_tile_map_layer.gd                  # core PentaTileMapLayer node
  penta_tile_synthesis.gd                  # synthesis machinery for Penta layouts
  penta_tile_atlas_slot.gd                 # slot resource (atlas_coords + transform_flags)
  _generate_bitmasks.py                    # internal tooling — regenerates bundled bitmask PNGs
  layouts/
    penta_tile_layout.gd                   # base PentaTileLayout
    penta_tile_layout_penta.gd             # Penta family (1–5 modes, horizontal & vertical)
    penta_tile_layout_dual_grid_16.gd      # Dual-grid 16-tile corner-mask
    penta_tile_layout_wang_2_edge.gd       # Wang 2-edge
    penta_tile_layout_wang_2_corner.gd     # Wang 2-corner
    penta_tile_layout_minimal_3x3.gd       # Minimal 3x3
    penta_tile_layout_penta/               # bundled per-mode PNGs (one_horizontal.png … five_vertical.png)
  tests/
    determinism_test.gd                    # PENTA-SYNTH-06 baseline check
    _capture_baseline.gd                   # baseline regeneration utility
    baselines/                             # captured hash + tile-map data
  demo/
    penta_tile_demo.tscn
    demo_player.gd
    demo_runtime_painter.gd
    penta_tile_ground.png
    penta_tile_ground.tres
    penta_layout_*_horizontal.tres         # demo Penta layout resources
```

`demo/penta_tile_ground.png` and `demo/penta_tile_ground.tres` are the demo atlas/TileSet. The `layouts/penta_tile_layout_penta/` PNG bundle ships the canonical Penta templates for each axis × mode combination.

## 🔌 Current API

`PentaTileMapLayer` extends `TileMapLayer`.

Use the native TileMapLayer API:

- `set_cell()`
- `erase_cell()`
- editor painting tools
- `tile_set`
- inherited TileMapLayer rendering/physics properties where applicable

Additional exported properties:

| Property                      | Purpose                                                                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `layout`                      | A `PentaTileLayout` resource — pick one of the bundled subclasses (Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3) or a custom. |
| `atlas_source_id`             | Atlas source to read from. `-1` uses the first source in the TileSet.                                                            |
| `logic_layer_opacity`         | Opacity for the hidden/editable logic layer. Defaults to `0.0`.                                                                  |
| `visual_z_index_offset`       | Z index applied to generated internal visual layers.                                                                             |
| `generated_collision_enabled` | Enables collisions on generated visual layers when the TileSet tiles have physics polygons.                                      |
| `logic_collision_enabled`     | Enables collisions on the source logic layer. Defaults to `false` to avoid hidden full-cell colliders.                           |

**Penta-specific layout properties** (on `PentaTileLayoutPenta`):

| Property       | Purpose                                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| `axis`         | `HORIZONTAL` (slots along X) or `VERTICAL` (slots along Y).                                                    |
| `tile_count`   | `AUTO` / `AUTO_STRIP` / `ONE..FIVE`. AUTO detects from atlas size; explicit modes pin the authoring scale.   |

Public helper:

| Method      | Purpose                                                               |
| ----------- | --------------------------------------------------------------------- |
| `rebuild()` | Clears and regenerates all visual cells from the current logic cells. |

## 🧪 Demo

Open `res://addons/penta_tile/demo/penta_tile_demo.tscn`.

The demo includes:

- a `PentaTileMapLayer` bound to a Penta FOUR-mode layout (`penta_layout_four_horizontal.tres`)
- a demo TileSet with collision polygons on the four authored Penta tiles
- generated visual-layer collisions enabled
- hidden logic-layer collisions disabled
- a `CharacterBody2D` using Godot's `icon.svg`, a capsule collision shape, gravity, arrow-key movement, and jump with Up/Space
- runtime editing: left click places the default logic tile, right click erases a logic tile

## 📝 Implementation Notes

Mask bits use:

| Bit | Quadrant     |
| --- | ------------ |
| `1` | Top-left     |
| `2` | Top-right    |
| `4` | Bottom-left  |
| `8` | Bottom-right |

The diagonal masks are `6` and `9`. Both resolve to the **OppositeCorners** archetype (slot 4 in a Penta atlas). PentaTile anchors mask 9 (`TL+BR`, "\\" diagonal) as the unrotated case (`_ROTATE_0`) and mask 6 (`TR+BL`, "/" diagonal) as `TRANSFORM_FLIP_H` of the same archetype. In modes ONE through FOUR the OppositeCorners art is synthesized from slot 0 corners by `PentaTileSynthesis`; in mode FIVE it is hand-authored. Single-layer dispatch only — no internal overlay layer.

The logic layer is hidden with `self_modulate.a`, not `visible = false`, because Godot may force cleanup behavior when a `TileMapLayer` is disabled, hidden, removed, or missing a TileSet.

## 🗺️ Roadmap

Future ideas remain intentionally separate from the V1 API:

- **PentaBake:** edit-time utility to procedurally compose a fifth edge/diagonal connector tile when useful.
- **Y-axis variations:** support atlas rows for deterministic/random visual variation.
- **Collision tooling:** research automatic collision generation and better collision presets. V1 supports TileSet-authored collision polygons on generated visual layers.
- **Outer transition tile support:** support transitions between terrain types, such as grass to dirt.
- **Top tiles:** support sets with designated top visuals for platformer-style grass caps.
- **Non-rotating tilesets:** support perspectives where top/bottom/left/right are not interchangeable.
- **MkDocs:** fuller documentation inspired by TileMapDual's docs.
- **Tileset converter:** convert Wang/blob tilesets or single-tile inputs into PentaTile-compatible atlases.

## 🔗 External Resources

- <a href="https://github.com/dandeliondino/godot-4-tileset-terrains-docs" target="_blank" rel="noopener">Godot 4 Autotilling Documentation ↗︎</a> - A detailed guide and starter project for understanding Godot 4's native terrain system.
- <a href="https://www.youtube.com/watch?v=jEWFSv3ivTg" target="_blank" rel="noopener">The Dual Grid Concept ↗︎</a> - A brilliant deep dive into how offset grid math solves the 47-tile problem.
- <a href="https://www.youtube.com/watch?v=aWcCNGen0cM" target="_blank" rel="noopener">Drawing Only 5 Tiles ↗︎</a> - The inspiration for PentaTile's minimalism, showing how to achieve high-end results with a tiny asset footprint.
- <a href="https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/" target="_blank" rel="noopener">Dual Tilemap Autotiling Technique (Excalibur.js) ↗︎</a> - Codifies the 5-archetype dual-grid set: <code>Filled</code>, <code>Edge</code>, <code>InnerCorner</code>, <code>OuterCorner</code>, <code>OppositeCorners</code>. Source for PentaTile's "Opposite Corners" archetype name. Companion code: <a href="https://github.com/jyoung4242/dual-grid-auto-tiling" target="_blank" rel="noopener">jyoung4242/dual-grid-auto-tiling ↗︎</a>.
- <a href="https://youtu.be/Uxeo9c-PX-w?t=305" target="_blank" rel="noopener">Oskar Stålberg — dual-grid implementation walkthrough (5:05) ↗︎</a> - The dual-grid talk that popularized this technique; the deep-link jumps straight to the tile-implementation breakdown.
- <a href="https://www.youtube.com/watch?v=buKQjkad2I0" target="_blank" rel="noopener">Programming Terrain Generation for my Farming Game ↗︎</a> - Devlog showing dual-grid / 5-tile autotiling applied in a real game project.
- <a href="https://www.rpgmakerweb.com/blog/classic-tutorial-how-autotiles-work" target="_blank" rel="noopener">Classic Tutorial: How Autotiles Work (RPG Maker) ↗︎</a> - Explains RPG Maker's A2 autotile internals — each tile composed from 4 mini-tiles of 24×24 px. Background reading for the eventual <code>RPGM-01/02</code> subtile compositor (v0.3+).

## 🙏 Attributions

- <a href="https://kenney.nl/assets/pico-8-platformer" target="_blank" rel="noopener">Kenney's Pico-8 Platformer ↗︎</a> - Asset pack used for the demo ground texture (CC0).
