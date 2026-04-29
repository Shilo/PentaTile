## Fallback routing UAT: paints a 3x3 pattern with each of the 8 actually-shipped
## layouts under tile_set = null. Asserts (a) PREVIEW-03 - tile_set auto-fills
## from layout.get_fallback_tile_set(); (b) every painted display cell composes
## non-zero opaque pixels into a virtual canvas; (c) PREVIEW-04 - direct
## tile_set assignment overrides fallback; (d) clearing tile_set + re-assigning
## layout re-routes to fallback; (e) SC-4 - user-supplied tile_set is preserved
## across a subsequent layout reassignment (NOT replaced by fallback).
##
## Layouts covered (D-04-05): Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3,
## Blob47Godot, PixelLabTopDown, PixelLabSideScroller. Tilesetter pair stays
## deferred per D-86 (b).
##
## Run headless:
##   Godot --headless --path . --script tests/fallback_routing_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")
const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")
const _PixelLabTopDownSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd")
const _PixelLabSideScrollerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== fallback_routing_test ===")

	var pattern: Array = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	]

	var layouts: Array = [
		{"name": "Penta", "script": _PentaScript},
		{"name": "DualGrid16", "script": _DualGrid16Sc},
		{"name": "Wang2Edge", "script": _Wang2EdgeSc},
		{"name": "Wang2Corner", "script": _Wang2CornerSc},
		{"name": "Min3x3", "script": _Min3x3Sc},
		{"name": "Blob47Godot", "script": _Blob47GodotSc},
		{"name": "PixelLabTopDown", "script": _PixelLabTopDownSc},
		{"name": "PixelLabSideScroller", "script": _PixelLabSideScrollerSc},
	]

	for layout_def: Dictionary in layouts:
		await _test_fallback(layout_def, pattern)

	await _test_preview_04_override()
	await _test_preview_04_reroute()
	await _test_preview_04_user_tileset_preserved()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _test_fallback(layout_def: Dictionary, pattern: Array) -> void:
	var layer = _LayerScript.new()
	layer.layout = layout_def.script.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var auto_filled_tile_set: TileSet = layer.tile_set
	if auto_filled_tile_set == null:
		_record(layout_def.name, "PREVIEW-03 - tile_set still null after layout assignment")
		layer.queue_free()
		return
	if not layer.get("_tile_set_is_fallback"):
		_record(layout_def.name, "PREVIEW-03 - _tile_set_is_fallback should be true after auto-fill")

	for cell: Vector2i in pattern:
		layer.set_cell(cell, 0, Vector2i.ZERO)
	await process_frame
	await process_frame
	layer.rebuild()
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(layout_def.name, "_primary_layer is null")
		layer.queue_free()
		return

	var painted_visual: Array = primary.get_used_cells()
	if painted_visual.is_empty():
		_record(layout_def.name, "no visual cells rendered under fallback")
		layer.queue_free()
		return

	var canvas_result := _compose_rendered_canvas(primary, painted_visual)
	if canvas_result.is_empty():
		_record(layout_def.name, "could not compose fallback canvas")
		layer.queue_free()
		return

	var canvas: Image = canvas_result.canvas
	var tile_size: Vector2i = canvas_result.tile_size
	var c_min: Vector2i = canvas_result.c_min

	if _count_opaque_pixels(canvas) == 0:
		# Diagnostic escape hatch per CLAUDE.md Test Methodology #4:
		# canvas.save_png("user://fallback_%s.png" % layout_def.name)
		_record(layout_def.name, "composed-canvas is fully empty under fallback")

	for cell: Vector2i in painted_visual:
		if not _cell_has_opaque_pixels(canvas, (cell - c_min) * tile_size, tile_size):
			_record(layout_def.name, "display cell %s has zero opaque pixels" % str(cell))
			break

	print("  %s painted display cells=%d tile_size=%s" % [layout_def.name, painted_visual.size(), tile_size])
	layer.queue_free()


func _compose_rendered_canvas(primary: TileMapLayer, painted_visual: Array) -> Dictionary:
	var eff_ts: TileSet = primary.tile_set
	if eff_ts == null:
		return {}

	var c_min := Vector2i(99999, 99999)
	var c_max := Vector2i(-99999, -99999)
	for cell: Vector2i in painted_visual:
		c_min.x = mini(c_min.x, cell.x)
		c_min.y = mini(c_min.y, cell.y)
		c_max.x = maxi(c_max.x, cell.x)
		c_max.y = maxi(c_max.y, cell.y)

	var first_source_id: int = primary.get_cell_source_id(painted_visual[0])
	var first_src := eff_ts.get_source(first_source_id) as TileSetAtlasSource
	if first_src == null or first_src.texture == null:
		return {}

	var tile_size: Vector2i = first_src.texture_region_size
	var w: int = (c_max.x - c_min.x + 1) * tile_size.x
	var h: int = (c_max.y - c_min.y + 1) * tile_size.y
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var atlas_images: Dictionary = {}
	var unrenderable_atlas := 0
	for cell: Vector2i in painted_visual:
		var source_id: int = primary.get_cell_source_id(cell)
		var eff_src := eff_ts.get_source(source_id) as TileSetAtlasSource
		if eff_src == null or eff_src.texture == null:
			unrenderable_atlas += 1
			continue
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		if not eff_src.has_tile(ac):
			unrenderable_atlas += 1
			continue
		if not atlas_images.has(source_id):
			atlas_images[source_id] = eff_src.texture.get_image()
		var atlas_img: Image = atlas_images[source_id]
		var cell_tile_size: Vector2i = eff_src.texture_region_size
		if cell_tile_size != tile_size:
			unrenderable_atlas += 1
			continue
		var alt: int = primary.get_cell_alternative_tile(cell)
		var transform: int = alt & ~0xfff
		var src_tile := atlas_img.get_region(Rect2i(ac * tile_size, tile_size))
		var rotated := _apply_transform(src_tile, transform)
		canvas.blit_rect(rotated, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min) * tile_size)

	if unrenderable_atlas > 0:
		_record("compose", "%d visual cells could not be blitted from their atlas source" % unrenderable_atlas)

	return {
		"canvas": canvas,
		"tile_size": tile_size,
		"c_min": c_min,
	}


func _test_preview_04_override() -> void:
	var layer = _LayerScript.new()
	layer.layout = _PentaScript.new()
	get_root().add_child(layer)
	await process_frame
	if not layer.get("_tile_set_is_fallback"):
		_record("PREVIEW-04-override", "_tile_set_is_fallback should be true after auto-fill")

	var custom = TileSet.new()
	layer.tile_set = custom
	await process_frame
	if layer.tile_set != custom:
		_record("PREVIEW-04-override", "custom tile_set assignment did not stick")
	if layer.get("_tile_set_is_fallback"):
		_record("PREVIEW-04-override", "_tile_set_is_fallback should flip to false after direct tile_set assignment")
	layer.queue_free()


func _test_preview_04_reroute() -> void:
	var layer = _LayerScript.new()
	layer.layout = _PentaScript.new()
	get_root().add_child(layer)
	await process_frame

	var custom = TileSet.new()
	layer.tile_set = custom
	await process_frame
	layer.tile_set = null
	layer.layout = _PentaScript.new()
	await process_frame

	var rerouted_tile_set: TileSet = layer.tile_set
	if rerouted_tile_set == null:
		_record("PREVIEW-04-reroute", "tile_set should re-route to fallback after clear + layout reassignment")
	if not layer.get("_tile_set_is_fallback"):
		_record("PREVIEW-04-reroute", "_tile_set_is_fallback should be true after re-route")
	layer.queue_free()


func _test_preview_04_user_tileset_preserved() -> void:
	var layer = _LayerScript.new()
	layer.layout = _DualGrid16Sc.new()
	get_root().add_child(layer)
	await process_frame

	var custom_tileset = TileSet.new()
	layer.tile_set = custom_tileset
	await process_frame

	layer.layout = _Wang2EdgeSc.new()
	await process_frame

	if layer.tile_set != custom_tileset:
		_record("PREVIEW-04-user-tileset-preserved", "user-supplied tile_set was replaced during layout reassignment")
	if layer.get("_tile_set_is_fallback"):
		_record("PREVIEW-04-user-tileset-preserved", "_tile_set_is_fallback should remain false after layout reassignment")
	layer.queue_free()


func _count_opaque_pixels(image: Image) -> int:
	var opaque := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				opaque += 1
	return opaque


func _cell_has_opaque_pixels(canvas: Image, origin: Vector2i, tile_size: Vector2i) -> bool:
	for y in range(origin.y, origin.y + tile_size.y):
		for x in range(origin.x, origin.x + tile_size.x):
			if canvas.get_pixel(x, y).a > 0.01:
				return true
	return false


func _apply_transform(src: Image, transform: int) -> Image:
	var transpose: bool = (transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var flip_h: bool = (transform & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v: bool = (transform & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
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
