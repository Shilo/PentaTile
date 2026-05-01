@tool
## Spike 009: Auto-detected terrain count from atlas dimensions.
##
## Uses programmatic Image textures (no file dependency) to validate:
##   1. Atlas grid → terrain count
##   2. Godot native terrain set names/colors
##   3. TileData.terrain = atlas_coords.y
##   4. Resolve terrain_id from painted cell
##   5. Name/color survives auto-rebuild (snapshot-old-names pattern)
##   6. Multiple atlas sources stack terrain IDs

extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("=== Spike 009: Auto Terrain Detection ===\n")
	await test_01_compute_terrain_count()
	await test_02_terrain_set_names_colors()
	await test_03_tiledata_terrain_equals_row()
	await test_04_resolve_from_cell()
	await test_05_persistence()
	await test_06_multi_atlas()

	if _failures.is_empty():
		print("\n=== ALL 6 TESTS PASSED ===")
	else:
		print("\n=== %d TEST(S) FAILED ===" % _failures.size())
		for f in _failures:
			print("  FAIL: ", f)
	quit(_failures.size())


# --- Helpers ---

func make_prog_image(w: int, h: int) -> Image:
	## Creates a small solid 1x1 RGBA image for atlas texture.
	## Godot TileSetAtlasSource just needs ANY texture to anchor the tile grid.
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return img


func make_atlas_tileset(cols: int, rows: int, tile_w: int, tile_h: int) -> TileSet:
	var img := make_prog_image(cols * tile_w, rows * tile_h)
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_w, tile_h)
	for y in range(rows):
		for x in range(cols):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ts.tile_size = Vector2i(tile_w, tile_h)
	return ts


func compute_terrain_count(tile_set: TileSet) -> Array:
	var result: Array = []
	var next_id: int = 0
	for src_idx in range(tile_set.get_source_count()):
		var sid: int = tile_set.get_source_id(src_idx)
		var src := tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var rows: int = src.get_atlas_grid_size().y
		if rows <= 0:
			continue
		result.append({"source_id": sid, "first_terrain_id": next_id, "row_count": rows})
		next_id += rows
	return result


func auto_setup_terrains(tile_set: TileSet) -> void:
	## Full auto-detection: terrain set 0, MATCH_CORNERS, per-tile terrain=row.
	## Idempotent — preserves user-set names/colors via snapshot-before-clear pattern.

	var infos := compute_terrain_count(tile_set)
	var total: int = 0
	for info in infos:
		total += int(info.row_count)
	if total == 0:
		return

	# Snapshot old names/colors BEFORE clearing (persistence)
	var old_names: Dictionary = {}
	var old_colors: Dictionary = {}
	if tile_set.get_terrain_sets_count() > 0:
		for i in tile_set.get_terrains_count(0):
			old_names[i] = tile_set.get_terrain_name(0, i)
			old_colors[i] = tile_set.get_terrain_color(0, i)

	# Clear + recreate terrain set 0
	while tile_set.get_terrain_sets_count() > 0:
		tile_set.remove_terrain_set(0)

	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)

	for i in range(total):
		tile_set.add_terrain(0)
		var name: String = "Terrain %d" % i
		if old_names.has(i):
			var old := str(old_names[i])
			if not old.begins_with("Terrain "):
				name = old  # preserve user-set name
		tile_set.set_terrain_name(0, i, name)
		if old_colors.has(i):
			tile_set.set_terrain_color(0, i, old_colors[i])
		else:
			tile_set.set_terrain_color(0, i,
				Color.from_hsv(float(hash("tc%d" % i) % 256) / 255.0, 0.7, 0.8))

	# TileData.terrain = atlas_coords.y
	for info in infos:
		var sid: int = int(info.source_id)
		var src := tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var first: int = int(info.first_terrain_id)
		var rows: int = int(info.row_count)
		for row in range(rows):
			var tid: int = first + row
			for col in range(src.get_atlas_grid_size().x):
				var coord := Vector2i(col, row)
				if src.has_tile(coord):
					for alt in range(src.get_alternative_tiles_count(coord)):
						var td := src.get_tile_data(coord, alt)
						if td:
							td.terrain_set = 0
							td.terrain = tid

	print("  Auto-detected: %d terrain(s) across %d source(s)" % [total, infos.size()])


# --- Tests ---

func test_01_compute_terrain_count() -> void:
	print("Test 01: Atlas grid → terrain count")
	var ts := make_atlas_tileset(5, 3, 32, 32)
	var infos := compute_terrain_count(ts)
	if infos.size() != 1 or int(infos[0].row_count) != 3 or int(infos[0].first_terrain_id) != 0:
		_failures.append("01")
		print("  FAIL")
		return
	print("  PASS: 5x3 atlas → 3 terrain rows")


func test_02_terrain_set_names_colors() -> void:
	print("Test 02: Terrain set names/colors on TileSet")
	var ts := make_atlas_tileset(5, 3, 32, 32)
	auto_setup_terrains(ts)

	if ts.get_terrain_sets_count() != 1 or ts.get_terrains_count(0) != 3:
		_failures.append("02-count")
		print("  FAIL")
		return

	for i in range(3):
		if not ts.get_terrain_name(0, i).begins_with("Terrain "):
			_failures.append("02-name%d" % i)
			print("  FAIL")
			return

	if ts.get_terrain_set_mode(0) != TileSet.TERRAIN_MODE_MATCH_CORNERS:
		_failures.append("02-mode")
		print("  FAIL")
		return

	print("  PASS: 3 terrains, MATCH_CORNERS, auto-names/colors set")


func test_03_tiledata_terrain_equals_row() -> void:
	print("Test 03: TileData.terrain = atlas_coords.y")
	var ts := make_atlas_tileset(5, 3, 32, 32)
	auto_setup_terrains(ts)

	var src := ts.get_source(0) as TileSetAtlasSource
	for row in range(3):
		for col in range(5):
			var td := src.get_tile_data(Vector2i(col, row), 0)
			if td == null or td.terrain_set != 0 or td.terrain != row:
				_failures.append("03-%d,%d" % [col, row])
				print("  FAIL")
				return
	print("  PASS: 15 tiles terrain=row (0/1/2), terrain_set=0")


func test_04_resolve_from_cell() -> void:
	print("Test 04: Resolve terrain_id from painted cell")
	var ts := make_atlas_tileset(5, 3, 32, 32)
	auto_setup_terrains(ts)

	var root := get_root()
	var layer := TileMapLayer.new()
	root.add_child(layer)
	layer.tile_set = ts
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(2, 1))  # col=2, row=1 → terrain=1

	var src := ts.get_source(0) as TileSetAtlasSource
	var ac := layer.get_cell_atlas_coords(Vector2i(0, 0))
	var td := src.get_tile_data(ac, 0)
	var tid: int = td.terrain if td else -1

	layer.queue_free()

	if tid != 1:
		_failures.append("04-got-%d" % tid)
		print("  FAIL")
		return
	print("  PASS: Painted (2,1) → terrain_id=1")


func test_05_persistence() -> void:
	print("Test 05: Name/color survives auto-rebuild")
	var ts := make_atlas_tileset(5, 3, 32, 32)
	auto_setup_terrains(ts)

	# User customizes
	ts.set_terrain_name(0, 0, "Floor")
	ts.set_terrain_color(0, 0, Color.GREEN)

	# Re-run auto_setup (simulates tileset rebuild)
	auto_setup_terrains(ts)

	if ts.get_terrain_name(0, 0) != "Floor":
		_failures.append("05-name")
		print("  FAIL: name not preserved")
		return
	if ts.get_terrain_color(0, 0) != Color.GREEN:
		_failures.append("05-color")
		print("  FAIL: color not preserved")
		return
	if not ts.get_terrain_name(0, 1).begins_with("Terrain "):
		_failures.append("05-auto-name")
		print("  FAIL: auto-name overwritten")
		return

	print("  PASS: 'Floor' + GREEN survive; 'Terrain 1/2' stay auto-named")


func test_06_multi_atlas() -> void:
	print("Test 06: Multiple atlas sources stack terrain IDs")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)

	# Source 0: 1 row (32×32 tile)
	var tex := ImageTexture.create_from_image(make_prog_image(160, 32))
	var src0 := TileSetAtlasSource.new()
	src0.texture = tex
	src0.texture_region_size = Vector2i(32, 32)
	src0.create_tile(Vector2i(0, 0))
	src0.create_tile(Vector2i(1, 0))
	ts.add_source(src0, 0)

	# Source 1: 2 rows (32×64 texture)
	var tex2 := ImageTexture.create_from_image(make_prog_image(160, 64))
	var src1 := TileSetAtlasSource.new()
	src1.texture = tex2
	src1.texture_region_size = Vector2i(32, 32)
	src1.create_tile(Vector2i(0, 0))
	src1.create_tile(Vector2i(1, 0))
	src1.create_tile(Vector2i(0, 1))
	ts.add_source(src1, 1)

	auto_setup_terrains(ts)

	# Source 0: 1 row → terrain 0
	# Source 1: 2 rows → terrains 1, 2
	# Total: 3 terrains
	if ts.get_terrains_count(0) != 3:
		_failures.append("06-total=%d" % ts.get_terrains_count(0))
		print("  FAIL")
		return

	var infos := compute_terrain_count(ts)
	if int(infos[0].row_count) != 1 or int(infos[0].first_terrain_id) != 0:
		_failures.append("06-src0")
		print("  FAIL")
		return
	if int(infos[1].row_count) != 2 or int(infos[1].first_terrain_id) != 1:
		_failures.append("06-src1")
		print("  FAIL")
		return

	# Check TileData terrain assignments
	var src_a := ts.get_source(0) as TileSetAtlasSource
	var src_b := ts.get_source(1) as TileSetAtlasSource
	if src_a.get_tile_data(Vector2i(0, 0), 0).terrain != 0:
		_failures.append("06-src0-terrain")
		print("  FAIL")
		return
	if src_b.get_tile_data(Vector2i(0, 1), 0).terrain != 2:
		_failures.append("06-src1-terrain")
		print("  FAIL")
		return

	print("  PASS: src0 (1 row→id0) + src1 (2 rows→ids 1-2) = 3 terrains")
