@tool
extends Control

signal update_overlay
signal close_requested
signal dock_edge_requested(edge: int)

enum PaintTool { NONE, DRAW, RECT, LINE, BUCKET, SEL, PICK, ERASE }
enum DragType { NONE, SELECT, MOVE, CLIPBOARD_PASTE }

const _draw_tools: Array[int] = [PaintTool.DRAW, PaintTool.RECT, PaintTool.LINE, PaintTool.BUCKET]

const COLOR_TRANSPARENT := Color(0, 0, 0, 0)
const COLOR_SELECTION_OUTLINE := Color(0.3, 0.7, 1.0, 1.0)
const COLOR_ERASE_OVERLAY := Color(0.0, 0.0, 0.0, 0.35)
const COLOR_PAINT_OVERLAY := Color(1.0, 1.0, 1.0, 0.35)
const COLOR_MOVE_PASTE_FALLBACK := Color(1.0, 1.0, 1.0, 0.25)
const RUNTIME_GRID_COLOR := Color(1.0, 0.5, 0.2, 0.5)
const TERRAIN_ENTRY_SIZE := Vector2(72, 72)
const RUNTIME_SETTINGS_PATH := "user://tyle_map_editor.cfg"
const RUNTIME_SETTINGS_SECTION := "panel"
const RUNTIME_GRID_KEY := "grid_enabled"
const RUNTIME_LAYER_HIGHLIGHT_KEY := "layer_highlight_enabled"
const DOCK_EDGE_TOP := 0
const DOCK_EDGE_BOTTOM := 1
const DOCK_EDGE_LEFT := 2
const DOCK_EDGE_RIGHT := 3

static var _runtime_settings_loaded: bool = false
static var _runtime_grid_enabled: bool = true
static var _runtime_layer_highlight_enabled: bool = false

var TILE_POLYGON: PackedVector2Array = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])

func _is_draw_tool() -> bool:
	return paint_tool in _draw_tools

@onready var draw_button: Button = %Draw
@onready var rect_button: Button = %Rect
@onready var line_button: Button = %Line
@onready var fill_button: Button = %Fill
@onready var pick_button: Button = %Pick
@onready var select_button: Button = %Select
@onready var erase_button: Button = %Erase
@onready var erase_all_button: Button = %EraseAll

@onready var layer_highlight: Button = %LayerHighlight
@onready var layer_grid: Button = %LayerGrid
@onready var layer_select: OptionButton = %LayerSelect
@onready var title_label: Label = %RuntimeTitle
@onready var more_button: MenuButton = %MoreButton
@onready var close_button: Button = %CloseButton

@onready var layout_root: VBoxContainer = $VBoxContainer
@onready var terrain_grid: HFlowContainer = %TerrainGrid
@onready var scroll_container: ScrollContainer = %TerrainScroll
@onready var empty_label: Label = %EmptyLabel

var tilemap: TileMapLayer = null:
	set(v):
		if tilemap and tilemap.visibility_changed.is_connected(_on_tilemap_visibility_changed):
			tilemap.visibility_changed.disconnect(_on_tilemap_visibility_changed)
		tilemap = v
		if tilemap:
			if not tilemap.visibility_changed.is_connected(_on_tilemap_visibility_changed):
				tilemap.visibility_changed.connect(_on_tilemap_visibility_changed)
		tileset = v.tile_set if v else null
		_selection.clear()
		_drag_type = DragType.NONE
		_drag_modified.clear()
		_held_button_count = 0
		mouse_down = false
		_update_layer_dropdown.call_deferred()
		_update_erase_buttons.call_deferred()

var tileset: TileSet = null:
	set(v):
		if tileset and tileset.changed.is_connected(_on_tileset_changed):
			tileset.changed.disconnect(_on_tileset_changed)
		tileset = v
		if tileset:
			if not tileset.changed.is_connected(_on_tileset_changed):
				tileset.changed.connect(_on_tileset_changed)
		_refresh_terrains()

var undo_manager: Object
var runtime_mode: bool = false
var layer_provider: Callable
var layer_selected_callback: Callable
var canvas_transform_provider: Callable
var viewport_size_provider: Callable
var runtime_highlight_changed_callback: Callable
var runtime_dock_edge: int = DOCK_EDGE_BOTTOM:
	set(value):
		runtime_dock_edge = clampi(value, DOCK_EDGE_TOP, DOCK_EDGE_RIGHT)
		_update_more_menu_checks()
var runtime_title: String = "":
	set(value):
		runtime_title = value
		update_runtime_title()

var flattened_terrains: Array[Dictionary] = []
var selected_index: int = -1
var paint_tool: PaintTool = PaintTool.DRAW
var _prev_tool: PaintTool = PaintTool.DRAW
var _tool_buttons: Array[Button] = []

var draw_overlay: bool = false
var mouse_down: bool = false
var mouse_start: Vector2i = Vector2i.ZERO
var mouse_current: Vector2i = Vector2i.ZERO
var mouse_prev: Vector2i = Vector2i.ZERO
var drag_erasing: bool = false
var _quick_source_tool: PaintTool = PaintTool.NONE
var selection_rect: Rect2i = Rect2i()
var drag_action_index: int = 0
var drag_action_count: int = 0
var _selection: Dictionary = {}
var _drag_type: int = DragType.NONE
var _drag_modified: Dictionary = {}
var _held_button_count: int = 0
var _clipboard: TileMapPattern
var plugin: Object = null
var _native_tilemap_editor: Object = null
var _native_grid_button: BaseButton = null
var _native_highlight_button: BaseButton = null
var _syncing_native: bool = false
var _is_narrow_layout: bool = false
var _dock_position_popup: PopupMenu = null

func _ready() -> void:
	erase_all_button.self_modulate = Color(1.0, 0.3, 0.3, 1.0)

	_setup_tooltips()
	_setup_more_menu()
	update_runtime_title()

	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_update_responsive_layout)

	draw_button.pressed.connect(_on_tool_changed.bind(PaintTool.DRAW))
	rect_button.pressed.connect(_on_tool_changed.bind(PaintTool.RECT))
	line_button.pressed.connect(_on_tool_changed.bind(PaintTool.LINE))
	fill_button.pressed.connect(_on_tool_changed.bind(PaintTool.BUCKET))
	select_button.pressed.connect(_on_tool_changed.bind(PaintTool.SEL))
	pick_button.pressed.connect(_on_tool_changed.bind(PaintTool.PICK))
	erase_button.pressed.connect(_on_tool_changed.bind(PaintTool.ERASE))
	erase_all_button.pressed.connect(_on_erase_all)

	layer_select.item_selected.connect(_on_layer_selected)
	layer_highlight.toggled.connect(_on_layer_highlight_toggled)
	layer_grid.toggled.connect(_on_layer_grid_toggled)
	close_button.pressed.connect(_on_close_pressed)

	draw_button.button_pressed = true
	_tool_buttons = [null, draw_button, rect_button, line_button, fill_button, select_button, pick_button, erase_button]
	for btn in _tool_buttons:
		if btn:
			btn.toggled.connect(_on_tool_toggled)
	_update_empty_state()
	_on_tool_toggled(false)
	call_deferred("_update_responsive_layout")

func _get_minimum_size() -> Vector2:
	if layout_root:
		return layout_root.get_combined_minimum_size()
	return Vector2.ZERO

func _on_close_pressed() -> void:
	close_requested.emit()

func update_runtime_title() -> void:
	if not title_label:
		return
	var show_runtime_title := runtime_mode and not runtime_title.is_empty()
	title_label.visible = show_runtime_title
	title_label.text = runtime_title

func _update_responsive_layout() -> void:
	var narrow := size.x > 0.0 and size.y > 0.0 and size.x < size.y
	if narrow == _is_narrow_layout:
		return
	_is_narrow_layout = narrow
	if narrow:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		terrain_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		terrain_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_grid.queue_sort()
	update_minimum_size()

func _on_visibility_changed() -> void:
	if not visible:
		if _drag_type == DragType.MOVE:
			_restore_move_cells()
		if _quick_source_tool != PaintTool.NONE:
			_exit_quick_tool()
		_drag_type = DragType.NONE
		mouse_down = false
		draw_overlay = false
		update_overlay.emit()

func _setup_tooltips() -> void:
	draw_button.tooltip_text = _make_tooltip_text({
		"Draw tile": &"tyle_draw"
	})
	rect_button.tooltip_text = _make_tooltip_text({
		"Rectangle": &"tyle_rect",
		"Quick rectangle": "Shift"
	})
	line_button.tooltip_text = _make_tooltip_text({
		"Line": &"tyle_line",
		"Quick line": "Ctrl"
	})
	fill_button.tooltip_text = _make_tooltip_text({
		"Flood fill": &"tyle_fill"
	})
	pick_button.tooltip_text = _make_tooltip_text({
		"Pick tile": &"tyle_pick",
		"Quick pick": "Alt"
	})
	select_button.tooltip_text = _make_tooltip_text({
		"Select tiles": &"tyle_select",
		"Add": "Shift",
		"Subtract": "Ctrl",
		"Move": "Click+Drag",
		"Cut, Copy, Paste": "Ctrl+X/C/V"
	})
	erase_button.tooltip_text = _make_tooltip_text({
		"Erase tile": &"tyle_erase",
		"Quick erase": "Right click"
	})
	erase_all_button.tooltip_text = "Erase all tiles on selected tile map layer"
	layer_highlight.tooltip_text = "Highlight selected tile map layer"
	layer_grid.tooltip_text = "Toggle grid visibility"
	more_button.tooltip_text = "Runtime dock options"
	close_button.tooltip_text = "Close Tyle panel"

func _setup_more_menu() -> void:
	more_button.visible = runtime_mode
	var popup := more_button.get_popup()
	popup.clear()
	_dock_position_popup = popup.get_node_or_null("DockPositionPopup") as PopupMenu
	if not _dock_position_popup:
		_dock_position_popup = PopupMenu.new()
		_dock_position_popup.name = "DockPositionPopup"
		popup.add_child(_dock_position_popup)
	_dock_position_popup.clear()
	_dock_position_popup.add_check_item("Top", DOCK_EDGE_TOP)
	_dock_position_popup.add_check_item("Bottom", DOCK_EDGE_BOTTOM)
	_dock_position_popup.add_check_item("Left", DOCK_EDGE_LEFT)
	_dock_position_popup.add_check_item("Right", DOCK_EDGE_RIGHT)
	popup.add_submenu_item("Dock Position", "DockPositionPopup")
	if not _dock_position_popup.id_pressed.is_connected(_on_more_menu_id_pressed):
		_dock_position_popup.id_pressed.connect(_on_more_menu_id_pressed)
	_update_more_menu_checks()

func _on_more_menu_id_pressed(id: int) -> void:
	runtime_dock_edge = id
	dock_edge_requested.emit(id)

func _update_more_menu_checks() -> void:
	if not _dock_position_popup:
		return
	for i in range(_dock_position_popup.item_count):
		_dock_position_popup.set_item_checked(i, _dock_position_popup.get_item_id(i) == runtime_dock_edge)

func _get_action_key_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return action
	for ev in events:
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.keycode)
	return events[0].as_text()

func _make_tooltip_text(entries: Dictionary) -> String:
	var lines: PackedStringArray = []
	for description in entries:
		var val = entries[description]
		if val is StringName:
			var key := _get_action_key_text(val)
			if key.is_empty():
				lines.append(description)
			else:
				lines.append("%s (%s)" % [description, key])
		elif val is String and not val.is_empty():
			lines.append("%s (%s)" % [description, val])
		else:
			lines.append(description)
	return "\n".join(lines)

func _is_tilemap_editable() -> bool:
	return tilemap != null and tilemap.is_visible_in_tree()

func _update_empty_state() -> void:
	if not tilemap:
		empty_label.text = "No terrain sets defined.\nUse the TileSet bottom panel to add terrains."
		empty_label.visible = true
		scroll_container.visible = false
	elif not tilemap.is_visible_in_tree():
		empty_label.text = "The TileMapLayer is disabled or invisible"
		empty_label.visible = true
		scroll_container.visible = false
	elif not tileset or flattened_terrains.is_empty():
		empty_label.text = "No terrain sets defined.\nUse the TileSet bottom panel to add terrains."
		empty_label.visible = true
		scroll_container.visible = false
	else:
		empty_label.visible = false
		scroll_container.visible = true
	_update_tool_buttons()

func _update_tool_buttons() -> void:
	var editable := _is_tilemap_editable()

	draw_button.disabled = not editable
	rect_button.disabled = not editable
	line_button.disabled = not editable
	fill_button.disabled = not editable
	pick_button.disabled = not editable
	select_button.disabled = not editable

func _on_tilemap_visibility_changed() -> void:
	_update_empty_state.call_deferred()

func _on_tool_changed(tool: PaintTool) -> void:
	if paint_tool != PaintTool.PICK and paint_tool != PaintTool.SEL:
		_prev_tool = paint_tool
	_quick_source_tool = PaintTool.NONE
	if _drag_type == DragType.MOVE:
		_restore_move_cells()
		update_overlay.emit()
	_drag_type = DragType.NONE
	_held_button_count = 0
	if tool != PaintTool.SEL:
		_selection.clear()
	mouse_down = false
	draw_overlay = false
	update_overlay.emit()
	paint_tool = tool
	selection_rect = Rect2i()
	_ensure_editor_select_mode()

func _on_tool_toggled(_pressed: bool) -> void:
	for btn in _tool_buttons:
		if btn:
			btn.flat = not btn.button_pressed

func _enter_quick_tool(tool: PaintTool) -> void:
	if _quick_source_tool != PaintTool.NONE:
		return
	_quick_source_tool = paint_tool
	paint_tool = tool
	drag_erasing = true
	if _quick_source_tool > 0 and _quick_source_tool < _tool_buttons.size():
		_tool_buttons[_quick_source_tool].set_pressed_no_signal(false)
		_tool_buttons[_quick_source_tool].flat = true
	if tool > 0 and tool < _tool_buttons.size():
		_tool_buttons[tool].set_pressed_no_signal(true)
		_tool_buttons[tool].flat = false

func _exit_quick_tool() -> void:
	if _quick_source_tool == PaintTool.NONE:
		return
	var source := _quick_source_tool
	var current := paint_tool
	_quick_source_tool = PaintTool.NONE
	paint_tool = source
	drag_erasing = false
	if current > 0 and current < _tool_buttons.size():
		_tool_buttons[current].set_pressed_no_signal(false)
		_tool_buttons[current].flat = true
	if source > 0 and source < _tool_buttons.size():
		_tool_buttons[source].set_pressed_no_signal(true)
		_tool_buttons[source].flat = false

func _select_tool_button(tool: PaintTool) -> void:
	paint_tool = tool
	if tool > 0 and tool < _tool_buttons.size():
		var tool_btn := _tool_buttons[tool]
		tool_btn.button_pressed = true
		tool_btn.pressed.emit()

func _on_tileset_changed() -> void:
	_refresh_terrains.call_deferred()

# ---- TERRAIN GRID ----

var _icon_cache: Dictionary = {}

func _refresh_terrains() -> void:
	for c in terrain_grid.get_children():
		terrain_grid.remove_child(c)
		c.free()
	flattened_terrains.clear()
	if not tileset:
		_update_empty_state()
		return
	_build_icon_cache()
	var terrain_count := 0
	for set_idx in tileset.get_terrain_sets_count():
		for ter_idx in tileset.get_terrains_count(set_idx):
			var name := tileset.get_terrain_name(set_idx, ter_idx)
			var color := tileset.get_terrain_color(set_idx, ter_idx)
			var key := "%d:%d" % [set_idx, ter_idx]
			var icon: Dictionary = _icon_cache.get(key, {})
			flattened_terrains.append({set = set_idx, idx = ter_idx, name = name, color = color, icon_texture = icon.get("texture", null)})
			terrain_count += 1
	if terrain_count == 0:
		_update_empty_state()
		return

	for i in flattened_terrains.size():
		_create_terrain_entry(flattened_terrains[i], i)
	if selected_index == -1 and flattened_terrains.size() > 0:
		selected_index = 0
	if selected_index >= flattened_terrains.size():
		selected_index = -1
	_update_empty_state()
	_update_selection_buttons()
	_update_erase_buttons.call_deferred()
	call_deferred("_update_layer_dropdown")

func _build_icon_cache() -> void:
	_icon_cache.clear()
	if not tileset:
		return
	for src_i in tileset.get_source_count():
		var source := tileset.get_source(tileset.get_source_id(src_i)) as TileSetAtlasSource
		if not source or not source.texture:
			continue
		for tile_i in source.get_tiles_count():
			var coord := source.get_tile_id(tile_i)
			for alt_i in source.get_alternative_tiles_count(coord):
				var alt_id := source.get_alternative_tile_id(coord, alt_i)
				var td: TileData = source.get_tile_data(coord, alt_id)
				if td and td.terrain_set >= 0:
					_cache_terrain_icon(td, source, coord, alt_id)

func _cache_terrain_icon(td: TileData, source: TileSetAtlasSource, coord: Vector2i, alt_id: int) -> void:
	var set_idx := td.terrain_set
	if set_idx < 0:
		return
	if td.terrain >= 0:
		var key_center := "%d:%d" % [set_idx, td.terrain]
		if not _icon_cache.has(key_center) and source.texture:
			_icon_cache[key_center] = _make_icon(source, coord)

func _make_icon(source: TileSetAtlasSource, coord: Vector2i) -> Dictionary:
	if not source or not source.texture:
		return {}
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = source.texture
	var region := source.get_tile_texture_region(coord, 0)
	atlas_tex.region = region
	return {texture = atlas_tex}

func _create_terrain_entry(data: Dictionary, index: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = TERRAIN_ENTRY_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	panel.add_child(inner)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(68, 52)
	tex.size_flags_horizontal = Control.SIZE_FILL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	if data.icon_texture:
		tex.texture = data.icon_texture
	inner.add_child(tex)

	var label := Label.new()
	label.text = data.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	inner.add_child(label)

	panel.gui_input.connect(_on_entry_gui_input.bind(panel, index))
	terrain_grid.add_child(panel)

	if index == selected_index:
		_update_entry_style(panel, true)

func _on_entry_gui_input(event: InputEvent, panel: PanelContainer, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_index = index
		_update_selection_buttons()
		if not _is_draw_tool():
			_select_tool_button(PaintTool.DRAW)
		_ensure_editor_select_mode()

func _update_entry_style(panel: PanelContainer, selected: bool) -> void:
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_TRANSPARENT
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 1.0, 1.0, 0.8)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		panel.add_theme_stylebox_override("panel", style)
	else:
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = COLOR_TRANSPARENT
		empty_style.content_margin_left = 0
		empty_style.content_margin_right = 0
		empty_style.content_margin_top = 0
		empty_style.content_margin_bottom = 0
		panel.add_theme_stylebox_override("panel", empty_style)

func _update_selection_buttons() -> void:
	for i in terrain_grid.get_child_count():
		var panel := terrain_grid.get_child(i) as PanelContainer
		if not panel:
			continue
		_update_entry_style(panel, i == selected_index)

func _update_erase_buttons() -> void:
	pass

func _update_layer_dropdown() -> void:
	layer_select.clear()
	if not tilemap:
		layer_select.disabled = true
		return

	var siblings: Array[Node] = _get_available_layers()
	if runtime_mode:
		_populate_layer_dropdown(siblings)
		return

	var editor_interface := _get_editor_interface()
	var root: Node = null
	if editor_interface:
		root = editor_interface.call("get_edited_scene_root") as Node
	if not root:
		layer_select.disabled = true
		layer_select.add_item(tilemap.name)
		layer_select.select(0)
		return
	siblings.clear()
	_collect_visible_tilemap_layers(root, siblings)
	_populate_layer_dropdown(siblings)

func _populate_layer_dropdown(siblings: Array[Node]) -> void:
	if siblings.size() <= 1:
		layer_select.disabled = true
		layer_select.add_item(tilemap.name if tilemap else "TileMapLayer")
		layer_select.select(0)
		return
	for i in siblings.size():
		var lyr: TileMapLayer = siblings[i]
		layer_select.add_item(lyr.name)
		if lyr == tilemap:
			layer_select.select(i)
	layer_select.disabled = false

func _collect_visible_tilemap_layers(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is TileMapLayer and child.visible:
			result.append(child)
		if child is Node:
			_collect_visible_tilemap_layers(child, result)

func _on_layer_selected(idx: int) -> void:
	var siblings := _get_available_layers()
	if runtime_mode:
		if idx >= 0 and idx < siblings.size():
			if layer_selected_callback.is_valid():
				layer_selected_callback.call(siblings[idx])
			else:
				tilemap = siblings[idx]
		return

	var editor_interface := _get_editor_interface()
	var root: Node = null
	if editor_interface:
		root = editor_interface.call("get_edited_scene_root") as Node
	if not root:
		return
	siblings.clear()
	_collect_visible_tilemap_layers(root, siblings)
	if idx >= 0 and idx < siblings.size():
		editor_interface.call("edit_node", siblings[idx])

func _get_available_layers() -> Array[Node]:
	if runtime_mode and layer_provider.is_valid():
		var provided = layer_provider.call()
		var result: Array[Node] = []
		if provided is Array:
			for node in provided:
				if node is TileMapLayer:
					result.append(node)
		return result
	if not runtime_mode:
		var editor_interface := _get_editor_interface()
		var root: Node = null
		if editor_interface:
			root = editor_interface.call("get_edited_scene_root") as Node
		if root:
			var siblings: Array[Node] = []
			_collect_visible_tilemap_layers(root, siblings)
			return siblings
	return []

func _on_layer_highlight_toggled(toggled: bool) -> void:
	if _syncing_native:
		return

	if runtime_mode:
		_ensure_runtime_settings_loaded()
		_runtime_layer_highlight_enabled = toggled
		_save_runtime_settings()
		_update_runtime_toggle_visuals()
		if runtime_highlight_changed_callback.is_valid():
			runtime_highlight_changed_callback.call()
		update_overlay.emit()
		return

	var settings := _get_editor_settings()
	if not settings:
		return
	settings.set_setting("editors/tiles_editor/highlight_selected_layer", toggled)
	settings.emit_changed()
	_toggle_native("Highlight Selected TileMap Layer", toggled)
	if plugin and plugin.has_method("_queue_overlay_redraw"):
		plugin._queue_overlay_redraw()
	update_overlay.emit()

func _on_layer_grid_toggled(toggled: bool) -> void:
	if _syncing_native:
		return

	if runtime_mode:
		_ensure_runtime_settings_loaded()
		_runtime_grid_enabled = toggled
		_save_runtime_settings()
		_update_runtime_toggle_visuals()
		update_overlay.emit()
		return

	var settings := _get_editor_settings()
	if not settings:
		return
	settings.set_setting("editors/tiles_editor/display_grid", toggled)
	settings.emit_changed()
	_toggle_native("Toggle grid visibility.", toggled)
	if plugin and plugin.has_method("_queue_overlay_redraw"):
		plugin._queue_overlay_redraw()
	update_overlay.emit()

func _toggle_native(tooltip: String, pressed: bool) -> void:
	var editor := _ensure_native_tilemap_editor()
	if editor:
		_find_and_toggle_in(editor, tooltip, pressed)
	else:
		var editor_interface := _get_editor_interface()
		var base_control: Control = null
		if editor_interface:
			base_control = editor_interface.call("get_base_control") as Control
		if base_control:
			_find_and_toggle_in(base_control, tooltip, pressed)

func _find_and_toggle_in(node: Node, tooltip: String, pressed: bool) -> void:
	for child in node.get_children():
		if child is BaseButton:
			var btn: BaseButton = child
			if btn.tooltip_text == tooltip:
				btn.set_pressed_no_signal(pressed)
				btn.toggled.emit(pressed)
				_connect_native_button(btn, tooltip)
				return
		_find_and_toggle_in(child, tooltip, pressed)

func _connect_native_button(btn: BaseButton, tooltip: String) -> void:
	if tooltip == "Toggle grid visibility.":
		if _native_grid_button != btn:
			if _native_grid_button and _native_grid_button.toggled.is_connected(_on_native_grid_toggled):
				_native_grid_button.toggled.disconnect(_on_native_grid_toggled)
			_native_grid_button = btn
			if not btn.toggled.is_connected(_on_native_grid_toggled):
				btn.toggled.connect(_on_native_grid_toggled)
	elif tooltip == "Highlight Selected TileMap Layer":
		if _native_highlight_button != btn:
			if _native_highlight_button and _native_highlight_button.toggled.is_connected(_on_native_highlight_toggled):
				_native_highlight_button.toggled.disconnect(_on_native_highlight_toggled)
			_native_highlight_button = btn
			if not btn.toggled.is_connected(_on_native_highlight_toggled):
				btn.toggled.connect(_on_native_highlight_toggled)
func _on_native_grid_toggled(pressed: bool) -> void:
	if _syncing_native:
		return
	_syncing_native = true

	layer_grid.set_pressed_no_signal(pressed)
	var settings := _get_editor_settings()
	if settings:
		settings.set_setting("editors/tiles_editor/display_grid", pressed)
	_syncing_native = false

func _on_native_highlight_toggled(pressed: bool) -> void:
	if _syncing_native:
		return
	_syncing_native = true

	layer_highlight.set_pressed_no_signal(pressed)
	var settings := _get_editor_settings()
	if settings:
		settings.set_setting("editors/tiles_editor/highlight_selected_layer", pressed)
	_syncing_native = false

func _ensure_native_tilemap_editor() -> Object:
	if _native_tilemap_editor and is_instance_valid(_native_tilemap_editor):
		return _native_tilemap_editor
	var editor_interface := _get_editor_interface()
	var editor_base: Control = null
	if editor_interface:
		editor_base = editor_interface.call("get_base_control") as Control
	if not editor_base:
		return null
	_native_tilemap_editor = _find_tilemap_editor_in_tree(editor_base)
	return _native_tilemap_editor

func _find_tilemap_editor_in_tree(node: Node) -> Object:
	if node.name == "TileMap" and node.is_class("TileMapLayerEditor"):
		return node
	for child in node.get_children():
		var found := _find_tilemap_editor_in_tree(child)
		if found:
			return found
	return null

func about_to_be_visible() -> void:
	if tilemap and tileset != tilemap.tile_set:
		tileset = tilemap.tile_set
	if runtime_mode:
		_ensure_runtime_settings_loaded()
		more_button.visible = true
		update_runtime_title()
		layer_highlight.set_pressed_no_signal(_runtime_layer_highlight_enabled)
		layer_grid.set_pressed_no_signal(_runtime_grid_enabled)
		_update_runtime_toggle_visuals()
		_update_empty_state()
		return
	var settings := _get_editor_settings()
	if not settings:
		_update_empty_state()
		return
	var hl: bool = settings.get_setting("editors/tiles_editor/highlight_selected_layer")
	var grid: bool = settings.get_setting("editors/tiles_editor/display_grid")

	layer_highlight.set_pressed_no_signal(hl)
	layer_grid.set_pressed_no_signal(grid)
	_update_empty_state()

func is_layer_highlight_enabled() -> bool:
	if runtime_mode:
		_ensure_runtime_settings_loaded()
		return _runtime_layer_highlight_enabled
	var settings := _get_editor_settings()
	if settings:
		return settings.get_setting("editors/tiles_editor/highlight_selected_layer")
	return false

func _update_runtime_toggle_visuals() -> void:
	if not runtime_mode:
		return
	layer_highlight.flat = not layer_highlight.button_pressed
	layer_grid.flat = not layer_grid.button_pressed

func _ensure_runtime_settings_loaded() -> void:
	if _runtime_settings_loaded:
		return
	_runtime_settings_loaded = true
	var config := ConfigFile.new()
	if config.load(RUNTIME_SETTINGS_PATH) != OK:
		return
	_runtime_grid_enabled = bool(config.get_value(RUNTIME_SETTINGS_SECTION, RUNTIME_GRID_KEY, _runtime_grid_enabled))
	_runtime_layer_highlight_enabled = bool(config.get_value(RUNTIME_SETTINGS_SECTION, RUNTIME_LAYER_HIGHLIGHT_KEY, _runtime_layer_highlight_enabled))

func _save_runtime_settings() -> void:
	var config := ConfigFile.new()
	config.load(RUNTIME_SETTINGS_PATH)
	config.set_value(RUNTIME_SETTINGS_SECTION, RUNTIME_GRID_KEY, _runtime_grid_enabled)
	config.set_value(RUNTIME_SETTINGS_SECTION, RUNTIME_LAYER_HIGHLIGHT_KEY, _runtime_layer_highlight_enabled)
	config.save(RUNTIME_SETTINGS_PATH)

func _get_editor_interface() -> Object:
	if not Engine.is_editor_hint():
		return null
	if not Engine.has_singleton(&"EditorInterface"):
		return null
	return Engine.get_singleton(&"EditorInterface")

func _get_editor_settings() -> Object:
	var editor_interface := _get_editor_interface()
	if not editor_interface:
		return null
	return editor_interface.call("get_editor_settings")

func _get_selected_terrain() -> Dictionary:
	if selected_index >= 0 and selected_index < flattened_terrains.size():
		return flattened_terrains[selected_index]
	return {}

# ---- SAVE / RESTORE ----

func _save_cells(coords: Array) -> Dictionary:
	var state := {}
	for c in coords:
		state[c] = _get_cell_state(c)
	return state

func _get_cell_state(c: Vector2i) -> Dictionary:
	var src := tilemap.get_cell_source_id(c)
	return {has_cell = src != -1, source_id = src if src != -1 else 0, atlas_coords = tilemap.get_cell_atlas_coords(c) if src != -1 else Vector2i.ZERO, alternative_tile = tilemap.get_cell_alternative_tile(c) if src != -1 else 0}

func _restore_cell_state(c: Vector2i, state: Dictionary, target: TileMapLayer) -> void:
	if state.has_cell:
		target.set_cell(c, state.source_id, state.atlas_coords, state.alternative_tile)
	else:
		target.erase_cell(c)

func _restore_cells(saved: Dictionary, tm: TileMapLayer) -> void:
	for c in saved:
		_restore_cell_state(c, saved[c], tm)

func _has_history() -> bool:
	return undo_manager != null

func _history_is_editor_manager() -> bool:
	return undo_manager != null and undo_manager.has_method("get_object_history_id")

func _history_create_action(action_name: String, merge_mode: int = UndoRedo.MERGE_DISABLE, context: Object = null, backward_undo_ops: bool = false) -> void:
	if not undo_manager:
		return
	if _history_is_editor_manager():
		undo_manager.callv("create_action", [action_name, merge_mode, context, backward_undo_ops])
	else:
		undo_manager.callv("create_action", [action_name, merge_mode, backward_undo_ops])

func _history_add_do_method(target: Object, method_name: StringName, args: Array = []) -> void:
	if not undo_manager:
		return
	if _history_is_editor_manager():
		undo_manager.callv("add_do_method", [target, method_name] + args)
	else:
		undo_manager.call("add_do_method", Callable(self, "_history_call").bind(target, method_name, args))

func _history_add_undo_method(target: Object, method_name: StringName, args: Array = []) -> void:
	if not undo_manager:
		return
	if _history_is_editor_manager():
		undo_manager.callv("add_undo_method", [target, method_name] + args)
	else:
		undo_manager.call("add_undo_method", Callable(self, "_history_call").bind(target, method_name, args))

func _history_commit_action() -> void:
	if undo_manager:
		undo_manager.call("commit_action")

func _history_call(target: Object, method_name: StringName, args: Array) -> void:
	if is_instance_valid(target):
		target.callv(method_name, args)

# ---- CANVAS INPUT ----

func canvas_input(event: InputEvent) -> bool:
	if not _is_tilemap_editable():
		return false
	if not tileset:
		return false

	if event is InputEventKey:
		return _handle_key_event(event)

	if not event is InputEventMouse:
		return false
	if not _is_editor_select_mode() and _drag_type != DragType.CLIPBOARD_PASTE:
		return false
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return false

	var transform := _canvas_tilemap_transform()
	var pos: Vector2 = transform.affine_inverse() * event.position
	mouse_prev = mouse_current
	mouse_current = tilemap.local_to_map(pos)

	if event is InputEventMouseMotion:
		if mouse_current == mouse_prev:
			return false
		if not mouse_down:
			draw_overlay = true
			update_overlay.emit()
		elif mouse_down:
			draw_overlay = true
			update_overlay.emit()
			if paint_tool == PaintTool.DRAW or paint_tool == PaintTool.ERASE:
				_do_paint_stroke()

	var released: bool = event is InputEventMouseButton and not event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed

	if released:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_held_button_count = maxi(0, _held_button_count - 1)
		if event.button_index == MOUSE_BUTTON_RIGHT and _quick_source_tool != PaintTool.NONE:
			_exit_quick_tool()
			if _held_button_count == 0:
				mouse_down = false
				draw_overlay = false
				update_overlay.emit()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and _quick_source_tool != PaintTool.NONE:
			if mouse_down:
				if paint_tool == PaintTool.LINE or paint_tool == PaintTool.RECT:
					_commit_paint_action()
			_exit_quick_tool()
			if _held_button_count == 0:
				mouse_down = false
				draw_overlay = false
				update_overlay.emit()
			return true
		if _drag_type == DragType.CLIPBOARD_PASTE:
			return true
		if paint_tool == PaintTool.SEL:
			if mouse_down and _held_button_count == 0:
				mouse_down = false
				if _drag_type == DragType.SELECT:
					_commit_selection()
				elif _drag_type == DragType.MOVE:
					_commit_move()
				draw_overlay = false
				update_overlay.emit()
				return true
			return true
		if not mouse_down:
			return false
		mouse_down = false
		if paint_tool == PaintTool.LINE or paint_tool == PaintTool.RECT:
			_commit_paint_action()
		draw_overlay = false
		update_overlay.emit()
		return true

	if clicked:
		if _drag_type == DragType.CLIPBOARD_PASTE:
			if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				_commit_paste()
				return true
			return false

		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_held_button_count += 1
		if paint_tool == PaintTool.SEL:
			if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and not mouse_down:
				if _selection.has(mouse_current) and not event.shift_pressed and not event.is_command_or_control_pressed():
					_start_move(mouse_current)
				else:
					_drag_type = DragType.SELECT
					mouse_down = true
					mouse_start = mouse_current
					mouse_prev = mouse_current
					selection_rect = Rect2i()
					draw_overlay = true
					update_overlay.emit()
			return true

		if event.button_index == MOUSE_BUTTON_RIGHT:
			_enter_quick_tool(PaintTool.ERASE)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.shift_pressed and not event.is_command_or_control_pressed() and not event.alt_pressed:
				_enter_quick_tool(PaintTool.RECT)
			elif event.is_command_or_control_pressed() and not event.shift_pressed and not event.alt_pressed:
				_enter_quick_tool(PaintTool.LINE)
			elif event.alt_pressed and not event.shift_pressed and not event.is_command_or_control_pressed():
				_enter_quick_tool(PaintTool.PICK)
				_pick_at_mouse()
				_exit_quick_tool()
				return true
		else:
			return false

		if paint_tool == PaintTool.PICK and event.button_index == MOUSE_BUTTON_LEFT:
			if _pick_at_mouse():
				_select_tool_button(_prev_tool)
			return true

		mouse_down = true
		mouse_start = mouse_current
		mouse_prev = mouse_current
		draw_overlay = true
		update_overlay.emit()
		drag_action_index += 1
		drag_action_count = 0
		if paint_tool == PaintTool.BUCKET:
			_do_bucket_fill(paint_tool == PaintTool.ERASE)
			mouse_down = false
			draw_overlay = false
			update_overlay.emit()
		else:
			_do_paint_stroke()
		return true
	return false

func canvas_mouse_exited() -> void:
	draw_overlay = false
	update_overlay.emit()

func _commit_paint_action() -> void:
	if paint_tool != PaintTool.LINE and paint_tool != PaintTool.RECT:
		return
	if not _has_history() or not tileset:
		return
	var cells := _get_brush_cells()

	if cells.is_empty():
		return
	var saved := _save_cells(_expand_cells(cells))
	var t := _get_selected_terrain()
	if paint_tool == PaintTool.ERASE or selected_index < 0:
		_history_create_action("Erase Action", UndoRedo.MERGE_DISABLE, tilemap)
		for c in cells:
			_history_add_do_method(tilemap, &"erase_cell", [c])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	elif not t.is_empty():
		_history_create_action("Paint Action", UndoRedo.MERGE_DISABLE, tilemap)
		_history_add_do_method(tilemap, &"set_cells_terrain_connect", [cells, t.set, t.idx, true])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	_history_commit_action()

func _do_paint_stroke() -> void:
	var cells := _get_stroke_cells()
	if cells.is_empty():
		return
	if not _has_history():
		return
	var expand := _expand_cells(cells)
	var saved := _save_cells(expand)
	var t := _get_selected_terrain()
	if paint_tool == PaintTool.ERASE or selected_index < 0:
		_history_create_action("Erase Terrain" + str(drag_action_index), UndoRedo.MERGE_ALL, tilemap, true)
		for c in cells:
			_history_add_do_method(tilemap, &"erase_cell", [c])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	elif not t.is_empty() and t.get("set", -1) >= 0 and t.get("idx", -1) >= 0:
		_history_create_action("Paint Terrain" + str(drag_action_index), UndoRedo.MERGE_ALL, tilemap, true)
		_history_add_do_method(tilemap, &"set_cells_terrain_connect", [cells, t.set, t.idx, true])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	else:
		return
	_history_commit_action()
	drag_action_count += 1

func _get_stroke_cells() -> Array[Vector2i]:
	match paint_tool:
		PaintTool.DRAW, PaintTool.ERASE:
			if mouse_prev == mouse_current:
				return [mouse_current]
			return _bresenham_line(mouse_prev, mouse_current)
		PaintTool.RECT, PaintTool.LINE:
			return []
	return []

func _expand_cells(cells: Array[Vector2i]) -> Array:
	var all := {}
	for c in cells:
		all[c] = true
		for peering in [0, 3, 4, 7, 8, 11, 12, 15]:
			var nb := tilemap.get_neighbor_cell(c, peering)
			if nb != c:
				all[nb] = true
	return all.keys()

func _get_brush_cells() -> Array[Vector2i]:
	match paint_tool:
		PaintTool.DRAW, PaintTool.ERASE:
			return [mouse_current]
		PaintTool.LINE:
			return _tileset_line(mouse_start, mouse_current)
		PaintTool.RECT:
			var area := Rect2i(mouse_start, mouse_current - mouse_start).abs()
			var cells: Array[Vector2i] = []
			for y in range(area.position.y, area.end.y + 1):
				for x in range(area.position.x, area.end.x + 1):
					cells.append(Vector2i(x, y))
			return cells
	return []

func _do_bucket_fill(erasing: bool) -> void:
	var cells := _flood_fill(mouse_current)
	if cells.is_empty():
		return
	if not _has_history():
		return
	var saved := _save_cells(_expand_cells(cells))
	var t := _get_selected_terrain()
	if erasing or selected_index < 0:
		_history_create_action("Erase Fill", UndoRedo.MERGE_DISABLE, tilemap)
		for c in cells:
			_history_add_do_method(tilemap, &"erase_cell", [c])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	elif not t.is_empty() and t.get("set", -1) >= 0 and t.get("idx", -1) >= 0:
		_history_create_action("Paint Fill", UndoRedo.MERGE_DISABLE, tilemap)
		_history_add_do_method(tilemap, &"set_cells_terrain_connect", [cells, t.set, t.idx, true])
		_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	else:
		return
	_history_commit_action()

func _flood_fill(start: Vector2i) -> Array:
	var target_src := tilemap.get_cell_source_id(start)
	var bounds := tilemap.get_used_rect()
	bounds = bounds.grow(1)
	var checked := {}
	var pending := [start]
	var result: Array[Vector2i] = []
	while not pending.is_empty():
		var p: Vector2i = pending.pop_front()
		if p in checked:
			continue
		checked[p] = true
		if not bounds.has_point(p):
			continue
		var src := tilemap.get_cell_source_id(p)
		if target_src == -1:
			if src != -1:
				continue
		elif src != target_src:
			continue
		result.append(p)
		for nb in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(p + nb)
	return result

func _pick_at_mouse() -> bool:
	var td := tilemap.get_cell_tile_data(mouse_current)
	if not td:
		return false
	var ts := td.terrain_set
	var tr := td.terrain
	if ts < 0 or tr < 0:
		return false
	for i in flattened_terrains.size():
		var f: Dictionary = flattened_terrains[i]
		if f.set == ts and f.idx == tr:
			selected_index = i
			_update_selection_buttons()
			return true
	return false

# ---- CANVAS OVERLAY ----

func canvas_draw(overlay: Control) -> void:
	if not _is_tilemap_editable() or not tileset:
		return
	_draw_our_grid(overlay)

	if _drag_type == DragType.CLIPBOARD_PASTE and _clipboard and not _clipboard.is_empty():
		_draw_paste_preview(overlay)
		return

	if paint_tool == PaintTool.SEL:
		if _drag_type == DragType.SELECT and mouse_down:
			var sel := Rect2i(mouse_start, mouse_current - mouse_start).abs()
			sel.size += Vector2i(1, 1)
			if not _selection.is_empty() and (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
				_draw_cells_outline(_selection, Color(0.3, 0.7, 1.0, 0.5), overlay)
			if sel.has_area():
				_draw_cells_filled(sel, Color(0.2, 0.6, 1.0, 0.3), overlay)
				var to_draw: Dictionary = {}
				for x in range(sel.position.x, sel.position.x + sel.size.x):
					for y in range(sel.position.y, sel.position.y + sel.size.y):
						var c := Vector2i(x, y)
						if tilemap.get_cell_source_id(c) != -1:
							to_draw[c] = true
				_draw_cells_outline(to_draw, COLOR_SELECTION_OUTLINE, overlay)
		elif _drag_type == DragType.MOVE and mouse_down:
			_draw_move_preview(mouse_current - mouse_start, overlay)
		elif not _selection.is_empty():
			_draw_cells_outline(_selection, COLOR_SELECTION_OUTLINE, overlay)
		return

	if not draw_overlay:
		return
	if not mouse_down:
		if paint_tool == PaintTool.PICK or paint_tool == PaintTool.ERASE:
			var td := tilemap.get_cell_tile_data(mouse_current)
			if not td or td.terrain_set < 0 or td.terrain < 0:
				return
	var color: Color
	if paint_tool == PaintTool.PICK:
		color = Color(0.2, 0.8, 1.0, 0.35)
	elif paint_tool == PaintTool.ERASE or selected_index < 0:
		color = COLOR_ERASE_OVERLAY
	else:
		color = COLOR_PAINT_OVERLAY
	var cells: Array
	if paint_tool == PaintTool.BUCKET and not mouse_down:
		cells = _flood_fill(mouse_current)
	elif mouse_down:
		cells = _get_brush_cells()
	if cells.is_empty():
		cells = [mouse_current]
	var transform := _canvas_tilemap_transform()
	var cell_size := tileset.tile_size
	var polygon := TILE_POLYGON
	for c in cells:
		var cell_transform := Transform2D(0.0, cell_size, 0.0, tilemap.map_to_local(c))
		overlay.draw_colored_polygon(transform * cell_transform * polygon, color)

func _draw_our_grid(overlay: Control) -> void:
	var grid_enabled := _runtime_grid_enabled
	var grid_color := RUNTIME_GRID_COLOR
	if not runtime_mode:
		var settings := _get_editor_settings()
		if not settings:
			return
		grid_enabled = settings.get_setting("editors/tiles_editor/display_grid")
		grid_color = settings.get_setting("editors/tiles_editor/grid_color")
	else:
		_ensure_runtime_settings_loaded()
		grid_enabled = _runtime_grid_enabled
	if not grid_enabled:
		return

	var cell_size := tileset.tile_size
	var tform := _canvas_tilemap_transform()
	var inv := tform.affine_inverse()

	# Scale fading: hide grid when on-screen tile size < 5 pixels
	var hint_distance: Vector2 = tform.get_scale() * Vector2(cell_size)
	var scale_fading := minf(1.0, (minf(absf(hint_distance.x), absf(hint_distance.y)) - 5.0) / 5.0)
	if scale_fading <= 0.0:
		return

	# Calculate viewport bounds in tile space
	var screen_size := _get_canvas_viewport_size()
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var corners: Array = [
		inv * Vector2.ZERO,
		inv * Vector2(screen_size.x, 0),
		inv * Vector2(screen_size.x, screen_size.y),
		inv * Vector2(0, screen_size.y),
	]
	var screen_rect := Rect2i(tilemap.local_to_map(corners[0]), Vector2i.ZERO)
	for i: int in range(1, 4):
		screen_rect = screen_rect.expand(tilemap.local_to_map(corners[i]))
	screen_rect = screen_rect.grow(1)

	# Intersect with used rect, add fade margin of 5 cells
	var used_rect := tilemap.get_used_rect()
	const FADING := 5
	var intersected := used_rect.intersection(screen_rect)
	if not intersected.has_area():
		return
	var displayed_rect := intersected.grow(FADING)
	if displayed_rect.size.x <= 0 or displayed_rect.size.y <= 0:
		return

	# Performance clamp: max 100x100 cells visible
	const MAX_SIZE := 100
	if displayed_rect.size.x > MAX_SIZE:
		var excess := (displayed_rect.size.x - MAX_SIZE) / 2
		displayed_rect = Rect2i(displayed_rect.position.x + excess, displayed_rect.position.y, MAX_SIZE, displayed_rect.size.y)
	if displayed_rect.size.y > MAX_SIZE:
		var excess := (displayed_rect.size.y - MAX_SIZE) / 2
		displayed_rect = Rect2i(displayed_rect.position.x, displayed_rect.position.y + excess, displayed_rect.size.x, MAX_SIZE)

	# Square tile shape: draw 4-line outline per cell (matches native renderer)
	if tileset.tile_shape == TileSet.TILE_SHAPE_SQUARE:
		for x in range(displayed_rect.position.x, displayed_rect.position.x + displayed_rect.size.x):
			for y in range(displayed_rect.position.y, displayed_rect.position.y + displayed_rect.size.y):
				var pos_in_rect := Vector2i(x, y) - displayed_rect.position

				# Fade out at edges: 5-cell gradient
				var left_opacity := clampf(inverse_lerp(0.0, float(FADING), float(pos_in_rect.x)), 0.0, 1.0)
				var right_opacity := clampf(inverse_lerp(float(displayed_rect.size.x), float(displayed_rect.size.x - FADING), float(pos_in_rect.x + 1)), 0.0, 1.0)
				var top_opacity := clampf(inverse_lerp(0.0, float(FADING), float(pos_in_rect.y)), 0.0, 1.0)
				var bottom_opacity := clampf(inverse_lerp(float(displayed_rect.size.y), float(displayed_rect.size.y - FADING), float(pos_in_rect.y + 1)), 0.0, 1.0)
				var opacity := clampf(minf(left_opacity, minf(right_opacity, minf(top_opacity, bottom_opacity))) + 0.1, 0.0, 1.0)

				var center := tilemap.map_to_local(Vector2i(x, y))
				var half := Vector2(cell_size) / 2.0
				var top_left := tform * (center - half)
				var top_right := tform * (center + Vector2(half.x, -half.y))
				var bottom_right := tform * (center + half)
				var bottom_left := tform * (center + Vector2(-half.x, half.y))

				var color := grid_color
				color.a *= opacity * scale_fading

				overlay.draw_line(top_left, top_right, color, -1.0, false)
				overlay.draw_line(top_right, bottom_right, color, -1.0, false)
				overlay.draw_line(bottom_right, bottom_left, color, -1.0, false)
				overlay.draw_line(bottom_left, top_left, color, -1.0, false)
	else:
		# Non-square shapes: use per-cell polyline outline
		var polygon: PackedVector2Array = _get_tile_shape_polygon()
		for x in range(displayed_rect.position.x, displayed_rect.position.x + displayed_rect.size.x):
			for y in range(displayed_rect.position.y, displayed_rect.position.y + displayed_rect.size.y):
				var pos_in_rect := Vector2i(x, y) - displayed_rect.position
				var left_opacity := clampf(inverse_lerp(0.0, float(FADING), float(pos_in_rect.x)), 0.0, 1.0)
				var right_opacity := clampf(inverse_lerp(float(displayed_rect.size.x), float(displayed_rect.size.x - FADING), float(pos_in_rect.x + 1)), 0.0, 1.0)
				var top_opacity := clampf(inverse_lerp(0.0, float(FADING), float(pos_in_rect.y)), 0.0, 1.0)
				var bottom_opacity := clampf(inverse_lerp(float(displayed_rect.size.y), float(displayed_rect.size.y - FADING), float(pos_in_rect.y + 1)), 0.0, 1.0)
				var opacity := clampf(minf(left_opacity, minf(right_opacity, minf(top_opacity, bottom_opacity))) + 0.1, 0.0, 1.0)

				var tile_xform := Transform2D(0.0, cell_size, 0.0, tilemap.map_to_local(Vector2i(x, y)))
				var world_polygon := tform * tile_xform * polygon
				var color := grid_color
				color.a *= opacity * scale_fading
				overlay.draw_polyline(world_polygon, color, -1.0, false)

func _get_tile_shape_polygon() -> PackedVector2Array:
	match tileset.tile_shape:
		TileSet.TILE_SHAPE_SQUARE:
			return PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)])
		TileSet.TILE_SHAPE_ISOMETRIC:
			return PackedVector2Array([Vector2(0.0, -0.5), Vector2(-0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.0), Vector2(0.0, -0.5)])
		_:
			var overlap: float = 0.25 if tileset.tile_shape == TileSet.TILE_SHAPE_HEXAGON else 0.0
			var pts := PackedVector2Array([
				Vector2(0.0, -0.5),
				Vector2(-0.5, overlap - 0.5),
				Vector2(-0.5, 0.5 - overlap),
				Vector2(0.0, 0.5),
				Vector2(0.5, 0.5 - overlap),
				Vector2(0.5, overlap - 0.5),
				Vector2(0.0, -0.5),
			])
			if tileset.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
				for i in pts.size():
					pts[i] = Vector2(pts[i].y, pts[i].x)
			return pts

func _canvas_tilemap_transform() -> Transform2D:
	if not tilemap:
		return Transform2D.IDENTITY
	if canvas_transform_provider.is_valid():
		var provided = canvas_transform_provider.call(tilemap)
		if provided is Transform2D:
			return provided
	var transform := tilemap.get_viewport_transform() * tilemap.global_transform
	var editor_interface := _get_editor_interface()
	var editor_viewport: Viewport = null
	if editor_interface:
		editor_viewport = editor_interface.call("get_editor_viewport_2d") as Viewport
	if editor_viewport and tilemap.get_viewport() != editor_viewport:
		var container := tilemap.get_viewport().get_parent() as SubViewportContainer
		if container:
			transform = editor_viewport.global_canvas_transform * container.get_transform() * transform
	return transform

func _get_canvas_viewport_size() -> Vector2:
	if viewport_size_provider.is_valid():
		var provided = viewport_size_provider.call()
		if provided is Vector2:
			return provided
	var editor_interface := _get_editor_interface()
	if editor_interface:
		var editor_viewport := editor_interface.call("get_editor_viewport_2d") as Viewport
		if editor_viewport:
			return editor_viewport.get_visible_rect().size
	if get_viewport():
		return get_viewport().get_visible_rect().size
	return Vector2.ZERO

# ---- LINE ALGORITHMS ----

func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [to]
	var points: Array[Vector2i] = []
	var delta := (to - from).abs() * 2
	var step := (to - from).sign()
	var current := from
	if delta.x > delta.y:
		var err := delta.x / 2
		while current.x != to.x:
			points.append(current)
			err -= delta.y
			if err < 0:
				current.y += step.y
				err += delta.x
			current.x += step.x
	else:
		var err := delta.y / 2
		while current.y != to.y:
			points.append(current)
			err -= delta.x
			if err < 0:
				current.x += step.x
				err += delta.y
			current.y += step.y
	points.append(current)
	return points

func _tileset_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if tileset.tile_shape == TileSet.TILE_SHAPE_SQUARE:
		return _bresenham_line(from, to)
	var points: Array[Vector2i] = []
	var transposed := tileset.get_tile_offset_axis() == TileSet.TILE_OFFSET_AXIS_VERTICAL
	var f := from
	var t := to
	if transposed:
		f = Vector2i(from.y, from.x)
		t = Vector2i(to.y, to.x)
	var delta := Vector2i(2 * (t.x - f.x) + abs(posmod(t.y, 2)) - abs(posmod(f.y, 2)), t.y - f.y)
	var sign := delta.sign()
	var current := f
	points.append(Vector2i(current.y, current.x) if transposed else current)
	var err := 0
	if abs(delta.y) < abs(delta.x):
		var err_step := 3 * delta.abs()
		while current != t:
			err += err_step.y
			if err > abs(delta.x):
				current.x += (sign.x if bool(current.y % 2) != (sign.x < 0) else 0) if sign.x != 0 else sign.y
				current.y += sign.y
				err -= err_step.x
			else:
				current.x += sign.x
				err += err_step.y
			points.append(Vector2i(current.y, current.x) if transposed else current)
	else:
		var err_step := delta.abs()
		while current != t:
			err += err_step.x
			if err > 0:
				current.x += (sign.x if bool(current.y % 2) != (sign.x < 0) else 0) if sign.x != 0 else sign.y
				current.y += sign.y
				err -= err_step.y
			else:
				current.x += (-sign.x if bool(current.y % 2) != (sign.x > 0) else 0) if sign.x != 0 else sign.y
				current.y += sign.y
				err += err_step.y
			points.append(Vector2i(current.y, current.x) if transposed else current)
	return points

# ---- ERASE ALL ----

func _on_erase_all() -> void:
	if not tilemap or not _has_history():
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Erase ALL tiles on layer '%s'?" % tilemap.name
	dialog.get_ok_button().text = "Erase All"
	if runtime_mode:
		add_child(dialog)
		dialog.popup_centered()
	else:
		var editor_interface := _get_editor_interface()
		if editor_interface:
			editor_interface.call("popup_dialog_centered", dialog)
		else:
			add_child(dialog)
			dialog.popup_centered()
	dialog.confirmed.connect(func():
		_erase_all_tiles()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

func _erase_all_tiles() -> void:
	if not tilemap or not _has_history():
		return
	var cells := tilemap.get_used_cells()
	var saved := _save_cells(cells)
	_history_create_action("Erase All on " + tilemap.name, UndoRedo.MERGE_DISABLE, tilemap)
	for c in cells:
		_history_add_do_method(tilemap, &"erase_cell", [c])
	_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	_history_commit_action()

# ---- UTILITY ----

func _await_dialog(dialog: AcceptDialog) -> bool:
	var confirmed := false
	dialog.confirmed.connect(func(): confirmed = true; dialog.hide())
	dialog.canceled.connect(dialog.hide)
	await dialog.visibility_changed
	return confirmed

func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var check := {}
	for v in a:
		check[v] = true
	for v in b:
		if not check.has(v):
			return false
	return true

func _is_editor_select_mode() -> bool:
	if not Engine.is_editor_hint():
		return true
	var btn := _find_canvas_select_mode_button()
	if not btn:
		return true
	return btn.button_pressed

func _ensure_editor_select_mode() -> void:
	if not Engine.is_editor_hint():
		return
	var btn := _find_canvas_select_mode_button()
	if btn and not btn.button_pressed:
		btn.button_pressed = true
		btn.pressed.emit()

func _find_canvas_select_mode_button() -> BaseButton:
	var editor_interface := _get_editor_interface()
	var vp: Viewport = null
	if editor_interface:
		vp = editor_interface.call("get_editor_viewport_2d") as Viewport
	if not vp:
		return null
	var node: Node = vp
	for _i in 6:
		node = node.get_parent()
		if not node:
			return null
		var result := _find_first_toggle_in(node)
		if result:
			return result
	return null

func _find_first_toggle_in(node: Node) -> BaseButton:
	var mode_names := ["Select Mode", "Select"]
	for child in node.get_children():
		if child is HBoxContainer:
			for btn in child.get_children():
				if btn is BaseButton and btn.toggle_mode:
					if btn.tooltip_text in mode_names:
						return btn
		var found := _find_first_toggle_in(child)
		if found:
			return found
	return null

# ---- SELECTION TOOL ----

func _draw_cells_outline(cells: Dictionary, color: Color, overlay: Control) -> void:
	var tform := _canvas_tilemap_transform()
	var cell_size := tileset.tile_size
	var half := Vector2(cell_size) / 2.0
	for c in cells:
		var center := tilemap.map_to_local(c)
		var tl := tform * (center - half)
		var tr := tform * (center + Vector2(half.x, -half.y))
		var br := tform * (center + half)
		var bl := tform * (center + Vector2(-half.x, half.y))

		if not cells.has(c + Vector2i.RIGHT):
			overlay.draw_line(tr, br, color)
		if not cells.has(c + Vector2i.DOWN):
			overlay.draw_line(br, bl, color)
		if not cells.has(c + Vector2i.LEFT):
			overlay.draw_line(bl, tl, color)
		if not cells.has(c + Vector2i.UP):
			overlay.draw_line(tl, tr, color)

func _draw_cells_filled(rect: Rect2i, color: Color, overlay: Control) -> void:
	var tform := _canvas_tilemap_transform()
	var cell_size := tileset.tile_size
	var polygon := TILE_POLYGON
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var cell_transform := Transform2D(0.0, cell_size, 0.0, tilemap.map_to_local(Vector2i(x, y)))
			overlay.draw_colored_polygon(tform * cell_transform * polygon, color)

func _draw_move_preview(offset: Vector2i, overlay: Control) -> void:
	var tform := _canvas_tilemap_transform()
	var cell_size := tileset.tile_size
	var half := Vector2(cell_size) / 2.0
	var polygon := TILE_POLYGON

	for c in _drag_modified:
		var dc: Dictionary = _drag_modified[c]
		if not dc.has_cell:
			continue
		var new_cell: Vector2i = c + offset
		var source := tileset.get_source(dc.source_id) as TileSetAtlasSource
		if source and source.texture:
			var region := source.get_tile_texture_region(dc.atlas_coords, 0)
			var center := tilemap.map_to_local(new_cell)
			var dest_top_left := tform * (center - half)
			var dest_bottom_right := tform * (center + half)
			var dest_rect := Rect2(dest_top_left, dest_bottom_right - dest_top_left)
			overlay.draw_texture_rect_region(source.texture, dest_rect, region, COLOR_PAINT_OVERLAY)
		else:
			var cell_transform := Transform2D(0.0, cell_size, 0.0, tilemap.map_to_local(new_cell))
			overlay.draw_colored_polygon(tform * cell_transform * polygon, COLOR_MOVE_PASTE_FALLBACK)

func _commit_selection() -> void:
	var rect := Rect2i(mouse_start, mouse_current - mouse_start).abs()
	var ctrl_or_cmd := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	var old_selection := _selection.keys()
	if not Input.is_key_pressed(KEY_SHIFT) and not ctrl_or_cmd:
		_selection.clear()
	for x in range(rect.position.x, rect.position.x + rect.size.x + 1):
		for y in range(rect.position.y, rect.position.y + rect.size.y + 1):
			var c := Vector2i(x, y)
			if ctrl_or_cmd:
				_selection.erase(c)
			elif tilemap.get_cell_source_id(c) != -1:
				_selection[c] = true
	if _has_history() and not _arrays_equal(old_selection, _selection.keys()):
		_history_create_action("Change Selection", UndoRedo.MERGE_DISABLE, tilemap)
		_history_add_undo_method(self, &"_set_selection", [old_selection])
		_history_add_do_method(self, &"_set_selection", [_selection.keys()])
		_history_commit_action()
	_drag_type = DragType.NONE

func _start_move(mouse_pos: Vector2i) -> void:
	_drag_type = DragType.MOVE
	mouse_down = true
	mouse_start = mouse_pos
	mouse_prev = mouse_pos
	_drag_modified.clear()
	for c in _selection:
		_drag_modified[c] = _get_cell_state(c)
		tilemap.erase_cell(c)
	draw_overlay = true
	update_overlay.emit()

func _restore_move_cells() -> void:
	for c in _drag_modified:
		_restore_cell_state(c, _drag_modified[c], tilemap)
	_drag_modified.clear()

func _commit_move() -> void:
	if _drag_modified.is_empty() or not _has_history():
		_drag_type = DragType.NONE
		mouse_down = false
		return

	var offset := mouse_current - mouse_start
	if offset == Vector2i.ZERO:
		_restore_move_cells()
		_drag_type = DragType.NONE
		mouse_down = false
		return

	var old_selection := _selection.keys()
	var new_selection: Array[Vector2i] = []
	for c in _drag_modified:
		var dc: Dictionary = _drag_modified[c]
		if dc.has_cell:
			new_selection.append(c + offset)

	_history_create_action("Move Tiles", UndoRedo.MERGE_DISABLE, tilemap)

	# DO: clear old positions, then set new positions, then update selection
	for c in _drag_modified:
		var dc: Dictionary = _drag_modified[c]
		if dc.has_cell:
			_history_add_do_method(tilemap, &"erase_cell", [c])
	for c in _drag_modified:
		var dc: Dictionary = _drag_modified[c]
		if dc.has_cell:
			var new_cell: Vector2i = c + offset
			if tileset.has_source(dc.source_id):
				_history_add_do_method(tilemap, &"set_cell", [new_cell, dc.source_id, dc.atlas_coords, dc.alternative_tile])
	_history_add_do_method(self, &"_set_selection", [new_selection])

	# UNDO: restore in reverse — selection, then what was at new positions, then clear new, then restore old
	_history_add_undo_method(self, &"_set_selection", [old_selection])
	for c in _drag_modified:
		var new_cell: Vector2i = c + offset
		var orig_src: int = -1
		var orig_atlas: Vector2i = Vector2i.ZERO
		var orig_alt: int = 0
		if _drag_modified.has(new_cell):
			var d2: Dictionary = _drag_modified[new_cell]
			orig_src = d2.source_id
			orig_atlas = d2.atlas_coords
			orig_alt = d2.alternative_tile
		else:
			orig_src = tilemap.get_cell_source_id(new_cell)
			orig_atlas = tilemap.get_cell_atlas_coords(new_cell) if orig_src != -1 else Vector2i.ZERO
			orig_alt = tilemap.get_cell_alternative_tile(new_cell) if orig_src != -1 else 0
		if orig_src != -1:
			_history_add_undo_method(tilemap, &"set_cell", [new_cell, orig_src, orig_atlas, orig_alt])
		else:
			_history_add_undo_method(tilemap, &"erase_cell", [new_cell])
	for c in _drag_modified:
		var du: Dictionary = _drag_modified[c]
		if du.has_cell:
			_history_add_undo_method(tilemap, &"set_cell", [c, du.source_id, du.atlas_coords, du.alternative_tile])
		else:
			_history_add_undo_method(tilemap, &"erase_cell", [c])

	_history_commit_action()

	_selection.clear()
	for c in new_selection:
		_selection[c] = true
	_drag_modified.clear()
	_drag_type = DragType.NONE
	_held_button_count = 0
	mouse_down = false

func _set_selection(arr: Array) -> void:
	_selection.clear()
	for v in arr:
		_selection[v] = true
	update_overlay.emit()

# ---- CLIPBOARD (CUT / COPY / PASTE) ----

func _handle_key_event(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false

	if event.keycode == KEY_ESCAPE and _drag_type == DragType.CLIPBOARD_PASTE:
		_drag_type = DragType.NONE
		update_overlay.emit()
		return true

	if event.is_command_or_control_pressed():
		match event.keycode:
			KEY_C:
				_do_copy()
				return true
			KEY_X:
				_do_cut()
				return true
			KEY_V:
				_do_paste()
				return true
		return false

	# Action-based tool switching (supports InputMap remapping)
	if event.is_action_pressed("tyle_draw"):
		_select_tool_button(PaintTool.DRAW)
		return true
	if event.is_action_pressed("tyle_rect"):
		_select_tool_button(PaintTool.RECT)
		return true
	if event.is_action_pressed("tyle_line"):
		_select_tool_button(PaintTool.LINE)
		return true
	if event.is_action_pressed("tyle_fill"):
		_select_tool_button(PaintTool.BUCKET)
		return true
	if event.is_action_pressed("tyle_select"):
		_select_tool_button(PaintTool.SEL)
		return true
	if event.is_action_pressed("tyle_pick"):
		_select_tool_button(PaintTool.PICK)
		return true
	if event.is_action_pressed("tyle_erase"):
		_select_tool_button(PaintTool.ERASE)
		return true

	# Fallback: shortcut-based matching on buttons (InputEventKey shortcuts)
	for i in range(1, _tool_buttons.size()):
		var btn := _tool_buttons[i] as Button
		if btn and btn.visible and not btn.disabled and btn.shortcut and btn.shortcut.matches_event(event):
			_select_tool_button(i)
			return true
	return false

func _do_copy() -> void:
	if _selection.is_empty():
		return
	var coords: Array[Vector2i] = []
	for c in _selection:
		coords.append(c)
	_clipboard = tilemap.get_pattern(coords)

func _do_cut() -> void:
	if _selection.is_empty():
		return
	_do_copy()
	if not _has_history():
		return
	var saved := _save_cells(_selection.keys())
	var old_selection := _selection.keys()
	_history_create_action("Cut Tiles", UndoRedo.MERGE_DISABLE, tilemap)
	for c in _selection:
		_history_add_do_method(tilemap, &"erase_cell", [c])
	_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	_history_add_undo_method(self, &"_set_selection", [old_selection])
	_selection.clear()
	_history_add_do_method(self, &"_set_selection", [_selection.keys()])
	_history_commit_action()
	update_overlay.emit()

func _do_paste() -> void:
	if not _clipboard or _clipboard.is_empty():
		return
	if _drag_type != DragType.NONE:
		return
	if not _validate_clipboard_tileset():
		return
	_drag_type = DragType.CLIPBOARD_PASTE
	update_overlay.emit()

func _validate_clipboard_tileset() -> bool:
	if not _clipboard or _clipboard.is_empty():
		return false
	for coord in _clipboard.get_used_cells():
		var src_id := _clipboard.get_cell_source_id(coord)
		if src_id != -1 and not tileset.has_source(src_id):
			return false
	return true

func _get_paste_origin(pattern: TileMapPattern, mouse_cell: Vector2i) -> Vector2i:
	var pattern_size := pattern.get_size()
	var center_offset := (Vector2(pattern_size) / 2.0 - Vector2(0.5, 0.5)) * Vector2(tileset.tile_size)
	return tilemap.local_to_map(tilemap.map_to_local(mouse_cell) - center_offset)

func _commit_paste() -> void:
	if not _clipboard or _clipboard.is_empty() or not _has_history():
		_drag_type = DragType.NONE
		return

	var pattern_pos := _get_paste_origin(_clipboard, mouse_current)

	var used_cells := _clipboard.get_used_cells()
	var saved := {}
	for coord in used_cells:
		var world_cell := pattern_pos + coord
		saved[world_cell] = _get_cell_state(world_cell)

	_history_create_action("Paste Tiles", UndoRedo.MERGE_DISABLE, tilemap)
	for coord in used_cells:
		var world_cell := pattern_pos + coord
		_history_add_do_method(tilemap, &"set_cell", [world_cell,
			_clipboard.get_cell_source_id(coord),
			_clipboard.get_cell_atlas_coords(coord),
			_clipboard.get_cell_alternative_tile(coord)])
	_history_add_undo_method(self, &"_restore_cells", [saved, tilemap])
	_history_commit_action()

	_drag_type = DragType.NONE
	update_overlay.emit()

func _draw_paste_preview(overlay: Control) -> void:
	var tform := _canvas_tilemap_transform()
	var cell_size := tileset.tile_size
	var half := Vector2(cell_size) / 2.0
	var polygon := TILE_POLYGON

	var pattern_pos := _get_paste_origin(_clipboard, mouse_current)

	for coord in _clipboard.get_used_cells():
		var world_cell: Vector2i = pattern_pos + coord
		var source_id: int = _clipboard.get_cell_source_id(coord)
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		if source and source.texture:
			var atlas_coords := _clipboard.get_cell_atlas_coords(coord)
			var region := source.get_tile_texture_region(atlas_coords, 0)
			var center := tilemap.map_to_local(world_cell)
			var top_left := tform * (center - half)
			var bottom_right := tform * (center + half)
			overlay.draw_texture_rect_region(source.texture, Rect2(top_left, bottom_right - top_left), region, Color(1.0, 1.0, 1.0, 0.5))
		else:
			var cell_transform := Transform2D(0.0, cell_size, 0.0, tilemap.map_to_local(world_cell))
			overlay.draw_colored_polygon(tform * cell_transform * polygon, COLOR_MOVE_PASTE_FALLBACK)
