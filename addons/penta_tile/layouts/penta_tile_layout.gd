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


# Returns true if this layout needs synthesis (i.e. is a PentaTileLayoutPenta instance).
# Default false. PentaTileLayoutPenta overrides to return true in Wave 3.
# Used by PentaTileMapLayer._ensure_visual_layers to branch without a forward type reference.
func needs_synthesis() -> bool:
	return false


# PITFALLS.md §3 + LAYOUT-05: alt-id and TRANSFORM_FLIP_* flags share one int.
# `alternative_tile` low bits go below 4096; transform flags are >= 4096.
# Always OR via this helper; assert prevents silent collision.
func _pack_alternative(alt_id: int, transform_flags: int) -> int:
	assert(alt_id < 4096, "alternative_tile alt_id must be < 4096; flags share the int")
	return alt_id | transform_flags


var _cached_fallback_tile_set: TileSet = null

# LAYOUT-06 / PREVIEW-02: build a TileSet from `bitmask_template` at first call, cached.
# Subclasses can override for custom logic (e.g. the Penta layout's per-mode lookup).
# Default impl: 1 source × 1 atlas with the `bitmask_template` PNG; warns on first call
# because the base class cannot know the correct grid size — subclasses must override.
# Consumer (PentaTileMapLayer) calls this when tile_set == null (PREVIEW-03 wired in Phase 4).
func get_fallback_tile_set() -> TileSet:
	if _cached_fallback_tile_set != null:
		return _cached_fallback_tile_set
	if bitmask_template == null:
		return null
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = bitmask_template
	# Subclasses override texture_region_size + create_tile() loops per their grid.
	# Base impl leaves src empty so this warning fires on first call, surfacing the
	# override-missing condition rather than silently rendering nothing.
	ts.add_source(src, 0)
	_cached_fallback_tile_set = ts
	push_warning("PentaTileLayout.get_fallback_tile_set called on base; subclass should override.")
	return _cached_fallback_tile_set
