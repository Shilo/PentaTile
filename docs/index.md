# Quickstart

![PentaTile logo](assets/brand/penta_tile_logo.png){ width="220" }

PentaTile is a Godot 4.6 addon centered on one node: `PentaTileMapLayer`.
You paint with Godot's normal `set_cell()` and `erase_cell()` APIs; the layer
generates autotiled visuals through its `layout` Resource.

## Fast path

1. Copy `addons/penta_tile/` into a Godot 4.6 project.
2. Enable the plugin in **Project > Project Settings > Plugins**.
3. Add a `PentaTileMapLayer` node to a scene.
4. Pick a `PentaTileLayout` Resource in the `layout` property.
5. Leave `tile_set` empty to use the layout's bundled fallback art, or assign
   your own `TileSet` that matches the selected layout.
6. Paint with Godot's TileMap tools or call `set_cell()` from code.

For the shipped example, open `res://addons/penta_tile/demo/penta_tile_demo.tscn`.

## What to read next

- [Installation](installation.md) for release-zip setup.
- [Layouts overview](layouts/index.md) to choose the atlas convention that
  matches your art.
- [What is a Penta tileset?](penta-tileset.md) for the 5-archetype format.
- [Authoring Custom Layouts](custom-layouts.md) if you need a new convention.
- [LLM Docs](llm-docs.md) for agent-friendly single-file docs.

## Local checks

The test suite lives outside the addon package:

```powershell
.\tests\run_tests.ps1 -NoPause
```

On Linux or CI:

```bash
bash tests/run_tests.sh
```
