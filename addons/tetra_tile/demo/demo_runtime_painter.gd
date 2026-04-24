extends Node2D

@export var map_path: NodePath = NodePath("TetraTileMapLayer")
@export var paint_source_id: int = 0
@export var paint_atlas_coords: Vector2i = Vector2i(0, 0)

@onready var tetra_map: TetraTileMapLayer = get_node(map_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var canvas_position := get_canvas_transform().affine_inverse() * mouse_event.position
	var cell := tetra_map.local_to_map(tetra_map.to_local(canvas_position))
	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			tetra_map.set_cell(cell, paint_source_id, paint_atlas_coords)
		MOUSE_BUTTON_RIGHT:
			tetra_map.erase_cell(cell)
