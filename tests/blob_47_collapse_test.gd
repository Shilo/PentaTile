## Phase 3 D-78: 256→47 collapse-completeness unit test for Blob47Godot.
##
## Enumerates all 256 D-76 8-bit Moore raw masks, applies
## PentaTileLayoutBlob47Godot._collapse_8bit_moore, and asserts every
## result is a key in _MASK_TO_ATLAS. Catches Pitfall A (47-entry dict
## transcription error) — if a key is missing, some raw mask collapses
## to a value the dict doesn't cover.
##
## Also asserts dict size == 47 — catches off-by-one transcription
## (extra or missing entry).
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/blob_47_collapse_test.gd
extends SceneTree

const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== blob_47_collapse_test ===")

	var dict: Dictionary = _Blob47GodotSc._MASK_TO_ATLAS

	# Size check — exactly 47 entries, no off-by-one.
	if dict.size() != 47:
		_failures.append("_MASK_TO_ATLAS has %d entries; expected exactly 47" % dict.size())

	# Coverage check — every collapsed raw mask is in the dict.
	var raw := 0
	while raw < 256:
		var collapsed: int = _Blob47GodotSc._collapse_8bit_moore(raw)
		if not dict.has(collapsed):
			_failures.append("raw mask %d → collapsed %d not in _MASK_TO_ATLAS" % [raw, collapsed])
		raw += 1

	# Idempotence spot-check: collapse(collapse(x)) == collapse(x) for a few values.
	for spot in [0, 17, 51, 119, 255]:
		var first: int = _Blob47GodotSc._collapse_8bit_moore(spot)
		var second: int = _Blob47GodotSc._collapse_8bit_moore(first)
		if first != second:
			_failures.append("idempotence: collapse(collapse(%d))=%d != collapse(%d)=%d" % [spot, second, spot, first])

	# mask=0 specific: must dispatch to (0, 0) per D-80 (lonely-tile slot).
	var slot0: PentaTileAtlasSlot = _Blob47GodotSc.new().mask_to_atlas(0)
	if slot0 == null:
		_failures.append("mask_to_atlas(0) returned null — Pitfall #9 violation, single-grid mask=0 must dispatch")
	elif slot0.atlas_coords != Vector2i(0, 0):
		_failures.append("mask_to_atlas(0).atlas_coords=%s; expected Vector2i(0, 0) per D-80 lonely-tile dispatch" % slot0.atlas_coords)
	elif slot0.transform_flags != 0:
		_failures.append("mask_to_atlas(0).transform_flags=%d; expected 0 — D-77 forbids rotation reuse for blob layouts" % slot0.transform_flags)

	# mask=255 specific: must dispatch to the LAST entry of the sorted 47-mask
	# list (index 46). With the row-major 7×7 packing that's (4, 6).
	var slot_full: PentaTileAtlasSlot = _Blob47GodotSc.new().mask_to_atlas(255)
	if slot_full == null:
		_failures.append("mask_to_atlas(255) returned null")
	elif slot_full.atlas_coords != Vector2i(4, 6):
		_failures.append("mask_to_atlas(255).atlas_coords=%s; expected Vector2i(4, 6) per documented 7×7 row-major packing" % slot_full.atlas_coords)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f: String in _failures:
			printerr("  - " + f)
		quit(1)
