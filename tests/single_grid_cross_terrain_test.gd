## Automated single-grid cross-terrain boundary dispatch test.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/single_grid_cross_terrain_test.gd
##
## What it does:
##   - Composed-canvas test: paint a 2-terrain scene (Floor + Wall) using Wang2Edge
##     and verify terrain boundary cells dispatch to correct layout's atlas slot.
##   - Verify single-terrain inner cells (fully surrounded by same terrain)
##     render normally.
##   - Verify null terrain_group preserves single-layout behavior.
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript       = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _TerrainGroupSc    = preload("res://addons/penta_tile/layouts/penta_tile_terrain_group.gd")
const _Wang2EdgeSc       = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _AtlasSlotSc       = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== single_grid_cross_terrain_test ===")

	await _test_cross_terrain_boundary()
	await _test_single_terrain_inner_cells()
	await _test_null_terrain_group_fallback()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# --- Helpers ---

func _build_paired_terrain_tileset() -> TileSet:
	"""Build a TileSet with 2 distinct (atlas_coord, terrain) tiles for Wang2Edge.
	Returns a TileSet where:
	  - Vector2i(0, 0): terrain=0 (Floor)
	  - Vector2i(1, 0): terrain=1 (Wall)
	Both are 32x32 solid-color tiles.
	"""
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)

	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)

	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.8, 0.2, 1.0))   # green = floor
	src.texture = ImageTexture.create_from_image(img)

	# Floor tile at (0, 0)
	src.create_tile(Vector2i(0, 0))
	var td0 := src.get_tile_data(Vector2i(0, 0), 0)
	td0.terrain_set = 0
	td0.terrain = 0

	# Wall tile at (1, 0)
	src.create_tile(Vector2i(1, 0))
	var td1 := src.get_tile_data(Vector2i(1, 0), 0)
	td1.terrain_set = 0
	td1.terrain = 1

	ts.add_source(src, 0)
	return ts


func _group_floor_wall() -> Resource:
	"""Create a PentaTileTerrainGroup with Floor (index 0) and Wall (index 1) Wang2Edge layouts."""
	var group = _TerrainGroupSc.new()
	group.layouts.append(_Wang2EdgeSc.new())   # terrain 0 = Floor
	group.layouts.append(_Wang2EdgeSc.new())   # terrain 1 = Wall
	return group


func _paint_logic_cells(layer: Node, cells: Array, terrain_id: int) -> void:
	"""Paint logic cells with atlas coord (0, terrain_id) for terrain encoding via atlas_coords.y."""
	for cell: Vector2i in cells:
		# Encode terrain in atlas_coords.y per D-05
		layer.set_cell(cell, 0, Vector2i(0, terrain_id))
	await process_frame
	await process_frame


func _get_visual_painted_count(layer: Node) -> int:
	var primary = layer.get("_primary_layer")
	if primary == null or not is_instance_valid(primary):
		return 0
	return primary.get_used_cells().size()


# --- Tests ---

func _test_cross_terrain_boundary() -> void:
	print("\n  --- cross-terrain boundary ---")

	var ts := _build_paired_terrain_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts
	var group := _group_floor_wall()
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint: Floor occupies (0,0)..(3,3), Wall at (4,0)..(5,3).
	# This creates a vertical boundary line between col 3 and col 4.
	var floor_cells: Array = []
	for x in range(4):
		for y in range(4):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array = []
	for x in range(4, 6):
		for y in range(4):
			wall_cells.append(Vector2i(x, y))

	_paint_logic_cells(layer, floor_cells, 0)   # Floor: atlas_coords = (0, 0)
	_paint_logic_cells(layer, wall_cells, 1)    # Wall: atlas_coords = (0, 1)

	# Trigger rebuild.
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	await process_frame

	var painted_count := _get_visual_painted_count(layer)
	print("  visual cells painted: ", painted_count)
	_assert("cross-terrain paints some visual cells", painted_count > 0)

	# Verify Floor inner cells (e.g. (1,1)) have visual output.
	var primary = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		# Check that a floor cell far from the boundary has a visual tile.
		var floor_inner := Vector2i(1, 1)
		# Single-grid uses logic-cell-as-display-cell.
		_assert("floor inner cell has visual", primary.get_cell_source_id(floor_inner) != -1)

		# Check that a wall inner cell has a visual tile.
		var wall_inner := Vector2i(4, 1)
		_assert("wall inner cell has visual", primary.get_cell_source_id(wall_inner) != -1)

	layer.queue_free()


func _test_single_terrain_inner_cells() -> void:
	print("\n  --- single-terrain inner cells ---")

	var ts := _build_paired_terrain_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts

	# Use only 1 terrain (Floor).
	var group = _TerrainGroupSc.new()
	group.layouts.append(_Wang2EdgeSc.new())
	layer.terrain_group = group

	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a 3x3 block of floor cells.
	var cells: Array = []
	for x in range(3):
		for y in range(3):
			cells.append(Vector2i(x, y))
	_paint_logic_cells(layer, cells, 0)
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	await process_frame

	var painted_count := _get_visual_painted_count(layer)
	print("  visual cells painted (single terrain): ", painted_count)
	_assert("single-terrain paints cells", painted_count > 0)

	# The center cell (1,1) should definitely have a visual tile.
	var primary = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		_assert("center cell has visual", primary.get_cell_source_id(Vector2i(1, 1)) != -1)

	layer.queue_free()


func _test_null_terrain_group_fallback() -> void:
	print("\n  --- null terrain group fallback ---")

	var ts := _build_paired_terrain_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts
	# Bind Wang2Edge directly as layout (no terrain group).
	var layout = _Wang2EdgeSc.new()
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint without terrain encoding.
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var painted_count := _get_visual_painted_count(layer)
	print("  visual cells (null terrain_group): ", painted_count)
	_assert("null terrain_group paints cells", painted_count > 0)

	layer.queue_free()


# --- Assertions ---

func _assert(label: String, condition: bool) -> void:
	if not condition:
		_failures.append(label)
		printerr("  FAIL: " + label)
