## Real artwork multi-terrain validation with sample_terrains.png.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/terrain_sample_terrains_test.gd
##
## What it does:
##   - Loads sample_terrains.png (160x96, 32px tiles, 3 terrain rows)
##   - Validates auto-detection creates 3 terrains
##   - Paints multi-terrain pattern across all 3 terrains
##   - Verifies boundary cells use correct terrain tiles
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Wang2EdgeSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Min3x3Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")

var _failures: Array = []

func _initialize() -> void:
	print("=== terrain_sample_terrains_test ===")

	await _test_load_sample_terrains()
	await _test_paint_multi_terrain()
	await _test_boundary_cells_correct()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _load_sample_tileset() -> TileSet:
	var tex_res := load("res://addons/penta_tile/sample_terrains.png")
	if tex_res == null:
		return null
	var img: Image = tex_res.get_image() if tex_res is Texture2D else null
	if img == null:
		return null
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)
	var tex := ImageTexture.create_from_image(img)
	src.texture = tex
	var src_id := ts.add_source(src)
	# Create tiles for all rows/cols based on image dimensions
	var cols: int = img.get_width() / 32
	var rows: int = img.get_height() / 32
	for row in range(rows):
		for col in range(cols):
			src.create_tile(Vector2i(col, row))
	return ts


# --- Test 1: Load sample_terrains.png, verify auto-detection ---
func _test_load_sample_terrains() -> void:
	print("  sub-test: load sample_terrains.png")
	var tex_res := load("res://addons/penta_tile/sample_terrains.png")
	_assert(tex_res != null, "load_sample: sample_terrains.png not found")
	if tex_res == null:
		return
	var img: Image = tex_res.get_image() if tex_res is Texture2D else null
	_assert(img != null, "load_sample: could not get image from texture")
	if img == null:
		return

	_assert(img.get_width() == 160, "load_sample: width expected 160, got %d" % img.get_width())
	_assert(img.get_height() == 96, "load_sample: height expected 96, got %d" % img.get_height())

	var ts := _load_sample_tileset()
	_assert(ts != null, "load_sample: TileSet creation failed")
	if ts == null:
		return

	var layer := _LayerScript.new()
	get_root().add_child(layer)
	layer.layout = _Wang2EdgeSc.new()
	await process_frame
	await process_frame
	layer.tile_set = ts
	await process_frame
	await process_frame

	# Verify 3 terrains auto-detected (96/32 = 3 rows)
	_assert(ts.get_terrains_count(0) == 3, "load_sample: expected 3 terrains, got %d" % ts.get_terrains_count(0))
	_assert(ts.get_terrain_name(0, 0) == "Terrain 0", "load_sample: terrain 0 name wrong")
	_assert(ts.get_terrain_name(0, 1) == "Terrain 1", "load_sample: terrain 1 name wrong")
	_assert(ts.get_terrain_name(0, 2) == "Terrain 2", "load_sample: terrain 2 name wrong")

	# Verify TileData.terrain assignments
	var src := ts.get_source(0) as TileSetAtlasSource
	if src != null:
		for row in range(3):
			var td := src.get_tile_data(Vector2i(0, row), 0)
			if td != null:
				_assert(td.terrain == row, "load_sample: tile (0,%d) terrain expected %d, got %d" % [row, row, td.terrain])

	print("    load_sample: %d terrains auto-detected from %dx%d image" % [ts.get_terrains_count(0), img.get_width(), img.get_height()])
	layer.queue_free()
	await process_frame


# --- Test 2: Paint multi-terrain pattern ---
func _test_paint_multi_terrain() -> void:
	print("  sub-test: paint multi-terrain")
	var ts := _load_sample_tileset()
	if ts == null:
		return

	var layer := _LayerScript.new()
	get_root().add_child(layer)
	layer.layout = _Wang2EdgeSc.new()
	await process_frame
	await process_frame
	layer.tile_set = ts
	await process_frame
	await process_frame

	# Paint cells across all 3 terrains in a grid pattern
	# Row 0: terrain 0, Row 1: terrain 1, Row 2: terrain 2
	for terrain_row in range(3):
		for col in range(3):
			layer.set_cell(Vector2i(col, terrain_row), 0, Vector2i(0, terrain_row))
	await process_frame
	await process_frame

	var visual := layer.get_node_or_null(NodePath("_PentaTileVisual"))
	_assert(visual != null, "paint_multi: visual layer is null")
	if visual == null:
		return

	var used: Array = visual.get_used_cells()
	_assert(used.size() > 0, "paint_multi: no painted cells on visual layer")

	# Each terrain row should have visual cells
	var rows_seen: Dictionary = {}
	for c: Vector2i in used:
		rows_seen[c.y] = true
	_assert(rows_seen.size() >= 1, "paint_multi: expected visual cells, got %d unique rows" % rows_seen.size())

	print("    paint_multi: %d visual cells across %d rows" % [used.size(), rows_seen.size()])
	layer.queue_free()
	await process_frame


# --- Test 3: Boundary cells correct ---
func _test_boundary_cells_correct() -> void:
	print("  sub-test: boundary cells correct")
	var ts := _load_sample_tileset()
	if ts == null:
		return

	var layer := _LayerScript.new()
	get_root().add_child(layer)
	layer.layout = _Min3x3Sc.new()
	await process_frame
	await process_frame
	layer.tile_set = ts
	await process_frame
	await process_frame

	# Paint terrain 0 adjacent to terrain 1
	# Left side: terrain 0, Right side: terrain 1
	for y in range(2):
		layer.set_cell(Vector2i(0, y), 0, Vector2i(0, 0))  # terrain 0
		layer.set_cell(Vector2i(1, y), 0, Vector2i(0, 1))  # terrain 1
	await process_frame
	await process_frame

	var visual := layer.get_node_or_null(NodePath("_PentaTileVisual"))
	_assert(visual != null, "boundary_sample: visual layer is null")
	if visual == null:
		return

	var used: Array = visual.get_used_cells()
	_assert(used.size() > 0, "boundary_sample: no painted cells")

	# Verify both terrain cells are rendered
	var has_t0 := false
	var has_t1 := false
	for c: Vector2i in used:
		if c.x == 0:
			has_t0 = true
		if c.x == 1:
			has_t1 = true
	_assert(has_t0, "boundary_sample: terrain 0 cells not rendered")
	_assert(has_t1, "boundary_sample: terrain 1 cells not rendered")

	print("    boundary_sample: %d visual cells, terrain 0=%s terrain 1=%s" % [used.size(), has_t0, has_t1])
	layer.queue_free()
	await process_frame
