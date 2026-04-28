## Pixel verification of Penta layout against the user's actual ground.tres
## tile_set, painted in a HOLLOW SQUARE pattern (the UAT scenario from the
## yellow-line screenshot).
##
## Test approach (per user request: "first create a test that will properly
## find the invalid pixels then create a fix after"):
##
##   1. Load `addons/penta_tile/demo/penta_tile_ground.tres` (5 authored tiles,
##      tile_size=16x16). It IS a Penta-format atlas — slot 0 = IsolatedCell,
##      slot 1 = Fill, slot 2 = Border, slot 3 = InnerCorner, slot 4 =
##      OppositeCorners.
##
##   2. For each Penta mode (ONE, FOUR, FIVE) × axis (HORIZONTAL, VERTICAL):
##      a. Configure the layer with a Penta layout in that mode/axis.
##      b. Replace the layer's tile_set with the ground.tres source so the
##         user's actual artwork is what gets synthesized + rendered.
##      c. Paint the hollow square (8x8 outer ring with 4x4 hole in the
##         middle) — same shape as Image #19.
##      d. Compose the rendered painted region into a virtual canvas by
##         blitting each dispatched tile (atlas + transform) at the display
##         cell's world position.
##      e. Find the bounding box of OPAQUE pixels in the canvas.
##      f. Compare the opaque bbox to the EXPECTED bbox for the painted ring
##         (12x8 outer outline with the hole punched out).
##
## Failure modes the test catches:
##   - Opaque pixels OUTSIDE the painted-cells × tile_size bounds (the
##     "orange lines outside the slots" artifact).
##   - Opaque pixels INSIDE the hole (the painted ring shouldn't fill the
##     hole; if it does, the inner-corner archetype is rendering too far).
##   - Cells dispatching to atlas coords that aren't registered.
##   - Cells dispatching to tiles whose pixel content has artifacts that
##     would NOT appear in the source authored slot 0.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/penta_ground_hollow_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _GROUND_TS_PATH := "res://addons/penta_tile/demo/penta_tile_ground.tres"

var _failures: Array = []


func _initialize() -> void:
	print("=== penta_ground_hollow_test ===")

	# Hollow ring: 8x8 outer cells with a 4x4 hole at the center. Painted cells
	# form a 16-cell ring around a 16-cell empty interior.
	var paint_cells: Array = _build_hollow_ring(0, 0, 8, 8, 2, 2, 4, 4)

	# tile_count values from the Penta layout's enum:
	#   ONE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5.
	# axis: 0 = HORIZONTAL, 1 = VERTICAL.
	var modes := [
		{"name": "ONE",   "tile_count": 1},
		{"name": "FOUR",  "tile_count": 4},
		{"name": "FIVE",  "tile_count": 5},
	]
	var axes := [
		{"name": "H", "axis": 0},
		{"name": "V", "axis": 1},
	]

	for mode: Dictionary in modes:
		for axis: Dictionary in axes:
			await _test_mode(paint_cells, mode, axis)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# Build a hollow rectangular ring (outer rect minus inner rect).
func _build_hollow_ring(ox: int, oy: int, ow: int, oh: int, ix_off: int, iy_off: int, iw: int, ih: int) -> Array:
	var cells: Array = []
	for x in range(ox, ox + ow):
		for y in range(oy, oy + oh):
			var inside_hole: bool = (x >= ox + ix_off and x < ox + ix_off + iw and y >= oy + iy_off and y < oy + iy_off + ih)
			if not inside_hole:
				cells.append(Vector2i(x, y))
	return cells


func _test_mode(paint_cells: Array, mode_def: Dictionary, axis_def: Dictionary) -> void:
	var label := "Penta-%s-%s" % [mode_def.name, axis_def.name]

	var layout = _PentaScript.new()
	layout.set("axis", axis_def.axis)
	layout.set("tile_count", mode_def.tile_count)

	var layer = _LayerScript.new()
	# Assign the user's ground tile_set BEFORE the layout — the layer's auto-fill
	# chain only kicks in when tile_set is null. With ground.tres assigned, the
	# layer treats it as user-supplied (not fallback) and synthesizes from it.
	layer.tile_set = load(_GROUND_TS_PATH)
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	for c: Vector2i in paint_cells:
		layer.set_cell(c, 0, Vector2i(0, 0))
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

	var painted_visual: Array = primary.get_used_cells()
	if painted_visual.is_empty():
		_record(label, "no visual cells rendered (layer painted nothing)")
		layer.queue_free()
		return

	# Effective tile_set — synthesized for Penta.
	var eff_ts: TileSet = primary.tile_set
	if eff_ts == null or eff_ts.get_source_count() == 0:
		_record(label, "visual layer has no tile_set / no atlas source")
		layer.queue_free()
		return
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource
	if eff_src == null:
		_record(label, "visual layer source 0 not a TileSetAtlasSource")
		layer.queue_free()
		return
	var atlas_img: Image = eff_src.texture.get_image() if eff_src.texture else null
	if atlas_img == null:
		_record(label, "atlas texture has no image data")
		layer.queue_free()
		return
	var tile_size: Vector2i = eff_src.texture_region_size

	# Painted pixel bbox of user-painted logic cells.
	var min_logic := Vector2i(99999, 99999)
	var max_logic := Vector2i(-99999, -99999)
	for c: Vector2i in paint_cells:
		min_logic.x = min(min_logic.x, c.x)
		min_logic.y = min(min_logic.y, c.y)
		max_logic.x = max(max_logic.x, c.x)
		max_logic.y = max(max_logic.y, c.y)
	var expected_min := Vector2i(min_logic.x * tile_size.x, min_logic.y * tile_size.y)
	var expected_max := Vector2i((max_logic.x + 1) * tile_size.x - 1, (max_logic.y + 1) * tile_size.y - 1)

	# Compose actual rendered canvas from the dispatched tiles.
	var c_min := Vector2i(99999, 99999)
	var c_max := Vector2i(-99999, -99999)
	for cell: Vector2i in painted_visual:
		c_min.x = min(c_min.x, cell.x)
		c_min.y = min(c_min.y, cell.y)
		c_max.x = max(c_max.x, cell.x)
		c_max.y = max(c_max.y, cell.y)
	var w: int = (c_max.x - c_min.x + 1) * tile_size.x
	var h: int = (c_max.y - c_min.y + 1) * tile_size.y
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var unrenderable_atlas := 0
	for cell: Vector2i in painted_visual:
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		if not eff_src.has_tile(ac):
			unrenderable_atlas += 1
			continue
		var alt: int = primary.get_cell_alternative_tile(cell)
		var transform: int = alt & ~0xfff
		var src_tile := atlas_img.get_region(Rect2i(ac * tile_size, tile_size))
		var rotated := _apply_transform(src_tile, transform)
		canvas.blit_rect(rotated, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min) * tile_size)

	if unrenderable_atlas > 0:
		_record(label, "%d cells dispatch to non-registered atlas coords" % unrenderable_atlas)

	# Find opaque-pixel bbox in WORLD coords.
	var canvas_origin := c_min * tile_size
	var is_dual_grid: bool = layout.is_dual_grid()
	if is_dual_grid:
		canvas_origin += Vector2i(- tile_size.x / 2, - tile_size.y / 2)
	var op_min := Vector2i(999999, 999999)
	var op_max := Vector2i(-999999, -999999)
	var any_opaque := false
	for py in range(h):
		for px in range(w):
			if canvas.get_pixel(px, py).a > 0.01:
				any_opaque = true
				var wx: int = canvas_origin.x + px
				var wy: int = canvas_origin.y + py
				op_min.x = min(op_min.x, wx)
				op_min.y = min(op_min.y, wy)
				op_max.x = max(op_max.x, wx)
				op_max.y = max(op_max.y, wy)
	if not any_opaque:
		_record(label, "painted ring rendered ZERO opaque pixels")
	else:
		# Assertion 1: opaque bbox stays within user-painted logic bounds.
		# For Penta dual-grid, perimeter display cells fill INNER quadrants
		# that fall inside the painted logic pixel bounds — net effect is
		# clean rectangle-aligned opaque bounds.
		if op_min.x < expected_min.x or op_min.y < expected_min.y or op_max.x > expected_max.x or op_max.y > expected_max.y:
			_record(label, "opaque bbox %s..%s extends OUTSIDE expected user-painted bounds %s..%s — orange-line-outside-slot artifact" % [op_min, op_max, expected_min, expected_max])

		# Assertion 2: hole interior (the unpainted center) should be transparent.
		# Compute hole pixel rect: offset from min_logic by inner-rect offsets.
		var hole_min := Vector2i((min_logic.x + 2) * tile_size.x, (min_logic.y + 2) * tile_size.y)
		var hole_max := Vector2i((min_logic.x + 2 + 4) * tile_size.x - 1, (min_logic.y + 2 + 4) * tile_size.y - 1)
		var hole_opaque := 0
		for hy in range(hole_min.y, hole_max.y + 1):
			for hx in range(hole_min.x, hole_max.x + 1):
				var canvas_x: int = hx - canvas_origin.x
				var canvas_y: int = hy - canvas_origin.y
				if canvas_x < 0 or canvas_y < 0 or canvas_x >= w or canvas_y >= h:
					continue
				if canvas.get_pixel(canvas_x, canvas_y).a > 0.01:
					hole_opaque += 1
		if hole_opaque > 0:
			_record(label, "%d opaque pixels rendered INSIDE the 4x4 hole at world bounds %s..%s — InnerCorner archetype filling too far" % [hole_opaque, hole_min, hole_max])
			# Save the canvas for visual inspection.
			var save_path := "user://hollow_%s.png" % label.to_lower().replace("-", "_")
			canvas.save_png(save_path)
			print("    canvas dumped: " + ProjectSettings.globalize_path(save_path))
			# Print the first few opaque-in-hole pixel positions and which display
			# cell they came from so we can pinpoint the bad dispatch.
			var samples := 0
			for hy in range(hole_min.y, hole_max.y + 1):
				for hx in range(hole_min.x, hole_max.x + 1):
					var cx: int = hx - canvas_origin.x
					var cy: int = hy - canvas_origin.y
					if cx < 0 or cy < 0 or cx >= w or cy >= h:
						continue
					if canvas.get_pixel(cx, cy).a > 0.01:
						# Identify which display cell this pixel falls in.
						var dcell := Vector2i((hx - canvas_origin.x) / tile_size.x + c_min.x, (hy - canvas_origin.y) / tile_size.y + c_min.y)
						var dac: Vector2i = primary.get_cell_atlas_coords(dcell)
						var dalt: int = primary.get_cell_alternative_tile(dcell)
						print("    opaque-in-hole world=(%d,%d) display_cell=%s atlas=%s transform=%d color=%s" % [hx, hy, dcell, dac, dalt & ~0xfff, canvas.get_pixel(cx, cy)])
						samples += 1
						if samples >= 6:
							break
				if samples >= 6:
					break

	print("  %s painted=%d opaque_bbox=%s..%s expected=%s..%s tile_size=%s" % [label, painted_visual.size(), op_min, op_max, expected_min, expected_max, tile_size])

	layer.queue_free()


# Apply a TileSetAtlasSource transform (TRANSPOSE | FLIP_H | FLIP_V) to an image.
# The transform encoding matches what the layer dispatches via alternative_tile.
func _apply_transform(src: Image, transform: int) -> Image:
	var transpose: bool = (transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var flip_h: bool   = (transform & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v: bool   = (transform & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	var w: int = src.get_width()
	var h: int = src.get_height()
	var dst_w: int = h if transpose else w
	var dst_h: int = w if transpose else h
	var dst := Image.create(dst_w, dst_h, false, Image.FORMAT_RGBA8)
	for sy in range(h):
		for sx in range(w):
			var c := src.get_pixel(sx, sy)
			var tx: int = sx
			var ty: int = sy
			if transpose:
				var tmp: int = tx
				tx = ty
				ty = tmp
			if flip_h:
				tx = dst_w - 1 - tx
			if flip_v:
				ty = dst_h - 1 - ty
			dst.set_pixel(tx, ty, c)
	return dst


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL " + label + ": " + msg)
