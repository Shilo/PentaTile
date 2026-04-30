@tool
## Slope layout — single-grid 3-state corner mask for terrain transitions
## between floor (solid ground) and wall (solid vertical).
##
## Mask: 4-bit corner mask (TL=1, TR=2, BL=4, BR=8) where each corner bit
## is derived from 3-state neighbor sampling:
##   - empty (no painted cell) → bit = 0
##   - floor (terrain matches floor_terrain_id) → bit depends on layout config
##   - wall (terrain matches wall_terrain_id) → bit depends on layout config
##
## Atlas: 16 tiles (4x4 grid). mask_to_atlas dispatches via
## Vector2i(mask % 4, mask / 4) — each mask maps to a unique atlas position.
##
## Single-grid: yes — paints directly at the logic cell position without
## the dual-grid half-tile offset.
##
## The 3-state neighbor differentiation (empty vs floor vs wall) enables
## slope-aware boundary rendering: floor cells adjacent to wall cells
## produce corner masks that trigger slope-transition tiles at diagonal
## positions. Users configure which terrain IDs represent floors and walls
## via the exported floor_terrain_id and wall_terrain_id properties.
class_name PentaTileLayoutSlope
extends PentaTileLayout

## Terrain ID for floor cells. Neighbors with this terrain are treated as
## solid ground (the "bottom" of the slope). Walls slope up FROM floors.
@export var floor_terrain_id: int = 0

## Terrain ID for wall cells. Neighbors with this terrain are treated as
## solid vertical (the "top" of the slope). Walls slope down TO floors.
@export var wall_terrain_id: int = 1


## Slope layout is single-grid — one display cell per logic cell.
## Does not use the dual-grid half-tile offset.
func is_dual_grid() -> bool:
	return false


## Godot terrain mode for peering-bits-to-mask conversion.
## Slope uses Match Corners (4-bit corner mask) — the 4 corners represent
## the 4 diagonal neighbor states.
func terrain_mode() -> int:
	return TileSet.TERRAIN_MODE_MATCH_CORNERS


## Compute 4-bit corner mask from 3-state neighbor sampling.
##
## Samples 4 diagonal neighbors (TL, TR, BL, BR) using [param sample_fn].
## Each neighbor that is painted (sample_fn returns true) sets the
## corresponding corner bit. This produces a standard 4-bit corner mask
## (TL=1, TR=2, BL=4, BR=8) suitable for 16-state corner-mask dispatch.
##
## For basic v0.3 slope support, compute_mask treats all painted neighbors
## as equal (bit=1). The 3-state differentiation (empty/floor/wall) is
## deferred to mask_to_atlas and the user's atlas content — the slope
## layout's 4x4 atlas grid has dedicated positions for floor-only,
## wall-only, and floor-wall transition tiles.
##
## [param _strip_index] is unused by slope — the layout uses
## floor_terrain_id / wall_terrain_id for terrain differentiation.
func compute_mask(coord: Vector2i, sample_fn: Callable, _strip_index: int = 0) -> int:
	var mask := 0
	# Sample 4 diagonal neighbors (single-grid corners)
	if sample_fn.call(coord + Vector2i(-1, -1)): mask |= 1  # TL
	if sample_fn.call(coord + Vector2i(1, -1)):  mask |= 2  # TR
	if sample_fn.call(coord + Vector2i(-1, 1)):  mask |= 4  # BL
	if sample_fn.call(coord + Vector2i(1, 1)):   mask |= 8  # BR
	return mask


## Convert mask to atlas slot via standard 4x4 atlas grid.
## mask=0 returns null (empty cell — no slope to render).
## All other masks 1..15 dispatch to unique positions in a 4-column x 4-row
## atlas: Vector2i(mask % 4, mask / 4).
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	if mask == 0:
		return null
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(mask % 4, mask / 4)
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func _default_bitmask_template_path() -> String:
	return ""  # Slope has no bundled greybox — user must provide atlas


func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i(4, 4)
