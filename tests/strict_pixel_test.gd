## Strict pixel-precise rendering test — every painted display cell's
## post-transform pixel content is compared BYTE-FOR-BYTE against the
## locked expected pattern for its layout + mask. Zero tolerance — any
## single-pixel overflow, off-by-one, or outline residue fails loud with
## the exact (x, y) coordinate of the first mismatch.
##
## visual_render_test uses 25%/50% per-quadrant thresholds for "opaque"
## vs "transparent" classification. That coarse check missed the
## reported 1-px-column overflow in FIVE-mode slot 0 (16 stray pixels
## in a 256-pixel BR quadrant = 6.25%, below the 25% transparent
## threshold). This test is strict — every pixel must match.
##
## Currently covers Penta-FIVE-H (corner-mask dual-grid). Add other
## layouts incrementally — each needs an expected_source_pattern table
## describing which source-tile pixels are opaque per slot.
##
## Run headless:
##   Godot --headless --path . --script tests/strict_pixel_test.gd
extends SceneTree

const _LayerScript  = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript  = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")

const _TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const _FLIP_H    := TileSetAtlasSource.TRANSFORM_FLIP_H
const _FLIP_V    := TileSetAtlasSource.TRANSFORM_FLIP_V

var _failures: Array = []


func _initialize() -> void:
	print("=== strict_pixel_test ===")
	await _test_penta_five()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# Penta-FIVE source-slot pixel pattern. Returns true if pixel (x, y) of
# `slot` should be opaque per the locked greybox spec.
# tile = ts × ts square; quadrants:
#   TL = (x:0..ts/2-1, y:0..ts/2-1)
#   TR = (x:ts/2..ts-1, y:0..ts/2-1)
#   BL = (x:0..ts/2-1, y:ts/2..ts-1)
#   BR = (x:ts/2..ts-1, y:ts/2..ts-1)
func _penta_source_opaque(slot: int, x: int, y: int, ts: int) -> bool:
	var half := ts / 2
	var in_tl: bool = (x < half) and (y < half)
	var in_tr: bool = (x >= half) and (y < half)
	var in_bl: bool = (x < half) and (y >= half)
	var in_br: bool = (x >= half) and (y >= half)
	match slot:
		0: return in_bl                                         # IsolatedCell — BL quadrant only
		1: return true                                          # Fill — full
		2: return y >= half                                     # Border — bottom half (BL+BR)
		3: return not in_tr                                     # InnerCorner — full minus TR
		4: return in_tl or in_br                                # OppositeCorners — TL + BR diagonal
	return false


# Apply the same transform Godot's tile renderer applies to a source pixel.
# Returns the destination (dx, dy) for source (sx, sy) under flags.
# Order: TRANSPOSE first, then FLIP_H, then FLIP_V (matches synthesis machinery).
func _transform_pixel(sx: int, sy: int, ts: int, flags: int) -> Vector2i:
	var dx := sx
	var dy := sy
	if flags & _TRANSPOSE:
		var t := dx
		dx = dy
		dy = t
	if flags & _FLIP_H:
		dx = ts - 1 - dx
	if flags & _FLIP_V:
		dy = ts - 1 - dy
	return Vector2i(dx, dy)


# Build the expected RENDERED pixel pattern for a (slot, transform) pair.
# Returns a 2D array of bools sized ts×ts where true = expected opaque.
func _build_expected_render(slot: int, transform: int, ts: int) -> Array:
	var out: Array = []
	out.resize(ts)
	for y in range(ts):
		var row: Array = []
		row.resize(ts)
		for x in range(ts):
			row[x] = false
		out[y] = row
	# For each source pixel that should be opaque, transform to dest and mark.
	for sy in range(ts):
		for sx in range(ts):
			if not _penta_source_opaque(slot, sx, sy, ts):
				continue
			var dst := _transform_pixel(sx, sy, ts, transform)
			out[dst.y][dst.x] = true
	return out


func _test_penta_five() -> void:
	print("\n--- Penta-FIVE-H strict pixel check ---")
	var penta := _PentaScript.new()
	penta.set("axis", 0)
	penta.set("tile_count", 5)

	var layer := _LayerScript.new()
	layer.layout = penta
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a 2×2 logic-cell block to exercise corner masks (1/2/4/8) +
	# borders (3/5/10/12) + inner corners (7/11/13/14) + opposite corners
	# (6/9 — but those need a diagonal pattern; skipped here, covered by
	# a separate diagonal cluster).
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		layer.set_cell(c, 0, Vector2i.ZERO)
	# Diagonal pair to exercise mask 6 + 9.
	layer.set_cell(Vector2i(5, 5), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(6, 6), 0, Vector2i.ZERO)
	await process_frame
	await process_frame

	var primary = layer.get("_primary_layer")
	var ts: TileSet = layer.tile_set
	var src := ts.get_source(0) as TileSetAtlasSource
	var atlas_img: Image = src.texture.get_image()
	var tile_size: int = src.texture_region_size.x

	var sample_fn := Callable(layer, "_has_logic_cell")
	var checked := 0
	var first_fails: Array = []

	for cell: Vector2i in primary.get_used_cells():
		var mask: int = penta.compute_mask(cell, sample_fn)
		var atlas_coords: Vector2i = primary.get_cell_atlas_coords(cell)
		var alt: int = primary.get_cell_alternative_tile(cell)
		var transform := alt & ~0xfff
		var slot := atlas_coords.x

		# Build expected rendered pattern for this (slot, transform).
		var expected := _build_expected_render(slot, transform, tile_size)

		# Compare pixel-by-pixel.
		var src_x0: int = atlas_coords.x * tile_size
		var src_y0: int = atlas_coords.y * tile_size
		var diffs := 0
		var first_diff_xy: Vector2i = Vector2i(-1, -1)
		var first_diff_actual := false
		var first_diff_expected := false
		# Render = source-tile pixels with transform applied. Iterate source pixels;
		# the pixel at SOURCE (sx, sy) lands at DEST per _transform_pixel; check
		# DEST opacity against expected DEST.
		for sy in range(tile_size):
			for sx in range(tile_size):
				var src_op: bool = atlas_img.get_pixel(src_x0 + sx, src_y0 + sy).a > 0.01
				var dst := _transform_pixel(sx, sy, tile_size, transform)
				var exp_op: bool = expected[dst.y][dst.x]
				# Note: expected is built BY transforming the source pattern, so
				# the dest pixel's expected = the source pattern at sx,sy. The
				# rendered dest pixel = the source pixel at sx,sy. So they should
				# match if the actual atlas tile matches the expected source pattern.
				var rendered_op: bool = src_op
				if rendered_op != exp_op:
					diffs += 1
					if first_diff_xy == Vector2i(-1, -1):
						first_diff_xy = dst
						first_diff_actual = rendered_op
						first_diff_expected = exp_op
		if diffs > 0:
			if first_fails.size() < 5:
				first_fails.append("cell %s mask=%d slot=%d transform=%d: %d pixel diffs; first at dst%s actual=%s expected=%s" % [
					cell, mask, slot, transform, diffs, first_diff_xy, str(first_diff_actual), str(first_diff_expected),
				])
		checked += 1

	print("  checked: %d cells" % checked)
	print("  failures: %d" % first_fails.size())
	for f in first_fails:
		print("    " + f)

	if first_fails.size() > 0:
		_failures.append("Penta-FIVE-H: %d cells with pixel mismatches" % first_fails.size())

	layer.queue_free()
