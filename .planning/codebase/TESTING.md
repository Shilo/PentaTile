# Testing Patterns

**Analysis Date:** 2026-04-26

## Test Framework

**Status:** Not configured

No formal test framework is currently integrated into this project. No test runner, assertion library, or test directory structure exists.

**Available Testing Approaches for Godot:**
- GUT (Godot Unit Test) - community testing framework
- GdUnit4 - newer testing framework for Godot 4
- Built-in `@test` decorator (Godot 4.1+)

## Test File Organization

**Current State:** No test files present.

**Recommended Structure** (if testing is added):
```
PentaTile/
├── addons/
│   └── penta_tile/
│       ├── penta_tile_map_layer.gd
│       ├── tests/                     # Test directory (new)
│       │   ├── test_penta_tile_map_layer.gd
│       │   └── test_mask_calculations.gd
│       └── demo/
```

**Naming Convention:** Test files should follow `test_*.gd` pattern if implemented.

## Testing Gaps

**Critical untested areas:**

1. **Mask Calculation Logic** (`_mask_at()` in `penta_tile_map_layer.gd`, lines 155-165)
   - 4-bit neighbor detection for 16 possible tile states
   - Directional logic: top-left, top-right, bottom-left, bottom-right quadrant checks
   - All 16 mask values (0-15) should be validated

2. **Tile Painting Logic** (`_paint_display_cell()` in `penta_tile_map_layer.gd`, lines 108-152)
   - 16-case match statement covering all mask scenarios
   - Special handling for diagonal masks (6 and 9) requiring two-layer composition
   - Visual cell correctness with proper rotation transforms

3. **Coordinate Transformation** (`_atlas_coords()` in `penta_tile_map_layer.gd`, lines 182-185)
   - Horizontal vs. vertical atlas layout support
   - Vector2i correctness for both layouts

4. **Layer Management** (`_ensure_visual_layers()` and `_get_or_create_visual_layer()`, lines 198-214)
   - Visual layer creation on first access
   - Layer validity checking after potential scene cleanup
   - Internal layer naming and initialization

5. **Rebuild Workflow** (`rebuild()` in `penta_tile_map_layer.gd`, lines 86-98)
   - Full cell regeneration from logic layer
   - Affected cell tracking
   - Proper cleanup and repainting

6. **Property Setters** (lines 26-54)
   - Each `@export` property setter triggers appropriate side effects
   - `_queue_rebuild()` deferred execution
   - Layer opacity and collision synchronization

7. **Runtime Painting** (`demo_runtime_painter.gd`)
   - Mouse button handling (left = place, right = erase)
   - Drag painting (continuous application while mouse held)
   - Cell coordinate tracking to avoid duplicate application

8. **Physics Integration** (`demo_player.gd`)
   - Gravity application
   - Jump velocity
   - Movement input handling
   - Collision detection with generated visual layers

## Manual Testing Approach

**Current Validation Method:** Visual testing in Godot editor

**Demo Scene:** `addons/penta_tile/demo/penta_tile_demo.tscn`

**Test Procedure:**
1. Open demo scene in Godot 4.6
2. Run the scene (F5 or Play button)
3. Use arrow keys to move the player
4. Use spacebar or Up arrow to jump
5. Left-click to paint tiles
6. Right-click to erase tiles
7. Verify:
   - Dual-grid visual updates correctly
   - Collision geometry matches visual tiles
   - Diagonal transitions render properly with two-layer composition
   - Physics responds to collisions

## Implementation Notes for Future Testing

**Unit Test Approach:**
```gdscript
# Pseudocode for mask calculation testing
func test_mask_at_empty_neighbors():
  # Cell with no neighbors should return 0
  var mask = penta_tile._mask_at(Vector2i(0, 0))
  assert_equal(mask, 0)

func test_mask_at_all_neighbors():
  # Cell surrounded by neighbors should return 15 (all 4 bits set)
  var mask = penta_tile._mask_at(Vector2i(0, 0))
  assert_equal(mask, 15)

func test_mask_quadrants():
  # Validate individual quadrant contributions
  # bit 1 = top-left, 2 = top-right, 4 = bottom-left, 8 = bottom-right
```

**Integration Test Approach:**
```gdscript
# Pseudocode for painting workflow
func test_set_cell_updates_visuals():
  var penta_tile = PentaTileMapLayer.new()
  penta_tile.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
  # Verify _update_cells() was called
  # Verify visual layers contain expected tiles
```

**Fixtures:**
- Demo scene provides basic fixture setup
- Complex mask scenarios would benefit from parameterized test data

## Coverage Gaps

**Not Measured:** No coverage metrics exist.

**Priority Areas for Testing (High → Low):**
1. High: Mask calculation algorithm (16 states, bitwise logic)
2. High: Tile painting match statement (special diagonal handling)
3. Medium: Layer management and validity checking
4. Medium: Property setter side effects
5. Low: Simple physics/movement (uses Godot built-ins)

## Mocking Considerations

**What to Mock (if testing is added):**
- `TileMapLayer` operations for isolated mask/paint testing
- `TileSet` reference to test null-safety paths
- Scene tree operations for layer creation

**What NOT to Mock:**
- Core algorithm logic (mask calculation, tile selection)
- Vector/coordinate calculations
- The dual-grid composition logic

## Error Paths

**Untested error conditions:**
- `tile_set == null` paths
- Invalid `atlas_source_id` values
- Missing visual layers after node cleanup
- Deferred rebuild queueing under rapid property changes

---

*Testing analysis: 2026-04-26*
