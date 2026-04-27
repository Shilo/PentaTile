## Loads the actual demo scene, lets it render for a few frames, captures a viewport
## screenshot to user://demo_screenshot.png. Run with rendering enabled:
##
##   Godot_v4.6.2-stable_win64_console.exe --rendering-driver opengl3 \
##     --display-driver headless --headless --path . \
##     --script addons/penta_tile/tests/screenshot_demo.gd
##
## (Strict --headless disables rendering. Some Godot 4.x builds support GL with
##  --display-driver headless; if not, this falls back to dumping the synthesized
##  atlas + per-cell paint output instead.)
extends SceneTree


func _initialize() -> void:
	var packed := load("res://addons/penta_tile/demo/penta_tile_demo.tscn") as PackedScene
	if packed == null:
		printerr("could not load demo scene")
		quit(1)
		return
	var root := packed.instantiate()
	get_root().add_child(root)

	# Wait several frames so deferred rebuild + initial render complete.
	for _i in range(8):
		await process_frame

	# Find the layer + dump the actual painted state.
	var layer := root.find_child("PentaTileMapLayer", true, false)
	if layer == null:
		printerr("PentaTileMapLayer not found")
		quit(1)
		return

	var primary: TileMapLayer = layer.get("_primary_layer")
	print("=== demo paint state ===")
	print("layer.tile_set: %s" % layer.tile_set)
	print("layer.layout: %s" % layer.layout)
	if primary != null:
		var painted_cells := primary.get_used_cells()
		print("primary visual layer painted cells: %d" % painted_cells.size())
		# Group cells by their atlas slot for a compact view.
		var by_slot: Dictionary = {}
		for c: Vector2i in painted_cells:
			var coords := primary.get_cell_atlas_coords(c)
			var alt := primary.get_cell_alternative_tile(c)
			var key := "%s alt=%d" % [coords, alt]
			if not by_slot.has(key):
				by_slot[key] = 0
			by_slot[key] += 1
		print("painted breakdown:")
		var keys := by_slot.keys()
		keys.sort()
		for k in keys:
			print("  %s → %d cells" % [k, by_slot[k]])

	# Try to capture a viewport screenshot. Some headless modes disable this; we
	# print a clear message either way.
	var vp := get_root()
	var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
	if img != null:
		var path := "user://demo_screenshot.png"
		img.save_png(path)
		var abs_path := ProjectSettings.globalize_path(path)
		print("screenshot saved to %s (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
	else:
		print("viewport texture unavailable in this run mode — skipping screenshot")

	root.queue_free()
	quit(0)
