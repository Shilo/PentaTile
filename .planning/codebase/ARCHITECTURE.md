# Architecture

**Analysis Date:** 2026-04-26

## Pattern Overview

**Overall:** Dual-Grid Autotiling with Composition-Based Diagonal Handling

**Key Characteristics:**
- Single public API class (`TetraTileMapLayer`) that extends Godot's native `TileMapLayer`
- Dual-grid system: logic layer (user-editable) + primary visual layer + overlay visual layer for diagonals
- Four-tile source atlas (Fill, Inner Corner, Border, Outer Corner) with transform-based rotations
- Marching-squares mask-based tile selection (16 possible states)
- Overlay layer composition for disconnected diagonal states (masks 6 and 9)
- Lean implementation: no persistent caches, no signal fanout, no watchers

## Layers

**Logic Layer (`TetraTileMapLayer`):**
- Purpose: User-facing tile map where cells are painted/erased with standard Godot API
- Location: `addons/tetra_tile/tetra_tile_map_layer.gd` (class definition)
- Contains: Editor paintable cells, collision properties, exported configuration
- Depends on: Godot's `TileMapLayer` base class, TileSet definitions
- Used by: Demo painter script, user code via `set_cell()` and `erase_cell()`

**Primary Visual Layer (`_TetraTileVisual`):**
- Purpose: Main rendered layer with generated tiles based on logic cell configuration
- Location: Internal `TileMapLayer` created at runtime (line 200 in tetra_tile_map_layer.gd)
- Contains: Generated visual tiles positioned at offset coordinates (dual-grid corners)
- Depends on: Logic layer cell state, TileSet with physics polygons
- Used by: Godot rendering and physics pipeline

**Overlay Visual Layer (`_TetraTileDiagonalOverlay`):**
- Purpose: Composition layer for disconnected diagonal states (when two diagonally opposite quadrants are filled)
- Location: Internal `TileMapLayer` created at runtime (line 201 in tetra_tile_map_layer.gd)
- Contains: Second outer-corner tile for masks 6 (TR+BL) and 9 (TL+BR)
- Depends on: Mask calculation, primary layer positioning
- Used by: Godot rendering pipeline for composite diagonal rendering

## Data Flow

**Paint/Erase Workflow:**

1. User calls `set_cell(logic_coord, source, atlas_coords)` or `erase_cell(logic_coord)` on `TetraTileMapLayer`
2. Godot's internal `TileMapLayer` queues update
3. `_update_cells(coords, forced_cleanup)` override is invoked with affected logic coordinates
4. Four affected display cells are calculated per logic change (logic cell + 3 neighbors form 4 visual cells)
5. For each display cell: mask is calculated (4-bit sample of adjacent logic cells)
6. Mask determines tile selection and transforms from 16-state table
7. Diagonal masks (6 and 9) trigger dual-layer composition
8. Visual layers receive `set_cell()` calls with computed source, atlas coords, and transforms
9. Godot renders both visual layers; physics is pulled from TileSet polygons

**Rebuild Workflow:**

1. User calls `rebuild()` or property change triggers `_queue_rebuild()`
2. Visual layers are cleared
3. All used logic cells are iterated
4. Same mask → visual cell painting logic applies across entire map
5. Completes in-frame update with `call_deferred()` safety during `_ready()`

**State Management:**
- No persistent cache of tile states; masks are sampled on-demand from `get_cell_source_id()`
- Visibility toggling uses `self_modulate.a` (opacity) not `visible` property to prevent Godot cleanup behavior
- Visual layer positioning is managed via `_visual_layer_offset()`: offset by `-tile_size / 2` for dual-grid alignment

## Key Abstractions

**Mask Calculation (4-bit Integer):**
- Purpose: Represents the occupancy of four quadrants around a display cell
- Examples: `_mask_at()` method (line 155), sampled from logic layer at TL/TR/BL/BR offsets
- Pattern: Bit flags encoding quadrant presence; enables O(1) tile lookup in 16-state table

**Atlas Layout Support:**
- Purpose: Accommodates horizontal (4x1) or vertical (1x4) tile source arrangements
- Examples: `atlas_layout` enum and `_atlas_coords()` method (line 182)
- Pattern: Configuration-driven coordinate mapping; allows asset flexibility

**Transform Constants:**
- Purpose: Godot's atlas source transform flags for tile rotations
- Examples: `_ROTATE_0`, `_ROTATE_90`, `_ROTATE_180`, `_ROTATE_270` (lines 16-19)
- Pattern: Bitwise flags combined for 90° rotations (TRANSPOSE + FLIP_H/V combinations)

**Visual Layer Management:**
- Purpose: Dynamic internal TileMapLayer creation and property synchronization
- Examples: `_ensure_visual_layers()` (line 198), `_sync_visual_layers()` (line 217)
- Pattern: Lazy initialization with validity checks; synchronizes rendering properties on every update

## Entry Points

**Main Entry: `tetra_tile_demo.tscn`:**
- Location: `res://addons/tetra_tile/demo/tetra_tile_demo.tscn`
- Triggers: Godot editor "Run" or command line
- Responsibilities: Initializes demo scene with tilemap, player, painter, and camera

**Runtime API:**
- `TetraTileMapLayer.set_cell(coords, source, atlas_coords, transform)` - Place tiles (inherited from TileMapLayer)
- `TetraTileMapLayer.erase_cell(coords)` - Remove tiles (inherited from TileMapLayer)
- `TetraTileMapLayer.rebuild()` - Force full rebuild of visual layers (public helper)

**Internal Hooks:**
- `_ready()` - Initialize visual layers and apply properties
- `_update_cells(coords, forced_cleanup)` - Main update interception point called by Godot
- Property setters - Trigger deferred rebuilds or property sync on configuration changes

## Error Handling

**Strategy:** Graceful degradation with validity checks

**Patterns:**
- Null/invalid checks on `tile_set`, `_primary_layer`, `_overlay_layer` before operations (lines 199-202)
- Source ID resolution with fallback: explicit ID → first source in set → -1 (error state)
- Forced cleanup when TileSet is null clears visual layers and returns early (lines 69-71)
- Exported property setters defer operations to frame end to avoid mid-frame instability

## Cross-Cutting Concerns

**Logging:** None - design prioritizes performance; no console output or debug logging

**Validation:** Implicit through property exports - Godot editor validates atlas layout and ID ranges

**Collision Management:** 
- Visual layer collision enabled/disabled via `generated_collision_enabled` property
- Physics shapes inherited from TileSet atlas source definitions (see `tetra_tile_ground.tres`)
- Logic layer collision controlled separately via `logic_collision_enabled` (default false, hides full-cell blockers)

**Performance Optimization:**
- No tile caches or terrain tries (vs TileMapDual architecture)
- Direct 4-bit mask sampling; O(1) per display cell
- Update batching at frame end via Godot's native `_update_cells` mechanism
- Overlay layer only rendered for 2 of 16 states (masks 6 and 9)

---

*Architecture analysis: 2026-04-26*
