@tool
## Abstract base for all TetraTile layout topologies.
##
## Subclasses implement compute_mask + mask_to_atlas + is_dual_grid. Each layout
## owns its mask topology (which neighbors / corners / edges feed bits) and its
## slot resolution (mask -> AtlasSlot).
##
## See:
##   - .planning/research/layouts/MASK_UNIFICATION.md §3 (Approach B selection)
##   - .planning/research/layouts/TEMPLATE_CONVENTIONS.md §5 (dual-grid declaration)
##   - .planning/research/PITFALLS.md §3 (_pack_alternative recipe)
class_name TetraTileLayout
extends Resource

@export var template_image: Texture2D                        # PREVIEW-01: stock inspector preview
@export var fallback_tile_set: TileSet                       # LAYOUT-03: declared, consumed in Phase 4
@export_multiline var description: String = ""               # D-22: multiline
@export var decoder_image: Texture2D                         # optional override (consumed Phase 4+)

# Back-reference to the owning AtlasContract.
# Set by TetraTileAtlasContract.layout setter via _set_contract(self).
# WeakRef to prevent cycle (AtlasContract owns layout -> layout would otherwise own AtlasContract).
# Consumed by Phase 3.5 PixelLab variation pick: layout._contract.get_ref().variation_seed.
# Phase 1 declares but does not exercise.
var _contract: WeakRef = null


func compute_mask(_coord: Vector2i, _sample_fn: Callable) -> int:
	push_error("TetraTileLayout.compute_mask is abstract; subclass must override.")
	return 0


func mask_to_atlas(_mask: int) -> TetraTileAtlasSlot:
	push_error("TetraTileLayout.mask_to_atlas is abstract; subclass must override.")
	return null


func is_dual_grid() -> bool:
	push_error("TetraTileLayout.is_dual_grid is abstract; subclass must override.")
	return true


# PITFALLS.md §3 + LAYOUT-05: alt-id and TRANSFORM_FLIP_* flags share one int.
# `alternative_tile` low bits go below 4096; transform flags are >= 4096.
# Always OR via this helper; assert prevents silent collision.
func _pack_alternative(alt_id: int, transform_flags: int) -> int:
	assert(alt_id < 4096, "alternative_tile alt_id must be < 4096; flags share the int")
	return alt_id | transform_flags


# Called by TetraTileAtlasContract.layout setter to wire the back-reference.
# Phase 3.5's PixelLab layouts read variation_seed via _contract.get_ref().variation_seed.
func _set_contract(contract: Resource) -> void:
	if contract == null:
		_contract = null
	else:
		_contract = weakref(contract)
