## Automated terrain group fallback routing test for PentaTileMapLayer.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/terrain_fallback_test.gd
##
## What it does:
##   - Test 1: terrain_group bound + tile_set == null → fallback to terrain_group.layouts[0].get_fallback_tile_set()
##   - Test 2: terrain_group bound + user tile_set assigned → user tile_set preserved
##   - Test 3: terrain_group null + tile_set null → original v0.2.0 fallback path unchanged
##   - Test 4: Swapping terrain_group produces new fallback tile_set
##   - Test 5: Penta layout within terrain_group triggers synthesis
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript    = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _TerrainGroupSc = preload("res://addons/penta_tile/layouts/penta_tile_terrain_group.gd")
const _Wang2EdgeSc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _DualGrid16Sc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Min3x3Sc       = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")
const _PentaLayoutSc  = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== terrain_fallback_test ===")

	await _test_terrain_group_fallback_tileset()
	await _test_user_tileset_preserved_with_terrain_group()
	await _test_null_terrain_group_fallback_unchanged()
	await _test_swapping_terrain_group_refreshes_fallback()
	await _test_penta_terrain_layout_triggers_synthesis()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# --- Tests ---

func _test_terrain_group_fallback_tileset() -> void:
	"""[Test 1] terrain_group bound + tile_set == null → fallback to first terrain layout."""
	print("\n  --- terrain group fallback tileset ---")

	var layer := _LayerScript.new()
	# Global layout = DualGrid16 (4x4 fallback grid)
	layer.layout = _DualGrid16Sc.new()

	# Create terrain_group with Min3x3 as first terrain (3x3 grid — different from global)
	var group := _TerrainGroupSc.new()
	group.layouts.append(_Min3x3Sc.new())     # terrain 0 — Min3x3 (3x3)
	group.layouts.append(_Wang2EdgeSc.new())   # terrain 1

	# Clear tile_set so auto-fill activates via terrain_group
	layer.tile_set = null
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify tile_set was auto-filled
	_assert("tile_set not null after terrain_group assignment", layer.tile_set != null)
	_assert("_tile_set_is_fallback is true", layer.get("_tile_set_is_fallback") == true)

	# Verify the fallback came from terrain 0's layout (Min3x3, 3x3 grid),
	# NOT from the global layout (DualGrid16, 4x4 grid). This is the key
	# terrain_group fallback routing behavior — when terrain_group is bound,
	# the first terrain's layout provides the fallback TileSet.
	var ts: TileSet = layer.tile_set
	if ts != null:
		_assert("tile_set has source", ts.get_source_count() > 0)
		var src := ts.get_source(0) as TileSetAtlasSource
		if src != null:
			var grid := src.get_atlas_grid_size()
			# Min3x3 has 3x3 grid (9 tiles); DualGrid16 has 4x4 grid (16 tiles).
			# If terrain fallback is working, we get 3x3. If falling through to
			# global layout, we'd get 4x4.
			_assert_eq("fallback grid matches Min3x3 (3x3), not global DualGrid16 (4x4)", grid, Vector2i(3, 3))

	layer.queue_free()


func _test_user_tileset_preserved_with_terrain_group() -> void:
	"""[Test 2] terrain_group bound + user tile_set assigned → user tile_set preserved (PREVIEW-04)."""
	print("\n  --- user tileset preserved with terrain group ---")

	var user_ts := TileSet.new()
	user_ts.tile_size = Vector2i(32, 32)

	var layer := _LayerScript.new()
	layer.layout = _Wang2EdgeSc.new()
	layer.tile_set = user_ts  # User assigns their own TileSet BEFORE terrain_group

	var group := _TerrainGroupSc.new()
	group.layouts.append(_DualGrid16Sc.new())
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	_assert_eq("user tile_set preserved after terrain_group assignment", layer.tile_set, user_ts)
	_assert("_tile_set_is_fallback is false", layer.get("_tile_set_is_fallback") == false)

	# Also verify: null tile_set → terrain_group fallback, then user assigns → preserved
	var layer2 := _LayerScript.new()
	layer2.layout = _Wang2EdgeSc.new()
	layer2.tile_set = null  # no user tile_set
	layer2.terrain_group = group.duplicate()
	get_root().add_child(layer2)
	await process_frame
	await process_frame

	_assert("layer2 got auto-filled fallback", layer2.tile_set != null)
	_assert("layer2 _tile_set_is_fallback is true", layer2.get("_tile_set_is_fallback") == true)

	# Now assign user tile_set — should override fallback
	layer2.tile_set = user_ts
	await process_frame
	await process_frame

	_assert_eq("layer2 user tile_set overrides fallback", layer2.tile_set, user_ts)
	_assert("layer2 _tile_set_is_fallback is false after user assign", layer2.get("_tile_set_is_fallback") == false)

	layer.queue_free()
	layer2.queue_free()


func _test_null_terrain_group_fallback_unchanged() -> void:
	"""[Test 3] terrain_group null + tile_set null → original v0.2.0 fallback path unchanged."""
	print("\n  --- null terrain group fallback unchanged ---")

	var layer := _LayerScript.new()
	layer.layout = _DualGrid16Sc.new()
	# No terrain_group set (null by default)
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify tile_set auto-filled from layout.get_fallback_tile_set() (v0.2.0 behavior)
	_assert("tile_set not null (v0.2.0 fallback)", layer.tile_set != null)
	_assert("_tile_set_is_fallback is true", layer.get("_tile_set_is_fallback") == true)

	var ts: TileSet = layer.tile_set
	if ts != null:
		var src := ts.get_source(0) as TileSetAtlasSource
		if src != null:
			_assert_eq("v0.2.0 fallback grid is 4x4 (DualGrid16)", src.get_atlas_grid_size(), Vector2i(4, 4))

	layer.queue_free()


func _test_swapping_terrain_group_refreshes_fallback() -> void:
	"""[Test 4] Swapping terrain_group (reassignment) produces new fallback tile_set."""
	print("\n  --- swapping terrain group refreshes fallback ---")

	var layer := _LayerScript.new()
	layer.layout = _Wang2EdgeSc.new()

	# First terrain_group: terrain 0 = Min3x3 (3x3 fallback grid)
	var group1 := _TerrainGroupSc.new()
	group1.layouts.append(_Min3x3Sc.new())
	group1.layouts.append(_Wang2EdgeSc.new())

	layer.tile_set = null
	layer.terrain_group = group1
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var first_fallback := layer.tile_set
	_assert("first fallback exists (Min3x3 3x3)", first_fallback != null)
	if first_fallback != null:
		var src := first_fallback.get_source(0) as TileSetAtlasSource
		if src != null:
			_assert_eq("first fallback grid is 3x3 (Min3x3)", src.get_atlas_grid_size(), Vector2i(3, 3))

	# Swap to a different terrain_group: terrain 0 = DualGrid16 (4x4 fallback grid)
	var group2 := _TerrainGroupSc.new()
	group2.layouts.append(_DualGrid16Sc.new())  # different layout in terrain 0
	group2.layouts.append(_Wang2EdgeSc.new())

	# Must manually set _tile_set_is_fallback back to true since we're swapping groups
	# while the current tile_set is an auto-filled fallback
	layer.set("_tile_set_is_fallback", true)
	layer.terrain_group = group2
	await process_frame
	await process_frame

	var second_fallback := layer.tile_set
	_assert("second fallback exists (DualGrid16 4x4)", second_fallback != null)
	if second_fallback != null:
		var src := second_fallback.get_source(0) as TileSetAtlasSource
		if src != null:
			_assert_eq("second fallback grid is 4x4 (DualGrid16)", src.get_atlas_grid_size(), Vector2i(4, 4))

	# Fallbacks should have different grid sizes
	var grids_differ := false
	if first_fallback != null and second_fallback != null:
		var src1 := first_fallback.get_source(0) as TileSetAtlasSource
		var src2 := second_fallback.get_source(0) as TileSetAtlasSource
		if src1 != null and src2 != null:
			grids_differ = src1.get_atlas_grid_size() != src2.get_atlas_grid_size()
	_assert("fallback tile_set changed after group swap (grids differ)", grids_differ)

	layer.queue_free()


func _test_penta_terrain_layout_triggers_synthesis() -> void:
	"""[Test 5] Penta layout within terrain_group triggers per-terrain synthesis."""
	print("\n  --- penta terrain layout triggers synthesis ---")

	var layer := _LayerScript.new()
	# Use a non-Penta global layout so synthesis isn't triggered globally
	layer.layout = _Wang2EdgeSc.new()

	# Create terrain_group with Penta layout in terrain 0
	var group := _TerrainGroupSc.new()
	var penta := _PentaLayoutSc.new()
	penta.set("axis", 0)       # HORIZONTAL
	penta.set("tile_count", 4) # FOUR mode — needs synthesis
	group.layouts.append(penta)
	group.layouts.append(_Wang2EdgeSc.new())

	# Provide a source TileSet so Penta synthesis has a source atlas to read from
	var source_ts := TileSet.new()
	source_ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)
	# Create FOUR tiles in horizontal strip for FOUR-mode Penta synthesis
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	src.texture = ImageTexture.create_from_image(img)
	for x in range(4):
		src.create_tile(Vector2i(x, 0))
	source_ts.add_source(src, 0)

	layer.tile_set = source_ts
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame
	await process_frame  # Extra frame for deferred synthesis

	# The synthesized TileSet should exist after synthesis is triggered
	var synth = layer.get("_synthesized_tile_set")
	_assert("synthesized tile_set exists after Penta terrain layout is bound", synth != null)
	if synth != null:
		_assert("synthesized TileSet has source", synth.get_source_count() > 0)
		# build_tile_set_from_synthesis always adds source at index 0 with
		# Texture2D and TileSetAtlasSource
		var synth_src := synth.get_source(0) as TileSetAtlasSource
		_assert("synthesized atlas source is valid", synth_src != null)

	layer.queue_free()


# --- Assertions ---

func _assert(label: String, condition: bool) -> void:
	if not condition:
		_failures.append(label)
		printerr("  FAIL: " + label)
	else:
		print("  PASS: " + label)


func _assert_eq(label: String, actual, expected) -> void:
	if actual != expected:
		_failures.append(label + " (expected " + str(expected) + " got " + str(actual) + ")")
		printerr("  FAIL: " + label + " (expected " + str(expected) + " got " + str(actual) + ")")
	else:
		print("  PASS: " + label)
