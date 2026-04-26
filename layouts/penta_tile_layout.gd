@tool
## Abstract base for all PentaTile layout topologies.
##
## Subclasses implement compute_mask + mask_to_atlas + is_dual_grid. Each layout
## owns its mask topology (which neighbors / corners / edges feed bits) and its
## slot resolution (mask -> AtlasSlot).
##
## See:
##   - .planning/research/layouts/MASK_UNIFICATION.md §3 (Approach B selection)
##   - .planning/research/layouts/TEMPLATE_CONVENTIONS.md §5 (dual-grid declaration)
##   - .planning/research/PITFALLS.md §3 (_pack_alternative recipe)
class_name PentaTileLayout
extends Resource

@export var bitmask_template: Texture2D                      # PREVIEW-01 / LAYOUT-03: stock inspector preview AND fallback TileSet source pixels (single PNG, both roles)
@export_multiline var description: String = ""               # D-22: multiline


func compute_mask(_coord: Vector2i, _sample_fn: Callable) -> int:
	push_error("PentaTileLayout.compute_mask is abstract; subclass must override.")
	return 0


func mask_to_atlas(_mask: int) -> PentaTileAtlasSlot:
	push_error("PentaTileLayout.mask_to_atlas is abstract; subclass must override.")
	return null


func is_dual_grid() -> bool:
	push_error("PentaTileLayout.is_dual_grid is abstract; subclass must override.")
	return true


# PITFALLS.md §3 + LAYOUT-05: alt-id and TRANSFORM_FLIP_* flags share one int.
# `alternative_tile` low bits go below 4096; transform flags are >= 4096.
# Always OR via this helper; assert prevents silent collision.
func _pack_alternative(alt_id: int, transform_flags: int) -> int:
	assert(alt_id < 4096, "alternative_tile alt_id must be < 4096; flags share the int")
	return alt_id | transform_flags


# LAYOUT-06: virtual TileSet codegen path. Default returns null in Wave 1;
# Wave 2 fills the body to construct a TileSet from `bitmask_template`.
# Subclasses can override for custom logic.
# Consumer (PentaTileMapLayer) calls this when tile_set == null (PREVIEW-03 wired in Phase 4).
func get_fallback_tile_set() -> TileSet:
	return null
