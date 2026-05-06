class_name TyleMapEditor
extends CanvasLayer

enum ActivationEdge { TOP, BOTTOM, LEFT, RIGHT }

const DEFAULT_INPUT_BINDINGS := {
	"tyle_select": KEY_S,
	"tyle_draw": KEY_D,
	"tyle_line": KEY_L,
	"tyle_rect": KEY_R,
	"tyle_fill": KEY_B,
	"tyle_pick": KEY_P,
	"tyle_erase": KEY_E,
}

const PANEL_SCENE_FILE := "tyle_map_editor_panel.tscn"
const RUNTIME_SETTINGS_PATH := "user://tyle_map_editor.cfg"
const RUNTIME_SETTINGS_SECTION := "runtime"
const RUNTIME_DOCK_EDGE_KEY := "activation_edge"
const RUNTIME_SELECTED_LAYER_KEY := "selected_layer"
const RUNTIME_DOCK_SIZE_PREFIX := "dock_axis_size_"
const _RUNTIME_HIGHLIGHT_DEFAULT := 0
const _RUNTIME_HIGHLIGHT_ABOVE := 1
const _RUNTIME_HIGHLIGHT_BELOW := 2
const _ZOOM_STEP := 1.1
const _MIN_CAMERA_ZOOM := 0.05
const _MAX_CAMERA_ZOOM := 64.0

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_inside_tree() and _split:
			_split.visible = enabled

@export var activation_edge: ActivationEdge = ActivationEdge.BOTTOM:
	set(value):
		activation_edge = value
		if is_inside_tree():
			_sync_panel_dock_edge()
			_layout_dock()
			_save_runtime_settings()

@export_range(1, 256, 1, "or_greater") var activation_thickness_px: int = 12
@export_range(0.0, 2.0, 0.01) var animation_duration: float = 0.2
@export var showing: bool = false:
	set(value):
		_showing = value
		if is_inside_tree():
			_apply_showing(value, true)
	get:
		return _showing

@export var excluded_controls: Array[NodePath] = []
@export var excluded_rects: Array[Rect2] = []
@export var discover_root_path: NodePath
@export var install_default_input_actions: bool = false
@export var viewport_navigation: bool = true:
	set(value):
		viewport_navigation = value
		if not is_inside_tree():
			return
		if viewport_navigation and showing:
			_activate_navigation_camera()
		else:
			_deactivate_navigation_camera()
@export var title: String = "":
	set(value):
		title = value
		if is_inside_tree():
			_sync_panel_title()

var _split: SplitContainer
var _game_area: Control
var _panel_container: PanelContainer
var _panel_margin: MarginContainer
var _panel: Control
var _undo_redo := UndoRedo.new()
var _layers: Array[TileMapLayer] = []
var _runtime_highlight_original_modulates: Dictionary = {}
var _runtime_selected_layer_path := ""
var _runtime_dock_axis_sizes: Dictionary = {}
var _runtime_settings_loaded := false
var _loading_runtime_settings := false
var _navigation_camera: Camera2D
var _previous_camera: Camera2D
var _navigation_panning := false
var _navigation_cursor_active := false
var _showing := false
var _hover_armed := true
var _tween: Tween


class GameArea extends Control:
	var host: TyleMapEditor

	func _draw() -> void:
		if host:
			host._draw_runtime_overlay(self)


func _ready() -> void:
	layer = 100
	_load_runtime_settings()
	if install_default_input_actions:
		_setup_default_input_actions()

	_build_nodes()
	get_viewport().size_changed.connect(_layout_dock)
	refresh_layers()
	_layout_dock()
	_apply_showing(showing, false)


func _process(_delta: float) -> void:
	if not enabled or showing:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var in_zone := _is_in_activation_zone(mouse_pos)
	if not in_zone:
		_hover_armed = true
		return
	if _hover_armed and not _is_excluded_position(mouse_pos):
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not showing or not _panel:
		return
	if _handle_viewport_navigation_input(event):
		get_viewport().set_input_as_handled()
		_queue_overlay_redraw()
		return
	if _panel.canvas_input(event):
		get_viewport().set_input_as_handled()
		_queue_overlay_redraw()


func refresh_layers() -> void:
	_layers.clear()
	var root := _get_discover_root()
	if root:
		_collect_visible_tilemap_layers(root, _layers)
	if _panel:
		if _panel.tilemap == null or not _layers.has(_panel.tilemap):
			var persisted_layer := _find_persisted_selected_layer(root)
			_panel.tilemap = persisted_layer if persisted_layer else (_layers[0] if not _layers.is_empty() else null)
		_panel.about_to_be_visible()
	_apply_runtime_layer_highlighting()


func set_tilemap(layer: TileMapLayer) -> void:
	if not _panel:
		return
	if layer and not _layers.has(layer):
		_layers.append(layer)
	_panel.tilemap = layer
	_save_selected_layer(layer)
	_panel.about_to_be_visible()
	_apply_runtime_layer_highlighting()
	_queue_overlay_redraw()


func set_editing_enabled(value: bool) -> void:
	enabled = value


func open(animated: bool = true) -> void:
	_apply_showing(true, animated)


func close(animated: bool = true) -> void:
	_apply_showing(false, animated)


func _apply_showing(value: bool, animated: bool) -> void:
	_showing = value
	if value and not enabled:
		return
	_hover_armed = not _is_in_activation_zone(get_viewport().get_mouse_position())
	if value:
		_hover_armed = true
		if _panel:
			_panel.about_to_be_visible()
		_layout_dock()
		if viewport_navigation:
			_activate_navigation_camera()
		_apply_runtime_layer_highlighting()
		_show_panel(animated)
	elif _panel:
		_panel.canvas_mouse_exited()
		_navigation_panning = false
		_set_navigation_drag_cursor(false)
		_deactivate_navigation_camera()
		_clear_runtime_layer_highlighting()
		_hide_panel(animated)


func undo() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		_queue_overlay_redraw()


func redo() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		_queue_overlay_redraw()


func _build_nodes() -> void:
	_split = SplitContainer.new()
	_split.name = "SplitContainer"
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.dragging_enabled = true
	_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split.visible = enabled
	_split.dragged.connect(_on_split_dragged)
	add_child(_split)

	_game_area = GameArea.new()
	_game_area.name = "GameArea"
	_game_area.host = self
	_game_area.clip_contents = false
	_game_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_area.z_index = -1
	_game_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_panel_container = PanelContainer.new()
	_panel_container.name = "TyleMapEditorPanelContainer"
	_panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_container.clip_contents = true
	_panel_container.z_index = 1
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_panel_margin = MarginContainer.new()
	_panel_margin.name = "MarginContainer"
	_panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_container.add_child(_panel_margin)

	var panel_scene := _load_panel_scene()
	if panel_scene == null:
		push_error("TyleMapEditor: failed to load panel scene from addon directory.")
		return
	_panel = panel_scene.instantiate()
	_panel.runtime_mode = true
	_panel.undo_manager = _undo_redo
	_panel.layer_provider = Callable(self, "_get_layers_for_panel")
	_panel.layer_selected_callback = Callable(self, "_on_panel_layer_selected")
	_panel.canvas_transform_provider = Callable(self, "_get_canvas_transform_for_panel")
	_panel.viewport_size_provider = Callable(self, "_get_viewport_size_for_panel")
	_panel.runtime_highlight_changed_callback = Callable(self, "_apply_runtime_layer_highlighting")
	_panel.runtime_dock_edge = int(activation_edge)
	_panel.runtime_title = title
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.update_overlay.connect(_queue_overlay_redraw)
	if _panel.has_signal("close_requested"):
		_panel.close_requested.connect(close)
	if _panel.has_signal("dock_edge_requested"):
		_panel.dock_edge_requested.connect(_on_panel_dock_edge_requested)
	_panel_margin.add_child(_panel)
	_configure_split_children()
	call_deferred("_configure_split_drag_areas")
	call_deferred("_sync_panel_size_to_container")
	call_deferred("_sync_panel_title")
	call_deferred("_layout_dock")


func _load_panel_scene() -> PackedScene:
	var script := get_script() as Script
	if script == null or script.resource_path.is_empty():
		return null
	var scene_path := script.resource_path.get_base_dir().path_join(PANEL_SCENE_FILE)
	return load(scene_path) as PackedScene


func _layout_dock() -> void:
	if not _split:
		return
	_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split.vertical = activation_edge == ActivationEdge.TOP or activation_edge == ActivationEdge.BOTTOM
	_sync_panel_dock_edge()
	_configure_split_children()
	if _panel:
		_panel.custom_minimum_size = Vector2.ZERO
		_apply_panel_size_flags()
	_apply_split_offset()
	_queue_overlay_redraw()


func _panel_should_be_first() -> bool:
	return activation_edge == ActivationEdge.TOP or activation_edge == ActivationEdge.LEFT


func _configure_split_children() -> void:
	if not _split or not _panel_container or not _game_area:
		return
	var desired := [_panel_container, _game_area] if _panel_should_be_first() else [_game_area, _panel_container]
	if _split.get_child_count() == desired.size() and _split.get_child(0) == desired[0] and _split.get_child(1) == desired[1]:
		return
	for child in [_panel_container, _game_area]:
		if child.get_parent() == _split:
			_split.remove_child(child)
	for child in desired:
		_split.add_child(child)
	_configure_split_drag_areas.call_deferred()


func _apply_panel_size_flags() -> void:
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_area.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _configure_split_drag_areas() -> void:
	if not _split:
		return
	for drag_area in _split.get_drag_area_controls():
		drag_area.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_split_dragged(_offset: int) -> void:
	_sync_panel_size_to_container()
	_save_current_dock_axis_size.call_deferred()


func _sync_panel_size_to_container() -> void:
	if not _panel_container or not _panel_margin or not _panel:
		return
	_panel_margin.size = _panel_container.size
	_panel.update_minimum_size()


func _apply_split_offset() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var split_size := _split.size
	if split_size.x <= 0.0 or split_size.y <= 0.0:
		split_size = viewport_size
	var side_dock := not _split.vertical
	var desired_panel_size := _get_saved_dock_axis_size()
	if desired_panel_size <= 0.0:
		desired_panel_size = _calculate_initial_panel_axis_size(side_dock)
	if _split.vertical:
		_split.split_offset = _split_offset_for_panel_size(desired_panel_size, split_size.y)
	else:
		_split.split_offset = _split_offset_for_panel_size(desired_panel_size, split_size.x)


func _split_offset_for_panel_size(panel_size: float, axis_size: float) -> int:
	if axis_size <= 0.0:
		return 0
	var available_axis_size := maxf(1.0, axis_size - _get_split_separator_size())
	panel_size = clampf(panel_size, 1.0, available_axis_size)
	var baseline := available_axis_size * 0.5
	var offset := panel_size - baseline
	if not _panel_should_be_first():
		offset = -offset
	return int(roundf(offset))


func _get_split_separator_size() -> float:
	if not _split:
		return 0.0
	var separator := 0.0
	if _split.has_theme_constant("separation"):
		separator = float(_split.get_theme_constant("separation"))
	for drag_area in _split.get_drag_area_controls():
		var drag_control := drag_area as Control
		if not drag_control:
			continue
		var drag_size := drag_control.get_combined_minimum_size()
		separator = maxf(separator, drag_size.y if _split.vertical else drag_size.x)
	return separator


func _calculate_initial_panel_axis_size(side_dock: bool) -> float:
	var content_size := _calculate_panel_content_axis_size(side_dock)
	var margins := _get_panel_container_margins()
	if side_dock:
		return maxf(1.0, content_size + margins.x)
	return maxf(1.0, content_size + margins.y)


func _calculate_panel_content_axis_size(side_dock: bool) -> float:
	if not _panel:
		return 1.0
	var toolbar := _panel.get_node_or_null("VBoxContainer/Toolbar") as Control
	var layout_root := _panel.get_node_or_null("VBoxContainer") as VBoxContainer
	var scroll := _panel.get_node_or_null("VBoxContainer/TerrainScroll") as ScrollContainer
	var terrain_grid := _panel.get_node_or_null("VBoxContainer/TerrainScroll/TerrainGrid") as Control
	var empty_label := _panel.get_node_or_null("VBoxContainer/EmptyLabel") as Control
	var terrain_strip_size := _get_terrain_strip_size(terrain_grid, side_dock)
	if terrain_strip_size <= 0.0 and empty_label and empty_label.visible:
		var empty_size := empty_label.get_combined_minimum_size()
		terrain_strip_size = empty_size.x if side_dock else empty_size.y
	var scroll_margin := _get_control_style_minimum_size(scroll) + _get_scrollbar_reserved_size(scroll)
	var toolbar_size := _get_toolbar_single_row_size(toolbar)
	if side_dock:
		return maxf(toolbar_size.x, terrain_strip_size + scroll_margin.x)
	var root_separation := layout_root.get_theme_constant("separation") if layout_root else 0
	return toolbar_size.y + root_separation + terrain_strip_size + scroll_margin.y


func _get_toolbar_single_row_size(toolbar: Control) -> Vector2:
	if not toolbar:
		return Vector2.ZERO
	var size := Vector2.ZERO
	var visible_count := 0
	var h_separation := toolbar.get_theme_constant("h_separation") if toolbar.has_theme_constant("h_separation") else 0
	for child in toolbar.get_children():
		var control := child as Control
		if not control or not control.visible:
			continue
		var child_size := control.get_combined_minimum_size()
		size.x += child_size.x
		size.y = maxf(size.y, child_size.y)
		visible_count += 1
	if visible_count > 1:
		size.x += h_separation * float(visible_count - 1)
	return size


func _get_terrain_strip_size(terrain_grid: Control, side_dock: bool) -> float:
	if not terrain_grid or not terrain_grid.visible:
		return 0.0
	var strip_size := 0.0
	for child in terrain_grid.get_children():
		var control := child as Control
		if not control or not control.visible:
			continue
		var child_size := control.get_combined_minimum_size()
		strip_size = maxf(strip_size, child_size.x if side_dock else child_size.y)
	if strip_size > 0.0:
		return strip_size
	var grid_size := terrain_grid.get_combined_minimum_size()
	return grid_size.x if side_dock else grid_size.y


func _get_control_style_minimum_size(control: Control) -> Vector2:
	if not control:
		return Vector2.ZERO
	var result := Vector2.ZERO
	for style_name in ["panel", "normal"]:
		if control.has_theme_stylebox(style_name):
			var style := control.get_theme_stylebox(style_name)
			if style:
				result = result.max(style.get_minimum_size())
	return result


func _get_scrollbar_reserved_size(scroll: ScrollContainer) -> Vector2:
	if not scroll:
		return Vector2.ZERO
	var result := Vector2.ZERO
	var h_scrollbar := scroll.get_h_scroll_bar()
	if h_scrollbar and h_scrollbar.visible:
		result.y += h_scrollbar.get_combined_minimum_size().y
	var v_scrollbar := scroll.get_v_scroll_bar()
	if v_scrollbar and v_scrollbar.visible:
		result.x += v_scrollbar.get_combined_minimum_size().x
	return result


func _get_panel_container_margins() -> Vector2:
	var margins := Vector2.ZERO
	if _panel_container:
		var panel_style := _panel_container.get_theme_stylebox("panel")
		if panel_style:
			margins += panel_style.get_minimum_size()
	if _panel_margin:
		margins.x += _panel_margin.get_theme_constant("margin_left") + _panel_margin.get_theme_constant("margin_right")
		margins.y += _panel_margin.get_theme_constant("margin_top") + _panel_margin.get_theme_constant("margin_bottom")
	return margins


func _show_panel(animated: bool) -> void:
	if not _panel_container:
		return
	if _tween:
		_tween.kill()
	_panel_container.visible = true
	if not animated or animation_duration <= 0.0:
		_panel_container.modulate.a = 1.0
		return
	_panel_container.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel_container, "modulate:a", 1.0, animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_panel(animated: bool) -> void:
	if not _panel_container:
		return
	if _tween:
		_tween.kill()
	if not animated or animation_duration <= 0.0:
		_panel_container.visible = false
		_panel_container.modulate.a = 1.0
		_queue_overlay_redraw()
		return
	_tween = create_tween()
	_tween.tween_property(_panel_container, "modulate:a", 0.0, animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		_panel_container.visible = false
		_panel_container.modulate.a = 1.0
		_queue_overlay_redraw()
	)


func _on_panel_dock_edge_requested(edge: int) -> void:
	activation_edge = clampi(edge, int(ActivationEdge.TOP), int(ActivationEdge.RIGHT))


func _sync_panel_dock_edge() -> void:
	if _panel:
		_panel.runtime_dock_edge = int(activation_edge)


func _sync_panel_title() -> void:
	if not _panel:
		return
	_panel.runtime_title = title
	if _panel.has_method("update_runtime_title"):
		_panel.update_runtime_title()


func _load_runtime_settings() -> void:
	if _runtime_settings_loaded:
		return
	_runtime_settings_loaded = true
	_loading_runtime_settings = true
	var config := ConfigFile.new()
	if config.load(RUNTIME_SETTINGS_PATH) == OK:
		activation_edge = clampi(int(config.get_value(RUNTIME_SETTINGS_SECTION, RUNTIME_DOCK_EDGE_KEY, int(activation_edge))), int(ActivationEdge.TOP), int(ActivationEdge.RIGHT))
		_runtime_selected_layer_path = str(config.get_value(RUNTIME_SETTINGS_SECTION, RUNTIME_SELECTED_LAYER_KEY, ""))
		for edge in [ActivationEdge.TOP, ActivationEdge.BOTTOM, ActivationEdge.LEFT, ActivationEdge.RIGHT]:
			var key := _dock_size_key(edge)
			if config.has_section_key(RUNTIME_SETTINGS_SECTION, key):
				_runtime_dock_axis_sizes[int(edge)] = float(config.get_value(RUNTIME_SETTINGS_SECTION, key, 0.0))
	_loading_runtime_settings = false


func _save_runtime_settings() -> void:
	if _loading_runtime_settings:
		return
	var config := ConfigFile.new()
	config.load(RUNTIME_SETTINGS_PATH)
	config.set_value(RUNTIME_SETTINGS_SECTION, RUNTIME_DOCK_EDGE_KEY, int(activation_edge))
	if not _runtime_selected_layer_path.is_empty():
		config.set_value(RUNTIME_SETTINGS_SECTION, RUNTIME_SELECTED_LAYER_KEY, _runtime_selected_layer_path)
	for edge in _runtime_dock_axis_sizes:
		config.set_value(RUNTIME_SETTINGS_SECTION, _dock_size_key(edge), _runtime_dock_axis_sizes[edge])
	config.save(RUNTIME_SETTINGS_PATH)


func _save_current_dock_axis_size() -> void:
	if not _panel_container:
		return
	var size := _panel_container.size.x if not _split.vertical else _panel_container.size.y
	if size <= 0.0:
		return
	_runtime_dock_axis_sizes[int(activation_edge)] = size
	_save_runtime_settings()


func _get_saved_dock_axis_size() -> float:
	return float(_runtime_dock_axis_sizes.get(int(activation_edge), 0.0))


func _dock_size_key(edge) -> String:
	return RUNTIME_DOCK_SIZE_PREFIX + str(int(edge))


func _save_selected_layer(layer: TileMapLayer) -> void:
	if not layer or _loading_runtime_settings:
		return
	var root := _get_discover_root()
	if root and root.is_ancestor_of(layer):
		_runtime_selected_layer_path = str(root.get_path_to(layer))
	else:
		_runtime_selected_layer_path = str(layer.get_path())
	_save_runtime_settings()


func _find_persisted_selected_layer(root: Node) -> TileMapLayer:
	if _runtime_selected_layer_path.is_empty():
		return null
	var path := NodePath(_runtime_selected_layer_path)
	var candidate: Node = null
	if root:
		candidate = root.get_node_or_null(path)
	if not candidate:
		candidate = get_node_or_null(path)
	if candidate is TileMapLayer and _layers.has(candidate):
		return candidate
	return null


func _is_in_activation_zone(pos: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var thickness := max(1.0, float(activation_thickness_px))
	match activation_edge:
		ActivationEdge.TOP:
			return pos.y <= thickness
		ActivationEdge.BOTTOM:
			return pos.y >= viewport_size.y - thickness
		ActivationEdge.LEFT:
			return pos.x <= thickness
		ActivationEdge.RIGHT:
			return pos.x >= viewport_size.x - thickness
	return false


func _is_excluded_position(pos: Vector2) -> bool:
	for rect in excluded_rects:
		if rect.has_point(pos):
			return true
	for path in excluded_controls:
		if path.is_empty():
			continue
		var node := get_node_or_null(path)
		if node is Control and node.visible and node.get_global_rect().has_point(pos):
			return true
	return false


func _get_discover_root() -> Node:
	if not discover_root_path.is_empty():
		var configured := get_node_or_null(discover_root_path)
		if configured:
			return configured
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	var parent_root: Node = self
	while parent_root.get_parent():
		parent_root = parent_root.get_parent()
	return parent_root


func _collect_visible_tilemap_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node is TileMapLayer and node.visible:
		result.append(node)
	for child in node.get_children():
		_collect_visible_tilemap_layers(child, result)


func _get_layers_for_panel() -> Array[TileMapLayer]:
	refresh_layers()
	return _layers


func _on_panel_layer_selected(layer: TileMapLayer) -> void:
	set_tilemap(layer)


func _get_canvas_transform_for_panel(layer: TileMapLayer) -> Transform2D:
	if not layer:
		return Transform2D.IDENTITY
	return layer.get_viewport_transform() * layer.global_transform


func _get_viewport_size_for_panel() -> Vector2:
	return get_viewport().get_visible_rect().size


func _activate_navigation_camera() -> void:
	if _navigation_camera:
		return
	var parent := _get_navigation_camera_parent()
	if not parent:
		return
	_previous_camera = get_viewport().get_camera_2d()
	_navigation_camera = Camera2D.new()
	_navigation_camera.name = "TyleMapEditorNavigationCamera"
	if _previous_camera and is_instance_valid(_previous_camera):
		_navigation_camera.global_transform = _previous_camera.global_transform
		_navigation_camera.zoom = _previous_camera.zoom
		_navigation_camera.offset = _previous_camera.offset
		_navigation_camera.anchor_mode = _previous_camera.anchor_mode
		_navigation_camera.ignore_rotation = _previous_camera.ignore_rotation
		_navigation_camera.limit_left = _previous_camera.limit_left
		_navigation_camera.limit_top = _previous_camera.limit_top
		_navigation_camera.limit_right = _previous_camera.limit_right
		_navigation_camera.limit_bottom = _previous_camera.limit_bottom
	else:
		_navigation_camera.global_position = get_viewport().get_visible_rect().size * 0.5
	parent.add_child(_navigation_camera)
	_navigation_camera.make_current()


func _deactivate_navigation_camera() -> void:
	if _previous_camera and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	_previous_camera = null
	if _navigation_camera and is_instance_valid(_navigation_camera):
		_navigation_camera.queue_free()
	_navigation_camera = null


func _get_navigation_camera_parent() -> Node:
	if _panel and _panel.tilemap and _panel.tilemap.get_parent():
		return _panel.tilemap.get_parent()
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	return _get_discover_root()


func _handle_viewport_navigation_input(event: InputEvent) -> bool:
	if not viewport_navigation:
		return false
	if not _navigation_camera or not is_instance_valid(_navigation_camera):
		_activate_navigation_camera()
	if not _navigation_camera:
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_navigation_panning = event.pressed
			_set_navigation_drag_cursor(_navigation_panning)
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_navigation_camera(event.position, event.button_index == MOUSE_BUTTON_WHEEL_UP)
			return true
	if event is InputEventMouseMotion and _navigation_panning:
		_navigation_camera.global_position -= event.relative / _navigation_camera.zoom
		return true
	return false


func _set_navigation_drag_cursor(active: bool) -> void:
	if active == _navigation_cursor_active:
		return
	_navigation_cursor_active = active
	if active:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _zoom_navigation_camera(screen_position: Vector2, zoom_in: bool) -> void:
	var before := _screen_to_world(screen_position)
	var factor := _ZOOM_STEP if zoom_in else 1.0 / _ZOOM_STEP
	var next_zoom := _navigation_camera.zoom * factor
	next_zoom.x = clampf(next_zoom.x, _MIN_CAMERA_ZOOM, _MAX_CAMERA_ZOOM)
	next_zoom.y = clampf(next_zoom.y, _MIN_CAMERA_ZOOM, _MAX_CAMERA_ZOOM)
	_navigation_camera.zoom = next_zoom
	var after := _screen_to_world(screen_position)
	_navigation_camera.global_position += before - after


func _screen_to_world(screen_position: Vector2) -> Vector2:
	if _navigation_camera:
		return _navigation_camera.get_canvas_transform().affine_inverse() * screen_position
	return get_viewport().canvas_transform.affine_inverse() * screen_position


func _draw_runtime_overlay(target: Control) -> void:
	if not enabled or not showing or not _panel:
		return
	target.draw_set_transform(-target.global_position, 0.0, Vector2.ONE)
	_panel.canvas_draw(target)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_runtime_layer_highlighting() -> void:
	if not _panel or not showing or not _panel.is_layer_highlight_enabled() or not _panel.tilemap:
		_clear_runtime_layer_highlighting()
		return
	var selected := _panel.tilemap as TileMapLayer
	_clear_runtime_layer_highlighting()
	var selected_seen := false
	for layer in _layers:
		if not is_instance_valid(layer):
			continue
		if layer == selected:
			selected_seen = true
			_set_runtime_layer_highlight(layer, _RUNTIME_HIGHLIGHT_DEFAULT)
		elif selected_seen:
			_set_runtime_layer_highlight(layer, _RUNTIME_HIGHLIGHT_ABOVE)
		else:
			_set_runtime_layer_highlight(layer, _RUNTIME_HIGHLIGHT_BELOW)


func _clear_runtime_layer_highlighting() -> void:
	for layer in _runtime_highlight_original_modulates.keys():
		if is_instance_valid(layer):
			layer.self_modulate = _runtime_highlight_original_modulates[layer]
	_runtime_highlight_original_modulates.clear()


func _set_runtime_layer_highlight(layer: TileMapLayer, mode: int) -> void:
	if not _runtime_highlight_original_modulates.has(layer):
		_runtime_highlight_original_modulates[layer] = layer.self_modulate
	var base: Color = _runtime_highlight_original_modulates[layer]
	match mode:
		_RUNTIME_HIGHLIGHT_ABOVE:
			var above := base.darkened(0.5)
			above.a *= 0.3
			layer.self_modulate = above
		_RUNTIME_HIGHLIGHT_BELOW:
			layer.self_modulate = base.darkened(0.5)
		_:
			layer.self_modulate = base


func _queue_overlay_redraw() -> void:
	if _game_area:
		_game_area.queue_redraw()


func _setup_default_input_actions() -> void:
	for action: String in DEFAULT_INPUT_BINDINGS:
		if InputMap.has_action(action):
			continue
		var ev := InputEventKey.new()
		ev.keycode = DEFAULT_INPUT_BINDINGS[action]
		ev.command_or_control_autoremap = false
		InputMap.add_action(action)
		InputMap.action_add_event(action, ev)
