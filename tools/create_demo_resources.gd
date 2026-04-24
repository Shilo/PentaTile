@tool
extends SceneTree


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://demo"))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://tetra_tile_ground.png")
	atlas.texture_region_size = Vector2i(16, 16)
	for x in range(4):
		atlas.create_tile(Vector2i(x, 0))
	tile_set.add_source(atlas, 0)
	ResourceSaver.save(tile_set, "res://demo/tetra_tile_ground.tres")

	var root := Node2D.new()
	root.name = "TetraTileDemo"

	var layer := TileMapLayer.new()
	layer.name = "TetraTileMapLayer"
	layer.set_script(load("res://addons/tetratile/tetra_tile_map_layer.gd"))
	layer.tile_set = tile_set
	layer.position = Vector2(128, 96)
	layer.set("logic_layer_opacity", 0.0)

	var cells: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(0, 1),
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(1, 2),
		Vector2i(2, 2),
		Vector2i(4, 2),
		Vector2i(1, 3),
		Vector2i(3, 3),
	]
	for cell in cells:
		layer.set_cell(cell, 0, Vector2i(0, 0))

	root.add_child(layer)
	layer.owner = root

	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, "res://demo/tetratile_demo.tscn")
	quit()
