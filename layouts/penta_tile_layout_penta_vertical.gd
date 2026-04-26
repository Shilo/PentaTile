@tool
## PentaTile vertical layout — same archetypes as horizontal, arranged in a 1×4 atlas.
##
## Output is bit-identical to v0.1's `atlas_layout = AtlasLayout.VERTICAL` mode.
## Subclasses PentaTileLayoutPentaHorizontal and overrides ONLY _make_slot (the
## atlas-axis-swap helper). compute_mask, mask_to_atlas, is_dual_grid, and all
## constants are inherited unchanged — the 16-state match table is shared.
##
## Per PATTERNS.md anti-pattern #4: this MUST extend Horizontal, not the base.
## That keeps the 16-state match as a single source of truth and the file under 35 LOC.
class_name PentaTileLayoutPentaVertical
extends PentaTileLayoutPentaHorizontal


# Override _make_slot to lay tiles along the y-axis instead of the x-axis.
# Equivalent to v0.1's `if atlas_layout == AtlasLayout.VERTICAL: return Vector2i(0, tile_index)`.
func _make_slot(
		tile_index: int,
		transform_flags: int,
		complement_tile_index: int = -1,
		complement_transform: int = 0) -> PentaTileAtlasSlot:
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(0, tile_index)                                   # vertical: y-axis
	slot.transform_flags = transform_flags
	slot.alternative_tile = 0
	if complement_tile_index >= 0:
		slot.diagonal_complement_atlas_coords = Vector2i(0, complement_tile_index)
		slot.alternative_tile = _pack_alternative(0, complement_transform)
	return slot
