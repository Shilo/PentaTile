# Technology Stack

**Analysis Date:** 2026-04-26

## Languages

**Primary:**
- GDScript 4.6 - Core addon implementation and demo scripts

**Secondary:**
- None (all game logic is GDScript)

## Runtime

**Environment:**
- Godot Engine 4.6.2 (stable, Windows)
- Executable: `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`

**Package Manager:**
- None (Godot projects use embedded dependency model)

## Frameworks

**Core Engine:**
- Godot Engine 4.6 - Game development framework

**Key Classes:**
- `TileMapLayer` - Base class for `PentaTileMapLayer` (extends via script)
- `TileSetAtlasSource` - Atlas tile management
- `TileSet` - Tileset configuration
- `Node2D` - Scene tree hierarchy for demo content
- `CharacterBody2D` - Physics-enabled character controller

**Build/Dev:**
- Godot Editor (Integrated IDE and scene editor)
- GDScript compiler/interpreter (built-in)

## Key Dependencies

**Core:**
- `TileMapLayer` (Godot native) - Base for autotiling implementation
- `TileSetAtlasSource` (Godot native) - Tile source and transformation handling
- `Input` system (Godot native) - Runtime painting mouse input

**Infrastructure:**
- Physics Layer 0 (Godot native) - Collision polygon support
- TileSet physics polygons - Demo collision shapes

## Configuration

**Environment:**
- Configured via `project.godot`
- Godot 4.6 with GL Compatibility rendering backend
- D3D12 renderer for Windows platform

**Build:**
- `project.godot` - Main engine configuration
  - Application name: "PentaTile"
  - Main scene: `res://addons/penta_tile/demo/penta_tile_demo.tscn`
  - Feature set: `4.6`, `GL Compatibility`
  - Physics engine: Jolt Physics (3D, not used in 2D addon)
  - Rendering method: `gl_compatibility`

**Addon Configuration:**
- `addons/penta_tile/plugin.cfg` - Addon metadata
  - Name: PentaTile
  - Version: 0.1.0
  - Author: Shilo
  - Entry point: None (script-based, no plugin class)

## Platform Requirements

**Development:**
- Windows 11 (verified at C:\Programming_Files\Godot\)
- Godot 4.6.2 stable or compatible 4.6.x release
- Text editor or Godot IDE for GDScript editing

**Production:**
- Godot 4.6+ runtime for game distribution
- Supports GL Compatibility rendering (cross-platform: Windows, Linux, macOS, Web)
- D3D12 driver for Windows platforms
- Jolt Physics (configured but not used in 2D addon)

## Editor Features

**Asset Pipeline:**
- PNG textures (embedded, no external asset pipeline required)
- TileSet definition files (`penta_tile_ground.tres`)
- Scene files (`.tscn` - text-based TSCN format)
- Sprite2D, TileMapLayer, and CharacterBody2D visual editor support

**Tooling:**
- `@tool` script annotation - `PentaTileMapLayer` runs in-editor for live preview
- Built-in signal/property system for inspector tweaking
- Editor script caching (`.godot/editor/` directory)

---

*Stack analysis: 2026-04-26*
