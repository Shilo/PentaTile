@tool
## A single atlas-slot record. Returned by PentaTileLayout.mask_to_atlas
## and consumed by PentaTileMapLayer._paint_with_slot.
##
## Fields:
##   atlas_coords   - the (x, y) coords of the slot in the TileSetAtlasSource grid.
##   transform_flags - TileSetAtlasSource.TRANSFORM_FLIP_H / FLIP_V / TRANSPOSE OR'd together.
##   alternative_tile - alt-tile id (must be < 4096; shares int with transform flags per PITFALLS §3).
class_name PentaTileAtlasSlot
extends Resource

@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var transform_flags: int = 0
@export var alternative_tile: int = 0
