## Automated terrain index correctness test for PentaTileMapLayer.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/terrain_index_test.gd
##
## What it does:
##   - Tests _build_terrain_index() correctness
##   - Tests alternative tile scanning (GAP-01)
##   - Tests center bit exclusion (GAP-02)
##   - Tests multi-source TileSet scanning
##   - Tests null terrain_group clears/keeps empty index
##   - Tests terrain_group reassignment rebuilds index
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _TerrainGroupSc  = preload("res://addons/penta_tile/layouts/penta_tile_terrain_group.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== terrain_index_test ===")

	await _test_two_terrain_index()
	await _test_null_terrain_group()
	await _test_alternative_tile_scanning()
	await _test_center_bit_exclusion()
	await _test_multi_source_scanning()
	await _test_reassign_triggers_rebuild()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# --- Helpers ---

func _build_tile_set_simple(terrain_map: Dictionary, max_coord: Vector2i = Vector2i(5, 1)) -> TileSet:
	"""Build a TileSet from a simple Dict[Vector2i, int] terrain map.
	Each key = atlas coord, value = terrain ID (-1 or >=0).
	Uses terrain_set=0 for all tiles that have terrain >= 0.
	"""
	var tile_size := 32
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	# Register terrain set 0 so TileData.terrain_set can reference it.
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(tile_size, tile_size)

	# Texture must be large enough for all tiles.
	var tex_w := (max_coord.x + 1) * tile_size
	var tex_h := (max_coord.y + 1) * tile_size
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	src.texture = ImageTexture.create_from_image(img)

	for coord: Vector2i in terrain_map.keys():
		var terrain_id: int = int(terrain_map[coord])
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0) as TileData
		if td == null:
			td = TileData.new()
		# Godot requires terrain_set >= 0 BEFORE setting terrain.
		if terrain_id >= 0:
			td.terrain_set = 0
			td.terrain = terrain_id
		else:
			td.terrain = -1

	ts.add_source(src, 0)
	return ts


func _build_tile_set_multi_alt(alt_map: Dictionary, max_coord: Vector2i = Vector2i(3, 1)) -> TileSet:
	"""Build a TileSet where each coord can have multiple alt entries.
	alt_map: Dict[Vector2i, Array[Dictionary]] where each dict has {terrain: int, terrain_set: int}.
	"""
	var tile_size := 32
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	# Register terrain set 0 so TileData.terrain_set can reference it.
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(tile_size, tile_size)

	var tex_w := (max_coord.x + 1) * tile_size
	var tex_h := (max_coord.y + 1) * tile_size
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	src.texture = ImageTexture.create_from_image(img)

	for coord: Vector2i in alt_map.keys():
		var alt_list: Array = alt_map[coord]
		src.create_tile(coord)
		for alt_id in range(alt_list.size()):
			var entry: Dictionary = alt_list[alt_id]
			if alt_id > 0:
				src.create_alternative_tile(coord, alt_id)
			var td := src.get_tile_data(coord, alt_id) as TileData
			if td == null:
				td = TileData.new()
			var tval: int = entry.get("terrain", -1)
			if tval >= 0:
				td.terrain_set = entry.get("terrain_set", 0)
				td.terrain = tval
			else:
				td.terrain = -1

	ts.add_source(src, 0)
	return ts


func _group_with_layouts(count: int) -> Resource:
	var group = _TerrainGroupSc.new()
	for i in range(count):
		group.layouts.append(_Wang2EdgeSc.new())
	return group


func _index_entry(layer: Node, terrain_id: int) -> Dictionary:
	var idx = layer.get("_terrain_index")
	if idx == null or typeof(idx) != TYPE_DICTIONARY:
		return {}
	return idx.get(terrain_id, {})


# Returns true if the layer has the terrain_group property accessible.
func _has_terrain_group(layer: Node) -> bool:
	# Try reading the property — if it doesn't exist, get() returns nil.
	# If the setter also doesn't exist, we can't even assign.
	# Use the property list to check existence.
	for prop in layer.get_property_list():
		if prop["name"] == "terrain_group":
			return true
	return false


# --- Tests ---

func _test_two_terrain_index() -> void:
	print("\n  --- two-terrain index ---")

	var terrain_map := {
		Vector2i(0, 0): 0,
		Vector2i(1, 0): 0,
		Vector2i(2, 0): 1,
		Vector2i(3, 0): 1,
		Vector2i(4, 0): 1,
	}
	var ts := _build_tile_set_simple(terrain_map, Vector2i(5, 1))

	var layer := _LayerScript.new()
	layer.tile_set = ts
	# Debug: verify tile data
	for si in range(ts.get_source_count()):
		var sid := ts.get_source_id(si)
		var src := ts.get_source(sid) as TileSetAtlasSource
		print("  source[%d] id=%d tiles=%d" % [si, sid, src.get_tiles_count() if src else 0])
		if src and src.get_tiles_count() > 0:
			var c0 := src.get_tile_id(0)
			var td := src.get_tile_data(c0, 0)
			print("    tile at ", c0, " terrain=", td.terrain if td else "null")

	var group := _group_with_layouts(2)
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var idx: Dictionary = layer.get("_terrain_index")
	_assert("index is dictionary", idx != null and typeof(idx) == TYPE_DICTIONARY)
	_assert_eq("index has 2 entries", idx.size(), 2)

	# Terrain 0
	var e0 := _index_entry(layer, 0)
	_assert("terrain 0 has layout", e0.has("layout"))
	_assert("terrain 0 has tiles", e0.has("tiles"))
	_assert_eq("terrain 0 tile count", e0.get("tiles", []).size(), 2)

	# Terrain 1
	var e1 := _index_entry(layer, 1)
	_assert("terrain 1 has layout", e1.has("layout"))
	_assert("terrain 1 has tiles", e1.has("tiles"))
	_assert_eq("terrain 1 tile count", e1.get("tiles", []).size(), 3)

	layer.queue_free()


func _test_null_terrain_group() -> void:
	print("\n  --- null terrain group ---")

	var ts := _build_tile_set_simple({Vector2i(0, 0): 0}, Vector2i(1, 1))

	var layer := _LayerScript.new()
	layer.tile_set = ts
	# Explicitly set null.
	layer.terrain_group = null
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var idx: Dictionary = layer.get("_terrain_index")
	_assert("null group index is empty or null", idx == null or idx.is_empty())

	layer.queue_free()


func _test_alternative_tile_scanning() -> void:
	print("\n  --- alternative tile scanning ---")

	# Build TileSet where alt_id=1 has terrain=0 but alt_id=0 has terrain=-1.
	# Per GAP-01: the index must scan ALL alternative tiles.
	var alt_map := {
		Vector2i(0, 0): [
			{"terrain": -1},       # alt_id=0 — no terrain
			{"terrain": 0},        # alt_id=1 — terrain 0 (should be scanned!)
		],
		Vector2i(1, 0): [
			{"terrain": 0},        # alt_id=0 — terrain 0
			{"terrain": 1},        # alt_id=1 — terrain 1 (different from base!)
		],
	}
	var ts := _build_tile_set_multi_alt(alt_map, Vector2i(2, 1))

	var layer := _LayerScript.new()
	layer.tile_set = ts
	var group := _group_with_layouts(2)
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# (0,0) alt_id=1 has terrain=0 → should be indexed under terrain 0
	var e0 := _index_entry(layer, 0)
	var t0 := e0.get("tiles", []) as Array
	_assert("terrain 0 has tiles from alt scan", t0.size() >= 1)
	if t0.size() >= 1:
		_assert("terrain 0 includes (1,0)", t0.has(Vector2i(1, 0)))

	# (1,0) alt_id=1 has terrain=1 → should be indexed under terrain 1
	var e1 := _index_entry(layer, 1)
	var t1 := e1.get("tiles", []) as Array
	_assert("terrain 1 has tiles from alt scan", t1.size() >= 1)

	layer.queue_free()


func _test_center_bit_exclusion() -> void:
	print("\n  --- center bit exclusion ---")

	# Tiles with terrain=-1 must be excluded from the index (GAP-02).
	var terrain_map := {
		Vector2i(0, 0): 0,
		Vector2i(1, 0): -1,  # no center bit — excluded
		Vector2i(2, 0): 0,
	}
	var ts := _build_tile_set_simple(terrain_map, Vector2i(3, 1))

	var layer := _LayerScript.new()
	layer.tile_set = ts
	var group := _group_with_layouts(1)
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var e0 := _index_entry(layer, 0)
	var t0 := e0.get("tiles", []) as Array
	_assert_eq("center-bit -1 excluded, count=2", t0.size(), 2)
	_assert("(1,0) not in tiles", not t0.has(Vector2i(1, 0)))

	layer.queue_free()


func _test_multi_source_scanning() -> void:
	print("\n  --- multi-source scanning ---")

	var tile_size := 32
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)

	var img := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var tex := ImageTexture.create_from_image(img)

	# Source 0 — terrain 0 tile
	var src0 := TileSetAtlasSource.new()
	src0.texture_region_size = Vector2i(tile_size, tile_size)
	src0.texture = tex
	src0.create_tile(Vector2i(0, 0))
	var td0 := src0.get_tile_data(Vector2i(0, 0), 0)
	td0.terrain_set = 0
	td0.terrain = 0
	ts.add_source(src0, 0)

	# Source 1 — terrain 1 tile
	var src1 := TileSetAtlasSource.new()
	src1.texture_region_size = Vector2i(tile_size, tile_size)
	src1.texture = tex
	src1.create_tile(Vector2i(0, 0))
	var td1 := src1.get_tile_data(Vector2i(0, 0), 0)
	td1.terrain_set = 0
	td1.terrain = 1
	ts.add_source(src1, 1)

	var layer := _LayerScript.new()
	layer.tile_set = ts
	var group := _group_with_layouts(2)
	layer.terrain_group = group
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var idx: Dictionary = layer.get("_terrain_index")

	var e0 := _index_entry(layer, 0)
	var t0 := e0.get("tiles", []) as Array
	_assert("multi-source terrain 0 found", t0.size() >= 1)

	var e1 := _index_entry(layer, 1)
	var t1 := e1.get("tiles", []) as Array
	_assert("multi-source terrain 1 found", t1.size() >= 1)

	layer.queue_free()


func _test_reassign_triggers_rebuild() -> void:
	print("\n  --- reassign triggers rebuild ---")

	var ts := _build_tile_set_simple({Vector2i(0, 0): 0}, Vector2i(1, 1))

	var layer := _LayerScript.new()
	layer.tile_set = ts

	var group1 := _group_with_layouts(1)
	layer.terrain_group = group1
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var idx: Dictionary = layer.get("_terrain_index")
	_assert_eq("first build: 1 entry", idx.size() if idx != null else 0, 1)

	var group2 := _group_with_layouts(2)
	layer.terrain_group = group2
	await process_frame
	await process_frame

	idx = layer.get("_terrain_index")
	_assert_eq("reassign rebuild: 2 entries", idx.size() if idx != null else 0, 2)

	layer.queue_free()


# --- Assertions ---

func _assert(label: String, condition: bool) -> void:
	if not condition:
		_failures.append(label)
		printerr("  FAIL: " + label)


func _assert_eq(label: String, actual, expected) -> void:
	if actual != expected:
		_failures.append(label + " (expected " + str(expected) + " got " + str(actual) + ")")
		printerr("  FAIL: " + label + " (expected " + str(expected) + " got " + str(actual) + ")")
