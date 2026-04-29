## Phase 3 D-87: 8-Moore propagation regression test.
##
## Verifies that painting a cell triggers a re-render of all 8 Moore
## neighbors (cardinals + diagonals). Catches regression of the legacy
## 4-cardinal-only behavior in _mark_affected_single_grid_cells, which
## would silently break 47-blob layouts (Phase 3) by leaving diagonal
## cells with stale masks.
##
## Strategy: paint cell (1,1) FIRST while no neighbors exist (mask = 0).
## Then paint diagonal neighbor (0,0). Under correct 8-Moore propagation,
## (1,1) is in the affected set when (0,0) changes, so it re-renders
## with its new mask (NW corner now set). Under broken 4-cardinal-only
## propagation, (1,1) is NOT in the affected set, so its atlas coord
## stays at the mask=0 dispatch.
##
## Probe layout: Wang2Corner — single-grid, samples diagonal neighbors
## (NE/SE/SW/NW). When (1,1) sees its NW (-1,-1)→(0,0) painted, its
## mask flips from 0 → 8, and Wang2Corner.mask_to_atlas dispatches
## mask 8 to atlas Vector2i(8 % 4, 8 / 4) = Vector2i(0, 2) — distinct
## from mask=0's Vector2i(0, 0). Atlas coord change is the regression
## signal.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd
extends SceneTree

const _LayerScript   = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Wang2CornerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== single_grid_8_moore_propagation_test ===")

	var layer = _LayerScript.new()
	var layout = _Wang2CornerSc.new()
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Wang2Corner samples diagonals (NE/SE/SW/NW) — perfect probe for 8-Moore
	# propagation. Paint cell (1,1) FIRST: mask=0 (no painted diagonals yet).
	# mask=0 dispatches to atlas (0, 0) per Wang2Corner.mask_to_atlas.
	layer.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	# Use property-access pattern that all other tests use; INTERNAL_MODE_FRONT
	# children aren't reachable via get_node, but the script-local `_primary_layer`
	# variable is exposed via Object.get(NAME).
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary == null:
		_failures.append("_primary_layer is null after initial paint")
		_finish(layer)
		return

	var initial_atlas: Vector2i = primary.get_cell_atlas_coords(Vector2i(1, 1))
	print("  initial atlas at (1,1) (mask=0): %s" % initial_atlas)
	if initial_atlas == Vector2i(-1, -1):
		_failures.append("cell (1,1) did not paint at all — initial render broken")

	# Paint diagonal neighbor (0,0). Under 4-cardinal propagation,
	# (1,1) is NOT in the affected set when (0,0) changes — it
	# keeps its stale mask=0 atlas coord (0, 0). Under 8-Moore propagation,
	# (1,1) re-renders with NW set (mask=8 in Wang2Corner ordering),
	# dispatching to atlas (0, 2).
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var post_atlas: Vector2i = primary.get_cell_atlas_coords(Vector2i(1, 1))
	print("  post  atlas at (1,1) (mask=8 expected): %s" % post_atlas)
	if post_atlas == initial_atlas:
		_failures.append(
			"cell (1,1) did NOT re-render after diagonal neighbor (0,0) was painted — 8-Moore propagation broken (D-87). initial=%s post=%s" %
			[initial_atlas, post_atlas])

	# Bonus assertion: the post-paint atlas should be the mask=8 dispatch.
	# (0, 2) per Wang2Corner.mask_to_atlas (mask % 4, mask / 4 with mask=8).
	var expected_post: Vector2i = Vector2i(0, 2)
	if _failures.is_empty() and post_atlas != expected_post:
		_failures.append(
			"cell (1,1) re-rendered but to wrong atlas after diagonal paint — expected %s (mask=8), got %s" %
			[expected_post, post_atlas])

	_finish(layer)


func _finish(layer: Node) -> void:
	layer.queue_free()
	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f: String in _failures:
			printerr("  - " + f)
		quit(1)
