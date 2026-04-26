# Codebase Structure

**Analysis Date:** 2026-04-26

## Directory Layout

```
project-root/
├── addons/                          # Godot addons directory
│   └── tetra_tile/                  # TetraTile addon root
│       ├── plugin.cfg               # Addon metadata and registration
│       ├── tetra_tile_map_layer.gd  # Core implementation (261 lines)
│       ├── tetra_tile_template.png  # Blank 4-tile reference template
│       ├── tetra_tile_map_layer.gd.uid  # Godot UID file
│       ├── tetra_tile_template.png.import  # Texture import config
│       └── demo/                    # Demo scene and assets
│           ├── tetra_tile_demo.tscn # Main demo scene entry point
│           ├── demo_player.gd       # Player controller (CharacterBody2D)
│           ├── demo_runtime_painter.gd  # Runtime tile painting system
│           ├── tetra_tile_ground.png    # 64x16 px tileset atlas (4 tiles × 16 px)
│           ├── tetra_tile_ground.tres   # TileSet resource with physics
│           ├── tetra_tile_ground.png.import  # Texture import config
│           ├── demo_player.gd.uid
│           ├── demo_runtime_painter.gd.uid
├── project.godot                    # Godot engine config
├── icon.svg                         # Default Godot project icon
├── README.md                        # User-facing documentation
├── RESEARCH.md                      # Technical research and design rationale
├── IMPLEMENTATION_PLAN.md           # MVP specification and 16-state mapping
└── .godot/                          # Engine-generated cache (not committed)
```

## Directory Purposes

**`addons/tetra_tile/`:**
- Purpose: Complete TetraTile addon package; distributed as-is in user projects
- Contains: Core class, plugin config, template asset, demo scene
- Key files: `tetra_tile_map_layer.gd` (single implementation file)

**`addons/tetra_tile/demo/`:**
- Purpose: Standalone demo scene showcasing full TetraTile functionality
- Contains: Playable scene, player controller, runtime painting demo, TileSet with physics
- Key files: `tetra_tile_demo.tscn` (entry point), `demo_runtime_painter.gd` (interactive painting)

## Key File Locations

**Entry Points:**
- `res://addons/tetra_tile/demo/tetra_tile_demo.tscn`: Demo scene (launches when project runs)
- `addons/tetra_tile/tetra_tile_map_layer.gd`: Class definition (auto-registered to Godot global namespace via `class_name`)

**Configuration:**
- `addons/tetra_tile/plugin.cfg`: Godot addon metadata (name, version, description)
- `project.godot`: Engine configuration (main_scene, features, rendering settings)

**Core Logic:**
- `addons/tetra_tile/tetra_tile_map_layer.gd`: All implementation (261 lines)
  - Constants: Tile indices, rotation flags, offset vectors
  - Properties: Export vars for atlas_source_id, atlas_layout, opacity, collisions
  - Methods: `_ready()`, `_update_cells()`, `rebuild()`, mask calculation, visual layer management

**Assets:**
- `addons/tetra_tile/demo/tetra_tile_ground.tres`: TileSet resource with physics polygons for all 4 tiles
- `addons/tetra_tile/demo/tetra_tile_ground.png`: 64x16 pixel atlas (4 tiles × 16 px, horizontally arranged)
- `addons/tetra_tile/tetra_tile_template.png`: Reference template (blank placeholder, not used at runtime)

**Testing:**
- No automated tests; demo scene serves as integration test
- Manual testing: Play demo, paint with left-click, erase with right-click, move player

## Naming Conventions

**Files:**
- Class files: Snake_case, match class name (`tetra_tile_map_layer.gd` → `TetraTileMapLayer`)
- Demo scripts: Prefix `demo_` with descriptive name (`demo_player.gd`, `demo_runtime_painter.gd`)
- Assets: Descriptive snake_case (`tetra_tile_ground.png`, `tetra_tile_template.png`)
- Godot resources: Match content purpose (`tetra_tile_ground.tres` for ground tileset)

**Directories:**
- Addons: Reverse-domain or product name (`tetra_tile/`)
- Subdirectories: Feature-based (`demo/`)

**GDScript Constants:**
- Private constants: Prefixed with underscore, UPPER_SNAKE_CASE (`_PRIMARY_LAYER_NAME`, `_FILL`, `_ROTATE_90`)
- Enum members: Capitalized (`HORIZONTAL`, `VERTICAL`)

**GDScript Classes and Methods:**
- Class name: PascalCase (`TetraTileMapLayer`)
- Private methods: Prefixed with underscore (`_ready()`, `_update_cells()`, `_mask_at()`)
- Public methods: snake_case without underscore (`rebuild()`, inherited `set_cell()`, `erase_cell()`)
- Export properties: snake_case (`atlas_source_id`, `atlas_layout`, `logic_layer_opacity`)

## Where to Add New Code

**New Feature (Editor Painting Enhancement):**
- Primary code: `addons/tetra_tile/tetra_tile_map_layer.gd` (extend `_update_cells()` or add public method)
- Tests: Add scenario to `tetra_tile_demo.tscn` or create new demo scene

**New Component/Module (Alternative Painter):**
- Implementation: `addons/tetra_tile/demo/demo_[feature_name].gd`
- Example: `demo_brush_tool.gd`, `demo_fill_bucket.gd`
- Usage: Attach as script to Node in demo scene

**Utilities (Helper Classes):**
- If internal to addon: Add directly to `addons/tetra_tile/` directory
- If addon-wide shared: Define in `tetra_tile_map_layer.gd` as inner class or utility functions
- If demo-specific: Place in `addons/tetra_tile/demo/` with `demo_` prefix

**Assets (New TileSet/Atlas):**
- Placement: `addons/tetra_tile/demo/` (co-locate with other demo assets)
- Naming: `tetra_tile_[terrain_type].png` and `tetra_tile_[terrain_type].tres`
- Format: 4 tiles, 16x16px each, horizontally or vertically arranged (configured via `atlas_layout`)

## Special Directories

**`.godot/` (Generated):**
- Purpose: Godot editor cache (scripts, metadata, editor state)
- Generated: Yes (at runtime)
- Committed: No (in `.gitignore`)

**`addons/` (Addon Structure):**
- Purpose: Godot's standard location for plugins and extensions
- Generated: No (user-managed)
- Committed: Yes (contains TetraTile source)

## File Reference Map

| Purpose | File Path | Lines | Responsibility |
|---------|-----------|-------|-----------------|
| Core Class | `addons/tetra_tile/tetra_tile_map_layer.gd` | 261 | Mask calculation, visual layer management, property exports |
| Demo Initialization | `addons/tetra_tile/demo/tetra_tile_demo.tscn` | 53 | Scene tree, node hierarchy, property bindings |
| Player Control | `addons/tetra_tile/demo/demo_player.gd` | 18 | CharacterBody2D movement, gravity, collision |
| Runtime Painter | `addons/tetra_tile/demo/demo_runtime_painter.gd` | 55 | Mouse input handling, cell placement/erasure |
| TileSet Definition | `addons/tetra_tile/demo/tetra_tile_ground.tres` | 20 | Physics layers, atlas source mapping |
| Addon Registration | `addons/tetra_tile/plugin.cfg` | 7 | Metadata, version, description |
| Project Config | `project.godot` | 28 | Engine version, main scene, rendering settings |

---

*Structure analysis: 2026-04-26*
