---
created: 2026-04-28T16:38:38.183Z
title: Re-research editor line/rect/bucket tool preview during drag
area: general
files:
  - .planning/research/editor-line-rect-preview.md
  - addons/penta_tile/penta_tile_map_layer.gd:380-442
---

## Problem

`PentaTileMapLayer` shows no preview while the user drags the editor's line, rectangle, or bucket tools when a `layout` is assigned. Without a layout the native fallback works fine.

Root cause (verified against Godot 4.6 source `editor/scene/2d/tiles/tile_map_layer_editor.cpp`):

- The editor's line/rect/bucket tools do **not** call `set_cell()` during the drag. They build an in-memory `preview` dictionary and render it directly to the viewport overlay via `p_overlay->draw_texture_rect_region(...)`. `_update_cells()` is never invoked during the drag — only on commit.
- The preview's alpha is computed (line 976) as `tile_data->get_modulate() * edited_layer->get_modulate_in_tree() * edited_layer->get_self_modulate()`, then drawn at 50% alpha.
- PentaTile's `logic_layer_opacity = 0.0` default sets `self_modulate.a = 0` (`penta_tile_map_layer.gd:439-442`) → the preview overlay alpha is multiplied to zero → invisible.
- Polling `get_used_cells()` won't catch preview cells (they're never in `tile_map_data`).
- `_use_tile_data_runtime_update` / `_tile_data_runtime_update` can't redirect a cell to a different atlas tile, only override modulate/transpose/flip/z_index/etc.

Full investigation in `.planning/research/editor-line-rect-preview.md` (commits, source line numbers, TileMapDual comparison, pitfalls, open questions).

## Solution

Two paths to choose from when revisiting:

**(a) Ghost-material approach (TileMapDual parity, raw preview)** — small refactor of `_apply_logic_layer_opacity`:

- Replace `self_modulate.a`-based hiding with a ghost `ShaderMaterial` (`COLOR = vec4(0)` in fragment) on the parent's `material` slot.
- Keep `self_modulate.a == 1.0` so the editor's preview overlay stays visible.
- Forward user-supplied `material` to the child `_primary_layer` via a new `display_material` property.
- User sees raw atlas preview (50% alpha) during drag — not autotile-dispatched, but visible. Matches TileMapDual.
- Breaking change to public `logic_layer_opacity` export (acceptable per CLAUDE.md breaking-changes policy).
- ~30 lines of code. Pitfall §7 (`visible = false` cleanup) stays mitigated.

**(b) Custom `EditorPlugin` with `forward_canvas_draw_over_viewport`** — full new phase:

- Hook editor drag state, compute the cells the line/rect tool will produce, run autotile dispatch with a virtual sample fn that includes preview cells, render the dispatched output as a viewport overlay.
- True dispatched preview during drag.
- Significant work. Risks conflicts with the editor's built-in preview overlay if both render simultaneously.

**Before implementing, re-verify the open questions in the research doc against the current Godot version:**

- Does `_tile_data_runtime_update` gain atlas-redirect capability in a future Godot release? (Would unblock a much simpler approach.)
- Does the editor expose preview state to scripts? (Would enable polling.)
- Has Godot added a per-layer "preview" hook? (Would enable a clean override.)

**Defer until after v0.2.0 ships.** Not blocking the current milestone — the bug only manifests when a layout is bound, and demo-scale paint-tool usage is acceptable. Revisit when v0.2 wraps and there's a natural break for editor-integration polish.
