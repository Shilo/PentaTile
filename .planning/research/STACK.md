# Stack Research

**Domain:** Godot 4.6 dual-grid autotiling addon — atlas-contract redesign
**Researched:** 2026-04-25
**Confidence:** HIGH (Godot 4.6 API surface verified via Context7 `/websites/godotengine_en_4_6` and direct fetches from `docs.godotengine.org/en/4.6`)

> Scope: this milestone (v0.2.0) expands the atlas contract to support Y-axis variation, top tiles, and non-rotating tilesets, while keeping TetraTile leaner than TileMapDual. The "stack" here is mostly Godot 4.6 internals — there are no third-party libraries to choose. The interesting decisions are which Godot APIs to ride and which authoring surfaces to expose.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Godot Engine | 4.6.x stable | Host engine | Already the project's hard requirement. 4.6 ships `TileMapLayer` with the stable `_update_cells(coords, forced_cleanup)` virtual override the addon already rides. No 4.5→4.6 breaking changes affecting our hooks were found in the upgrade guide. |
| GDScript | 2 (4.6) | All addon code | `@tool`, `class_name`, typed arrays (`Array[Vector2i]`), strongly-typed `Resource` subclasses, and `@export_group`/`@export_subgroup` give us all the inspector surface we need. Sticks to project constraint: no C#, no GDExtension. |
| `TileMapLayer` | Godot 4.6 native | Logic layer + 2 internal visual layers | The native API the user paints with. `set_cell(coords, source_id, atlas_coords, alternative_tile)` is the single ingress; `_update_cells()` is the single egress. Continuing to ride it is a milestone constraint. |
| `TileSetAtlasSource` | Godot 4.6 native | Atlas tiles + alternative tiles + transforms | The `alternative_tile` parameter on `set_cell()` is the **one** channel we have to encode both rotation (via `TRANSFORM_FLIP_H \| TRANSFORM_FLIP_V \| TRANSFORM_TRANSPOSE` flags) and Y-axis variation (via real alternative IDs). They combine via bitwise OR. v0.1.0 already uses this for rotation; v0.2.0 extends it for variation. |
| `TileData` | Godot 4.6 native | Per-(tile, alternative) metadata | Hosts `probability: float` (default `1.0`, "Relative probability of this tile being selected when drawing a pattern of random tiles") and the user's custom data layers. This is where TetraTile reads variation weights from at `_update_cells()` time. |
| Native `Resource` subclassing | Godot 4.6 GDScript | "Atlas contract" data shape | A single `class_name TetraTileAtlasContract extends Resource` exported on the node lets the user describe what the atlas contains in the inspector, without reaching for `EditorInspectorPlugin` polish. This is the key shape change vs v0.1.0's strict 4-tile assumption. |

### Supporting Libraries

There are no third-party libraries in scope. Everything is built from Godot's stdlib.

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `RandomNumberGenerator` | Godot 4.6 native | Deterministic per-cell variation | When picking alternative tiles for variation. Seed from cell coords (`hash(Vector2i(x, y))`) so variation is stable across `_update_cells()` invocations on the same cell — otherwise dragging through a tile would flicker the variation each frame. |
| `EditorInspectorPlugin` | Godot 4.6 native | (Defer) custom inspector widgets | **Do NOT use this milestone.** A standard `@export var atlas_contract: TetraTileAtlasContract` plus `@export_group` annotations on the contract Resource gives the user every knob they need (rotation lock, variation rules, slot enable/disable) without writing or maintaining a custom inspector. EditorInspectorPlugin is the right tool when you need to render bespoke UI for a value type — not when you just need grouped, typed exports. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Godot Editor 4.6.2 | Authoring + live preview | The `@tool` annotation on `TetraTileMapLayer` already makes the contract rebuild in-editor. Keep it. |
| Built-in TileSet editor | Authoring alternatives + probability | Variation authoring stays in Godot's existing TileSet editor: right-click base tile → "Create an Alternative Tile" → set `probability` in the inspector. TetraTile reads those probabilities at runtime; we add **no** custom variation UI. |
| GitHub Releases | Distribution | Single artifact per tag: `tetra_tile-vX.Y.Z.zip` containing an `addons/tetra_tile/` folder at archive root (per Godot's "Installing plugins" docs: extract the ZIP, move the `addons/` folder into the project). |
| Git tags | Versioning | `vX.Y.Z` simple semver — no `-pre`, `-alpha`, `-dev` suffixes per project constraint. Bump `addons/tetra_tile/plugin.cfg`'s `version` field in the same commit as the tag. |

## Installation

No external packages — everything ships in Godot 4.6.

```bash
# No npm / pip / cargo install. Addon dependencies are only:
#   - Godot 4.6.x stable (already a project constraint)
#   - The addons/tetra_tile/ folder (already in this repo)
```

## API Surface — Verified Signatures (Godot 4.6)

These are the exact signatures the milestone implementation must call. All verified against
`docs.godotengine.org/en/4.6/classes/...` directly (HIGH confidence).

```gdscript
# TileMapLayer (the override we ride)
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void
# coords: cells modified since last update, "roughly in the order they were modified"
# forced_cleanup: true when the layer is disabled, not visible, tile_set is null,
#                 the node is removed from the tree, or the node is freed.

# TileMapLayer (the only paint API we use)
func set_cell(coords: Vector2i, source_id: int = -1,
              atlas_coords: Vector2i = Vector2i(-1, -1),
              alternative_tile: int = 0) -> void
# alternative_tile is a SINGLE int: lower bits = real alt ID,
# upper bits OR'd with TileSetAtlasSource.TRANSFORM_FLIP_H (4096),
# TRANSFORM_FLIP_V (8192), TRANSFORM_TRANSPOSE (16384).

func get_cell_alternative_tile(coords: Vector2i) -> int
func get_cell_tile_data(coords: Vector2i) -> TileData  # null if cell empty / not atlas

# TileSetAtlasSource (alternative-tile management)
func create_alternative_tile(atlas_coords: Vector2i,
                             alternative_id_override: int = -1) -> int
func get_next_alternative_tile_id(atlas_coords: Vector2i) -> int
func get_tile_data(atlas_coords: Vector2i, alternative_tile: int) -> TileData
func remove_alternative_tile(atlas_coords: Vector2i, alternative_tile: int) -> void

# Note: there is NO get_alternative_tiles_count(). To enumerate alternatives, scan IDs
# starting from 1 and call get_tile_data() on each, stopping when it returns null,
# OR iterate up to get_next_alternative_tile_id() - 1.

# TileData (per-(tile, alt) metadata)
var probability: float           # default 1.0
var modulate: Color
var flip_h: bool                 # bake-time, not the runtime transform flags
var flip_v: bool
var transpose: bool
func get_custom_data(layer_name: String) -> Variant
func set_custom_data(layer_name: String, value: Variant) -> void

# TileSet (custom data layers — for per-tile metadata that drives our contract)
func add_custom_data_layer(to_position: int = -1) -> void
func set_custom_data_layer_name(layer_index: int, layer_name: String) -> void
func set_custom_data_layer_type(layer_index: int, layer_type: Variant.Type) -> void
func get_custom_data_layer_by_name(layer_name: String) -> int
func has_custom_data_layer_by_name(layer_name: String) -> bool
```

### Critical Behavior Note: Probability Is Editor-Paint-Only

Godot's `TileData.probability` is consumed by the editor's **scattering / random-tile paint
tool** when the user has multiple tiles selected and randomization enabled. **It is NOT
applied automatically at render time when `set_cell()` is called with a specific
alternative_tile**. The official tutorial confirms scattering "is taken into account"
only by the Paint, Line, Rectangle, and Bucket Fill tools — and "Eraser mode does not
take randomization and scattering into account."

This has a load-bearing implication for TetraTile: **we must run the weighted-RNG
ourselves** inside `_update_cells()` when picking an alternative for a Y-variant.
Reading `probability` off each alternate's `TileData` is the right input — Godot already
authors it in the inspector — but TetraTile does the actual selection. This keeps us
aligned with the engine's authoring UX (no custom variation inspector) while honoring the
mandate to "ride Godot's built-in TileSetAtlasSource alternate-tile probability."

Confidence: HIGH on the editor-only behavior of scattering (`tutorials/2d/using_tilemaps.html`).
HIGH on `set_cell()` not auto-randomizing (signature takes a specific `alternative_tile: int`).

## Recommended Architecture for the Atlas Contract

> Detailed structure decisions belong in `ARCHITECTURE.md`. The stack-level recommendation:

**Use a strongly-typed `Resource` subclass, not custom data layers, for the contract itself.**

```gdscript
# addons/tetra_tile/tetra_tile_atlas_contract.gd
@tool
class_name TetraTileAtlasContract
extends Resource

enum AtlasLayout { HORIZONTAL, VERTICAL, GRID }
enum SymmetryMode { ROTATIONAL, NON_ROTATING }

@export_group("Source")
@export var atlas_source_id: int = -1
@export var atlas_layout: AtlasLayout = AtlasLayout.HORIZONTAL

@export_group("Symmetry")
@export var symmetry_mode: SymmetryMode = SymmetryMode.ROTATIONAL
# When NON_ROTATING, the contract declares per-direction slots
# (top/bottom/left/right) instead of a single rotated slot.

@export_group("Slots")
@export var slots: Array[TetraTileSlot] = []
# Each slot declares: role (Fill / InnerCorner / Border / OuterCorner / TopBorder / ...),
# atlas_coords, allow_rotation, allow_y_variation, top_tile flag.
```

`TetraTileSlot` is itself a `Resource` subclass exported as `Array[TetraTileSlot]`,
which Godot 4.6 renders as an inline editable list in the inspector with no custom
inspector code required. This is the idiomatic GDScript-2 way to do "declare what
you have" — verified in
`tutorials/scripting/gdscript/gdscript_exports.html`.

**Use TileSet custom data layers for per-tile flags that the user authors in the
TileSet editor** (e.g. "is_top_tile", "lock_rotation"). This lets users tag tiles
inside Godot's existing TileSet UI rather than the contract Resource. The two
mechanisms are complementary, not competing: the contract describes the atlas
**shape**; custom data layers describe **per-tile semantics** that the contract
doesn't need to enumerate.

Confidence: HIGH (both `Array[Resource]` exports and `TileSet.add_custom_data_layer` are
documented 4.6 APIs).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `Array[TetraTileSlot]` Resource subclass for the contract | Use only `TileSet` custom data layers, no contract Resource | If we wanted **zero** addon-side schema and to push everything into the TileSet inspector. Rejected because slot ordering, the symmetry mode, and atlas layout are addon-shape concerns that don't belong on per-tile data. |
| `Array[TetraTileSlot]` Resource subclass | `Dictionary` with string keys | If we wanted dynamic schemas. Rejected: typed Resources give inspector grouping, drag-and-drop reuse across scenes, and compile-time field checks. Dictionaries get none of that. |
| Manual weighted-RNG in `_update_cells()` driven by `TileData.probability` | Auto-create `TileSetAtlasSource` animation frames for variation | Animation frames cycle on a timer, not per-cell. They'd give every cell the same animated variation, defeating the purpose. Probability + RNG is the only path to spatial-only variation. |
| `@export var atlas_contract: TetraTileAtlasContract` | Custom `EditorInspectorPlugin` | Use a custom inspector if v0.3+ wants drag-to-reorder slot UI, atlas thumbnail previews, or "auto-import this PNG" buttons. Out of scope for v0.2.0 — explicitly so. |
| Continue riding `_update_cells(coords, forced_cleanup)` | Watch `tile_set.changed` and `tile_map.changed` signals | Rejected: the project's "lean" constraint forbids signal fanout / watcher infrastructure. `_update_cells` is the documented hook and already works. |
| Plain `set_cell()` with packed `alternative_tile` int | Two separate set_cell calls (one for transform, one for variant) | Not an option — `alternative_tile` is a single int. The bitwise composition (alt ID OR'd with TRANSFORM_* flags) is the only path. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| C# / GDExtension / native modules | Project constraint: pure GDScript only. Adds a build step and excludes pure-GDScript-only Godot users. | GDScript 2 with typed arrays and Resource subclasses. |
| Custom RNG library / addon | Godot ships `RandomNumberGenerator` and `@GlobalScope.randi()`/`randi_range()`. Pulling in a library adds dependency surface for a 5-line problem. | `var rng := RandomNumberGenerator.new(); rng.seed = hash(cell_coords)`. Seeded per-cell ensures stability across redraws. |
| `EditorInspectorPlugin` for v0.2.0 | Heavyweight: requires an EditorPlugin entrypoint (`script=` in `plugin.cfg`), `_can_handle()`, `_parse_property()`, custom controls. The v0.2.0 contract is just typed exports — no custom widgets needed. | Plain `@export`, `@export_group`, `@export_subgroup`, `@export_range`, `Array[Resource]`. |
| Asset Library submission | Out of scope per `PROJECT.md`. Polishing for AssetLib (icons, screenshots, descriptions per their guidelines) is wasted effort this milestone. | GitHub-only release. The `addons/tetra_tile/` folder at ZIP root is sufficient for `git clone` users and ZIP-download users alike. |
| `min_godot_version` / `compatibility_minimum` in `plugin.cfg` | Not a real `plugin.cfg` field. The proposal to add one (godotengine/godot-proposals#8653) is archived without a documented implementation. `compatibility_minimum` exists in `.gdextension` files, NOT `.cfg`. Putting it in `plugin.cfg` does nothing — Godot ignores unknown keys, so no error, but no enforcement either. | Document "Requires Godot 4.6+" in `README.md` and the GitHub release notes. Optionally `assert(Engine.get_version_info().minor >= 6)` in `_ready()` if we want a runtime guard. |
| `TileMap` (deprecated parent class) | Deprecated; multiple `TileMapLayer` nodes are the official replacement. v0.1.0 is already on `TileMapLayer` — keep it that way. | `TileMapLayer` (already in use). |
| `visible = false` to hide the logic layer | Triggers `_update_cells(_, forced_cleanup=true)`, wiping our visual layers. v0.1.0 already documents this gotcha. | `self_modulate.a = 0.0` (current solution). Document this in the contract Resource so users don't override it. |
| Reading `probability` and expecting Godot to apply it at render time | Probability is consumed only by the editor's scattering paint tool, never by `set_cell()` or `_update_cells()`. | Read `TileData.probability` for each alternate ourselves and run a weighted RNG seeded by cell coords. |

## Stack Patterns by Variant

**If the user authors a rotationally-symmetric atlas (the v0.1.0 case):**
- Use `symmetry_mode = ROTATIONAL`. Contract declares 4 slots (Fill, InnerCorner, Border, OuterCorner).
- Slot lookup at runtime: pick role from the 16-state mask table → look up `atlas_coords` from the slot → OR in the rotation flags.
- Y-variation: enumerate alternates of `(slot.atlas_coords, alt_id ≥ 1)`, weight by `TileData.probability`, OR the chosen alt ID into `alternative_tile`.

**If the user authors a non-rotating atlas (top tiles, platformer caps):**
- Use `symmetry_mode = NON_ROTATING`. Contract declares per-direction slots: `border_top`, `border_bottom`, `border_left`, `border_right`, plus the four corner variants.
- The 16-state mask table maps each state to a **directional** role rather than a rotation-parameterized role. No `TRANSFORM_*` flags applied to those slots.
- Diagonal masks (6 and 9) still composite via the overlay layer — but with the appropriate per-direction outer-corner sprite on each of the two layers, not the same sprite rotated.

**If the user wants both top-tile + Y-variation in one atlas:**
- They author two slots: `border_top` (with N alternates, varied probability) and `border_bottom` (different alternates if non-rotating, or "use border_top rotated 180°" if rotational).
- The contract supports this naturally because slots are independent rows in `Array[TetraTileSlot]`.

## Distribution Mechanics — Concrete

### `addons/tetra_tile/plugin.cfg` (current → v0.2.0 target)

The current file (verified):

```ini
[plugin]
name="TetraTile"
description="A lightweight dual-grid autotiling layer built around four atlas tiles."
author="Shilo"
version="0.1.0"
script=""
```

**Recommended v0.2.0 target:**

```ini
[plugin]
name="TetraTile"
description="A lightweight dual-grid autotiling layer for Godot 4.6 with declarative atlas contracts, Y-axis variation, and top-tile / non-rotating tileset support."
author="Shilo"
version="0.2.0"
script=""
```

Notes (HIGH confidence — verified in `tutorials/plugins/editor/making_plugins.html`):

- `script=""` (empty) is intentional. We have no `EditorPlugin` entrypoint because we don't need editor UI hooks — `TetraTileMapLayer` is a `@tool` Node, not an editor plugin. Setting `script=""` (empty) matches the v0.1.0 setup and is supported.
- The `version` field is a free-form string. Update it to match the git tag.
- Update the `description` to mention the new capabilities (variation, top tiles, non-rotating) so the GitHub mirror's plugin metadata reflects v0.2.0's value prop.
- Do NOT add `min_godot_version` / `compatibility_minimum` — not a real field for `plugin.cfg`. Document the requirement in README.

### Git Tag Flow

```bash
# 1. Bump version in plugin.cfg
# 2. Update CHANGELOG / release notes (if any)
# 3. Commit:
git commit -m "chore: bump to v0.2.0"
# 4. Tag (no -pre/-alpha/-dev suffixes per PROJECT.md constraint):
git tag -a v0.2.0 -m "TetraTile v0.2.0 — atlas contract redesign"
git push origin main --tags
# 5. Create GitHub Release from the tag, attach the ZIP artifact (below).
```

### Release Artifact Layout

The ZIP attached to the GitHub Release should look like this so users can extract and merge into their project's `addons/` directly (per Godot's "Installing plugins" docs):

```
tetra_tile-v0.2.0.zip
└── addons/
    └── tetra_tile/
        ├── plugin.cfg
        ├── tetra_tile_map_layer.gd
        ├── tetra_tile_atlas_contract.gd          # NEW v0.2.0
        ├── tetra_tile_slot.gd                    # NEW v0.2.0
        ├── tetra_tile_template.png
        └── demo/
            ├── demo_player.gd
            ├── tetra_tile_demo.tscn
            ├── tetra_tile_ground.png
            └── tetra_tile_ground.tres
```

Two practical notes:
1. The repo's `addons/tetra_tile/` is already shaped this way — so the release ZIP is just a packaged copy of that folder under an `addons/` parent.
2. Excluding `demo/` from the ZIP is an option for "library-only" releases. For TetraTile (private audience, demo is the main usage doc), **include** the demo. v0.3+ can revisit if the demo grows large.

### Suggested Release Notes Template

```markdown
# TetraTile v0.2.0

**Requires:** Godot 4.6+

## What's New
- Atlas contract redesign — declare-what-you-have model via `TetraTileAtlasContract` resource
- Y-axis variation using Godot's native `TileData.probability`
- Top-tile support for platformer-style grass caps
- Non-rotating tileset support (per-direction T/B/L/R authoring)

## Breaking Changes
- v0.1.0 atlases require migration. See [migration notes](#migration).

## Install
1. Download `tetra_tile-v0.2.0.zip` below.
2. Extract and copy the `addons/tetra_tile/` folder into your Godot 4.6 project.
3. Project Settings → Plugins → enable TetraTile.
```

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| `TetraTileMapLayer` (v0.2.0) | Godot 4.6.x stable | `_update_cells(coords, forced_cleanup)` signature stable through 4.6. No 4.5→4.6 breaking changes documented for `TileMapLayer` in the upgrade guide. (HIGH on signature; MEDIUM on "no breaking changes" — upgrade guide content was sparse for tile-related sections.) |
| `TetraTileAtlasContract` Resource | Godot 4.6.x | `Array[Resource]` exports work cleanly in 4.6; this pattern is the official idiom. |
| Variation reads from `TileData.probability` | Godot 4.6.x | Field exists since 4.x. The behavior of "probability is editor-scattering-only" is consistent across all 4.x versions per docs. |
| v0.1.0 atlases | NOT compatible with v0.2.0 | Per `PROJECT.md`, breaking changes accepted pre-1.0. Demo updated alongside. |

## Sources

**Authoritative (HIGH confidence — direct quotes verified):**

- Context7: `/websites/godotengine_en_4_6` — `TileSetAtlasSource` methods, `TRANSFORM_FLIP_H/V/TRANSPOSE` constants, `EditorPlugin` virtual methods, `TileSet` custom data layer methods, `TileData` API.
- Official Godot 4.6 docs: [class_tilemaplayer](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html) — `_update_cells` signature, `forced_cleanup` semantics, `set_cell` signature with `alternative_tile: int = 0`.
- Official Godot 4.6 docs: [class_tilesetatlassource](https://docs.godotengine.org/en/4.6/classes/class_tilesetatlassource.html) — full alphabetized method inventory; transform-flag composition rule for `alternative_tile`.
- Official Godot 4.6 docs: [class_tiledata](https://docs.godotengine.org/en/4.6/classes/class_tiledata.html) — `probability` property ("Relative probability of this tile being selected when drawing a pattern of random tiles"), custom-data methods.
- Official Godot 4.6 docs: [class_tileset](https://docs.godotengine.org/en/4.6/classes/class_tileset.html) — `add_custom_data_layer`, `set_custom_data_layer_name`, `get_custom_data_layer_by_name`.
- Official Godot 4.6 docs: [making_plugins.html](https://docs.godotengine.org/en/4.6/tutorials/plugins/editor/making_plugins.html) — `plugin.cfg` field list (name/description/author/version/script).
- Official Godot 4.6 docs: [installing_plugins.html](https://docs.godotengine.org/en/4.6/tutorials/plugins/editor/installing_plugins.html) — ZIP layout requirement (`addons/` at archive root).
- Official Godot 4.6 docs: [gdscript_exports.html](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_exports.html) — `@export var foo: Resource`, `Array[Resource]`, `@export_group`, `@export_subgroup`.
- Official Godot 4.6 docs: [using_tilemaps.html](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilemaps.html) — confirms scattering/probability are editor-paint-time only.
- Official Godot 4.6 docs: [using_tilesets.html](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html) — alternative tile creation flow ("right-click a base tile … Create an Alternative Tile"); confirms alt-tile properties don't inherit from base.
- Official Godot 4.6 docs: [inspector_plugins.html](https://docs.godotengine.org/en/4.6/tutorials/plugins/editor/inspector_plugins.html) — `EditorInspectorPlugin` virtuals (deferred, not used this milestone).

**MEDIUM confidence (verified by single source or community-confirmed):**

- [godotengine/godot-proposals#8653](https://github.com/godotengine/godot-proposals/issues/8653) — proposal for `min_godot_version` in `plugin.cfg`; archived/closed without documented implementation. Conclusion: don't put it in `plugin.cfg`.
- 4.5→4.6 upgrade guide ([upgrading_to_godot_4.6.html](https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html)) — TOC was the only content easily extractable; the page does not appear to contain a dedicated TileMapLayer breaking-change section. MEDIUM on "no relevant breaking changes" until the full content is read by a human.

**LOW confidence (not load-bearing for this milestone):**

- v0.1.0 logic-layer-hidden-via-`self_modulate` claim is documented in our own README and codebase notes, not in upstream Godot docs as an explicit gotcha. Accept as project-internal lore (HIGH within this codebase, untracked upstream).

---
*Stack research for: Godot 4.6 dual-grid autotiling addon — atlas contract expansion (TetraTile v0.2.0)*
*Researched: 2026-04-25*
