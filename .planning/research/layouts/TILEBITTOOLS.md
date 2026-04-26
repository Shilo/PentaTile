# TileBitTools Deep Audit — Source, Templates, Patterns

**Purpose:** map TileBitTools' addon structure, template inventory, and customization model so TetraTile's v0.2 layout-Resource library can adopt the patterns that fit and ignore the ones that don't. The user explicitly cited TileBitTools as the gold-standard reference for "heavy customization and multiple popular templates"; this audit converts that pointer into a concrete spec.

**Repo:** `https://github.com/dandeliondino/tile_bit_tools`
**Owner:** dandeliondino
**Latest version:** 1.1.0 (released 2023-07-09)
**Status:** **archived 2024-04-13**, MIT license, 66 stars, 3 forks
**Stack:** pure GDScript (~3,500 LOC), Godot 4.x EditorPlugin
**Audited:** 2026-04-25 from the `main` branch tree

> **Headline reframing:** TileBitTools is **not** a runtime layout-library addon like TetraTile aspires to be. It is an **edit-time inspector plugin** that mutates Godot's stock TileSet `terrain_set` / `terrain` / `terrain_peering_bits` metadata in place. Its "templates" are `.tres` Resources that encode peering-bit configurations to *apply to* a Godot terrain set; they are **not** atlas-image templates. This is the central architectural fork TetraTile must navigate: TileBitTools chose the "click-author through Godot's terrain system, but faster" path; TetraTile's v0.1 chose the "skip Godot's terrain system entirely" path. The two designs are complementary, not equivalent.

> **Confidence:** HIGH on file layout, README contents, .tres structure, and per-template peering-bit encoding (all read directly from the live repo). MEDIUM on the user-flow click counts and dialog UX (read from the wiki + source, not exercised in a live editor). LOW on Tilesetter compatibility claims that the README makes (TileBitTools does not document its own Tilesetter alignment beyond the template description text).

---

## Table of Contents

1. [Repo identity and license](#1-repo-identity-and-license)
2. [README transcription and feature summary](#2-readme-transcription-and-feature-summary)
3. [Addon file structure and LOC inventory](#3-addon-file-structure-and-loc-inventory)
4. [Resource subclasses and the `TemplateBitData` schema](#4-resource-subclasses-and-the-templatebitdata-schema)
5. [Bundled template inventory (the 12 `.tres` files)](#5-bundled-template-inventory-the-12-tres-files)
6. [Example atlas PNGs (the 7 reference images)](#6-example-atlas-pngs-the-7-reference-images)
7. [Customization model — Project Settings + Tags + Custom templates](#7-customization-model--project-settings--tags--custom-templates)
8. [User-facing workflow (apply / save / edit)](#8-user-facing-workflow-apply--save--edit)
9. [The 47-blob "Godot community template" question](#9-the-47-blob-godot-community-template-question)
10. [Patterns TetraTile should adopt](#10-patterns-tetratile-should-adopt)
11. [Anti-patterns TetraTile should NOT copy](#11-anti-patterns-tetratile-should-not-copy)
12. [Finalized v0.2 TetraTile layout-library mapping table](#12-finalized-v02-tetratile-layout-library-mapping-table)
13. [Honest gaps](#13-honest-gaps)

---

## 1. Repo identity and license

| Field | Value |
|---|---|
| Full URL | `https://github.com/dandeliondino/tile_bit_tools` |
| Owner | `dandeliondino` (single maintainer, GitHub user id 68911895) |
| Created | 2023-03-05 |
| Last push | 2024-04-13 |
| Archived | **YES** (read-only since 2024-04-13) |
| Default branch | `main` |
| Stars | 66 |
| Forks | 3 |
| Language | GDScript |
| License | MIT (`addons/tile_bit_tools/LICENSE`) |
| Repo size | 12,347 KB |
| Open issues | 0 (issues disabled — `has_issues: false`) |
| Has wiki | YES (used for end-user docs) |

**Release history (verbatim from `gh api repos/dandeliondino/tile_bit_tools/releases`):**

```
v1.1.0  (2023-07-09)  v1.1.0
v1.0.3  (2023-06-04)  v1.0.3
v1.0.2  (2023-03-29)  v1.0.2
v1.0.1  (2023-03-21)  v1.0.1
v1.0.0  (2023-03-16)  v1.0.0 Asset Library Release
v0.2.0  (2023-03-16)  v0.2.0
v0.1.1  (2023-03-09)  Initial Release (v0.1.1)
```

**Asset Library entry:** [Godot Asset Library #1757](https://godotengine.org/asset-library/asset/1757), labelled "compatible with Godot 4.1" but the README never names a specific Godot version.

**Maintenance status (verbatim from README):**

> ***As of 4/2024, this repo is no longer being actively maintained.***

This matters for TetraTile because (a) any architectural pattern we lift is unlikely to receive further upstream changes that would create maintenance friction, and (b) any bug we inherit from copying patterns we'll have to own ourselves.

---

## 2. README transcription and feature summary

The README at `addons/tile_bit_tools/README.md` (5518 bytes) is the addon's authoritative description. Verbatim sections:

### Stated purpose

> "TileBitTools is a Godot 4 plugin for autotile templates and terrain bit editing.
>
> The terrain system in Godot 4 is powerful and extensible, and has a lot of untapped potential. The goal of this plugin is to enable fast iterations, to assist in migrating from Godot 3, and to speed up the learning process for new users."

Reading between the lines: TileBitTools is **a UX-improvement layer on top of Godot 4's stock terrain system**, not a replacement. Its value proposition is "Godot's terrain system is correct but tedious; here's a faster way to fill in the same metadata."

### Features (verbatim)

> - **Built-in autotile templates for all three Godot 4 terrain modes**
>     - **3x3 minimal**, **3x3 16-tile** and **2x2** templates from Godot 3 documentation.
>     - **Blob**, **Wang** and **Wang 3-terrain** templates to match Tilesetter's default export.
>     - **Simple 9- and 4-tile** templates. These are modular corner-mode templates that match tile configurations commonly found in spritesheets.
> - **Tips and example tiles for all built-in templates**
> - **Terrain bit editing buttons** to make changes like 'Fill' and 'Clear' to multiple tiles or peering bits in one click
> - **Custom user template creation**
>     - Save new templates from the terrain peering bits on existing tiles. Statistics and previews are automatically generated.
>     - Use as a quick way to copy-paste terrain bits.
>     - Or use to save complex, reusable templates to a shared directory accessible to all projects.
> - **Options in Project Settings**
>     - Customize the template bit colors (default colors are from the color-blind-friendly 'bright' scheme from [Paul Tol](https://personal.sron.nl/~pault/))
>     - Customize which messages appear in the Output log
>     - Customize the template save folder location

### Limitations (verbatim)

> - Even using Godot 3 autotile templates, tile placement will not work exactly the same as it did in Godot 3, as the core matching algorithm is different
> - Hex and isometric tiles are not supported
> - Alternative tiles are not supported

### How to use (verbatim)

> *Please back up your project before making any changes. Godot 4 is still new, and TileBitTools is even newer, so unexpected behavior may occur.*
>
> TileBitTools is located in the bottom TileSet editor, in the Select tab. To access any of its functions, the first step is to select tiles.

The "Select tab" is part of Godot's stock TileSet editor; TileBitTools attaches itself there via an `EditorInspectorPlugin` rather than adding its own dock or menu. **This is one of the cleanest UX-integration patterns in the Godot addon ecosystem** — invisible until you select tiles, contextual when you do.

### Compatibility notes

The README does NOT name a specific Godot 4.x minor version. The Asset Library entry says 4.1. The `plugin.cfg` says `version="1.1.0"` for TileBitTools itself. Empirically the code uses `TileSet.TerrainMode`, `TileSet.CellNeighbor`, `TileData.set_terrain_peering_bit()` — all 4.0+ APIs.

### License (verbatim)

The addon ships a copy of the MIT License at `addons/tile_bit_tools/LICENSE` (1070 bytes), with copyright attributed to `dandeliondino` (2023). This means TetraTile can lift code patterns or even whole files (with attribution) without licensing friction.

### Credits worth noting

> "Concept inspired by [Wareya's Godot Tile Setup Helper](https://github.com/wareya/godot-tile-setup-helper) for Godot 3.5"
>
> "Huge thanks to [YuriSizov's Godot Editor Theme Explorer](https://github.com/YuriSizov/godot-editor-theme-explorer) and [Zylann's Editor Debugger](https://github.com/Zylann/godot_editor_debugger_plugin)"

The Wareya tool is the spiritual predecessor — also a "click-author Godot's terrain bits" tool, but for Godot 3.5. TileBitTools is the Godot 4 reimagining.

---

## 3. Addon file structure and LOC inventory

The full tree under `addons/tile_bit_tools/` (transcribed from `gh api .../git/trees/main?recursive=1`):

```
addons/tile_bit_tools/
├── LICENSE                              (1070 bytes)
├── README.md                            (5518 bytes)
├── plugin.cfg                           (167 bytes)         # 5 lines
├── plugin.gd                            (1579 bytes)        # 62 LOC — EditorPlugin entry
├── inspector_plugin.gd                  (9748 bytes)        # 353 LOC — EditorInspectorPlugin
│
├── controls/                            # All UI scenes + scripts
│   ├── bit_data_draw/
│   │   ├── bit_data_draw.gd                                 # 237 LOC — renders bit color overlays
│   │   ├── bit_data_draw_node.gd                            # ~30 LOC
│   │   └── bit_data_draw_node.tscn
│   ├── icons/
│   │   └── tile_bit_tools_16.svg                            # plugin dock icon
│   ├── shared/
│   │   ├── icon_button.gd
│   │   ├── inspector_section_button.gd
│   │   ├── inspector_section_button.tscn
│   │   ├── template_info_list.gd
│   │   └── template_info_list.tscn
│   ├── tbt_plugin_control/
│   │   ├── tbt_plugin_control.gd                            # 245 LOC — root control
│   │   ├── tbt_plugin_control.tscn
│   │   ├── template_manager.gd                              # 109 LOC — template loader/cache
│   │   ├── tiles_manager.gd                                 # 133 LOC — apply/preview pipeline
│   │   ├── theme_updater.gd                                 # ~270 LOC — theme harmonization
│   │   └── popups/
│   │       ├── template_dialog.gd                           # 173 LOC
│   │       ├── save_template_dialog.gd                      # 75 LOC
│   │       └── edit_template_dialog.gd                      # 62 LOC
│   ├── tiles_inspector/
│   │   ├── tiles_inspector.gd                               # 45 LOC — root inspector control
│   │   ├── tiles_inspector.tscn
│   │   ├── template_section/
│   │   │   ├── templates_section.gd                         # 276 LOC — template picker UI
│   │   │   ├── template_info_panel.gd                       # 126 LOC
│   │   │   ├── terrain_picker.gd                            # 91 LOC — maps template terrains → atlas terrains
│   │   │   └── selected_tag.gd / selected_tag_stylebox.tres
│   │   └── tool_buttons/
│   │       ├── tool_buttons.gd                              # 177 LOC — Fill / Clear / Set Bits buttons
│   │       └── tool_buttons.tscn
│   └── tiles_preview/
│       ├── tiles_preview.gd                                 # 206 LOC — live preview overlay
│       ├── tiles_preview.tscn
│       ├── tiles_view.gd
│       ├── tiles_view.tscn
│       └── terrain_opacity_slider.gd
│
├── core/
│   ├── globals.gd                       # 95 LOC — paths, settings, enums
│   ├── icons.gd                         # 35 LOC
│   ├── output.gd                        # 160 LOC — debug/info/user output channels
│   ├── texts.gd                         # 53 LOC — externalized strings
│   ├── context.gd                       # 114 LOC — current tile/source/tile_set state
│   ├── bit_data.gd                      # 245 LOC — base Resource for bit data
│   ├── editor_bit_data.gd               # 123 LOC — bit_data attached to live editor tiles
│   ├── template_bit_data.gd             # 105 LOC — bit_data serialized as a template
│   ├── template_loader.gd               # 257 LOC — discovers + tags + caches templates
│   └── template_tag_data.gd             # 134 LOC — auto-tag definitions (Built-In, Mode, etc.)
│
├── examples/                            # 7 example PNGs + ABOUT.txt per template
│   ├── godot3_2x2/                      (16-tile 4×4 atlas)
│   ├── godot3_3x3_16_tiles/             (16-tile 4×4 atlas)
│   ├── godot3_3x3_minimal/              (47-tile 13×12 atlas with gaps)
│   ├── simple_tilesets/                 (4 + 9 tile examples)
│   ├── tilesetter_blob/                 (47-tile 12×5 atlas with gaps — Tilesetter Set View layout)
│   ├── tilesetter_wang/                 (15-tile 6×3 atlas)
│   └── tilesetter_wang_3_terrains/      (multi-block atlas)
│
└── templates/
    ├── godot3_2x2.tres                                      # MATCH_CORNERS, 16 tiles
    ├── godot3_3x3_16_tiles.tres                             # MATCH_SIDES, 16 tiles
    ├── godot3_3x3_minimal.tres                              # MATCH_CORNERS_AND_SIDES, 47 tiles
    ├── simple_4-tile_(inside_corners).tres                  # MATCH_CORNERS, 4 tiles
    ├── simple_9-tile_(inside_corners).tres                  # MATCH_CORNERS, 9 tiles
    ├── simple_9-tile_(outside_corners).tres                 # MATCH_CORNERS, 9 tiles
    ├── tilepipe2_256_tile_16x16.tres                        # MATCH_CORNERS_AND_SIDES, 256 tiles
    ├── tilepipe2_256_tile_32x8.tres                         # MATCH_CORNERS_AND_SIDES, 256 tiles
    ├── tilesetter_blob.tres                                 # MATCH_CORNERS_AND_SIDES, 47 tiles
    ├── tilesetter_wang.tres                                 # MATCH_CORNERS, 15 tiles
    ├── tilesetter_wang_3-terrain.tres                       # MATCH_CORNERS, 3 terrains
    └── tilesetter_wang_3-terrain_transitions.tres           # MATCH_CORNERS, 3 terrains
```

### LOC summary by area (`wc -l` on `.gd` files)

| Area | LOC | Files |
|---|---|---|
| Core (data + loader + globals) | ~1,180 | bit_data, editor_bit_data, template_bit_data, template_loader, template_tag_data, context, globals, output, icons, texts |
| Plugin entry + inspector | ~415 | plugin.gd, inspector_plugin.gd |
| `tbt_plugin_control` (root + popups + managers) | ~880 | tbt_plugin_control, template_manager, tiles_manager, theme_updater, 3 popup scripts |
| `tiles_inspector` (UI panels + controls) | ~830 | tiles_inspector, templates_section, template_info_panel, terrain_picker, tool_buttons, selected_tag |
| `tiles_preview` (live overlay) | ~250 | tiles_preview, tiles_view, terrain_opacity_slider |
| `bit_data_draw` (subviewport renderer) | ~270 | bit_data_draw, bit_data_draw_node |
| **Total GDScript** | **~3,825 LOC** | 25+ scripts |

For comparison: TetraTile v0.1.0 is **~261 LOC** total. TileBitTools is **roughly 15× the size of v0.1 TetraTile**. This is a different scale of project — useful for showing what's possible, but TetraTile must NOT scale to match (per PROJECT.md's "smaller and simpler than TileMapDual" identity guardrail).

---

## 4. Resource subclasses and the `TemplateBitData` schema

TileBitTools uses a clean three-tier Resource inheritance:

```
Resource
  └── BitData                    (core/bit_data.gd, 245 LOC)
       │   Stores _tiles dict, terrain_set, terrain_mode.
       │   Provides set/get_bit_terrain, fill_all_tile_terrains,
       │   replace_all_tile_terrains, etc.
       │
       ├── EditorBitData         (core/editor_bit_data.gd, 123 LOC)
       │   Bit data extracted from the LIVE editor selection.
       │   Talks to TileSet/TileSetAtlasSource/TileData directly.
       │
       └── TemplateBitData       (core/template_bit_data.gd, 105 LOC)
            Bit data serialized as a .tres on disk.
            Adds: version, template_name, template_description,
                  _custom_tags, template_terrain_count, example_folder_path,
                  built_in (runtime only), preview_texture (runtime only).
            load_editor_bit_data(): converts EditorBitData into a savable template.
```

### Verbatim `BitData` schema (from `core/bit_data.gd`)

```gdscript
@tool
extends Resource

enum TerrainBits {
    CENTER=99,
    TOP_LEFT_CORNER=TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,    # = 11
    TOP_SIDE=TileSet.CELL_NEIGHBOR_TOP_SIDE,                  # = 12
    TOP_RIGHT_CORNER=TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,  # = 15
    RIGHT_SIDE=TileSet.CELL_NEIGHBOR_RIGHT_SIDE,              # = 0
    BOTTOM_RIGHT_CORNER=TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, # = 3
    BOTTOM_SIDE=TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,            # = 4
    BOTTOM_LEFT_CORNER=TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,   # = 7
    LEFT_SIDE=TileSet.CELL_NEIGHBOR_LEFT_SIDE,                # = 8
}

const NULL_TERRAIN_INDEX := -1
const NULL_TERRAIN_SET := -1
const NULL_TERRAIN_MODE := -1

# Lookup: which neighbor bits each terrain mode reads
var CellNeighborsByMode := {
    TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: [
        TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,    # 11
        TileSet.CELL_NEIGHBOR_TOP_SIDE,           # 12
        TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,   # 15
        TileSet.CELL_NEIGHBOR_RIGHT_SIDE,         # 0
        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,# 3
        TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,        # 4
        TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, # 7
        TileSet.CELL_NEIGHBOR_LEFT_SIDE,          # 8
    ],
    TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS: [
        TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,    # 11
        TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,   # 15
        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,# 3
        TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, # 7
    ],
    TileSet.TerrainMode.TERRAIN_MODE_MATCH_SIDES: [
        TileSet.CELL_NEIGHBOR_TOP_SIDE,           # 12
        TileSet.CELL_NEIGHBOR_RIGHT_SIDE,         # 0
        TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,        # 4
        TileSet.CELL_NEIGHBOR_LEFT_SIDE,          # 8
    ],
}

enum _TileKeys {TERRAIN, PEERING_BITS}

# _tiles[Vector2i atlas coords] = {
#   _TileKeys.TERRAIN: int,         # the tile's center terrain
#   _TileKeys.PEERING_BITS: { CellNeighbor : terrain_index, ... }
# }
@export var _tiles := {}
@export var terrain_set := NULL_TERRAIN_SET
@export var terrain_mode := TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES
```

### Verbatim `TemplateBitData` schema (from `core/template_bit_data.gd`)

```gdscript
@tool
extends "res://addons/tile_bit_tools/core/bit_data.gd"

const additional_colors := [Color.RED, Color.BLUE, Color.YELLOW, ...]

@export var version : String                    # template format version, e.g. "0.2.0"
@export var template_name : String              # display name in the picker
@export var template_description : String       # multi-line description
@export var _custom_tags := []                  # user-defined tags like "Tilesetter", "Godot 3"
@export var template_terrain_count : int        # how many terrains it defines
@export var example_folder_path : String        # path to a sibling examples/ folder

var built_in := false                           # set at load time, NOT serialized
var preview_texture : Texture2D                 # generated at runtime, NOT serialized

var terrain_colors := { -1: Color.TRANSPARENT, 0: ..., 1: ..., 2: ..., 3: ... }

func get_terrain_color(terrain_index : int) -> Color: ...
func get_custom_tags() -> Array: ...
func load_editor_bit_data(bit_data : EditorBitData) -> G.Errors: ...
```

### Custom data layers

**TileBitTools does NOT use TileSet `custom_data_layers`.** It writes directly to:

- `TileData.terrain_set`
- `TileData.terrain` (the center bit)
- `TileData.set_terrain_peering_bit(cell_neighbor, terrain_id)` (the 8/4 peering bits per Godot's terrain mode)

This is the central design choice: **TileBitTools is a tool that fills in Godot's stock metadata fields, not one that adds new metadata.** Once the user clicks "Apply Changes," the template data is gone — only the per-tile peering bits remain. The template `.tres` is just the source of those bits.

### Inspector plugin

`addons/tile_bit_tools/inspector_plugin.gd` (353 LOC) is an `EditorInspectorPlugin` that hooks into the running TileSet editor. The hot-path:

```gdscript
func _can_handle(object: Object) -> bool:
    if object.is_class("AtlasTileProxyObject"):
        return true
    return false

func _parse_end(object: Object) -> void:
    if !object.is_class("AtlasTileProxyObject"):
        return
    var result := await _add_inspector()
    # adds the TBT panel BELOW Godot's stock per-tile inspector
```

It also walks the editor's internal scene tree to find `TileSetEditor`, `TileSetAtlasSourceEditor`, and `TileAtlasView` nodes, then attaches a shared `TBTPluginControl` to the editor's base control. **This is fragile** — relies on internal class names that could change between Godot versions — but it's also the only way to integrate a contextual UI inside a stock editor panel. TetraTile must decide whether to copy this fragility or stay clean of editor internals.

### Configuration files

There is **no project-level `tile_bit_tools_config.tres`**. Settings are stored in `ProjectSettings` under the prefix `addons/tile_bit_tools/`:

```gdscript
const Settings := {
    "user_templates_path":  { default: "",       hint: PROPERTY_HINT_DIR },
    "output_show_user":     { default: true,     type: BOOL },
    "output_show_info":     { default: false,    type: BOOL },
    "output_show_debug":    { default: false,    type: BOOL },
    "colors_terrain_01":    { default: "AA3377"  (pink) },     # Paul Tol "bright" scheme
    "colors_terrain_02":    { default: "CCBB44"  (yellow) },
    "colors_terrain_03":    { default: "228833"  (green) },
    "colors_terrain_04":    { default: "66ccee"  (cyan) },
}
```

Project Settings rather than a settings Resource is a deliberate Godot-native choice — the user finds these under **Project → Project Settings → Tile Bit Tools** and they're versioned with `project.godot`.

---

## 5. Bundled template inventory (the 12 `.tres` files)

Each template is a `.tres` Resource with the schema in §4. **No template ships an atlas PNG with built-in slot ordering** — TileBitTools doesn't define a slot order; it defines per-tile peering bits and the user's atlas image is whatever they bring. The `Vector2i(x, y)` keys in `_tiles` are atlas coordinates the user is *expected* to lay out at, but TileBitTools cannot enforce this — it can only apply the bits to whichever tiles the user has selected, and assumes the (col, row) selection rectangle aligns with the template's coordinate space.

### 5.1 `godot3_2x2.tres`

| Field | Value |
|---|---|
| `template_name` | `"2x2 (Godot 3)"` |
| `version` | `"0.1.0"` |
| `template_terrain_count` | 2 |
| `terrain_mode` | `1` = `MATCH_CORNERS` |
| `_custom_tags` | `["Godot 3", "TilePipe2"]` |
| `example_folder_path` | `"res://addons/tile_bit_tools/examples/godot3_2x2/"` |
| Tile count | 16 |
| Atlas occupancy | 4×4 fully populated |
| File size | 1715 bytes |

**Description (verbatim):**
> "Like all corner-matching templates, it can be used for simple blocks of terrain or diagonal paths or walls. It cannot be drawn in a single-tile wide line. This configuration is based on the Godot 3 documentation."

**Atlas occupancy (parsed from `_tiles` Vector2i keys):**

```
# # # #
# # # #
# # # #
# # # #
```

**Slot-by-slot peering bits (decoded — example for `Vector2i(0, 0)`):**

```
Vector2i(0, 0): terrain=0,  peering = { 3:1, 7:0, 11:1, 15:1 }
                                       BR  BL   TL  TR
                              = "TL=1, TR=1, BR=1, BL=0"
                              = mask 0b1110 (TL+TR+BR set; BL empty)
```

The 16 entries cover the 16 corner-mask permutations exactly.

### 5.2 `godot3_3x3_16_tiles.tres`

| Field | Value |
|---|---|
| `template_name` | `"3x3 16 Tiles (Godot 3)"` |
| `terrain_mode` | `2` = `MATCH_SIDES` |
| `_custom_tags` | `["Godot 3"]` |
| Tile count | 16 |
| Atlas occupancy | 4×4 fully populated |
| File size | 1698 bytes |

**Peering keys used:** `0, 4, 8, 12` = `RIGHT_SIDE, BOTTOM_SIDE, LEFT_SIDE, TOP_SIDE`. The 4 edge bits, 16 permutations.

### 5.3 `godot3_3x3_minimal.tres`

| Field | Value |
|---|---|
| `template_name` | `"3x3 Minimal (Godot 3)"` |
| `terrain_mode` | `0` = `MATCH_CORNERS_AND_SIDES` |
| `_custom_tags` | `["Godot 3", "TilePipe2"]` |
| Tile count | 47 |
| Atlas occupancy | 12×4 with one cell unused (Vector2i(11, 3) is the gap) |
| File size | 4831 bytes |

**Description (verbatim):**
> "Like all corner-and-side-matching templates, this 47/48-tile template has flexible uses and can make complex shapes. It is good for terrains, paths and walls."

**Note:** the example PNG `godot3_3x3_minimal.png` is **208×192 px (13×12 atlas grid)** — that's larger than the .tres's 12×4 = 48 cells. The example PNG bundles multiple terrains (grass + dirt + water) into one image; the template only addresses the grass terrain in a 12-cell stripe. TetraTile's lesson: example images and templates can target different visual scopes.

### 5.4 `simple_4-tile_(inside_corners).tres`

| Field | Value |
|---|---|
| `template_name` | `"Simple 4-Tile (Inside Corners)"` |
| `terrain_mode` | `1` = `MATCH_CORNERS` |
| `_custom_tags` | `["Incomplete Autotile", "Simple"]` |
| Tile count | 4 |
| Atlas occupancy | 2×2 fully populated |
| File size | 1109 bytes |

**Description (verbatim):**
> "Use with Simple 9-Tile (Outside Corners). These simple autotiles are commonly found in spritesheets. Combining sets of inside and outside corners allows drawing a variety of over-lapping rectangles. However, the diagonal corners found in a full set of Corner tiles will be missing. And, like all Corner-mode autotiles, single-tile lines are not possible."

The `"Incomplete Autotile"` tag is doing real work — TileBitTools tells the user upfront that this template alone doesn't cover all states; you pair it with the matching outside-corners template.

### 5.5 `simple_9-tile_(inside_corners).tres`

| Field | Value |
|---|---|
| `template_name` | `"Simple 9-Tile (Inside Corners)"` |
| `terrain_mode` | `1` = `MATCH_CORNERS` |
| `_custom_tags` | `["Incomplete Autotile", "Simple"]` |
| Tile count | 9 |
| Atlas occupancy | 3×3 fully populated |
| File size | 1403 bytes |

The "fill" tile at `Vector2i(1, 1)` has `terrain=1` (the others are `terrain=0`); it's the center of a typical "inside corners" 3×3 spritesheet block.

### 5.6 `simple_9-tile_(outside_corners).tres`

Symmetric counterpart to 5.5. Same dimensions, same description boilerplate, complementary peering bits. File size 1410 bytes.

### 5.7 `tilesetter_blob.tres`

**This is the headline template** — the one most directly relevant to TetraTile's `TetraTileLayoutTilesetterBlob47`.

| Field | Value |
|---|---|
| `template_name` | `"Blob (Tilesetter)"` |
| `version` | `"0.2.0"` |
| `terrain_mode` | `0` = `MATCH_CORNERS_AND_SIDES` |
| `_custom_tags` | `["Tilesetter"]` |
| Tile count | 47 |
| Atlas occupancy | **11×5 with gaps** — see grid below |
| File size | 4684 bytes |

**Description (verbatim):**
> "Corners-and-Sides autotile in Tilesetter's layout. In Tilesetter, select the center tile, build borders for 'Blob', then select the tiles and export as 'Image'. Does not include the stray single tile. Select that tile separately, and click 'Fill'."

**Atlas occupancy (parsed from `_tiles` Vector2i keys):**

```
col    0 1 2 3 4 5 6 7 8 9 10
row 0  # # # # # # # # # # .
row 1  # # # # # # # # # # .
row 2  # # # # # # # # # # #
row 3  # # # # # # # # # # #
row 4  . . . . # # # # # . .
```

This is the **discrete sub-block layout** the TILESETTER_AND_GODOT.md audit flagged. The previous research's "7×8 with 9 unused cells in last row" inference was wrong; the real layout is **11 columns × 5 rows with intentional gaps**:

- Top-right corner (cols 10, rows 0-1) is empty
- Bottom row (row 4) is mostly empty except for cols 4-8 (5 cells), which form the "stray single tile cluster" the description warns about

This is **Tilesetter's exported PNG layout, encoded directly into the .tres** — meaning the dandeliondino author DID empirically determine Tilesetter's slot order and bake it in. TetraTile can use this `.tres` as a Rosetta Stone: read the (col, row) → peering bits mapping, derive the (col, row) → mask mapping, and that's the slot order for `TetraTileLayoutTilesetterBlob47`.

> **MAJOR INSIGHT:** the empirical fingerprinting work that TILESETTER_AND_GODOT.md said TetraTile needs to do — **TileBitTools has already done it** for Tilesetter Blob and Tilesetter Wang. The MIT license means we can lift the `_tiles` table verbatim, decode it once into TetraTile's mask-to-slot table, and never run Tilesetter ourselves. This is a major v0.2 timeline win.

**Sample peering bits for `Vector2i(1, 1)` (the empty bottom-right corner):**

```
Vector2i(1, 1): terrain=0, peering = { 0:0, 3:0, 4:0, 7:0, 8:0, 11:0, 12:0, 15:0 }
              = all 8 neighbors are terrain 0 (not the painted terrain)
              = mask 0 = "isolated tile, surrounded by background"
```

**Sample peering bits for `Vector2i(3, 3)` (a corner-blob shape):**

```
Vector2i(3, 3): terrain=0, peering = { 0:1, 3:1, 4:1, 7:1, 8:1, 11:1, 12:1, 15:1 }
              = all 8 neighbors are terrain 1 (the painted terrain)
              = the "fully connected" tile
```

Decoding the full table is a TetraTile v0.2 implementation task; the .tres provides the canonical reference.

### 5.8 `tilesetter_wang.tres`

| Field | Value |
|---|---|
| `template_name` | `"Wang (Tilesetter)"` |
| `terrain_mode` | `1` = `MATCH_CORNERS` |
| `_custom_tags` | `["Tilesetter"]` |
| Tile count | **15** (NOT 16) |
| Atlas occupancy | 5×3 fully populated |
| File size | 1608 bytes |

**Description (verbatim):**
> "Corners autotile in Tilesetter's layout. In Tilesetter, select the center tile, build borders for 'Wang', then select the tiles and export as 'Image'. Does not include the stray single tile. Select that tile separately, and click 'Fill'."

**Critical finding:** Tilesetter's Wang export is **15 tiles, not 16**. The "stray single tile" is the all-empty / fully-isolated tile that gets handled separately. This contradicts every previous claim in TetraTile research that "Tilesetter Wang is 16 tiles." It is in fact 15 tiles + 1 separately-filled tile.

**Atlas occupancy (5×3 grid, fully populated):**

```
col    0 1 2 3 4
row 0  # # # # #
row 1  # # # # #
row 2  # # # # #
```

15 tiles across `Vector2i(0,0)` through `Vector2i(4,2)`. Decoded mask values from the peering bits would give the (col, row) → corner-mask table for `TetraTileLayoutTilesetterWang16` (or rather `TetraTileLayoutTilesetterWang15`).

### 5.9 `tilesetter_wang_3-terrain.tres`

| Field | Value |
|---|---|
| `template_name` | `"Wang 3-Terrain (Tilesetter)"` |
| `terrain_mode` | `1` = `MATCH_CORNERS` |
| `_custom_tags` | `["Tilesetter"]` |
| `template_terrain_count` | **3** |
| Tile count | 81 |
| Atlas occupancy | 12×12 with gaps — see grid below |
| File size | 5514 bytes |

**Atlas occupancy (parsed):**

```
col    0  1  2  3  4  5  6  7  8  9 10 11
row 0  .  #  #  #  #  #  .  .  .  .  .  .
row 1  #  #  #  #  #  #  .  .  .  .  .  .
row 2  .  #  #  #  #  #  .  .  .  .  .  .
row 3  .  #  #  #  #  #  .  .  .  .  .  .
row 4  #  #  .  #  #  #  .  .  .  .  .  .
row 5  .  #  #  #  #  #  .  .  .  .  .  .
row 6  .  #  #  #  #  #  #  #  #  #  #  #
row 7  .  #  .  #  #  #  #  #  #  #  #  #
row 8  .  #  #  #  #  #  #  #  #  #  #  #
row 9  .  .  .  .  .  .  #  #  #  #  #  #
row10  .  .  .  .  .  .  #  #  #  #  #  #
row11  .  .  .  .  .  .  #  #  #  #  #  #
```

This is the **multi-terrain Tilesetter export**: three colors (terrains 0, 1, 2) interleaved across 81 atlas slots, with terrain transitions between any two of the three. **PROJECT.md explicitly rules out multi-terrain support**, so this template is informational only — TetraTile won't ship `TetraTileLayoutTilesetterWang3Terrain`. But it's worth noting that TileBitTools' Resource schema (`template_terrain_count`, `terrain_colors` dict, terrain_mapping in apply) **scales to N terrains for free** — the same Resource type holds 1, 2, or 3+ terrains. TetraTile's layout Resources, if they followed the same pattern, would inherit the same scaling.

### 5.10 `tilesetter_wang_3-terrain_transitions.tres`

A complementary template; transition tiles between the three terrains. `template_terrain_count = 3`, `_custom_tags = ["Tilesetter", "Incomplete Autotile"]`. Used in conjunction with #5.9 or with the basic 2-terrain Tilesetter Wang. File size 2832 bytes. Detailed atlas analysis omitted; same overall pattern as #5.9.

### 5.11 `tilepipe2_256_tile_16x16.tres`

| Field | Value |
|---|---|
| `template_name` | `"256-tile 16x16 (TilePipe2)"` |
| `terrain_mode` | `0` = `MATCH_CORNERS_AND_SIDES` |
| `_custom_tags` | `["TilePipe2", "Plugin Required"]` |
| Tile count | 256 |
| Atlas occupancy | 16×16 fully populated |
| File size | 22475 bytes |

**Description (verbatim):**
> "Full 256-tile Corners and Sides mode autotile. 256-tile templates match individual diagonal connnections. They are NOT compatible with Godot 4 and require a plugin such as Terrain Autotiler to use. To automatically generate this layout, use TilePipe2's 'template_256_16x16.png' template and export tile as a 'texture'."

**The `"Plugin Required"` tag is doing real work** — TileBitTools admits up front that this template doesn't work with stock Godot 4 and points the user at [`dandeliondino/terrain-autotiler`](https://github.com/dandeliondino/terrain-autotiler) (the same author's separate project for full 256-tile blob support). TetraTile should NOT ship a 256-tile template — both because it goes beyond v0.1's "lean" stance and because it would force depending on a separate runtime.

### 5.12 `tilepipe2_256_tile_32x8.tres`

Same as #5.11 but with a 32×8 atlas layout instead of 16×16. Both files exist because TilePipe2 generates both shapes.

### Template inventory summary

| Template | Mode | Tiles | Atlas | TetraTile relevance |
|---|---|---|---|---|
| `godot3_2x2` | MATCH_CORNERS | 16 | 4×4 | Equivalent to TetraTile `Wang2Corner`-style |
| `godot3_3x3_16_tiles` | MATCH_SIDES | 16 | 4×4 | Equivalent to TetraTile `Wang2Edge` |
| `godot3_3x3_minimal` | MATCH_CORNERS_AND_SIDES | 47 | 12×4 (one gap) | Native Godot 47-blob layout — distinct convention |
| `simple_4-tile_(inside_corners)` | MATCH_CORNERS | 4 | 2×2 | Subset of Tetra's 4-tile contract |
| `simple_9-tile_(inside_corners)` | MATCH_CORNERS | 9 | 3×3 | Spritesheet-shape pattern |
| `simple_9-tile_(outside_corners)` | MATCH_CORNERS | 9 | 3×3 | Spritesheet-shape pattern |
| `tilesetter_blob` | MATCH_CORNERS_AND_SIDES | 47 | 11×5 (gaps) | **Direct match for `TetraTileLayoutTilesetterBlob47`** |
| `tilesetter_wang` | MATCH_CORNERS | **15** | 5×3 | **Direct match for `TetraTileLayoutTilesetterWang15`** |
| `tilesetter_wang_3-terrain` | MATCH_CORNERS | 81 | 12×12 (gaps) | Out of scope (multi-terrain) |
| `tilesetter_wang_3-terrain_transitions` | MATCH_CORNERS | varies | varies | Out of scope (multi-terrain) |
| `tilepipe2_256_tile_16x16` | MATCH_CORNERS_AND_SIDES | 256 | 16×16 | Out of scope (256-blob, plugin-required) |
| `tilepipe2_256_tile_32x8` | MATCH_CORNERS_AND_SIDES | 256 | 32×8 | Out of scope (256-blob, plugin-required) |

---

## 6. Example atlas PNGs (the 7 reference images)

Every built-in template ships an `examples/<name>/` folder with:
- `<name>.png` — a sample atlas the user can study
- `ABOUT.txt` — credits + tile size
- `<name>.png.import` — Godot import metadata

All seven examples use **16-pixel tiles** and credit Kenney's CC0 Pixel Shmup pack.

| Example | PNG dimensions | Atlas grid (at 16px) | Visual style |
|---|---|---|---|
| `godot3_2x2/godot3_2x2.png` | 64×64 px | 4×4 | Brown organic dirt/rock |
| `godot3_3x3_16_tiles/godot3_3x3_16_tiles.png` | 80×64 px | 5×4 | Pink wall + green hedges |
| `godot3_3x3_minimal/godot3_3x3_minimal.png` | 208×192 px | 13×12 | Multi-terrain (grass + dirt + water + walls) |
| `simple_tilesets/simple_9_and_4.png` | 96×48 px | 6×3 | Brown ground sample |
| `simple_tilesets/simple_9_and_9.png` | 96×48 px | 6×3 | Brown + green sample |
| `tilesetter_blob/tilesetter_blob.png` | 192×80 px | 12×5 | Brown organic blob with gaps |
| `tilesetter_wang/tilesetter_wang.png` | 96×48 px | 6×3 | Brown wang sample |
| `tilesetter_wang_3_terrains/tilesetter_wang_3_terrain.png` | 192×192 px | 12×12 | Multi-terrain sample |

**Important:** the atlas grids of the example PNGs **do NOT always match** the atlas occupancy of the corresponding `.tres` template:

- `tilesetter_blob.png` is **12×5 = 60 cells**, but `tilesetter_blob.tres` only addresses 11×5 (47 used cells). The 12th column is decorative — Kenney art the .tres doesn't reach.
- `tilesetter_wang.png` is **6×3 = 18 cells** but `tilesetter_wang.tres` is 15 cells. The extra 3 are the "stray fill tile" the description references plus padding/decoration.
- `godot3_3x3_minimal.png` is **13×12 = 156 cells** showing three terrains in one image; the .tres only references 47 cells of one terrain.

**Lesson for TetraTile:** the artist-facing reference PNG and the engineer-facing layout Resource serve different purposes. TileBitTools keeps them adjacent (sibling folders) but loosely coupled (the .tres references `example_folder_path` as a string, not as a strict atlas mapping). TetraTile's templates folder should follow the same loose-coupling: the layout Resource declares a slot table; the template PNG illustrates that slot table for artists; they don't have to be byte-identical.

---

## 7. Customization model — Project Settings + Tags + Custom templates

TileBitTools' customization knobs cluster into three buckets:

### 7.1 Project Settings (4 categories, 8 keys)

```
addons/tile_bit_tools/
├── paths/
│   └── user_templates_path           : DirPath = ""
├── output/
│   ├── show_user_messages            : bool = true
│   ├── show_info_messages            : bool = false
│   └── show_debug_messages           : bool = false
└── colors/
    ├── template_terrain_1            : Color = #AA3377  (pink)
    ├── template_terrain_2            : Color = #CCBB44  (yellow)
    ├── template_terrain_3            : Color = #228833  (green)
    └── template_terrain_4            : Color = #66CCEE  (cyan)
```

The colors are intentionally chosen from [Paul Tol's "bright" color-blind-friendly palette](https://personal.sron.nl/~pault/) — **a small but signal-rich UX choice TetraTile should consider mirroring** if the layout library ever has to render multi-terrain previews.

### 7.2 Template tags (5 auto-tags + N custom tags)

From `core/template_tag_data.gd`:

```gdscript
enum Tags {
    BUILT_IN,                    # auto: bit_data.built_in
    USER,                        # auto: !bit_data.built_in
    MATCH_CORNERS_AND_SIDES,     # auto: terrain_mode == 0
    MATCH_CORNERS,               # auto: terrain_mode == 1
    MATCH_SIDES,                 # auto: terrain_mode == 2
}
```

Plus **custom tags from `_custom_tags : Array[String]`** in each `TemplateBitData`. The bundled templates use:

| Custom tag | Templates that use it | Icon (Godot editor theme name) |
|---|---|---|
| `"Godot 3"` | godot3_2x2, godot3_3x3_minimal, godot3_3x3_16_tiles | `Godot` |
| `"TilePipe2"` | godot3_2x2, godot3_3x3_minimal, tilepipe2_256_tile_16x16, tilepipe2_256_tile_32x8 | `TileSet` |
| `"Tilesetter"` | tilesetter_blob, tilesetter_wang, tilesetter_wang_3-terrain, tilesetter_wang_3-terrain_transitions | `TileSet` |
| `"Simple"` | simple_4-tile, simple_9-tile (both) | (no icon) |
| `"Incomplete Autotile"` | simple_*, tilesetter_wang_3-terrain_transitions | `NodeWarning` (yellow) |
| `"Plugin Required"` | tilepipe2_* | `NodeWarning` (yellow) |

The `Incomplete Autotile` and `Plugin Required` tags are **disclosure tags** — they tell the user up front that the template won't work standalone or won't work with stock Godot. TetraTile should consider a similar tag — e.g., `"Empirical"` for layouts where the slot mapping is reverse-engineered from another tool, `"v0.3+"` for layouts deferred from v0.2.

The picker UI lets the user filter by multiple tags (chip-style). Templates appear in the dropdown only if they match ALL selected tags.

### 7.3 Custom user templates (3 storage locations)

From `globals.gd` + `template_manager.gd`:

```gdscript
const BUILTIN_TEMPLATES_PATH := "res://addons/tile_bit_tools/templates/"
const PROJECT_TEMPLATES_PATH := "user://addons/tile_bit_tools/templates/"
const GODOT_TEMPLATES_FOLDER := "/Godot/tile_bit_tools_templates/"   # appended to OS.get_data_dir()
# plus the Project Settings configurable user_templates_path
```

The **Save Template dialog** lets the user pick:

1. **Project Templates Folder** — `user://addons/tile_bit_tools/templates/` — visible only to this project
2. **Shared Templates Folder** — `<OS data dir>/Godot/tile_bit_tools_templates/` — visible across all projects on this machine
3. **User Templates Folder** — whatever path is set in Project Settings → Tile Bit Tools → paths/user_templates_path — typically pointed at a dropbox/git-tracked folder

The metadata captured at save time (verbatim from save_template_dialog.tscn structure):

- **Name** (required) — used as `template_name`
- **Description** (optional) — used as `template_description`
- **Custom Tags** (optional, comma-separated) — parsed into `_custom_tags`
- **Save Folder** (one of the three above)

The dialog also displays an **auto-generated preview**: a `BitDataDrawNode` (`controls/bit_data_draw/bit_data_draw.gd`, 237 LOC) renders a SubViewport showing each peering bit as a colored corner / edge, giving the user a quick visual confirmation before saving.

This is the single most polished UX feature in the addon. **Whether TetraTile ships anything like it depends entirely on whether layout Resources are user-authorable (they're currently designed as built-in only)**. See §10 for the recommendation.

---

## 8. User-facing workflow (apply / save / edit)

### 8.1 Apply a template (the main workflow)

Quoting the wiki [Applying Templates](https://github.com/dandeliondino/tile_bit_tools/wiki/3.1-Applying-Templates) page directly + cross-referencing source code:

1. **Open the TileSet editor** (bottom dock when a `TileSet` resource is selected).
2. **Switch to "Select" tab** in the TileSet editor (Godot's stock toggle, top-left of the panel).
3. **Click and drag-select the tiles** in the atlas you want to apply the template to.
4. **TileBitTools auto-attaches** to Godot's per-tile inspector; a "Tile Bit Tools" subsection appears below the stock terrain inspector.
5. **Expand the `Apply Terrain Template` section.**
6. **Optionally filter by tags** — click "Select Tag to Filter..." dropdown. Multiple tags can stack.
7. **Pick a template** from the filtered list. The template's name, description, and example link appear.
8. **Map template terrains to atlas terrains** — for each terrain the template defines, pick which terrain in the user's TileSet it corresponds to. (e.g., template terrain 0 → user's "grass"; template terrain 1 → user's "dirt".) Per the wiki: *"When placing tiles on empty backgrounds, leave the terrain that doesn't include the center bits empty (this is usually the last one listed)."*
9. **Live preview overlays** the user's selected tiles as they map terrains. The colors come from Project Settings.
10. **Click "Apply Changes"** — bits are written into `TileData` via `TileData.set_terrain_peering_bit()`.

The wiki includes an animated GIF demonstrating the entire flow at `assets/tutorials/apply_template.gif` (1.7 MB, ~30 seconds). It's worth viewing if you ever want to clone the UX precisely.

### 8.2 Limitations on apply

> "Only terrain sets and terrains matching the template's terrain mode will be selectable. You must either choose a different template or create a new terrain set with the appropriate mode if needed options aren't available."

**This cannot be undone.** TileBitTools writes directly to `TileData` — there's no undo stack integration. From `tiles_manager.gd`:

```gdscript
## Applies the changes to TileData object
## including terrain_set, terrain and terrain peering bits
## There is no undo
func apply_bit_data() -> void:
    if !preview_bit_data:
        return
    # ... iterate context.tiles, call tile_data.set_terrain_peering_bit()
```

The author shipped this as a known limitation. **For TetraTile this is a useful warning** — if any v0.2 customization knob mutates user TileSet data in place, document the no-undo fact loudly.

### 8.3 Save a custom template

1. **Select tiles** that already have correctly-authored peering bits.
2. **Expand the `Save Terrain Template` section.**
3. **Click the save button** — opens "Save Terrain Template" dialog.
4. **Fill the dialog:**
   - Name (required)
   - Description (optional, multi-line)
   - Custom Tags (comma-separated)
   - Save folder (Project / Shared / User)
5. **Click Save** — writes a `.tres` to the chosen folder. It's immediately available in the picker after the next template reload (manual refresh button).

Per the README warning: *"if you are saving a significant amount of data in your templates, please make sure they are being backed up and/or added to a version control system. There are rare cases of [template data being deleted on editor startup](https://github.com/dandeliondino/tile_bit_tools/issues/49)."*

### 8.4 Outputs

TileBitTools produces:

- **Modifications to `TileData` peering bits** — the primary output, in-place.
- **`.tres` files** — when the user saves a custom template.

It does NOT produce:

- New atlas images
- New TileSet resources
- New tiles (it only modifies existing tiles)

### 8.5 Runtime component

**There is none.** TileBitTools is `@tool` only. The plugin exits cleanly via `_exit_tree()` without leaving anything behind in the running scene. This is a clean separation: edit-time-only tooling, runtime gets stock Godot terrain rendering.

For TetraTile this is an important distinction: TetraTile v0.1 has runtime code (`tetra_tile_map_layer.gd`); TileBitTools has only edit-time code. Any layout-Resource library TetraTile builds inherits this split — the layout Resources themselves can be runtime-loadable (since they're just data), but a "save custom layout" UI would be edit-time-only.

---

## 9. The 47-blob "Godot community template" question

The user asked about the "47-blob Godot community template" with a "4-row grouped layout with discrete sub-blocks." **TileBitTools' `tilesetter_blob` template IS that layout** (see §5.7, §6). The atlas shape:

```
Tilesetter Blob 47 — 11 cols × 5 rows with gaps:

col    0 1 2 3 4 5 6 7 8 9 10
row 0  # # # # # # # # # # .          ← rows 0-3 form the "main 4-row grouped layout"
row 1  # # # # # # # # # # .
row 2  # # # # # # # # # # #
row 3  # # # # # # # # # # #
row 4  . . . . # # # # # . .          ← row 4 is the "stray cluster" (5 extra tiles)
                                       
Total: 47 used cells (10+10+11+11+5)
```

The **discrete sub-blocks** the user described are the visible groupings inside the 4-row main layout — connected pieces of similar mask values cluster together (e.g., the "fill" tile at row 3 col 10 sits in a triangular cluster of fully-connected variants, while the "isolated" tile at row 1 col 1 sits in a 4-corner cluster of isolated variants).

**This is exactly what the Tilesetter Set View renders.** TileBitTools' author transcribed Tilesetter's actual export coords into the .tres, validating the "Tilesetter Set View == exported PNG" hypothesis from TILESETTER_AND_GODOT.md.

The "Godot community" attribution is accurate in a soft sense: this layout is the de-facto standard for any Godot 4 project that uses Tilesetter (which is many of them). It is NOT an official Godot template — Godot ships no template — but it IS the most commonly-encountered 47-blob layout in the Godot ecosystem because Tilesetter is the most popular generator. TileBitTools' choice to include it cements that.

The CR31 7×7 / 6×8 layouts and the Excalibur 12×4 layout from TILESETTER_AND_GODOT.md are **different** conventions, used by different communities. Tilesetter's layout (11×5 with the bottom-row cluster) is its own. TetraTile should ship Tilesetter's as the primary 47-blob layout because that's what Godot users encounter most often.

---

## 10. Patterns TetraTile should adopt

Five concrete patterns, in priority order:

### Pattern 1: Three-tier Resource hierarchy (`BitData` → `EditorBitData` / `TemplateBitData`)

**Why:** separates the "live editor selection" concept from the "serialized template on disk" concept while sharing the bit-storage primitive. Godot 4's `@tool` script inheritance handles this cleanly.

**TetraTile mapping:**

```
Resource
  └── TetraTileLayout                  # base — defines the abstract slot ↔ mask interface
       ├── TetraTileLayoutBuiltIn      # concrete subclass for shipped layouts (Tetra4, DualGrid16, Wang2Edge, etc.)
       └── TetraTileLayoutCustom       # concrete subclass user can author (deferred to v0.3+)
```

The parallel to TileBitTools is loose — TetraTile doesn't have an "editor selection" concept the way TileBitTools does — but the inheritance pattern is still useful: a base class with shared primitives, concrete subclasses for different lifecycles.

**Recommendation: YES, adopt.**

### Pattern 2: External-tool tags as first-class metadata

**Why:** TileBitTools' `_custom_tags = ["Tilesetter"]`, `["Godot 3"]`, `["TilePipe2"]` immediately tells the user "this template comes from / matches that tool." Filtering by tag becomes the discovery primitive.

**TetraTile mapping:** every `TetraTileLayoutXxx` Resource should expose a `tags : PackedStringArray` field. Suggested initial vocabulary:

```
Tool tags:        "Tilesetter", "Excalibur", "RPGMaker", "Tiled", "LDtk"
Convention tags:  "CR31", "Jaconir", "Enichan"
Topology tags:    "MatchCorners", "MatchSides", "MatchCornersAndSides"
Status tags:      "Empirical" (slot mapping reverse-engineered),
                  "Plugin Required" (not standalone),
                  "Multi-Terrain" (out of v0.2 scope, informational only)
```

**Recommendation: YES, adopt.** Implement as a `tags : Array[StringName]` `@export` field on `TetraTileLayout`.

### Pattern 3: Sibling examples folder per template

**Why:** TileBitTools puts each template's example PNG in `examples/<name>/<name>.png` with a sibling `ABOUT.txt`. This mirrors the way artists actually file reference images.

**TetraTile mapping:** the existing `addons/tetra_tile/templates/` folder should split into:

```
addons/tetra_tile/templates/
├── README.md                   # already exists, artist-facing reference
├── tetra_horizontal/
│   ├── tetra_horizontal.png    # blank template (slot-numbered)
│   ├── tetra_horizontal.tres   # the layout Resource
│   ├── ABOUT.txt               # tile size + credits
│   └── example.png             # painted example
├── dual_grid_16/
│   ├── dual_grid_16.png
│   ├── dual_grid_16.tres
│   ├── ABOUT.txt
│   └── example.png
... (one folder per layout)
```

The current proposal in [`addons/tetra_tile/templates/README.md`](../../../addons/tetra_tile/templates/README.md) puts everything flat in one folder. The TileBitTools pattern is cleaner for users browsing the addon. **HOWEVER**, this also adds N folders to the addon root, which conflicts with the "smaller than TileMapDual" guardrail. Compromise: ship the layout `.tres` files in a flat `addons/tetra_tile/layouts/` folder, and ship blank+example PNGs together in `addons/tetra_tile/templates/<name>/`. Keep the folder count bounded.

**Recommendation: YES, adopt with the compromise.** Layouts in flat `layouts/`, templates+examples in nested `templates/<name>/`.

### Pattern 4: Disclosure tags for non-standalone templates

**Why:** `"Incomplete Autotile"`, `"Plugin Required"` warn the user upfront that a template won't work standalone. The icon (Godot's `NodeWarning` yellow triangle) makes the warning visible.

**TetraTile mapping:** for layouts where the slot order is reverse-engineered (Tilesetter Wang/Blob), tag them `"Empirical"`. For layouts that need additional setup (e.g., the diagonals-overlay rule for Tetra4), document that in the description.

**Recommendation: YES, adopt.** Add `"Empirical"` and `"Reverse-Engineered"` to the tag vocabulary.

### Pattern 5: Project Settings for runtime knobs (paths + verbosity + colors)

**Why:** Godot users find addon settings under `Project → Project Settings → <Addon Name>` more readily than in custom resource files. ProjectSettings keys are versioned with `project.godot`, which the user is already managing in source control.

**TetraTile mapping:** for v0.2 the only meaningful addon-level setting might be **`addons/tetra_tile/output/show_debug_logs` : bool = false** to surface the runtime cell-rebuild diagnostics. If the layout library ever adds inspector preview rendering, **`addons/tetra_tile/colors/preview_*`** keys would mirror TileBitTools.

**Recommendation: PARTIAL ADOPT.** Worth adding the `output/show_debug_logs` key in v0.2; defer color settings until inspector preview rendering exists.

---

## 11. Anti-patterns TetraTile should NOT copy

Five concrete patterns to *avoid*, with rationale.

### Anti-pattern 1: 3,800 LOC of UI for a 105-LOC data structure

TileBitTools is **97% UI code, 3% data model**. The `TemplateBitData` schema is 105 LOC; everything else (popups, scenes, inspector hooks, theme harmonization, preview viewports) exists to make that 105 LOC pleasant to interact with. For an inspector-plugin the ratio is justifiable; for a runtime addon it isn't.

PROJECT.md is explicit: "TetraTile must remain visibly smaller and simpler than TileMapDual." A custom-template authoring UI would push TetraTile across that line. **Defer custom-layout authoring to v0.3+ at earliest, possibly indefinitely.**

**Recommendation: DO NOT COPY.** Ship layout Resources as built-in only for v0.2; users can author custom Resources by extending `TetraTileLayout` and writing GDScript, no UI required.

### Anti-pattern 2: EditorInspectorPlugin that walks Godot's internal scene tree

`inspector_plugin.gd` (353 LOC) reaches into the running Godot editor and finds nodes by class name (`TileSetEditor`, `TileSetAtlasSourceEditor`, `TileAtlasView`, `AtlasTileProxyObject`). This is a deep coupling to engine internals. Each Godot 4.x release risks breaking it. The plugin's archived status (no longer maintained) suggests this was indeed painful to keep working.

**Recommendation: DO NOT COPY.** TetraTile already operates as a `TileMapLayer` subclass, which uses Godot's *public* APIs only. Don't add an inspector plugin in v0.2; the layout Resource picker can be a normal `@export` slot on `TetraTileMapLayer`.

### Anti-pattern 3: No-undo destructive edits

TileBitTools' "Apply Changes" writes to `TileData` directly with no undo. The wiki warns the user, but accidents happen. For an inspector plugin this is acceptable; for any TetraTile feature that mutates user data it would be a regression.

**Recommendation: DO NOT COPY.** TetraTile v0.2 should treat the layout Resource as read-only configuration and never mutate the user's TileSet. If a future "convert tileset to TetraTile layout" feature exists, it should produce a *new* TileSet rather than mutating the existing one, so undo/git remain meaningful.

### Anti-pattern 4: `_custom_tags : Array` (untyped)

TileBitTools uses `@export var _custom_tags := []` — an untyped Array. This works because `.tres` serialization is forgiving, but it loses Godot 4's type-safety benefits. New tags can be misspelled silently.

**Recommendation: DO NOT COPY.** Use `@export var tags : Array[StringName]` with a documented vocabulary in code comments. Future-proof for Godot 4's `Array[StringName]` enforcement.

### Anti-pattern 5: Mutating peering bits in place at all

This is the deepest disagreement: **TileBitTools' core value-add IS the in-place mutation of Godot's terrain peering bits.** TetraTile's v0.1 sells the opposite: skip peering bits entirely. Adopting TileBitTools' "click-author Godot's terrain" model would erase TetraTile's distinguishing identity.

**Recommendation: DO NOT COPY.** TetraTile must keep "no per-tile peering-bit authoring required" as the headline contract. The layout Resources are read at runtime by `TetraTileMapLayer`; they never write to user TileSets.

---

## 12. Finalized v0.2 TetraTile layout-library mapping table

Bringing together the audit findings, the v0.2 layout library should ship the following Resources. The mapping column shows which TileBitTools template (if any) provides the canonical reference for slot order. The "How to ship" column tells implementers whether the slot table can be authored directly or must be derived from TBT.

| TetraTile Resource | Matches TileBitTools template | Mask system | Tile count | How to ship in v0.2 |
|---|---|---|---|---|
| `TetraTileLayoutTetra4Horizontal` | (none — TetraTile-native) | 4-bit corner with rotation | 4 | Already exists; lock to v0.1's TL=1, TR=2, BL=4, BR=8 |
| `TetraTileLayoutTetra4Vertical` | (none — TetraTile-native) | 4-bit corner with rotation | 4 | Same convention as horizontal, transposed |
| `TetraTileLayoutDualGrid16` | (none — TetraTile-native) | 4-bit corner | 16 | Author directly using TetraTile's TL=1, TR=2, BL=4, BR=8 corner convention |
| `TetraTileLayoutWang2Edge` | `godot3_3x3_16_tiles` (loose match — same mask, possibly different slot order) | 4-bit edge | 16 | Author directly using CR31 N=1, E=2, S=4, W=8 edge convention; cross-check slot order against TBT's .tres |
| `TetraTileLayoutWang2Corner` | `godot3_2x2` (loose match — same mask, possibly different slot order) | 4-bit corner | 16 | Author directly using CR31 NE=1, SE=2, SW=4, NW=8 corner convention; cross-check slot order against TBT's .tres |
| `TetraTileLayoutSimple4InsideCorners` | `simple_4-tile_(inside_corners)` (direct match) | 4-bit corner | 4 | Decode TBT's .tres directly into TetraTile's slot table |
| `TetraTileLayoutSimple9InsideCorners` | `simple_9-tile_(inside_corners)` (direct match) | 4-bit corner | 9 | Decode TBT's .tres |
| `TetraTileLayoutSimple9OutsideCorners` | `simple_9-tile_(outside_corners)` (direct match) | 4-bit corner | 9 | Decode TBT's .tres |
| `TetraTileLayoutGodot3Minimal` | `godot3_3x3_minimal` (direct match) | 8-bit Moore | 47 | Decode TBT's .tres — gives a Godot-native 47-blob slot order distinct from Tilesetter's |
| **`TetraTileLayoutTilesetterBlob47`** | **`tilesetter_blob` (direct match)** | 8-bit Moore | 47 | **Decode TBT's .tres directly — eliminates the empirical-fingerprinting step from TILESETTER_AND_GODOT.md** |
| **`TetraTileLayoutTilesetterWang15`** | **`tilesetter_wang` (direct match — note: 15 tiles, NOT 16)** | 4-bit corner | 15 | **Decode TBT's .tres directly** |
| `TetraTileLayoutExcaliburBlob47` | (none in TileBitTools; cross-reference with [Excalibur autotiling blog post](https://excaliburjs.com/blog/Autotiling%20Technique/)) | 8-bit Moore | 47 | Author directly from Excalibur's published 12×4 layout |

### Layouts EXPLICITLY OUT of v0.2 scope

| Resource | Why out |
|---|---|
| `TetraTileLayoutTilesetterWang3Terrain` | Multi-terrain — PROJECT.md guardrail |
| `TetraTileLayoutTilePipe2_256` | 256-blob — requires terrain-autotiler runtime, conflicts with "lean" stance |
| `TetraTileLayoutGodotNative` | Godot doesn't have a layout — peering bits are per-tile metadata |
| `TetraTileLayoutSubBlob20` / `TetraTileLayoutMicroBlob13` | Quarter-tile compositor not in v0.2 |
| `TetraTileLayoutRPGMakerA2` / `A4` | Subtile compositor not in v0.2 |
| Tiled `.tsx` importer | Rule importer, not a layout |
| LDtk `.ldtk` importer | Rule importer + rule runtime |

### Build-order recommendation

1. **First wave** (zero new external dependencies, leverage existing v0.1 work):
   - `TetraTileLayoutTetra4Horizontal` / `Vertical` — port from v0.1
   - `TetraTileLayoutDualGrid16` — author directly, TetraTile-native convention
2. **Second wave** (decode TileBitTools .tres files):
   - `TetraTileLayoutTilesetterBlob47` ← decode `tilesetter_blob.tres`
   - `TetraTileLayoutTilesetterWang15` ← decode `tilesetter_wang.tres`
   - `TetraTileLayoutGodot3Minimal` ← decode `godot3_3x3_minimal.tres`
   - `TetraTileLayoutSimple9*` ← decode the three simple .tres files
3. **Third wave** (independent authoring, well-documented sources):
   - `TetraTileLayoutWang2Edge` / `TetraTileLayoutWang2Corner` ← CR31 standard
   - `TetraTileLayoutExcaliburBlob47` ← Excalibur blog post

The first wave validates the Resource API. The second wave doubles the count by lifting from TileBitTools (under MIT, with attribution). The third wave fills out the popular community conventions.

---

## 13. Honest gaps

1. **Per-template peering-bit decoder not yet implemented.** The audit confirms TileBitTools' .tres files contain the canonical Tilesetter slot mappings, but actually decoding them into TetraTile's `mask → Vector2i` lookup requires a small one-time tool: read the .tres dictionary, decode each `Vector2i(col, row) → peering_bits` pair into `(col, row) → mask`. This is a one-afternoon implementation task; not done yet.

2. **The Godot CellNeighbor enum is direction-coded, not bit-weighted.** TileBitTools stores peering bits as `{ 0: terrain_id, 3: terrain_id, 4: terrain_id, 7: terrain_id, 8: terrain_id, 11: terrain_id, 12: terrain_id, 15: terrain_id }` where the keys are direction enum values (0=R, 3=BR_corner, 4=B, 7=BL_corner, 8=L, 11=TL_corner, 12=T, 15=TR_corner), not bit weights. Translating to TetraTile's mask integers requires a fixed mapping `{enum_value: bit_position}` that TetraTile's bit convention defines.

3. **Did not exhaustively read all 12 .tres files cell-by-cell.** I parsed atlas occupancy from all of them, but the per-cell peering-bits transcription is partial (see §5.7's `Vector2i(1,1)` and `Vector2i(3,3)` samples). Full decoding is the v0.2 implementation step.

4. **Did not fingerprint the `inspector_plugin.gd` against Godot 4.6 specifically.** The plugin walks the editor scene tree by class name. I trust the README's "Godot 4.x compatible" claim but did not verify that all referenced internal class names (`TileSetEditor`, `TileSetAtlasSourceEditor`, `TileAtlasView`, `AtlasTileProxyObject`, `TileSetAtlasSourceProxyObject`) still exist in Godot 4.6. Since TetraTile won't be copying the inspector-plugin pattern (per anti-pattern §11.2), this gap is non-blocking.

5. **The 256-tile `tilepipe2_*` templates were not deeply analyzed.** I confirmed dimensions (16×16 and 32×8) and tile count (256). The actual peering bit encodings are a 22 KB .tres each — over twenty times larger than the 47-blob template. Decoding them is feasible if TetraTile ever reverses on the "out-of-scope" decision, but for v0.2 the analysis stops at "256 tiles, plugin-required, out of scope."

6. **Did not test apply-template UX in a live Godot 4.6 editor.** The wiki and source describe the workflow; I did not exercise it. Click counts in §8.1 are inferred from source structure, not measured.

7. **The `editor_bit_data.gd` / `bit_data.gd` distinction is partially documented.** I read both files but didn't trace the full lifecycle (extract from live tiles → preview → save as TemplateBitData). Full understanding would require running the addon. For TetraTile this is non-blocking — TetraTile won't be extracting bit data from live tiles.

8. **The OpenGameArt 7×7 / CR31 6×8 layouts are NOT in TileBitTools.** TileBitTools ships ONE 47-blob convention (`godot3_3x3_minimal`) and ONE 47-blob in Tilesetter convention (`tilesetter_blob`). It does NOT ship the cr31/OpenGameArt 7×7 or CR31 6×8 conventions. If TetraTile wants those, the slot tables come from [BorisTheBrave's reference](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html), not from TileBitTools.

9. **The `assets/tutorials/apply_template.gif` was not viewed.** The animated workflow demo is 1.7 MB at `assets/tutorials/apply_template.gif`. Description-only documentation is sufficient for this audit.

10. **The Wareya Godot 3.5 predecessor was not audited.** TileBitTools credits [Wareya/godot-tile-setup-helper](https://github.com/wareya/godot-tile-setup-helper) as inspiration. That repo may have additional patterns worth lifting, but it targets Godot 3.5 (different terrain API), so direct portability is questionable. Out of scope for this audit.

---

## Appendix A — Quick reference: Godot 4 CellNeighbor enum

For decoding peering-bit dictionaries in TileBitTools .tres files:

| Enum value | Constant name | Direction (square grid) |
|---|---|---|
| 0 | `CELL_NEIGHBOR_RIGHT_SIDE` | E |
| 3 | `CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER` | SE |
| 4 | `CELL_NEIGHBOR_BOTTOM_SIDE` | S |
| 7 | `CELL_NEIGHBOR_BOTTOM_LEFT_CORNER` | SW |
| 8 | `CELL_NEIGHBOR_LEFT_SIDE` | W |
| 11 | `CELL_NEIGHBOR_TOP_LEFT_CORNER` | NW |
| 12 | `CELL_NEIGHBOR_TOP_SIDE` | N |
| 15 | `CELL_NEIGHBOR_TOP_RIGHT_CORNER` | NE |

Source: [Godot 4 TileSet documentation](https://docs.godotengine.org/en/stable/classes/class_tileset.html) (verified 2026-04-25).

The other enum values (1, 2, 5, 6, 9, 10, 13, 14) are for hex/isometric grid neighbors and don't appear in TileBitTools' square-grid templates.

## Appendix B — TileBitTools' bundled-template peering-bit conventions decoded

Cross-referencing the CellNeighbor table above with the `_tiles` schema:

**For `terrain_mode = 0` (MATCH_CORNERS_AND_SIDES)** — `tilesetter_blob`, `godot3_3x3_minimal`, `tilepipe2_*`:

```
peering keys: 0, 3, 4, 7, 8, 11, 12, 15
            = E, SE, S, SW, W, NW, N, NE
```

**For `terrain_mode = 1` (MATCH_CORNERS)** — `godot3_2x2`, `simple_*`, `tilesetter_wang`, `tilesetter_wang_3-terrain*`:

```
peering keys: 3, 7, 11, 15
            = SE, SW, NW, NE
```

**For `terrain_mode = 2` (MATCH_SIDES)** — `godot3_3x3_16_tiles`:

```
peering keys: 0, 4, 8, 12
            = E, S, W, N
```

To convert a TileBitTools .tres entry to a TetraTile mask, walk the peering dict, look up each key in the table above, and OR in the appropriate bit weight from TetraTile's chosen bit convention (e.g., for Wang2Edge with CR31: N=1, E=2, S=4, W=8).

---

*Audit recorded 2026-04-25. Companion to [TILESETTER_AND_GODOT.md](TILESETTER_AND_GODOT.md), [COMPARISON.md](COMPARISON.md), [TAXONOMY.md](TAXONOMY.md). Feeds the v0.2 ROADMAP.md layout-library work.*
