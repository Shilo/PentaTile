@tool
@icon("res://icon.svg")
class_name PentaTileMapLayer
extends TileMapLayer

const _PRIMARY_LAYER_NAME := "_PentaTileVisual"
const _OVERLAY_LAYER_NAME := "_PentaTileDiagonalOverlay"

@export var atlas_source_id: int = -1:
	set(value):
		atlas_source_id = value
		_queue_rebuild()

@export var atlas_contract: PentaTileAtlasContract:
	set(value):
		if atlas_contract == value:
			return                                                                  # idempotence guard (D-08, PITFALLS §5)
		if atlas_contract != null and atlas_contract.changed.is_connected(_on_contract_changed):
			atlas_contract.changed.disconnect(_on_contract_changed)
		atlas_contract = value
		if atlas_contract != null:
			atlas_contract.changed.connect(_on_contract_changed)
		_queue_rebuild()

@export_range(0.0, 1.0, 0.01) var logic_layer_opacity: float = 0.0:
	set(value):
		logic_layer_opacity = value
		_apply_logic_layer_opacity()

@export var visual_z_index_offset: int = 0:
	set(value):
		visual_z_index_offset = value
		_sync_visual_layers()

@export var generated_collision_enabled: bool = true:
	set(value):
		generated_collision_enabled = value
		_sync_visual_layers()

@export var logic_collision_enabled: bool = false:
	set(value):
		logic_collision_enabled = value
		_apply_logic_collision()

var _primary_layer: TileMapLayer
var _overlay_layer: TileMapLayer

# Debug-build instrumentation (Phase 1 Wave 0 — verifies CONTRACT-05 idempotence).
# Counts every _queue_rebuild() call in debug builds. Read by verification recipes
# (Plan 05 idempotence + signal-storm checks). Excluded from release builds via
# OS.is_debug_build() gate inside _queue_rebuild.
var _rebuild_count: int = 0

# Lazy singleton for null-contract fallback (D-07 / CONTRACT-04).
# Allocated once on first _resolve_layout() call when no contract is assigned.
# v0.1-style scenes (atlas_contract = null) get PentaTileLayoutPentaHorizontal
# behavior — output bit-identical to v0.1's HORIZONTAL atlas_layout.
static var _DEFAULT_LAYOUT: PentaTileLayout = null


func _ready() -> void:
	_ensure_visual_layers()
	_apply_logic_layer_opacity()
	_apply_logic_collision()
	rebuild.call_deferred()


func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	_ensure_visual_layers()
	if forced_cleanup or tile_set == null:
		_clear_visual_layers()
		return

	_sync_visual_layers()
	if coords.is_empty():
		rebuild()
		return

	var layout := _resolve_layout()
	var source := _resolve_source_id()
	if source == -1:
		return
	var sample_fn := Callable(self, "_has_logic_cell")

	var affected: Dictionary = {}
	if layout.is_dual_grid():
		for logic_cell: Vector2i in coords:
			_mark_affected_display_cells(affected, logic_cell)
	else:
		for logic_cell: Vector2i in coords:
			_mark_affected_single_grid_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_via_layout(display_cell, layout, source, sample_fn)


func rebuild() -> void:
	_ensure_visual_layers()
	_clear_visual_layers()
	if tile_set == null:
		return

	_sync_visual_layers()
	var layout := _resolve_layout()
	var source := _resolve_source_id()
	if source == -1:
		return
	var sample_fn := Callable(self, "_has_logic_cell")

	var affected: Dictionary = {}
	if layout.is_dual_grid():
		for logic_cell: Vector2i in get_used_cells():
			_mark_affected_display_cells(affected, logic_cell)
	else:
		for logic_cell: Vector2i in get_used_cells():
			_mark_affected_single_grid_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_via_layout(display_cell, layout, source, sample_fn)


# PRESERVED from v0.1 (line 101-105). Dual-grid affected-cells: 4 corner offsets.
func _mark_affected_display_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
	affected[logic_cell] = true
	affected[logic_cell + Vector2i.RIGHT] = true
	affected[logic_cell + Vector2i.DOWN] = true
	affected[logic_cell + Vector2i(1, 1)] = true


# NEW for D-06: Single-grid pipeline (logic and visual share the same grid).
# Marks cell + 4 cardinal neighbors. Phase 1 has no consumer (Penta H/V are dual-grid);
# Phase 2's Wang2Corner is the first consumer. Locked planner option (a) — ship the
# pipeline fully wired so Phase 2 layouts are pure subclass adds.
func _mark_affected_single_grid_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
	affected[logic_cell] = true
	affected[logic_cell + Vector2i.UP] = true
	affected[logic_cell + Vector2i.DOWN] = true
	affected[logic_cell + Vector2i.LEFT] = true
	affected[logic_cell + Vector2i.RIGHT] = true


# The dispatcher per affected display cell. Computes mask once, short-circuits
# on 0 (universal cleanup per PITFALLS §4), resolves slot, paints primary +
# optional overlay. Replaces v0.1's _paint_display_cell (lines 108-152) — the
# 16-state match relocated into PentaTileLayoutPentaHorizontal.mask_to_atlas.
func _paint_via_layout(display_cell: Vector2i, layout: PentaTileLayout, source: int, sample_fn: Callable) -> void:
	_primary_layer.erase_cell(display_cell)
	_overlay_layer.erase_cell(display_cell)

	var mask := layout.compute_mask(display_cell, sample_fn)
	if mask == 0:
		return                                                                      # universal short-circuit (PITFALLS §4)

	var slot := layout.mask_to_atlas(mask)
	if slot == null:
		return
	_paint_with_slot(_primary_layer, slot, display_cell, source)
	_paint_overlay_for_slot(slot, display_cell, source)


# Paints the primary slot. Replaces v0.1's _set_visual_cell (lines 172-179) —
# the slot now carries atlas_coords directly (no _atlas_coords axis dispatch
# — D-19 removed that helper; the layout owns the axis via _make_slot).
func _paint_with_slot(layer: TileMapLayer, slot: PentaTileAtlasSlot, display_cell: Vector2i, source: int) -> void:
	if slot == null:
		layer.erase_cell(display_cell)
		return
	# Phase 1 layouts: alternative_tile = 0 in transform_flags only. Plan 03's
	# PentaTileLayoutPentaHorizontal._make_slot writes pure transform flags here.
	layer.set_cell(display_cell, source, slot.atlas_coords, slot.transform_flags)


# Paints the optional overlay slot for diagonal masks (penta masks 6 and 9).
# The complement transform was packed into slot.alternative_tile by the layout's
# _make_slot via _pack_alternative(0, complement_transform). Phase 1 layouts use
# alt_id = 0 so alternative_tile == complement_transform.
func _paint_overlay_for_slot(slot: PentaTileAtlasSlot, display_cell: Vector2i, source: int) -> void:
	if slot == null or slot.diagonal_complement_atlas_coords == Vector2i(-1, -1):
		return
	var complement_transform := slot.alternative_tile
	_overlay_layer.set_cell(display_cell, source, slot.diagonal_complement_atlas_coords, complement_transform)


# PRESERVED from v0.1 (line 168-169). Logic-cell sampling for the layout's
# compute_mask Callable.
func _has_logic_cell(logic_cell: Vector2i) -> bool:
	return get_cell_source_id(logic_cell) != -1


# Lazy-singleton fallback (D-07, CONTRACT-04). When atlas_contract is null
# OR atlas_contract.layout is null, return a single shared PentaTileLayoutPentaHorizontal
# so v0.1-style scenes render bit-identically to v0.1 horizontal mode.
func _resolve_layout() -> PentaTileLayout:
	if atlas_contract != null and atlas_contract.layout != null:
		return atlas_contract.layout
	if _DEFAULT_LAYOUT == null:
		_DEFAULT_LAYOUT = PentaTileLayoutPentaHorizontal.new()
	return _DEFAULT_LAYOUT


func _resolve_source_id() -> int:
	if tile_set == null:
		return -1
	if atlas_source_id >= 0:
		return atlas_source_id
	if tile_set.get_source_count() == 0:
		return -1
	return tile_set.get_source_id(0)


# PRESERVED from v0.1 (line 198-203). Lazy visual-layer creation.
func _ensure_visual_layers() -> void:
	if _primary_layer == null or not is_instance_valid(_primary_layer):
		_primary_layer = _get_or_create_visual_layer(_PRIMARY_LAYER_NAME)
	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		_overlay_layer = _get_or_create_visual_layer(_OVERLAY_LAYER_NAME)
	_sync_visual_layers()


# PRESERVED from v0.1 (line 206-214). Helper for visual layer instantiation.
func _get_or_create_visual_layer(layer_name: StringName) -> TileMapLayer:
	var existing := get_node_or_null(NodePath(layer_name))
	if existing is TileMapLayer:
		return existing

	var layer := TileMapLayer.new()
	layer.name = layer_name
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


# PRESERVED from v0.1 (line 217-233) with one CHANGE: _visual_layer_offset()
# now branches on layout.is_dual_grid(). The function body itself is unchanged.
func _sync_visual_layers() -> void:
	_apply_logic_collision()
	for layer: TileMapLayer in [_primary_layer, _overlay_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.tile_set = tile_set
		layer.enabled = enabled
		layer.visible = true
		layer.z_index = visual_z_index_offset
		layer.rendering_quadrant_size = rendering_quadrant_size
		layer.y_sort_enabled = y_sort_enabled
		layer.y_sort_origin = y_sort_origin
		layer.x_draw_order_reversed = x_draw_order_reversed
		layer.collision_enabled = generated_collision_enabled
		layer.navigation_enabled = false
		layer.occlusion_enabled = false
		layer.position = _visual_layer_offset()


# CHANGED from v0.1: branches on the active layout's is_dual_grid().
# Dual-grid: -tile_size/2 (preserves v0.1 behavior).
# Single-grid: Vector2.ZERO (no half-tile shift; the cell lives at its own logic position).
func _visual_layer_offset() -> Vector2:
	if tile_set == null:
		return Vector2.ZERO
	var layout := _resolve_layout()
	if not layout.is_dual_grid():
		return Vector2.ZERO
	return Vector2(tile_set.tile_size) * -0.5


# PRESERVED from v0.1 (line 242-245).
func _clear_visual_layers() -> void:
	for layer: TileMapLayer in [_primary_layer, _overlay_layer]:
		if layer != null and is_instance_valid(layer):
			layer.clear()


# PRESERVED VERBATIM from v0.1 (line 248-251). PITFALLS §7 mitigation —
# logic layer is hidden via self_modulate.a, never `visible = false`.
func _apply_logic_layer_opacity() -> void:
	var color := self_modulate
	color.a = logic_layer_opacity
	self_modulate = color


# PRESERVED from v0.1 (line 254-255).
func _apply_logic_collision() -> void:
	collision_enabled = logic_collision_enabled


# PRESERVED from Plan 01 Task 0.3 (Wave 0 instrumentation).
func _queue_rebuild() -> void:
	if OS.is_debug_build():
		_rebuild_count += 1
	if is_inside_tree():
		rebuild.call_deferred()


# Receives Resource.changed from atlas_contract or its sub-Resources (layout)
# via the CONTRACT-05 disconnect-before-reconnect pattern. Coalesces via
# _queue_rebuild's call_deferred — multiple emissions per frame collapse to
# one rebuild.
func _on_contract_changed() -> void:
	_queue_rebuild()
