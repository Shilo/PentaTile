## Phase 2 Wave 7 determinism test — run headlessly:
##   Godot_v4.6.2-stable_win64.exe --headless --path . --script addons/penta_tile/tests/determinism_test.gd
##
## Tests:
##   Sub-test (a) — transform_vertex worked example (Gate 2, all 8 flag combos)
##   Sub-test (b) — clip_polygon_to_subrect hash determinism (10 invocations)
##   Main test    — rebuild loop × 10 runs; assert all hashes identical AND match BASELINE_HASH
##   Sub-test (c) — VERTICAL-axis structural coverage (WR-07 regression net)
##
## PENTA-SYNTH-06 invariant: cache-invalidation via rebuild() between runs.
## (The demo scene's PentaTileMapLayer.rebuild() call re-runs synthesis from scratch.)
extends SceneTree

# Preload all required scripts explicitly so symbols are available in --script mode.
const _SynthesisScript = preload("res://addons/penta_tile/penta_tile_synthesis.gd")
const _SlotScript = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayoutScript = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")

# FOUR-mode baseline. Re-captured 2026-04-28 after _sync_visual_layers gained
# the null-layout fallback branch and started calling _apply_logic_layer_opacity
# from inside the layout-active path. Paint dispatch + slot art are unchanged —
# the shift is in tile_map_data binary serialization order, not cell content.
# Determinism property holds (11 reruns identical at the new hash).
#
# Prior values:
#   2986698704 — Wave 6 baseline through commit 7de100b (faded-silhouette slot 0).
#   3429057564 — null-layout fallback in _sync_visual_layers.
#   4075543519 — bundled FIVE-mode greybox slot 0 = BL-quadrant only.
#   480538583  — removed slot outlines from bundled greyboxes.
#   4100093049 — PentaTileMapLayer.layout default = fresh PentaTileLayoutPenta.
#   1693834751 — FIVE-mode greybox slot 0 BL fill corrected to exact 16×16.
#   2561003017 — current: determinism test refactored to be self-contained
#                (builds its own layer + bundled FOUR greybox source instead
#                of loading the demo .tscn). Decouples determinism check
#                from the demo scene's editable state — user can freely
#                paint / delete nodes in the demo without breaking this
#                test. Hash reflects the new fixed test pattern, not the
#                demo's tile_map_data.
const BASELINE_HASH := 2561003017

# Expected painted cell count for the demo scene's PentaTileMapLayer. Used by both
# the main HORIZONTAL test and sub-test (c) VERTICAL coverage. If WR-07 regresses
# (`_make_slot` returning out-of-grid coords for VERTICAL), painted cells drop and
# this count fails — the regression net the bare hash misses.
const BASELINE_CELLS := 46

# WR-07 regression net path — the alt layout used by sub-test (c). The .tres mirrors
# penta_layout_four_horizontal.tres with axis = 1 (VERTICAL).
const VERTICAL_LAYOUT_PATH := "res://addons/penta_tile/demo/penta_layout_four_vertical.tres"

func _initialize() -> void:
	# -----------------------------------------------------------------------
	# Sub-test (a) — transform_vertex worked example (Gate 2 table, all 8 combos)
	# -----------------------------------------------------------------------
	_subtest_transform_vertex_worked_example()

	# -----------------------------------------------------------------------
	# Sub-test (b) — clip_polygon_to_subrect determinism (10 invocations)
	# -----------------------------------------------------------------------
	_subtest_clip_polygon_determinism()

	# -----------------------------------------------------------------------
	# Main test — 10-run rebuild loop against demo scene (FOUR horizontal layout)
	# -----------------------------------------------------------------------
	await _run_main_rebuild_test()

	# -----------------------------------------------------------------------
	# Sub-test (c) — VERTICAL-axis structural coverage (WR-07 regression net)
	# -----------------------------------------------------------------------
	# Post-WR-07, `mask_to_atlas` is axis-independent — the synthesized strip is always
	# horizontal regardless of `axis`, so HORIZONTAL and VERTICAL produce identical
	# tile_map_data hashes. The bare hash therefore can't distinguish a working VERTICAL
	# from a broken one. The structural check here verifies (1) the painted cell count
	# matches the HORIZONTAL baseline, and (2) every painted cell's atlas coord exists
	# in the synthesized atlas (Godot would otherwise silently render empty / strip the
	# cell — the original WR-07 failure mode).
	await _subtest_vertical_axis_structural_coverage()

	quit(0)


func _subtest_transform_vertex_worked_example() -> void:
	# Asserts PentaTileSynthesis.transform_vertex(v, flags) matches the
	# worked-example table from 02-02-PLAN.md Gate 2 for all 8 flag combinations.
	var v := Vector2(0.25, 0.75)
	var FLIP_H := TileSetAtlasSource.TRANSFORM_FLIP_H        # 4096
	var FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V        # 8192
	var TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE  # 16384

	# Expected outputs from 02-02-PLAN.md Gate 2 table:
	var cases := [
		{ "label": "identity",                      "flags": 0,                           "out": Vector2( 0.25,  0.75) },
		{ "label": "FLIP_H",                         "flags": FLIP_H,                      "out": Vector2(-0.25,  0.75) },
		{ "label": "FLIP_V",                         "flags": FLIP_V,                      "out": Vector2( 0.25, -0.75) },
		{ "label": "FLIP_H + FLIP_V",                "flags": FLIP_H | FLIP_V,             "out": Vector2(-0.25, -0.75) },
		{ "label": "TRANSPOSE",                      "flags": TRANSPOSE,                   "out": Vector2( 0.75,  0.25) },
		{ "label": "TRANSPOSE + FLIP_H",             "flags": TRANSPOSE | FLIP_H,          "out": Vector2(-0.75,  0.25) },
		{ "label": "TRANSPOSE + FLIP_V",             "flags": TRANSPOSE | FLIP_V,          "out": Vector2( 0.75, -0.25) },
		{ "label": "TRANSPOSE + FLIP_H + FLIP_V",    "flags": TRANSPOSE | FLIP_H | FLIP_V, "out": Vector2(-0.75, -0.25) },
	]

	var all_pass := true
	for case in cases:
		var actual: Vector2 = _SynthesisScript.transform_vertex(v, case.flags)
		var pass_flag := actual.is_equal_approx(case.out)
		if not pass_flag:
			printerr("FAIL sub-test (a) [%s]: transform_vertex(%s, %d) = %s; expected %s" % [
				case.label, v, case.flags, actual, case.out])
			all_pass = false

	if all_pass:
		print("Sub-test (a) — transform_vertex worked example: PASS (8 combinations)")
	else:
		printerr("Sub-test (a) — transform_vertex worked example: FAIL")
		quit(1)


func _subtest_clip_polygon_determinism() -> void:
	# Calls clip_polygon_to_subrect 10 times with identical inputs;
	# asserts output hash is identical across all invocations.
	var test_polygon := PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1),
	])
	var test_sub_rect := Rect2(0.25, 0.25, 0.5, 0.5)
	var test_full_tile_size := Vector2(1.0, 1.0)

	var hashes: Array[int] = []
	for i in range(10):
		var clipped: PackedVector2Array = _SynthesisScript.clip_polygon_to_subrect(
			test_polygon, test_sub_rect, test_full_tile_size
		)
		hashes.append(hash(Array(clipped)))

	var first_hash := hashes[0]
	var all_match := true
	for i in range(1, 10):
		if hashes[i] != first_hash:
			printerr("FAIL sub-test (b): clip_polygon_to_subrect non-deterministic on run %d: %d != %d" % [i, hashes[i], first_hash])
			all_match = false

	if all_match:
		print("Sub-test (b) — clip_polygon_to_subrect determinism: PASS (10 invocations, hash=%d)" % first_hash)
	else:
		printerr("Sub-test (b) — clip_polygon_to_subrect determinism: FAIL")
		quit(1)


# Build a self-contained PentaTileMapLayer with the bundled FOUR-mode greybox
# as its source TileSet. Used by both the main rebuild test and sub-test (c)
# so the determinism check is decoupled from the demo .tscn's editable state
# (the demo's PentaTileMapLayer can be deleted / repainted during UAT and this
# test still runs reproducibly).
func _build_test_layer(axis_value: int) -> Node:
	var penta := _PentaScript.new()
	penta.set("axis", axis_value)
	penta.set("tile_count", 4)                                                  # FOUR

	var bundled_path := "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png" if axis_value == 0 else "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_vertical.png"
	var tex := load(bundled_path) as Texture2D
	if tex == null:
		return null
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	var tile_w: int
	var tile_h: int
	if axis_value == 0:                                                         # HORIZONTAL: 4 tiles along X, 1 row
		tile_w = tex.get_width() / 4
		tile_h = tex.get_height()
		src.texture_region_size = Vector2i(tile_w, tile_h)
		for i in range(4):
			src.create_tile(Vector2i(i, 0))
	else:                                                                       # VERTICAL: 1 col, 4 tiles along Y
		tile_w = tex.get_width()
		tile_h = tex.get_height() / 4
		src.texture_region_size = Vector2i(tile_w, tile_h)
		for i in range(4):
			src.create_tile(Vector2i(0, i))
	ts.tile_size = Vector2i(tile_w, tile_h)
	ts.add_source(src, 0)

	var layer = _LayerScript.new()
	layer.tile_set = ts
	layer.layout = penta
	get_root().add_child(layer)
	return layer


# Deterministic logic-cell pattern used by both the main rebuild test and
# sub-test (c). Exercises a mix of mask states (single cells, 2×2 blocks,
# L-shapes) so the synthesized output covers most dispatch table entries.
const _TEST_LOGIC_CELLS := [
	# 2×2 block (covers all 16 corner masks via the 3×3 affected area)
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	# Isolated single cell
	Vector2i(5, 0),
	# L-shape
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(0, 6),
	# Diagonal pair (mask 6 / 9 territory)
	Vector2i(5, 5), Vector2i(6, 6),
]


func _run_main_rebuild_test() -> void:
	# Build a self-contained HORIZONTAL FOUR layer, paint a deterministic
	# pattern, run rebuild() 11 times, assert all hashes identical AND match
	# BASELINE_HASH. Independent of the demo .tscn's saved state.
	var layer = _build_test_layer(0)                                            # HORIZONTAL
	if layer == null:
		printerr("determinism_test: could not build test layer")
		quit(1)
		return

	# Wait for _ready + auto-fill chain.
	await process_frame
	await process_frame

	# Paint the deterministic pattern.
	for c: Vector2i in _TEST_LOGIC_CELLS:
		layer.set_cell(c, 0, Vector2i.ZERO)
	await process_frame
	await process_frame

	if layer.has_method("rebuild"):
		layer.rebuild()
	var primary = layer.get("_primary_layer")
	if primary == null:
		printerr("determinism_test: _primary_layer is null after initial rebuild")
		layer.queue_free()
		quit(1)
		return

	var data: PackedByteArray = primary.tile_map_data
	var h0: int = hash(Array(data))
	print("Run 0 (initial): hash=%d baseline_match=%s" % [h0, str(h0 == BASELINE_HASH)])

	var all_match := true
	for i in range(1, 11):
		if layer.has_method("_on_layout_changed"):
			layer._on_layout_changed()
		layer.rebuild()
		var h: int = hash(Array(primary.tile_map_data))
		print("Run %d: hash=%d matches_run0=%s baseline_match=%s" % [
			i, h, str(h == h0), str(h == BASELINE_HASH)])
		if h != h0:
			printerr("FAIL main test: determinism violated on run %d: %d != %d" % [i, h, h0])
			all_match = false

	if all_match and h0 == BASELINE_HASH:
		print("MAIN TEST PASSED — 10 re-runs identical AND match BASELINE_HASH=%d" % BASELINE_HASH)
	elif all_match and h0 != BASELINE_HASH:
		printerr("MAIN TEST WARNING — 10 re-runs internally consistent but hash %d != BASELINE_HASH %d" % [h0, BASELINE_HASH])
		all_match = false
	else:
		printerr("MAIN TEST FAILED — synthesis is non-deterministic")

	layer.queue_free()

	if not all_match:
		quit(1)


func _subtest_vertical_axis_structural_coverage() -> void:
	# WR-07 regression net (self-contained version). Builds a HORIZONTAL FOUR
	# test layer, paints the deterministic pattern, captures cell count. Then
	# builds a fresh VERTICAL FOUR layer with the same pattern, asserts:
	#   1. VERTICAL paint count matches HORIZONTAL on the same pattern.
	#   2. Every painted cell's atlas coord exists in the synthesized atlas.
	#
	# Pre-WR-07: VERTICAL FOUR's `_make_slot` returned `Vector2i(0, slot_index)`
	# while the synthesizer always produced a horizontal strip — so coords
	# (0, 1..4) were referenced but the atlas only had tiles at (0..4, 0).
	# Both failure modes (dropped cells, unrenderable atlas refs) are caught.
	var h_layer = _build_test_layer(0)
	if h_layer == null:
		printerr("Sub-test (c): could not build HORIZONTAL test layer")
		quit(1)
		return
	await process_frame
	await process_frame
	for c: Vector2i in _TEST_LOGIC_CELLS:
		h_layer.set_cell(c, 0, Vector2i.ZERO)
	await process_frame
	await process_frame
	if h_layer.has_method("rebuild"):
		h_layer.rebuild()
	var horizontal_count: int = h_layer.get("_primary_layer").get_used_cells().size()
	h_layer.queue_free()

	var v_layer = _build_test_layer(1)                                          # VERTICAL
	if v_layer == null:
		printerr("Sub-test (c): could not build VERTICAL test layer")
		quit(1)
		return
	await process_frame
	await process_frame
	for c: Vector2i in _TEST_LOGIC_CELLS:
		v_layer.set_cell(c, 0, Vector2i.ZERO)
	await process_frame
	await process_frame
	if v_layer.has_method("rebuild"):
		v_layer.rebuild()

	var primary = v_layer.get("_primary_layer")
	if primary == null:
		printerr("Sub-test (c): _primary_layer is null after VERTICAL rebuild")
		v_layer.queue_free()
		quit(1)
		return

	var used_cells: Array = primary.get_used_cells()
	var cell_count := used_cells.size()
	var cells_match: bool = cell_count == horizontal_count
	if not cells_match:
		printerr("FAIL sub-test (c) [cell count]: VERTICAL FOUR painted %d cells, HORIZONTAL FOUR painted %d on same logic-cell pattern" % [cell_count, horizontal_count])

	# Verify every painted cell's atlas coord resolves in the synthesized atlas.
	var synth_tile_set: TileSet = primary.tile_set
	var coords_valid := true
	var invalid_coord_count := 0
	if synth_tile_set != null and synth_tile_set.get_source_count() > 0:
		var source = synth_tile_set.get_source(0) as TileSetAtlasSource
		if source != null:
			for cell in used_cells:
				var atlas_coord: Vector2i = primary.get_cell_atlas_coords(cell)
				if not source.has_tile(atlas_coord):
					if invalid_coord_count < 3:
						printerr("FAIL sub-test (c) [out-of-grid coord]: cell %s atlas %s not in synthesized atlas" % [cell, atlas_coord])
					invalid_coord_count += 1
					coords_valid = false
		else:
			printerr("FAIL sub-test (c): synthesized atlas source 0 is not a TileSetAtlasSource")
			coords_valid = false
	else:
		printerr("FAIL sub-test (c): synthesized tile_set is null or has no sources")
		coords_valid = false

	if invalid_coord_count > 3:
		printerr("  ...and %d more out-of-grid coords (suppressed)" % (invalid_coord_count - 3))

	if cells_match and coords_valid:
		print("Sub-test (c) — VERTICAL-axis structural coverage: PASS (cells=%d match HORIZONTAL baseline; all atlas coords resolve in synthesized atlas)" % cell_count)
	else:
		printerr("Sub-test (c) — VERTICAL-axis structural coverage: FAIL")
		v_layer.queue_free()
		quit(1)
		return

	v_layer.queue_free()
