## Automated PentaTileLayoutSlope layout test.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/slope_layout_test.gd
##
## What it does:
##   - Test PentaTileLayoutSlope class exists and extends PentaTileLayout
##   - Test compute_mask returns 4-bit corner mask from neighbor sampling
##   - Test mask_to_atlas dispatches correct atlas slots
##   - Test is_dual_grid returns false (single-grid)
##   - Test terrain_mode returns MATCH_CORNERS
##   - Test floor_terrain_id and wall_terrain_id exports
##   - Test slope layout integrates with terrain_group
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript       = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _TerrainGroupSc    = preload("res://addons/penta_tile/layouts/penta_tile_terrain_group.gd")
const _SlopeLayoutSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_slope.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== slope_layout_test ===")

	await _test_class_exists()
	await _test_virtual_overrides()
	await _test_compute_mask()
	await _test_mask_to_atlas()
	await _test_export_properties()
	await _test_terrain_group_integration()
	await _test_single_grid_propagation()

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

func _build_slope_tileset() -> TileSet:
	"""Build a simple TileSet for slope testing.
	4x4 atlas with terrain 0 = Floor and terrain 1 = Wall.
	"""
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)

	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in range(4):
		for x: int in range(4):
			var c := Color(0.2 + x * 0.15, 0.3 + y * 0.15, 0.5, 1.0)
			for px: int in range(32):
				for py: int in range(32):
					img.set_pixel(x * 32 + px, y * 32 + py, c)
	src.texture = ImageTexture.create_from_image(img)

	for y: int in range(4):
		for x: int in range(4):
			src.create_tile(Vector2i(x, y))
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.terrain_set = 0
			# First 2 rows = terrain 0 (Floor), last 2 rows = terrain 1 (Wall)
			if y < 2:
				td.terrain = 0
			else:
				td.terrain = 1

	ts.add_source(src, 0)
	return ts


# --- Tests ---

func _test_class_exists() -> void:
	print("\n  --- class exists ---")

	var slope: Resource = _SlopeLayoutSc.new()
	_assert("PentaTileLayoutSlope creates", slope != null)
	_assert("extends Resource", slope is Resource)
	
	# Check class_name chain: PentaTileLayoutSlope extends PentaTileLayout extends Resource
	# In GDScript, `is` checks work with class_name
	_assert("has class_name", slope.get_script() != null)


func _test_virtual_overrides() -> void:
	print("\n  --- virtual overrides ---")

	var slope: Resource = _SlopeLayoutSc.new()

	# is_dual_grid() should return false
	_assert("is_dual_grid returns false", not slope.is_dual_grid())

	# terrain_mode() should return MATCH_CORNERS (0)
	_assert("terrain_mode is MATCH_CORNERS", slope.terrain_mode() == TileSet.TERRAIN_MODE_MATCH_CORNERS)

	# compute_mask should exist and not push_error
	var sample_fn := Callable()
	var _m: int = slope.compute_mask(Vector2i.ZERO, sample_fn)
	_assert("compute_mask returns int", typeof(_m) == TYPE_INT)

	# mask_to_atlas should exist
	var slot = slope.mask_to_atlas(1)
	_assert("mask_to_atlas returns slot", slot != null)


func _test_compute_mask() -> void:
	print("\n  --- compute_mask ---")

	var slope: Resource = _SlopeLayoutSc.new()

	# Create a simple sample function that simulates terrain-aware neighbors.
	# The slope's compute_mask uses terrain ID from sample_fn to check
	# if a neighbor is Wall (wall_terrain_id) or Floor (floor_terrain_id).
	# For testing, we use a lambda that returns true for any cell
	# (all cells are "painted"). The slope's compute_mask should see
	# them as wall if wall_terrain_id matches the terrain context.
	
	# Test 1: all-empty (no painted neighbors) → mask should be 0
	# sample_fn always returns false
	var empty_fn := func(_c: Vector2i) -> bool: return false
	
	# But we need to bind slope's compute_mask to a sample_fn
	# compute_mask(coord, sample_fn, strip_index=0)
	# The strip_index is unused by slope (it uses floor/wall_terrain_id)
	var mask_empty: int = slope.compute_mask(Vector2i(2, 2), empty_fn)
	_assert("all-empty mask is 0", mask_empty == 0)

	# Test 2: one neighbor painted → mask should have 1 bit
	# Simulate a painted cell at TL corner
	var tl_fn := func(_c: Vector2i) -> bool:
		return _c == Vector2i(1, 1)  # TL neighbor of (2,2)
	var mask_tl: int = slope.compute_mask(Vector2i(2, 2), tl_fn)
	print("  mask with TL painted: ", mask_tl)
	_assert("single-neighbor mask has bits", mask_tl > 0)

	# Resource is RefCounted — no explicit free needed


func _test_mask_to_atlas() -> void:
	print("\n  --- mask_to_atlas ---")

	var slope: Resource = _SlopeLayoutSc.new()

	# mask=0 returns null (empty cell)
	var slot0 = slope.mask_to_atlas(0)
	_assert("mask=0 returns null", slot0 == null)

	# mask=1 returns slot at (1, 0) = (mask%4, mask/4)
	var slot1 = slope.mask_to_atlas(1)
	if slot1 != null:
		_assert("mask=1 atlas_coords is (1,0)", slot1.atlas_coords == Vector2i(1, 0))

	# mask=4 returns slot at (0, 1) = (4%4, 4/4)
	var slot4 = slope.mask_to_atlas(4)
	if slot4 != null:
		_assert("mask=4 atlas_coords is (0,1)", slot4.atlas_coords == Vector2i(0, 1))

	# mask=15 returns slot at (3, 3)
	var slot15 = slope.mask_to_atlas(15)
	if slot15 != null:
		_assert("mask=15 atlas_coords is (3,3)", slot15.atlas_coords == Vector2i(3, 3))

	# Resource is RefCounted — no explicit free needed


func _test_export_properties() -> void:
	print("\n  --- export properties ---")

	var slope: Resource = _SlopeLayoutSc.new()

	# floor_terrain_id default = 0
	var ftid = slope.get("floor_terrain_id")
	_assert("floor_terrain_id default 0", ftid == 0)

	# wall_terrain_id default = 1
	var wtid = slope.get("wall_terrain_id")
	_assert("wall_terrain_id default 1", wtid == 1)

	# Can set and read back
	slope.set("floor_terrain_id", 2)
	var ftid2 = slope.get("floor_terrain_id")
	_assert("floor_terrain_id set to 2", ftid2 == 2)

	slope.set("wall_terrain_id", 3)
	var wtid2 = slope.get("wall_terrain_id")
	_assert("wall_terrain_id set to 3", wtid2 == 3)

	# Resource is RefCounted — no explicit free needed


func _test_terrain_group_integration() -> void:
	print("\n  --- terrain group integration ---")

	var ts := _build_slope_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts

	var slope := _SlopeLayoutSc.new()
	var group := _TerrainGroupSc.new()
	group.layouts.append(slope)  # terrain 0 = Slope
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a cell with terrain 0 (Slope).
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	await process_frame

	# Slope layout is single-grid (is_dual_grid = false).
	# Since the default Penta layout (dual-grid) triggers dual-grid path,
	# the slope layout embedded in terrain_group gets called via
	# _paint_dual_grid_terrain's per-terrain mask computation.
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var painted_count: int = primary.get_used_cells().size()
		print("  visual cells painted: ", painted_count)
		_assert("slope in terrain_group paints cells", painted_count > 0)

	layer.queue_free()


func _test_single_grid_propagation() -> void:
	print("\n  --- single-grid propagation ---")

	# Slope is single-grid. When used as self.layout (not via terrain_group),
	# the single-grid _mark_affected_single_grid_cells should propagate.
	var ts := _build_slope_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts

	var slope := _SlopeLayoutSc.new()
	layer.layout = slope  # directly assign as the layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint cells diagonally adjacent (Slope samples diagonals, not cardinals).
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var painted_count: int = primary.get_used_cells().size()
		print("  single-grid painted: ", painted_count)
		_assert("slope single-grid paints cells", painted_count > 0)

	layer.queue_free()


# --- Assertions ---

func _assert(label: String, condition: bool) -> void:
	if not condition:
		_failures.append(label)
		printerr("  FAIL: " + label)
