@tool
## PentaTile horizontal layout — 4 archetypes (Fill / Inner Corner / Border / Outer Corner)
## arranged in a 4×1 atlas with rotation reuse.
##
## Output is bit-identical to v0.1's `atlas_layout = AtlasLayout.HORIZONTAL` mode.
## The 16-state match block was relocated VERBATIM from
## addons/penta_tile/penta_tile_map_layer.gd:116-152 (v0.1 source).
##
## Mask convention: TL=1, TR=2, BL=4, BR=8 (corner mask).
## Dual-grid: yes — paints at the half-tile-offset display cell.
class_name PentaTileLayoutPentaHorizontal
extends PentaTileLayout

# Tile indices in the 4×1 atlas (relocated from v0.1 layer lines 11-14).
const _FILL := 0
const _INNER_CORNER := 1
const _BORDER := 2
const _OUTER_CORNER := 3

# Transform-flag rotations (relocated from v0.1 layer lines 16-19).
const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

# Corner-neighbor offsets (relocated from v0.1 layer lines 21-24).
const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)


func is_dual_grid() -> bool:
	return true


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _TL):
		mask |= 1
	if sample_fn.call(coord + _TR):
		mask |= 2
	if sample_fn.call(coord + _BL):
		mask |= 4
	if sample_fn.call(coord + _BR):
		mask |= 8
	return mask


func mask_to_atlas(mask: int) -> PentaTileAtlasSlot:
	# The 16-state table — v0.1 layer lines 116-152 relocated.
	# Mask 0 returns null (dispatcher short-circuits to erase).
	# Masks 6 and 9 use diagonal_complement_atlas_coords for the overlay layer.
	match mask:
		0:
			return null
		1:
			return _make_slot(_OUTER_CORNER, _ROTATE_90)
		2:
			return _make_slot(_OUTER_CORNER, _ROTATE_180)
		3:
			return _make_slot(_BORDER, _ROTATE_180)
		4:
			return _make_slot(_OUTER_CORNER, _ROTATE_0)
		5:
			return _make_slot(_BORDER, _ROTATE_90)
		6:
			# Diagonal: primary on _primary_layer, complement on _overlay_layer.
			# The dispatcher reads diagonal_complement_atlas_coords and paints to overlay
			# with the SAME transform packed in alternative_tile field for the overlay paint.
			# The complement transform is _ROTATE_0 (per v0.1 line 132).
			return _make_slot(_OUTER_CORNER, _ROTATE_180, _OUTER_CORNER, _ROTATE_0)
		7:
			return _make_slot(_INNER_CORNER, _ROTATE_90)
		8:
			return _make_slot(_OUTER_CORNER, _ROTATE_270)
		9:
			# Diagonal — complement transform is _ROTATE_270 (per v0.1 line 140).
			return _make_slot(_OUTER_CORNER, _ROTATE_90, _OUTER_CORNER, _ROTATE_270)
		10:
			return _make_slot(_BORDER, _ROTATE_270)
		11:
			return _make_slot(_INNER_CORNER, _ROTATE_180)
		12:
			return _make_slot(_BORDER, _ROTATE_0)
		13:
			return _make_slot(_INNER_CORNER, _ROTATE_0)
		14:
			return _make_slot(_INNER_CORNER, _ROTATE_270)
		15:
			return _make_slot(_FILL, _ROTATE_0)
	# Unreachable mask (>15 — corner mask is 4 bits).
	push_error("PentaTileLayoutPentaHorizontal.mask_to_atlas got out-of-range mask %d" % mask)
	return null


# Build an AtlasSlot for the horizontal axis (4×1 atlas: x = tile_index, y = 0).
# Subclasses (e.g. PentaTileLayoutPentaVertical) override _make_slot to swap axes.
# Per CONTEXT.md D-04: the alt-tile slot of `transform_flags` is reserved for transform
# flags only in Phase 1; Phase 3.5 PixelLab variation work uses _pack_alternative
# to put both alt-id and flags in there. Phase 1 layouts pass alt_id = 0 (no variation).
func _make_slot(
		tile_index: int,
		transform_flags: int,
		complement_tile_index: int = -1,
		complement_transform: int = 0) -> PentaTileAtlasSlot:
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(tile_index, 0)                                   # horizontal: x-axis
	slot.transform_flags = transform_flags
	slot.alternative_tile = 0                                                     # Phase 1: no variation
	if complement_tile_index >= 0:
		slot.diagonal_complement_atlas_coords = Vector2i(complement_tile_index, 0)
		# The dispatcher reads the complement transform from alternative_tile when
		# the overlay paint occurs. Phase 1 packs ONLY transform there for the
		# overlay path (alt = 0 + transform); _pack_alternative is the formal helper.
		slot.alternative_tile = _pack_alternative(0, complement_transform)
	# else: leave diagonal_complement_atlas_coords at default (-1, -1) — sentinel.
	return slot
