extends Node2D

@export var map_path: NodePath = NodePath("PentaTileMapLayer")
@export var paint_source_id: int = 0
@export var paint_atlas_coords: Vector2i = Vector2i(0, 0)

@onready var penta_map: PentaTileMapLayer = get_node(map_path)

var _active_button := MOUSE_BUTTON_NONE
var _last_cell := Vector2i(1073741823, 1073741823)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	if mouse_event.pressed:
		_active_button = mouse_event.button_index
		_last_cell = Vector2i(1073741823, 1073741823)
		_apply_at_event_position(mouse_event.position, _active_button)
	elif mouse_event.button_index == _active_button:
		_active_button = MOUSE_BUTTON_NONE
		_last_cell = Vector2i(1073741823, 1073741823)


func _handle_mouse_motion(mouse_event: InputEventMouseMotion) -> void:
	if _active_button == MOUSE_BUTTON_NONE:
		return
	_apply_at_event_position(mouse_event.position, _active_button)


func _apply_at_event_position(event_position: Vector2, button: MouseButton) -> void:
	var canvas_position := get_canvas_transform().affine_inverse() * event_position
	var cell := penta_map.local_to_map(penta_map.to_local(canvas_position))
	if cell == _last_cell:
		return
	_last_cell = cell

	_apply_cell(cell, button)


func _apply_cell(cell: Vector2i, button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_LEFT:
			penta_map.set_cell(cell, paint_source_id, paint_atlas_coords)
		MOUSE_BUTTON_RIGHT:
			penta_map.erase_cell(cell)
