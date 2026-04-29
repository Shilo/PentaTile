## Diagnostic: load the demo .tscn EXACTLY as the user has it on disk and report
## what the layer is actually doing — what's bound, what's painted, what tile
## the visual layer ends up with, and the pixel opacity of each painted tile
## (so we can tell "registered but transparent" apart from "rendered correctly").
##
## Run: Godot --headless --path . --script tests/demo_scene_diag.gd

extends SceneTree


func _initialize() -> void:
	print("=== demo_scene_diag ===")
	var packed := load("res://addons/penta_tile/demo/penta_tile_demo.tscn") as PackedScene
	if packed == null:
		printerr("could not load demo scene")
		quit(1)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var layer = root.find_child("PentaTileMapLayer", true, false)
	if layer == null:
		printerr("PentaTileMapLayer not found in demo")
		quit(1)
		return

	# Dump bound state
	print("\n[BOUND STATE]")
	print("  layout:", layer.layout)
	print("  layout class:", layer.layout.get_script().resource_path if layer.layout != null and layer.layout.get_script() != null else "null")
	print("  tile_set:", layer.tile_set)
	print("  tile_set sources:", layer.tile_set.get_source_count() if layer.tile_set != null else 0)
	print("  _tile_set_is_fallback:", layer.get("_tile_set_is_fallback"))
	print("  parent self_modulate:", layer.self_modulate)

	# Source atlas of the tile_set
	if layer.tile_set != null and layer.tile_set.get_source_count() > 0:
		var src := layer.tile_set.get_source(0) as TileSetAtlasSource
		if src != null and src.texture != null:
			var ts_img: Image = src.texture.get_image()
			print("  source atlas size:", ts_img.get_size() if ts_img else "null")
			print("  source atlas grid:", src.get_atlas_grid_size())
			print("  source texture_region_size:", src.texture_region_size)

	# Synthesized atlas (if Penta)
	var synth = layer.get("_synthesized_tile_set")
	print("\n[SYNTHESIS]")
	print("  _synthesized_tile_set:", synth)
	if synth != null and synth.get_source_count() > 0:
		var ssrc := synth.get_source(0) as TileSetAtlasSource
		if ssrc != null and ssrc.texture != null:
			var simg: Image = ssrc.texture.get_image()
			print("  synth atlas size:", simg.get_size() if simg else "null")
			print("  synth atlas grid:", ssrc.get_atlas_grid_size())

	# Logic-layer painted cells (parent — the user's set_cell input)
	print("\n[LOGIC LAYER (parent — what user painted)]")
	var logic_cells: Array = layer.get_used_cells()
	print("  count:", logic_cells.size())
	for c: Vector2i in logic_cells:
		var ac: Vector2i = layer.get_cell_atlas_coords(c)
		var sid: int = layer.get_cell_source_id(c)
		print("    %s source=%d atlas=%s" % [c, sid, ac])

	# Visual-layer painted cells (child — autotile dispatch output)
	var primary = layer.get("_primary_layer")
	print("\n[VISUAL LAYER (_primary_layer — autotile output)]")
	if primary == null:
		print("  null!")
	else:
		print("  visible:", primary.visible)
		print("  position:", primary.position)
		print("  tile_set is same as parent:", primary.tile_set == layer.tile_set)
		print("  tile_set is synth:", primary.tile_set == synth)
		var visual_cells: Array = primary.get_used_cells()
		print("  count:", visual_cells.size())

		# Pixel-opacity check on each painted visual cell
		var eff_src = primary.tile_set.get_source(0) as TileSetAtlasSource if primary.tile_set != null and primary.tile_set.get_source_count() > 0 else null
		var eff_img: Image = eff_src.texture.get_image() if eff_src != null and eff_src.texture != null else null
		var region: Vector2i = eff_src.texture_region_size if eff_src != null else Vector2i.ZERO

		for c: Vector2i in visual_cells:
			var ac: Vector2i = primary.get_cell_atlas_coords(c)
			var alt: int = primary.get_cell_alternative_tile(c)
			var transform := alt & ~0xfff
			var has_tile: bool = eff_src.has_tile(ac) if eff_src != null else false

			# Sample opacity at the dispatched tile's pixel region
			var opacity := 0
			var total := 0
			if eff_img != null and has_tile and region != Vector2i.ZERO:
				var px0: int = ac.x * region.x
				var py0: int = ac.y * region.y
				for py in range(region.y):
					for px in range(region.x):
						total += 1
						if eff_img.get_pixel(px0 + px, py0 + py).a > 0.01:
							opacity += 1
			var pct: float = (100.0 * opacity / max(1, total))
			print("    %s atlas=%s transform=%d has_tile=%s opacity=%.0f%%" % [c, ac, transform, str(has_tile), pct])

	# ----- SIMULATE USER PAINTING -----
	# Paint a small cluster as if the user clicked in the TileMap pane.
	# This exercises the same _update_cells dispatch path the editor uses.
	print("\n[SIMULATED PAINT (1 cell at (0,0))]")
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if primary != null:
		print("  visual cells after 1-cell paint:", primary.get_used_cells().size())
		for c: Vector2i in primary.get_used_cells():
			var ac: Vector2i = primary.get_cell_atlas_coords(c)
			var alt: int = primary.get_cell_alternative_tile(c)
			print("    %s atlas=%s alt=%d" % [c, ac, alt])

	print("\n[SIMULATED PAINT (2x2 cluster at (5,5)..(6,6))]")
	layer.set_cell(Vector2i(5, 5), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(6, 5), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(5, 6), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(6, 6), 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if primary != null:
		print("  visual cells after 2x2 paint:", primary.get_used_cells().size())

	root.queue_free()
	quit(0)
