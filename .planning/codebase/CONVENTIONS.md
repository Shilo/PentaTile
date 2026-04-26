# Coding Conventions

**Analysis Date:** 2026-04-26

## Naming Patterns

**Files:**
- GDScript files use `snake_case` (e.g., `tetra_tile_map_layer.gd`, `demo_player.gd`, `demo_runtime_painter.gd`)
- Scene files use `snake_case` (e.g., `tetra_tile_demo.tscn`)
- Configuration files use standard names (`plugin.cfg`, `.editorconfig`, `.gitattributes`)

**Classes:**
- Class names use `PascalCase` and are declared with `class_name` directive (e.g., `TetraTileMapLayer` in `tetra_tile_map_layer.gd`)

**Functions:**
- Private functions start with underscore and use `snake_case` (e.g., `_ready()`, `_update_cells()`, `_ensure_visual_layers()`, `_queue_rebuild()`)
- Public functions use `snake_case` without leading underscore (e.g., `rebuild()`)
- Built-in lifecycle methods are overridden with leading underscore (e.g., `_physics_process()`, `_unhandled_input()`)
- Handler functions follow naming pattern `_handle_[event_type]()` (e.g., `_handle_mouse_button()`, `_handle_mouse_motion()`)
- Helper methods follow naming pattern `_[action]_[subject]()` (e.g., `_mark_affected_display_cells()`, `_paint_display_cell()`, `_apply_logic_collision()`)

**Variables:**
- Private member variables start with underscore and use `snake_case` (e.g., `_primary_layer`, `_overlay_layer`, `_active_button`, `_last_cell`)
- Local variables use `snake_case` without leading underscore (e.g., `direction`, `mask`, `display_cell`, `logic_cell`)
- Exported properties use `snake_case` without underscores (e.g., `speed`, `jump_velocity`, `gravity`, `atlas_source_id`, `logic_layer_opacity`)

**Constants:**
- Constants use `UPPER_SNAKE_CASE` with leading underscore when private (e.g., `_PRIMARY_LAYER_NAME`, `_FILL`, `_ROTATE_0`, `_ROTATE_90`, `_TL`, `_TR`, `_BL`, `_BR`)
- Enum members use `UPPER_CASE` (e.g., `AtlasLayout.HORIZONTAL`, `AtlasLayout.VERTICAL`)
- Named string constants use `UPPER_SNAKE_CASE` (e.g., `StringName`)

## Code Style

**Formatting:**
- UTF-8 encoding (enforced by `.editorconfig`)
- LF line endings for all files (enforced by `.gitattributes`)
- No formal formatter configured; reliance on Godot 4.6 built-in code editing

**Type Annotations:**
- Return type annotations used consistently (e.g., `func _ready() -> void:`, `func _mask_at(display_cell: Vector2i) -> int:`)
- Parameter types annotated (e.g., `func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:`)
- Variable type annotations used for clarity in complex contexts
- Type inference used for simple local variables

**Attributes/Decorators:**
- `@tool` decorator used on scripts that work in editor (e.g., `TetraTileMapLayer`)
- `@icon()` decorator applied to node classes with custom icons
- `@export` decorator used for properties exposed in inspector
- `@export_range()` decorator used to constrain numeric ranges (e.g., `@export_range(0.0, 1.0, 0.01)`)
- `@onready` decorator used for node references initialized after scene tree entry (e.g., `@onready var tetra_map: TetraTileMapLayer = get_node(map_path)`)

**Setter Patterns:**
- Property setters trigger deferred rebuild or state synchronization:
  ```gdscript
  @export var atlas_source_id: int = -1:
    set(value):
      atlas_source_id = value
      _queue_rebuild()
  ```

## Import Organization

**Not applicable** - GDScript files do not use import statements. Node references are resolved via `class_name`, `extends`, and `@onready` decorators.

## Error Handling

**Null Checking:**
- Explicit null checks before using potentially invalid nodes:
  ```gdscript
  if _primary_layer == null or not is_instance_valid(_primary_layer):
    _primary_layer = _get_or_create_visual_layer(_PRIMARY_LAYER_NAME)
  ```
- Use `is_instance_valid()` to verify node validity after potential cleanup

**Early Return:**
- Early returns used to exit functions on invalid conditions:
  ```gdscript
  if source == -1:
    return
  ```

**Silent Failures:**
- Invalid states sometimes return silently (e.g., when `tile_set == null`), allowing graceful degradation

## Logging

**Framework:** Built-in `print()` and `push_error()` functions (standard Godot logging)

**Patterns:**
- No formal logging observed in production code (`tetra_tile_map_layer.gd`)
- Demo code uses no logging
- Error reporting relies on Godot's console output

## Comments

**When to Comment:**
- Complex mask calculations are explained inline:
  ```gdscript
  # Diagonal masks are two disconnected quadrants, so compose them with the overlay layer.
  _set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_180)
  _set_visual_cell(_overlay_layer, display_cell, source, _OUTER_CORNER, _ROTATE_0)
  ```
- Non-obvious algorithms (e.g., bitwise mask operations) include explanation
- Design decisions are documented in README rather than inline comments

**JSDoc/TSDoc:**
- Not used in GDScript (Godot has no formal documentation generation system)
- Function signatures are self-documenting through type annotations

## Function Design

**Size:** Functions are small and focused. Most functions in `tetra_tile_map_layer.gd` are 1-15 lines.

**Parameters:**
- Functions accept only necessary parameters
- Complex data passed as custom types when applicable (e.g., `Vector2i`, `Dictionary`)
- Array parameters use typed generics (e.g., `Array[Vector2i]`)

**Return Values:**
- Functions return typed values (void for side-effect-only functions)
- Early returns preferred over nested conditionals
- Match statements used for exhaustive branching on constants

## Module Design

**Single Responsibility:**
- `TetraTileMapLayer` (`tetra_tile_map_layer.gd`) - core dual-grid autotiling logic
- `DemoPlayer` (`demo_player.gd`) - simple physics and input handling for demo
- `DemoRuntimePainter` (`demo_runtime_painter.gd`) - runtime painting interaction handler

**Exports:**
- Primary class exported via `class_name TetraTileMapLayer`
- Public API exposed through exported properties and public methods (`rebuild()`)
- Internal implementation hidden via underscore-prefixed methods and variables

**Internal Layers:**
- Composition layer: `_primary_layer` and `_overlay_layer` for visual rendering
- Logic layer: base `TileMapLayer` stores actual tile data
- Internal state: no persistent cache; direct coordinate/mask computation

## Match Statements

**Mask-based Routing:**
- `match` statements used for tile painting based on 4-bit neighbor masks (0-15):
  ```gdscript
  match _mask_at(display_cell):
    0:
      return
    1:
      _set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_90)
    # ... cases 2-15
  ```

**Button/Input Routing:**
- Button handling uses `match` for dispatch:
  ```gdscript
  match button:
    MOUSE_BUTTON_LEFT:
      tetra_map.set_cell(cell, paint_source_id, paint_atlas_coords)
    MOUSE_BUTTON_RIGHT:
      tetra_map.erase_cell(cell)
  ```

## Deferred Calls

**Pattern:**
- Use `call_deferred()` to defer expensive operations until frame end:
  ```gdscript
  rebuild.call_deferred()
  _queue_rebuild()  # wraps this pattern
  ```
- Prevents multiple rebuild calls within a single frame

---

*Convention analysis: 2026-04-26*
