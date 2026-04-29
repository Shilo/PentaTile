## AUTO_STRIP axis-symmetry regression test.
##
## User report: paint two clusters with different source atlas_coords (e.g.
## atlas (0,0) and atlas (3,0)). Switch the Penta layout's tile_count between
## AUTO and AUTO_STRIP, and axis between HORIZONTAL and VERTICAL.
##
## Observation:
##   HORIZONTAL AUTO         — both clusters render
##   HORIZONTAL AUTO_STRIP   — both clusters render
##   VERTICAL   AUTO         — both clusters render
##   VERTICAL   AUTO_STRIP   — atlas (3,0) cluster DOESN'T render
##
## Question: AUTO_STRIP is supposed to detect tile_count per strip (just like
## AUTO but per strip). Why does the VERTICAL combination fail?
##
## This test reproduces the user's setup, runs all four (axis × {AUTO,
## AUTO_STRIP}) combinations, and asserts every painted display cell ends up
## with a registered atlas coord in the synthesized atlas. If a cell dispatches
## to a coord NOT registered, that's the bug.
##
## Run headless:
##   Godot --headless --path . --script tests/auto_strip_axis_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")

# Match the user's painted state from the demo .tscn (decoded):
#   atlas (0,0) cluster: (5,5), (6,5), (6,4)
#   atlas (3,0) cluster: (8,6), (8,5), (8,4), (9,4), (9,3)
const _CLUSTER_A := [Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 4)]
const _CLUSTER_B := [Vector2i(8, 6), Vector2i(8, 5), Vector2i(8, 4), Vector2i(9, 4), Vector2i(9, 3)]

# Penta tile_count enum values.
const _AUTO       := 0
const _AUTO_STRIP := -1

var _failures: Array = []


func _initialize() -> void:
	print("=== auto_strip_axis_test ===")
	# 4 combinations: (axis, tile_count)
	var combos := [
		[0, _AUTO,       "HORIZONTAL AUTO"],
		[0, _AUTO_STRIP, "HORIZONTAL AUTO_STRIP"],
		[1, _AUTO,       "VERTICAL   AUTO"],
		[1, _AUTO_STRIP, "VERTICAL   AUTO_STRIP"],
	]
	for c: Array in combos:
		await _test_combo(c[0], c[1], c[2])

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _test_combo(axis_value: int, tile_count_value: int, label: String) -> void:
	print("\n--- " + label + " ---")
	# Build layer with bundled FIVE-mode horizontal greybox as source (5×1 atlas).
	var penta := _PentaScript.new()
	penta.set("axis", axis_value)
	penta.set("tile_count", tile_count_value)
	var layer = _LayerScript.new()
	layer.layout = penta
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint cluster A with atlas (0, 0).
	for c: Vector2i in _CLUSTER_A:
		layer.set_cell(c, 0, Vector2i(0, 0))
	# Paint cluster B with atlas (3, 0).
	for c: Vector2i in _CLUSTER_B:
		layer.set_cell(c, 0, Vector2i(3, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null")
		layer.queue_free()
		return

	# Effective tile_set the visual layer renders from.
	var eff_ts: TileSet = layer.get("_synthesized_tile_set") if layer.get("_synthesized_tile_set") != null else layer.tile_set
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource if eff_ts != null and eff_ts.get_source_count() > 0 else null
	if eff_src == null:
		_record(label, "no atlas source 0 in effective tile_set")
		layer.queue_free()
		return

	var visual_cells: Array = primary.get_used_cells()
	print("  visual cells painted: %d, synth atlas grid: %s" % [visual_cells.size(), eff_src.get_atlas_grid_size()])

	# Per-cluster cell counting: a display cell "belongs" to cluster X if any of
	# its TL/TR/BL/BR neighbors is a logic cell painted with cluster X's atlas.
	var cluster_a_cells := 0
	var cluster_b_cells := 0
	var unrenderable_count := 0
	var first_unrenderable: Variant = null

	for cell: Vector2i in visual_cells:
		var atlas_coord: Vector2i = primary.get_cell_atlas_coords(cell)
		# Verify the dispatched coord exists in the effective atlas.
		if not eff_src.has_tile(atlas_coord):
			unrenderable_count += 1
			if first_unrenderable == null:
				first_unrenderable = "cell %s atlas %s" % [cell, atlas_coord]

		# Classify by neighbor source-atlas coord.
		var neighbors := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
		for offset: Vector2i in neighbors:
			var nb: Vector2i = cell + offset
			if layer.get_cell_source_id(nb) != -1:
				var nb_ac: Vector2i = layer.get_cell_atlas_coords(nb)
				if nb_ac == Vector2i(0, 0):
					cluster_a_cells += 1
					break
				elif nb_ac == Vector2i(3, 0):
					cluster_b_cells += 1
					break

	print("  cluster A (atlas 0,0) display cells: %d" % cluster_a_cells)
	print("  cluster B (atlas 3,0) display cells: %d" % cluster_b_cells)
	print("  unrenderable (atlas not in synth) cells: %d" % unrenderable_count)
	if first_unrenderable != null:
		print("    first unrenderable: " + str(first_unrenderable))

	if cluster_a_cells == 0:
		_record(label, "cluster A produced 0 display cells (paint dispatch broken)")
	if cluster_b_cells == 0:
		_record(label, "cluster B produced 0 display cells (paint dispatch broken)")
	if unrenderable_count > 0:
		_record(label, "%d display cells dispatched to atlas coords NOT in the synthesized atlas (will render empty)" % unrenderable_count)

	layer.queue_free()


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL: " + msg)
