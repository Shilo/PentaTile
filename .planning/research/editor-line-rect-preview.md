# Research: Editor Line/Rect Tool Preview During Drag

Date: 2026-04-28
Status: Investigation only (no code changes)
Related: PITFALLS.md §7 (`visible = false` cleanup), `penta_tile_map_layer.gd:439-442` (`_apply_logic_layer_opacity`), `penta_tile_map_layer.gd:380-413` (`_sync_visual_layers`)

## Problem statement

When a `PentaTileMapLayer` has a `layout` assigned, the Godot editor's line and rectangle tools do not show any preview while the user is mid-drag. The preview only "appears" once the drag is committed (mouse release), at which point the autotile dispatch kicks in via `_update_cells()` and the child `_primary_layer` paints the result.

When `layout` is `null`, the line/rect preview works correctly during the drag because the addon's null-layout branch falls back to native `TileMapLayer` rendering on the parent.

## Root cause

Traced in Godot 4.6 source: `editor/scene/2d/tiles/tile_map_layer_editor.cpp`.

**The line and rect tools do not call `set_cell()` during the drag.** They build an in-memory `preview` dictionary and render it directly to the viewport overlay using `p_overlay->draw_texture_rect_region(...)`. `_update_cells()` is never invoked during the drag — it only fires when the drag commits (mouse release) and the undo/redo manager applies the final cells.

Key source excerpts:

- Lines 889-902: line/rect drag stores `drag_modified` (original cells, for restore-on-cancel) but the actual preview cells are computed by `_draw_line()` / `_draw_rect()` and stored in the `preview` dictionary, **never written to `tile_map_data`**.
- Line 950: `for (const KeyValue<Vector2i, TileMapCell> &E : preview)` iterates the preview dictionary and draws each tile directly to the canvas overlay.
- Line 976: the preview's modulate is computed as
  ```cpp
  Color modulate = tile_data->get_modulate()
                 * edited_layer->get_modulate_in_tree()
                 * edited_layer->get_self_modulate();
  ```
  i.e., the preview overlay is multiplied by the parent TileMapLayer's `self_modulate`.
- Line 980: drawn with `modulate * Color(1.0, 1.0, 1.0, 0.5)` (the 50% alpha you see).

Why PentaTile is invisible during the drag:

1. `PentaTileMapLayer.logic_layer_opacity` defaults to `0.0`.
2. `_apply_logic_layer_opacity()` writes `self_modulate.a = logic_layer_opacity` → `self_modulate.a = 0.0`.
3. The editor's preview overlay (drawn directly to viewport) multiplies its alpha by `self_modulate.a` → preview alpha becomes 0 → invisible.

The child `_primary_layer` (the dispatched output) doesn't help here because the preview cells aren't in `tile_map_data`, so `_update_cells()` never fires for them and the dispatch never runs.

## How TileMapDual handles it

TileMapDual (https://github.com/pablogila/TileMapDual) does support line/rect tool preview during drag — but only the **raw** preview (not autotile-dispatched).

Mechanism (`tile_map_dual.gd:115-130`, `ghost.gdshader`):

- Applies a ghost shader to the parent's `material` slot:
  ```glsl
  shader_type canvas_item;
  void fragment() { COLOR = vec4(0); }
  ```
- Keeps `self_modulate.a == 1.0` (does not zero it).
- The shader makes the parent's actual cell rendering invisible (alpha=0 from fragment shader).
- The editor's preview overlay is drawn to the **viewport overlay**, not through the parent's `_draw`, so it bypasses the material entirely. Its alpha is multiplied by `self_modulate.a == 1.0` and stays visible.

Result: during drag, the user sees the editor's 50%-alpha raw preview (the literal selected atlas tile, not autotile-dispatched), plus the dispatched output of any already-committed cells on the child display layer.

TileMapDual exposes a `display_material` property so users can apply their own material to the dispatch output (the child layer), since the parent's `material` slot is now claimed by the ghost shader.

## What's achievable for PentaTile

| Approach | What you see during drag | Cost / risk |
|---|---|---|
| **Ghost-material hide** (TileMapDual's approach) | Raw atlas preview (50% alpha) — not autotile-dispatched | Small refactor (~30 lines): replace `self_modulate.a`-based hiding with a ghost shader on the parent. `logic_layer_opacity` becomes vestigial or repurposed. Breaking change to the public `logic_layer_opacity` property; user-supplied materials on the parent would need to be forwarded to the child `_primary_layer`. |
| **Custom `EditorPlugin`** with `forward_canvas_draw_over_viewport` | Fully autotile-dispatched preview during drag | New phase of work. Hook into editor drag state, compute the cells the line/rect will produce, run autotile dispatch with a virtual sample fn that returns true for "preview cells", render the dispatched output as a viewport overlay. |
| **Polling `get_used_cells()`** | Nothing useful | Doesn't work. The preview dictionary is internal to the editor; preview cells are never in `tile_map_data`, so polling can't catch them. |
| **`_use_tile_data_runtime_update` / `_tile_data_runtime_update`** | Nothing useful | Doesn't work. Runtime tile data updates can override `modulate`, `transpose`, `flip_h/v`, `z_index`, etc. — but **not** which atlas tile is rendered. Can't use it to redirect a raw cell to a dispatched cell. |

## Pitfalls / things to verify before implementing

- **`logic_layer_opacity` is a public `@export`.** Breaking changes are allowed (CLAUDE.md), but the parameter currently has user-facing meaning ("show me the logic layer for debugging"). Replacement: keep it as a debug toggle that switches the parent's material between the ghost shader and `null`, so users can still toggle visibility for debugging.
- **`material` slot becomes addon-claimed.** Need a `display_material` (or similar) property that flows the user's chosen material onto `_primary_layer` instead. Must guard the parent `material` setter against external writes (TileMapDual does this with a popup; we could just silently copy).
- **Pitfall §7 stays mitigated.** The parent stays `visible = true` and `enabled` — only the rendering output is zeroed by the shader. The cleanup leak that motivated the original `self_modulate.a` mitigation still doesn't trigger.
- **Editor-only or runtime-too?** TileMapDual applies the ghost shader unconditionally (in-game and in editor). For PentaTile this should also be unconditional — the parent's raw cells are never the "real" rendering once a layout is assigned, regardless of whether we're in the editor or in-game.
- **Null-layout branch.** When `layout == null`, the parent renders directly (native `TileMapLayer` fallback). The ghost shader must be removed in that branch and the user's `display_material` re-applied to the parent. Symmetric to the current `self_modulate.a = 1.0` reset in `_sync_visual_layers` line 386-388.
- **Synthesis cache and tile_set swapping.** When the layout is swapped, the parent's `tile_set` is auto-replaced via `_tile_set_is_fallback`. This is independent of the material/modulate fix — should not regress.

## Open questions

- Does the bucket tool have the same issue? Likely yes (same `preview` overlay codepath in `tile_map_layer_editor.cpp` ~line 904).
- Does the eraser tool work? It calls `set_cell()` directly during paint-style drag (DRAG_TYPE_PAINT), so `_update_cells()` fires and the dispatched output should update. But under DRAG_TYPE_LINE/RECT the eraser uses the same overlay-preview path → same invisibility problem.
- Does the "random tile" toggle change anything? At line 957 the random-tile branch draws a generic tile shape outline (not the actual texture), still multiplied by `self_modulate`. Same fix applies.
- Pattern paste (`DRAG_TYPE_CLIPBOARD_PASTE`) — also overlay-based per lines 875-882, same invisibility.

## Source references

- Godot 4.6 source: `editor/scene/2d/tiles/tile_map_layer_editor.cpp` lines 875-990 (preview rendering), 647-770 (drag type setup).
- TileMapDual: `addons/TileMapDual/tile_map_dual.gd`, `addons/TileMapDual/ghost.gdshader`, `addons/TileMapDual/ghost_material.tres`.
- PentaTile: `addons/penta_tile/penta_tile_map_layer.gd:380-442`.

## Recommendation (when revisited)

Start with the ghost-material approach — it gives parity with TileMapDual at low cost, and unblocks the user's most common complaint (no preview during line/rect). If raw-tile preview turns out to be confusing in practice (because users expect the dispatched output, not the raw atlas tile), upgrade to the EditorPlugin approach in a separate phase.

Avoid mixing the two — the EditorPlugin's dispatched overlay would conflict with the editor's built-in preview overlay if both render simultaneously.
