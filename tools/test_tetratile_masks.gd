@tool
extends SceneTree

const TETRA_TILE_MAP_LAYER := preload("res://addons/tetratile/tetra_tile_map_layer.gd")
const PRIMARY_LAYER := "_TetraTileVisual"
const OVERLAY_LAYER := "_TetraTileDiagonalOverlay"

const ROTATE_0 := 0
const ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

var _failures := 0


func _init() -> void:
	var layer := TileMapLayer.new()
	layer.set_script(TETRA_TILE_MAP_LAYER)
	layer.tile_set = _make_tile_set()
	root.add_child(layer)
	await process_frame

	var cases := {
		0: [Vector2i(-1, -1), 0, Vector2i(-1, -1), 0],
		1: [Vector2i(3, 0), ROTATE_90, Vector2i(-1, -1), 0],
		2: [Vector2i(3, 0), ROTATE_180, Vector2i(-1, -1), 0],
		3: [Vector2i(2, 0), ROTATE_180, Vector2i(-1, -1), 0],
		4: [Vector2i(3, 0), ROTATE_0, Vector2i(-1, -1), 0],
		5: [Vector2i(2, 0), ROTATE_90, Vector2i(-1, -1), 0],
		6: [Vector2i(3, 0), ROTATE_180, Vector2i(3, 0), ROTATE_0],
		7: [Vector2i(1, 0), ROTATE_90, Vector2i(-1, -1), 0],
		8: [Vector2i(3, 0), ROTATE_270, Vector2i(-1, -1), 0],
		9: [Vector2i(3, 0), ROTATE_90, Vector2i(3, 0), ROTATE_270],
		10: [Vector2i(2, 0), ROTATE_270, Vector2i(-1, -1), 0],
		11: [Vector2i(1, 0), ROTATE_180, Vector2i(-1, -1), 0],
		12: [Vector2i(2, 0), ROTATE_0, Vector2i(-1, -1), 0],
		13: [Vector2i(1, 0), ROTATE_0, Vector2i(-1, -1), 0],
		14: [Vector2i(1, 0), ROTATE_270, Vector2i(-1, -1), 0],
		15: [Vector2i(0, 0), ROTATE_0, Vector2i(-1, -1), 0],
	}

	for mask: int in cases:
		_paint_logic_for_mask(layer, mask)
		layer.call("rebuild")
		var expected: Array = cases[mask]
		_assert_cell(layer.get_node(PRIMARY_LAYER), mask, "primary", expected[0], expected[1])
		_assert_cell(layer.get_node(OVERLAY_LAYER), mask, "overlay", expected[2], expected[3])

	quit(_failures)


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://tetra_tile_ground.png")
	atlas.texture_region_size = Vector2i(16, 16)
	for x in range(4):
		atlas.create_tile(Vector2i(x, 0))
	tile_set.add_source(atlas, 0)
	return tile_set


func _paint_logic_for_mask(layer: TileMapLayer, mask: int) -> void:
	layer.clear()
	if mask & 1:
		layer.set_cell(Vector2i(-1, -1), 0, Vector2i(0, 0))
	if mask & 2:
		layer.set_cell(Vector2i(0, -1), 0, Vector2i(0, 0))
	if mask & 4:
		layer.set_cell(Vector2i(-1, 0), 0, Vector2i(0, 0))
	if mask & 8:
		layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))


func _assert_cell(
		layer: TileMapLayer,
		mask: int,
		layer_name: String,
		expected_coords: Vector2i,
		expected_alternative: int,
) -> void:
	var actual_coords := layer.get_cell_atlas_coords(Vector2i.ZERO)
	var actual_alternative := layer.get_cell_alternative_tile(Vector2i.ZERO)
	if actual_coords != expected_coords:
		_fail("mask %d %s coords: expected %s, got %s" % [mask, layer_name, expected_coords, actual_coords])
	if expected_coords != Vector2i(-1, -1) and actual_alternative != expected_alternative:
		_fail("mask %d %s alternative: expected %d, got %d" % [mask, layer_name, expected_alternative, actual_alternative])


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
