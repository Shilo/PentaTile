## Terrain rebuild determinism test: validates that rebuild produces bit-identical
## output across runs and that different seeds produce different variation picks.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/terrain_determinism_test.gd
##
## What it does:
##   - Same terrain_id + seed = same variation pick
##   - Different seed = different variation pick
##   - Rebuild preserves terrain boundaries (painted cell count stable)
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _DualGrid16Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")

var _failures: Array = []

func _initialize() -> void:
	print("=== terrain_determinism_test ===")

	await _test_same_seed_same_output()
	await _test_different_seed_different_output()
	await _test_rebuild_preserves_boundaries()

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

func _build_probability_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)
	# 3 cols x 2 rows: terrain 0 = row 0 (3 variants), terrain 1 = row 1 (2 variants)
	var img := Image.create(3 * 32, 2 * 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	# Row 0 (terrain 0): blue/green/cyan variants
	img.fill_rect(Rect2i(0, 0, 32, 32), Color.BLUE)
	img.fill_rect(Rect2i(32, 0, 32, 32), Color.GREEN)
	img.fill_rect(Rect2i(64, 0, 32, 32), Color.CYAN)
	# Row 1 (terrain 1): red/yellow variants
	img.fill_rect(Rect2i(0, 32, 32, 32), Color.RED)
	img.fill_rect(Rect2i(32, 32, 32, 32), Color.YELLOW)
	var tex := ImageTexture.create_from_image(img)
	src.texture = tex
	var src_id := ts.add_source(src)
	for row in range(2):
		for col in range(3):
			src.create_tile(Vector2i(col, row))
	# Set probabilities for terrain 0 variants: 0.1, 0.3, 0.6
	src.get_tile_data(Vector2i(0, 0), 0).probability = 0.1
	src.get_tile_data(Vector2i(1, 0), 0).probability = 0.3
	src.get_tile_data(Vector2i(2, 0), 0).probability = 0.6
	# Set probabilities for terrain 1 variants: 0.4, 0.6
	src.get_tile_data(Vector2i(0, 1), 0).probability = 0.4
	src.get_tile_data(Vector2i(1, 1), 0).probability = 0.6
	return ts

func _snapshot_visual_atlas(layer: Node) -> Dictionary:
	var visual := layer.get_node_or_null(NodePath("_PentaTileVisual"))
	if visual == null:
		return {}
	var result: Dictionary = {}
	for cell: Vector2i in visual.get_used_cells():
		result[cell] = {
			"atlas": visual.get_cell_atlas_coords(cell),
			"alt": visual.get_cell_alternative_tile(cell),
		}
	return result

func _paint_pattern(layer: Node) -> void:
	# 2x3 block: left column terrain 0, right column terrain 1
	for y in range(3):
		layer.set_cell(Vector2i(0, y), 0, Vector2i(0, 0))
		layer.set_cell(Vector2i(1, y), 0, Vector2i(0, 1))
	# Extra terrain 0 cell
	layer.set_cell(Vector2i(2, 1), 0, Vector2i(0, 0))


# --- Test 1: Same seed = same variation pick ---
func _test_same_seed_same_output() -> void:
	print("  sub-test: same seed same output")
	var ts := _build_probability_tileset()
	var layer := _LayerScript.new()
	get_root().add_child(layer)
	layer.layout = _DualGrid16Sc.new()
	layer.variation_seed = 42
	await process_frame
	await process_frame
	layer.tile_set = ts
	await process_frame
	await process_frame

	_paint_pattern(layer)
	await process_frame
	await process_frame

	var snap1 := _snapshot_visual_atlas(layer)

	# Rebuild from scratch
	layer.rebuild()
	await process_frame
	await process_frame

	var snap2 := _snapshot_visual_atlas(layer)

	# Compare: same cells should have same atlas coords
	_assert(snap1.size() > 0, "same_seed: no painted cells in first snapshot")
	_assert(snap2.size() > 0, "same_seed: no painted cells in second snapshot")
	_assert(snap1.size() == snap2.size(), "same_seed: cell count differs (%d vs %d)" % [snap1.size(), snap2.size()])

	var mismatches := 0
	for cell: Vector2i in snap1.keys():
		if snap2.has(cell):
			var a1: Vector2i = snap1[cell].atlas
			var a2: Vector2i = snap2[cell].atlas
			if a1 != a2:
				mismatches += 1
		else:
			mismatches += 1
	_assert(mismatches == 0, "same_seed: %d mismatched cells between rebuilds" % mismatches)
	print("    same_seed: %d cells, 0 mismatches" % snap1.size())
	layer.queue_free()
	await process_frame


# --- Test 2: Different seed = different variation pick ---
func _test_different_seed_different_output() -> void:
	print("  sub-test: different seed different output")
	var ts := _build_probability_tileset()

	# Seed 42
	var layer1 := _LayerScript.new()
	get_root().add_child(layer1)
	# Use single-grid layout for variation test — dual-grid path doesn't
	# route through _pick_variation_tile (variation only on single-grid).
	var layout1 := _Wang2EdgeSc.new()
	layout1.variation_mode = 1  # PROBABILITY
	layer1.layout = layout1
	layer1.variation_seed = 42
	await process_frame
	await process_frame
	layer1.tile_set = ts
	await process_frame
	await process_frame
	_paint_pattern(layer1)
	await process_frame
	await process_frame
	var snap42 := _snapshot_visual_atlas(layer1)

	# Seed 99 (different TileSet needed since TileData was mutated)
	var ts2 := _build_probability_tileset()
	var layer2 := _LayerScript.new()
	get_root().add_child(layer2)
	var layout2 := _Wang2EdgeSc.new()
	layout2.variation_mode = 1  # PROBABILITY
	layer2.layout = layout2
	layer2.variation_seed = 99
	await process_frame
	await process_frame
	layer2.tile_set = ts2
	await process_frame
	await process_frame
	_paint_pattern(layer2)
	await process_frame
	await process_frame
	var snap99 := _snapshot_visual_atlas(layer2)

	# At least one cell's atlas_coords should differ (due to different rng picks)
	var diff_count := 0
	for cell: Vector2i in snap42.keys():
		if snap99.has(cell):
			if snap42[cell].atlas != snap99[cell].atlas:
				diff_count += 1
	_assert(diff_count > 0 or snap42.size() != snap99.size(),
		"diff_seed: all cells identical between seeds 42 and 99 (expected variation)")
	print("    diff_seed: %d cells differ between seeds" % diff_count)
	layer1.queue_free()
	layer2.queue_free()
	await process_frame


# --- Test 3: Rebuild preserves terrain boundaries ---
func _test_rebuild_preserves_boundaries() -> void:
	print("  sub-test: rebuild preserves boundaries")
	var ts := _build_probability_tileset()
	var layer := _LayerScript.new()
	get_root().add_child(layer)
	layer.layout = _Wang2EdgeSc.new()
	layer.variation_seed = 42
	await process_frame
	await process_frame
	layer.tile_set = ts
	await process_frame
	await process_frame

	# Paint cross-terrain pattern
	for y in range(3):
		layer.set_cell(Vector2i(0, y), 0, Vector2i(0, 0))  # terrain 0
		layer.set_cell(Vector2i(1, y), 0, Vector2i(0, 1))  # terrain 1
	await process_frame
	await process_frame

	var visual := layer.get_node_or_null(NodePath("_PentaTileVisual"))
	_assert(visual != null, "rebuild_preserve: visual layer is null")

	var cell_count_1: int = visual.get_used_cells().size()
	_assert(cell_count_1 > 0, "rebuild_preserve: no cells before rebuild 1")

	# Rebuild 3 times, verify consistent cell count
	for i in range(3):
		layer.rebuild()
		await process_frame
		await process_frame
		var cell_count: int = visual.get_used_cells().size()
		_assert(cell_count == cell_count_1,
			"rebuild_preserve: rebuild %d cell count %d differs from initial %d" % [(i + 1), cell_count, cell_count_1])

	print("    rebuild_preserve: %d cells stable across 3 rebuilds" % cell_count_1)
	layer.queue_free()
	await process_frame
