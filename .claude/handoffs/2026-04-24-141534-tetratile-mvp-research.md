# Handoff: TetraTile MVP Research And Implementation Start

## Session Metadata
- Created: 2026-04-24 14:15:34
- Project: C:\Programming_Files\Shilocity\TetraTile
- Branch: main
- Session duration: about 25 minutes

### Recent Commits
- 70b44d2 feat(godot): add texture import configurations
- e163691 docs: add attributions section to README
- c5c4c8e chore: initialize project with basic configuration files
- ddb686f chore: README documentation
- b078864 Initial commit

## Handoff Chain

- **Continues from**: None (fresh start)
- **Supersedes**: None

This is the first handoff for the TetraTile MVP implementation task.

## Current State Summary

The user asked for a Godot 4.6 addon named TetraTile: a lightweight dual-grid autotiling system built around one user-facing `TetraTileMapLayer extends TileMapLayer`, a strict 4-tile atlas template, native `_update_cells` interception, and automatically managed internal visual layers. No implementation files were created before the user paused the work. Research is complete enough to proceed: `_update_cells` is a valid Godot 4.6 hook, TileMapDual's architecture has been burned down, and the critical diagonal bridge problem has an MVP-compatible solution using composition on a second managed visual layer.

## Codebase Understanding

## Architecture Overview

The repository is currently a small Godot 4.6 project with `project.godot`, `README.md`, `icon.svg`, and two imported 64x16 PNG templates: `tetra_tile_template.png` and `tetra_tile_ground.png`. There is no addon code yet.

The desired architecture is:
- User edits a visible/invisible logic `TetraTileMapLayer`.
- `TetraTileMapLayer` owns one or two internal child/sibling `TileMapLayer` nodes for visuals.
- Native editor drawing and runtime `set_cell()` trigger `_update_cells(coords: Array[Vector2i], forced_cleanup: bool)`.
- The override computes affected dual-grid coordinates, builds a 4-bit mask from neighboring logic cells, and writes visual atlas cells with rotation/flip transforms.
- The logic layer should remain the user's API surface; no custom `set_cell` wrapper should be required.

## Critical Files

| File | Purpose | Relevance |
|------|---------|-----------|
| C:\Programming_Files\Shilocity\TetraTile\project.godot | Godot project config | Already targets Godot 4.6 and GL Compatibility. |
| C:\Programming_Files\Shilocity\TetraTile\README.md | Product/spec context | Contains comparison claims and attribution for `tetra_tile_ground.png`. |
| C:\Programming_Files\Shilocity\TetraTile\tetra_tile_template.png | Minimal template image | 64x16, four 16x16 tiles in required order. |
| C:\Programming_Files\Shilocity\TetraTile\tetra_tile_ground.png | Demo/template atlas | 64x16, likely the demo visual atlas. |
| C:\Programming_Files\Shilocity\Godot\Tests\TileMapDual-main\addons\TileMapDual\tile_map_dual.gd | Reference addon entry point | Confirms TileMapDual already uses `_update_cells` as its native swizzle path. |
| C:\Programming_Files\Shilocity\Godot\Tests\TileMapDual-main\addons\TileMapDual\display_layer.gd | Reference visual layer logic | Useful contrast for simplifying the hot path. |
| C:\Programming_Files\Shilocity\Godot\Tests\TileMapDual-main\addons\TileMapDual\terrain_layer.gd | Reference trie rule matcher | Main complexity TetraTile should avoid. |

## Key Patterns Discovered

TileMapDual uses a multi-file architecture: `tile_map_dual.gd`, `display.gd`, `display_layer.gd`, `terrain_dual.gd`, `terrain_layer.gd`, `tile_cache.gd`, `tile_set_watcher.gd`, `atlas_watcher.gd`, `terrain_preset.gd`, `plugin.gd`, `tile_map_dual_legacy.gd`, and helpers. It relies on watchers, resource classes, signals, dictionaries, a terrain trie, and editor autogeneration. TetraTile can replace all of that with direct mask math because V1 supports one square-grid terrain and a fixed four-tile template.

The template inspection showed `tetra_tile_template.png` is 64x16. Per 16x16 tile, alpha occupancy looks like:
- Tile 0 Fill: all four quadrants filled.
- Tile 1 Inner Corner: missing top-right quadrant.
- Tile 2 Border: bottom half filled.
- Tile 3 Outer Corner: bottom-left quadrant filled.

## Work Completed

## Tasks Finished

- [x] Spawned the requested research subagent and received its findings.
- [x] Inspected the TetraTile repo shape and git branch state.
- [x] Inspected TileMapDual's addon files and identified architecture bulk to avoid.
- [x] Verified via official Godot docs that `_update_cells` exists on `TileMapLayer` and is intended for internal cell update interception.
- [x] Checked available Godot executable path: `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`.
- [x] Confirmed `tetra_tile_template.png` and `tetra_tile_ground.png` are 64x16.
- [x] Decided the MVP diagonal solution: composition using the same Outer Corner tile on a second managed visual layer.

## Files Modified

| File | Changes | Rationale |
|------|---------|-----------|
| C:\Programming_Files\Shilocity\TetraTile\.claude\handoffs\2026-04-24-141534-tetratile-mvp-research.md | Created handoff | Preserve research and continuation context. |

## Decisions Made

| Decision | Options Considered | Rationale |
|----------|-------------------|-----------|
| Use `_update_cells` as the native hook | Custom setters, signals, polling, `_update_cells` | Godot 4.6 exposes `_update_cells`; TileMapDual also uses it for editor drawing/undo/runtime changes. |
| Keep one public class | Multi-file TileMapDual-like addon, single `TetraTileMapLayer` | User explicitly requested single-class philosophy and minimal boilerplate. |
| Solve diagonal masks by composition | Require 5th tile, shader fallback, bake step, second visual layer | Four physical templates cannot represent the two diagonal states in one cell without composition. Two internal visual layers preserve the 4-tile promise and keep shader/bake work deferred. |
| Scope V1 to square-grid one-terrain tiles | TileMapDual-like support for iso/hex/multiterrain | Fixed 4-tile template and performance target make square one-terrain logic the correct MVP. |

## Pending Work

## Immediate Next Steps

1. Create the addon script at the requested TetraTile path with `@tool`, `class_name TetraTileMapLayer`, and a lean `_update_cells` override.
2. Create the addon plugin configuration and a minimal plugin script only if needed to register the custom type in the editor.
3. Create a demo `TileSet` resource from `tetra_tile_ground.png` with 16x16 texture regions and four tiles at atlas coords `(0,0)` through `(3,0)`.
4. Create a demo scene with a `TetraTileMapLayer` using that TileSet and a small painted logic shape to exercise borders, corners, and diagonal masks.
5. Run Godot 4.6.2 console validation on the project and fix GDScript/resource errors.

## Blockers/Open Questions

- Godot MCP did not appear in the Codex tool registry after the user added `.mcp.json`; tool discovery still only surfaced node, GitHub, automation, and Playwright tools. The next session should retry `tool_search` first.
- Need confirm exact GDScript transform constants for `TileMapLayer.set_cell(..., alternative_tile)` in Godot 4.6. Expected pattern is to use TileSetAtlasSource transform flags for flip/transpose, but verify against engine/docs or with a tiny Godot script.
- Need decide whether the logic layer is hidden by `visible = false`, self-modulate alpha, a material, or by using a transparent marker tile. Avoid recursion and avoid surprising the user in editor.
- Need decide whether visual layers are children of the logic layer or siblings. Children are simpler for single-class ownership; copying visual properties may be needed.

## Deferred Items

- `TetraBake`: defer until the MVP proves the two-layer diagonal composition works.
- Y-axis variations: defer until base atlas lookup and transform flags are stable.
- Shader fallback: defer; composition is simpler and less fragile for MVP.
- Auto collision, multiterrain transitions, top tiles, non-rotating tilesets, docs site, and converters remain roadmap/backlog.

## Context for Resuming Agent

## Important Context

The diagonal bridge problem is the central design constraint. With only four source tiles and one visual tile per dual-grid coordinate, masks `5` and `10` cannot be faithfully represented: they contain two disconnected occupied diagonal quadrants. The accepted MVP solution is to keep the user-facing class single but allow two managed visual `TileMapLayer`s. For normal masks, write only the primary visual layer. For diagonal masks, write one Outer Corner on the primary layer and the other Outer Corner on the overlay layer at the same display coordinate.

Use bit order `TL=1`, `TR=2`, `BL=4`, `BR=8`. Recommended mask mapping:
- `0`: erase visual cell.
- `15`: Fill tile index `0`.
- Single bits `1,2,4,8`: Outer Corner tile index `3`, transformed so the occupied quadrant is correct.
- Three-bit masks `14,13,11,7`: Inner Corner tile index `1`, transformed so the missing quadrant is correct.
- Adjacent pairs `3,6,12,9`: Border tile index `2`, transformed so the occupied edge is correct.
- Diagonal pairs `5,10`: two Outer Corner placements, one per occupied quadrant, using both visual layers.

TileMapDual burn-down details from the research subagent:
- `addons/TileMapDual` has about 14 GDScript files, 2,126 lines, 14 `class_name`s, 8 signals, 106 functions, and 56 `Dictionary` mentions.
- Hot path is `_update_cells` -> display update -> cache update -> signal fanout -> display layer recomputation -> terrain trie lookup -> `set_cell`.
- TetraTile should delete/simplify grid-shape dispatch, terrain peering-bit parsing, trie rules, TileSet/Atlas watchers, editor popups, ghost material, cursor, legacy implementation, and large per-cell terrain dictionaries.

Official docs note: `TileMapLayer._update_cells(coords, forced_cleanup)` is a virtual method called when cells need internal updates, including individual cell modifications and TileSet changes. Updates are batched to frame end. Docs warn that overriding can degrade performance, so the override must be lean and avoid recursive writes to the same layer.

## Assumptions Made

- V1 targets square orthogonal grids only.
- A logic cell is occupied if `get_cell_source_id(cell) != -1`.
- The first TileSet atlas source contains the 4x1 template in order Fill, Inner Corner, Border, Outer Corner.
- Tile region size is 16x16 for the provided demo assets, but production code should derive tile size from `tile_set.tile_size`.
- It is acceptable for the single public class to manage internal child `TileMapLayer` nodes.

## Potential Gotchas

- Do not call `set_cell` on the same `TetraTileMapLayer` from `_update_cells`, or it may recurse. Write only to managed visual layers.
- `forced_cleanup` should probably erase visuals or skip normal recompute when the layer is hidden/disabled/freed. Verify behavior with Godot.
- Creating child nodes inside an `@tool` script can dirty scenes if ownership is wrong. Internal visual layers should have clear names, be reused if already present, and likely not be user-owned unless demo scene needs serialization.
- If the logic layer remains visible, users will see both marker tiles and generated visuals. Hide it deliberately or document the marker workflow.
- The two diagonal masks must clear the overlay layer when a cell changes back to a non-diagonal state.
- The docs page retrieved was the stable page for current Godot docs, and the installed local executable is 4.6.2 stable. Verify exact API names in the local engine if possible.

## Environment State

## Tools/Services Used

- PowerShell in `C:\Programming_Files\Shilocity\TetraTile`.
- Web search/open for official Godot `TileMapLayer` docs.
- Subagent `019dc14f-6fce-72f1-a797-f7b38275dbd8` completed research.
- Godot executable found at `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`.
- `rg` failed due packaged executable access denial, so PowerShell `Get-ChildItem` and `Get-Content` were used instead.

## Active Processes

- User said Godot was open for MCP usage.
- No long-running shell command or dev server was intentionally left running by this session.

## Environment Variables

- No relevant environment variables were inspected or required.

## Related Resources

- Official Godot docs: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- Reference implementation: C:\Programming_Files\Shilocity\Godot\Tests\TileMapDual-main
- Target project: C:\Programming_Files\Shilocity\TetraTile
- Research inspiration URL from user: https://www.youtube.com/watch?v=aWcCNGen0cM

## Suggested First Implementation Shape

Create a compact `TetraTileMapLayer` like this:
- Constants for tile indices: fill `Vector2i(0,0)`, inner `Vector2i(1,0)`, border `Vector2i(2,0)`, outer `Vector2i(3,0)`.
- Constants for affected display offsets around a changed logic cell: `(0,0)`, `(1,0)`, `(0,1)`, `(1,1)` or equivalent depending on chosen display coordinate origin.
- `_ready()` calls `_ensure_visual_layers()` and queues a full rebuild.
- `_update_cells(coords, forced_cleanup)` ensures visual layers, expands changed logic coords to affected dual coords, and recomputes each affected visual coordinate.
- `_mask_at(display_cell)` samples the four logic cells that surround that dual cell with direct `get_cell_source_id` checks.
- `_paint_mask(display_cell, mask)` erases primary/overlay first, then writes the proper atlas tile plus transform flags.

Keep implementation comments sparse but include one short comment near the diagonal composition branch because that is the non-obvious design choice.
