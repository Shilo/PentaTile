# TetraTile ✨

## ✨ The 4-Tile Autotiling Revolution

**TetraTile** is a high-octane, ultra-lightweight **autotiling system** for Godot 4.6 that turns the "Standard 47" blob tileset nightmare into a distant memory. It’s not just a collection of assets—it’s a sophisticated **Dual-Grid logic engine** that squeezes every drop of potential out of a minimal 4-tile template.

By mastering the math of the Dual Grid, TetraTile takes four basic ingredients—**Fill, Inner Corner, Border, and Outer Corner**—and expands them into a seamless world with all the visual polish of a traditional 47-tile set, but with none of the grind.

---

## 📑 Table of Contents

1. [Why TetraTile?](#-why-tetratile-is-a-game-changer)
2. [The Tetra-System Template](#-the-tetra-system-template)
3. [Comparison: TetraTile vs. TileMapDual](#-tetratile-vs-tilemapdual-api)
4. [Choosing Your Champion](#-choosing-your-champion)
5. [Addon Layout](#-addon-layout)
6. [Current API](#-current-api)
7. [Demo](#-demo)
8. [Implementation Notes](#-implementation-notes)
9. [Roadmap](#-roadmap)
10. [External Resources](#-external-resources)

---

## 🚀 Why TetraTile is a Game Changer

- **The 4-Tile Superpower:** Let’s be real—drawing 47 tiles for a single wall type is a soul-crushing chore. Even a "simple" 16-tile dual-grid set (wang) feels like a mountain when you want to add variety. TetraTile slashes the entry fee to game art, giving you professional results for the cost of just four tiles.
- **Variations Without the Burnout:** This is where the magic happens. Because you only have to manage **four base tiles**, you finally have the freedom to go wild with **infinite variations**. Instead of struggling to finish one set of 47, you can draw 5 or 10 distinct versions of your 4 core tiles. TetraTile can then cycle through these to banish repetitive patterns forever. This level of organic, hand-crafted variety is practically impossible with bulky, old-school systems.
- **Native Performance, Zero Bloat:** Built as a sleek, single-class subclass of `TileMapLayer`, TetraTile isn't a clunky addon. It hooks directly into Godot's native API, listening to your drawing commands and updating the world in real-time. It’s fast, it’s invisible, and it feels like a native part of the engine.

---

## 🎨 The Tetra-System Template

To unlock the logic, your atlas just needs these four essential components arranged horizontally or vertically:

1.  **Fill** (The solid core)
2.  **Inner Corner** (For internal nooks)
3.  **Border** (Straight edges)
4.  **Outer Corner** (The finishing touch)

The two disconnected diagonal states are handled by composing two transformed outer corners on an internal overlay layer. This preserves the four-tile source template without pretending those masks can be represented by a single transformed tile.

---

## ⚔️ TetraTile vs. TileMapDual API

While [TileMapDual](https://github.com/pablogila/TileMapDual) is a fantastic pioneer for Dual Grid systems in Godot, **TetraTile** is built with a different philosophy: **Maximum Artistic Freedom through Minimum Technical Overhead.**

| Area | TetraTile | TileMapDual |
| --- | --- | --- |
| Public node | `TetraTileMapLayer` | `TileMapDual` plus supporting addon classes |
| Drawing API | Native `TileMapLayer.set_cell()` / editor painting | Native painting plus custom helpers such as `draw_cell(cell, terrain)` |
| Update hook | `_update_cells(coords, forced_cleanup)` directly recomputes affected masks | `_update_cells()` forwards into display/cache/watcher systems |
| Terrain model | Binary occupied/empty terrain for V1 | Terrain peering bits and terrain rules |
| Tile requirement | Four source tiles, with two-layer composition for diagonals | 15-16 tile dual-grid/Wang-style sets |
| Internal state | No persistent coordinate cache; direct 4-bit sampling | Tile caches, terrain rule tries, watchers, signals |
| TileSet setup | Strict atlas order, no terrain metadata required | Terrain metadata and optional editor autotile setup |
| Grid scope | Square orthogonal V1 | Broader grid-shape handling |
| Collisions | Generated visual layers can use TileSet physics polygons | Display layers copy collision-related properties from the parent |

TetraTile is smaller because it gives up TileMapDual's multi-terrain/general-grid flexibility. TileMapDual remains the better fit when you need complex transitions, terrain metadata workflows, or established 16-tile dual-grid sets.

---

## ⚖️ Choosing Your Champion

### Why choose TetraTile?

- **The "Variety" Factor:** Because you only draw 4 tiles, you can create 10+ variations of each. Drawing 47 variations for a traditional set is impossible; drawing 10 variations for TetraTile is a fun afternoon.
- **Engine Purity:** TetraTile acts as a "swizzle" on the native `TileMapLayer`. You don't learn a new API; you just use Godot as intended via native painting tools, and the system handles the rest.
- **Performance First:** No complex dictionary lookups or signal watchers. It uses direct bitwise math to determine rotations and flips instantly.

### Why choose [TileMapDual](https://github.com/pablogila/TileMapDual)?

- **Complex Transitions:** If your game requires complex "Grass-to-Sand-to-Rock" multi-terrain blending out of the box, TileMapDual’s heavier architecture is built to handle that specific complexity.
- **Established Workflow:** If you already have 16-tile Dual Grid tilesets (wang) prepared, TileMapDual is a plug-and-play solution for that specific template.

---

## 🛠️ Addon Layout

```text
addons/tetra_tile/
  plugin.cfg
  tetra_tile_map_layer.gd
  tetra_tile_template.png
  demo/
    demo_player.gd
    tetra_tile_demo.tscn
    tetra_tile_ground.png
    tetra_tile_ground.tres
```

`tetra_tile_template.png` is the blank 4-tile template. `demo/tetra_tile_ground.png` and `demo/tetra_tile_ground.tres` are the demo atlas/TileSet.

---

## 🔌 Current API

`TetraTileMapLayer` extends `TileMapLayer`.

Use the native TileMapLayer API:

- `set_cell()`
- `erase_cell()`
- editor painting tools
- `tile_set`
- inherited TileMapLayer rendering/physics properties where applicable

Additional exported properties:

| Property | Purpose |
| --- | --- |
| `atlas_source_id` | Atlas source to read from. `-1` uses the first source in the TileSet. |
| `atlas_layout` | Supports horizontal 4x1 or vertical 1x4 atlas layouts. |
| `logic_layer_opacity` | Opacity for the hidden/editable logic layer. Defaults to `0.0`. |
| `visual_z_index_offset` | Z index applied to generated internal visual layers. |
| `generated_collision_enabled` | Enables collisions on generated visual layers when the TileSet tiles have physics polygons. |
| `logic_collision_enabled` | Enables collisions on the source logic layer. Defaults to `false` to avoid hidden full-cell colliders. |

Public helper:

| Method | Purpose |
| --- | --- |
| `rebuild()` | Clears and regenerates all visual cells from the current logic cells. |

---

## 🧪 Demo

Open `res://addons/tetra_tile/demo/tetra_tile_demo.tscn`.

The demo includes:

- a `TetraTileMapLayer`
- a demo TileSet with collision polygons on all four template tiles
- generated visual-layer collisions enabled
- hidden logic-layer collisions disabled
- a `CharacterBody2D` using Godot's `icon.svg`, a capsule collision shape, gravity, arrow-key movement, and jump with Up/Space
- runtime editing: left click places the default logic tile, right click erases a logic tile

---

## 📝 Implementation Notes

Mask bits use:

| Bit | Quadrant |
| --- | --- |
| `1` | Top-left |
| `2` | Top-right |
| `4` | Bottom-left |
| `8` | Bottom-right |

The diagonal masks are `6` and `9`. They are drawn by placing one outer corner on the primary visual layer and the other on the internal overlay layer.

The logic layer is hidden with `self_modulate.a`, not `visible = false`, because Godot may force cleanup behavior when a `TileMapLayer` is disabled, hidden, removed, or missing a TileSet.

---

## 🗺️ Roadmap

Future ideas remain intentionally separate from the V1 API:

- **TetraBake:** edit-time utility to procedurally compose a fifth edge/diagonal connector tile when useful.
- **Y-axis variations:** support atlas rows for deterministic/random visual variation.
- **Shader fallback:** single-pass shader option for diagonal compositing.
- **Collision tooling:** research automatic collision generation and better collision presets. V1 supports TileSet-authored collision polygons on generated visual layers.
- **Outer transition tile support:** support transitions between terrain types, such as grass to dirt.
- **Top tiles:** support tilesets with designated top visuals for platformer-style grass caps.
- **Non-rotating tilesets:** support perspectives where top/bottom/left/right are not interchangeable.
- **MkDocs:** fuller documentation inspired by TileMapDual's docs.
- **Tileset converter:** convert Wang/blob tilesets or single-tile inputs into TetraTile-compatible atlases.

---

## 🔗 External Resources

- [Godot 4 Autotilling Documentation](https://github.com/dandeliondino/godot-4-tileset-terrains-docs) - A detailed guide and starter project for understanding Godot 4's native terrain system.
- [The Dual Grid Concept](https://www.youtube.com/watch?v=jEWFSv3ivTg) - A brilliant deep dive into how offset grid math solves the 47-tile problem.
- [Drawing Only 5 Tiles](https://www.youtube.com/watch?v=aWcCNGen0cM) - The inspiration for TetraTile's minimalism, showing how to achieve high-end results with a tiny asset footprint.

---

## 🙏 Attributions

- [Kenney's Pico-8 Platformer](https://kenney.nl/assets/pico-8-platformer) - Asset pack used for the demo ground texture (CC0).
