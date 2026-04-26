# Phase 1 — Pattern Map

**Date:** 2026-04-25
**Status:** PATTERN MAPPING COMPLETE
**Files mapped:** 6 .gd (1 modified + 5 new) + 4 .tres (all new)
**Analogs found:** 10 / 10 (in-repo for layer + .tres; out-of-repo Godot-stock idioms for Resource subclasses since the project has zero existing Resource subclass scripts)

---

## Context Caveat (Read First)

The project codebase contains exactly **three `.gd` files** (per `Glob("**/*.gd")`):

1. `addons/tetra_tile/tetra_tile_map_layer.gd` — `extends TileMapLayer` (the v0.1 core)
2. `addons/tetra_tile/demo/demo_player.gd` — `extends CharacterBody2D`
3. `addons/tetra_tile/demo/demo_runtime_painter.gd` — `extends Node2D`

**There are zero in-repo `.gd` files that `extends Resource`.** All four new Resource subclasses (`TetraTileAtlasContract`, `TetraTileAtlasSlot`, `TetraTileLayout`, plus the two layout subclasses) are first-of-kind in this codebase. Their patterns are therefore extracted from:

- `tetra_tile_map_layer.gd` for **export setter discipline + idempotence + `_queue_rebuild` deferred coalescing + class registration shape** (transferable patterns).
- The `.gd` files' top-of-file shape (`@tool` / `@icon` / `class_name` / `extends`) as the convention to copy verbatim.
- `addons/tetra_tile/demo/tetra_tile_ground.tres` as the **only existing `.tres`** in the repo — the format spec for the four new bundled `.tres` resources.
- `PITFALLS.md §3, §5` recipes for setter/Resource.changed patterns that no in-repo file demonstrates (yet).

Where no in-repo analog exists, this document still excerpts the canonical Godot 4.6 idiom and ties it to a real file for the surrounding shell (header, naming, indentation).

---

## File-to-Analog Map

| New / modified file | Closest analog | Lines to study | Match quality | Key pattern |
|---------------------|----------------|----------------|---------------|-------------|
| `addons/tetra_tile/tetra_tile_atlas_contract.gd` (NEW, ~50 LOC) | `addons/tetra_tile/tetra_tile_map_layer.gd` | 1-4 (header), 26-29 (export setter), 31-34 (export setter), 258-260 (`_queue_rebuild`) + PITFALLS.md §5 (Resource.changed disconnect-before-reconnect, no in-repo analog) | role-mismatch (Node→Resource) but pattern-match for setter+coalescer | `extends Resource` + `class_name TetraTileAtlasContract`; idempotence-guarded setter on `layout`; `disconnect → assign → connect` on `Resource.changed`; emit `changed` from sub-Resource so the layer's `_on_contract_changed` fires |
| `addons/tetra_tile/tetra_tile_atlas_slot.gd` (NEW, ~30 LOC) | `addons/tetra_tile/tetra_tile_map_layer.gd` | 1-4 (header), 21-24 (typed `Vector2i` constants — same type as `atlas_coords`) | role-mismatch but type-shape match | `extends Resource` + `class_name TetraTileAtlasSlot`; 4 typed `@export` fields with defaults; no setters (passive data record) |
| `addons/tetra_tile/tetra_tile_layout.gd` (NEW base, ~50 LOC) | `addons/tetra_tile/tetra_tile_map_layer.gd` | 1-4 (header), 26-29 (typed export with default), 17-19 (bit-packed const pattern as inspiration for `_pack_alternative` helper) | role-mismatch, transferable pattern | `extends Resource` + `class_name TetraTileLayout`; `## doc-comment` head; 3 virtual methods that `push_error` on base; `_pack_alternative(alt, flags)` helper with `assert(alt < 4096)` per PITFALLS.md §3 |
| `addons/tetra_tile/tetra_tile_layout_tetra_horizontal.gd` (NEW, ~80 LOC) | `addons/tetra_tile/tetra_tile_map_layer.gd` | 11-19 (4-tile + rotation constants), 108-152 (the 16-state match block — RELOCATED VERBATIM into `mask_to_atlas`), 155-165 (`_mask_at` body — RELOCATED into `compute_mask`) | exact (this file IS the source of the relocated logic) | Subclass `TetraTileLayout`; `is_dual_grid() => true`; `compute_mask` is `_mask_at` adapted to `sample_fn: Callable`; `mask_to_atlas` is the 16-state match returning `AtlasSlot` instances |
| `addons/tetra_tile/tetra_tile_layout_tetra_vertical.gd` (NEW, ~30 LOC) | `addons/tetra_tile/tetra_tile_layout_tetra_horizontal.gd` (sibling) + v0.1 layer line 182-185 (`_atlas_coords` axis dispatch) | 182-185 of v0.1 layer | exact (axis-flip extension of horizontal) | Subclass `TetraTileLayoutTetraHorizontal` OR `TetraTileLayout`; override `mask_to_atlas` to swap `Vector2i(x,0)` → `Vector2i(0,x)`; reuse parent `compute_mask`/`is_dual_grid` |
| `addons/tetra_tile/tetra_tile_map_layer.gd` (MODIFIED v0.1 261 LOC → ~290 LOC) | itself (v0.1) | 1-4, 26-54 (existing setters), 67-83 (`_update_cells`), 108-152 (REMOVE), 155-165 (RELOCATE), 182-185 (REMOVE), 198-214 (PRESERVE), 217-233 (PRESERVE), 258-260 (PRESERVE) | exact (this is the file being modified) | Hard-remove `AtlasLayout` enum + `atlas_layout` export + `_atlas_coords`; ADD `@export var atlas_contract: TetraTileAtlasContract` with locked PITFALLS §5 setter; ADD `_resolve_layout()` with lazy singleton fallback; ADD dual-grid + single-grid pipeline branch; ADD `_paint_with_slot(layer, slot, cell)` helper |
| `addons/tetra_tile/contracts/default_horizontal.tres` (NEW) | `addons/tetra_tile/demo/tetra_tile_ground.tres` | 1-19 (full file) | role-match (Resource serialization shape) | `[gd_resource type="Resource" script_class="TetraTileAtlasContract" format=3]` with `[ext_resource]` for layout `.tres` and `[resource]` block setting `layout = ExtResource(...)`, `version = 1`, `variation_seed = 0` |
| `addons/tetra_tile/contracts/default_vertical.tres` (NEW) | same as above | same | same | same shape, references `tetra_vertical_default.tres` |
| `addons/tetra_tile/contracts/tetra_horizontal_default.tres` (NEW) | `addons/tetra_tile/demo/tetra_tile_ground.tres` | 1-19 | role-match | `[gd_resource type="Resource" script_class="TetraTileLayoutTetraHorizontal" format=3]` with `[ext_resource type="Texture2D"]` for `templates/tetra_horizontal.png` and `[resource] template_image = ExtResource(...)`, `description = "..."` |
| `addons/tetra_tile/contracts/tetra_vertical_default.tres` (NEW) | same as above | same | same | same shape, references `templates/tetra_vertical.png` |

---

## Code Excerpts (verbatim)

### File 1: `tetra_tile_atlas_contract.gd` → analog: `tetra_tile_map_layer.gd`

**Excerpt A: Class header + class_name registration shape (file 1-4)**
```gdscript
@tool
@icon("res://icon.svg")
class_name TetraTileMapLayer
extends TileMapLayer
```
**Why this analog:** The only `.gd` file in the addon proper. Its 4-line header is the project's convention for top-level class scripts. The new `TetraTileAtlasContract` should match the shape but `extends Resource` instead.

**What the new file MUST replicate:**
- `@tool` annotation (Resources used by `@tool` nodes need `@tool` themselves so the editor can mutate them safely — confirmed by Godot 4.6 docs and load-bearing for `update_configuration_warnings()` and live-editor preview).
- `class_name TetraTileAtlasContract` — registers it in the typed-picker so `@export var atlas_contract: TetraTileAtlasContract` filters correctly (REQ CONTRACT-01).
- `extends Resource` (NOT `TileMapLayer`).
- LF line endings + UTF-8 (per `.editorconfig` / `.gitattributes`, CONVENTIONS.md §Formatting).

**What it must NOT do:**
- Add `@icon("res://icon.svg")` — that line attaches the project icon to *node* classes that appear in the scene-tree Add menu. Resources don't appear there. Either omit `@icon` or supply a Resource-distinguishing icon.

**Excerpt B: Export setter + idempotence + `_queue_rebuild` shape (lines 26-34, 258-260)**
```gdscript
@export var atlas_source_id: int = -1:
	set(value):
		atlas_source_id = value
		_queue_rebuild()

@export var atlas_layout: AtlasLayout = AtlasLayout.HORIZONTAL:
	set(value):
		atlas_layout = value
		_queue_rebuild()
```
```gdscript
func _queue_rebuild() -> void:
	if is_inside_tree():
		rebuild.call_deferred()
```
**Why this analog:** This is the project's established setter convention (CONVENTIONS.md §Setter Patterns explicitly cites this code). The new contract `layout` setter must extend this pattern with the **idempotence guard + `Resource.changed` disconnect/reconnect** required by PITFALLS.md §5 (no in-repo demonstration exists yet — Phase 1 introduces it).

**What the new file MUST replicate:**
- The general shape of `@export var <name>: <Type>: set(value): ...; <action>`.
- Calling a deferred coalescer (the contract's own `changed.emit()` will reach the layer via `_on_contract_changed` which calls `_queue_rebuild`).
- Adding the **two NEW guards** that the v0.1 layer setters DON'T have: idempotence (`if value == layout: return`) and disconnect-before-reconnect on `layout.changed` if it's a sub-Resource. Per PITFALLS.md §5 and CONTEXT.md D-08, the pattern is:
  ```gdscript
  @export var layout: TetraTileLayout:
  	set(value):
  		if layout == value: return                                        # idempotence (D-08, PITFALLS §5)
  		if layout != null and layout.changed.is_connected(_on_layout_changed):
  			layout.changed.disconnect(_on_layout_changed)
  		layout = value
  		if layout != null:
  			layout.changed.connect(_on_layout_changed)
  		emit_changed()                                                    # propagates up to the layer's _on_contract_changed
  ```

**What it must NOT do:**
- Direct `rebuild.call_deferred()` — Resources don't have a `rebuild()` method. They emit `changed`; the layer listens.
- Skip the `is_connected()` guard before `disconnect()` — Godot 4.6 will `push_error` on disconnect of unconnected signal.
- Re-emit `changed` inside `_on_layout_changed` (signal storm — PITFALLS §4).

---

### File 2: `tetra_tile_atlas_slot.gd` → analog: `tetra_tile_map_layer.gd`

**Excerpt A: Typed Vector2i constant shape (lines 21-24)**
```gdscript
const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)
```
**Why this analog:** Same `Vector2i` typing the new `atlas_coords` field uses. Demonstrates the project's typed-literal style (`Vector2i(x, y)` with explicit args, no `.ZERO`/`.ONE` for positions).

**What the new file MUST replicate:**
```gdscript
@tool
class_name TetraTileAtlasSlot
extends Resource

@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var transform_flags: int = 0
@export var alternative_tile: int = 0
@export var diagonal_complement_atlas_coords: Vector2i = Vector2i(-1, -1)  # sentinel: "no overlay"
```

- Four typed `@export` fields with default values.
- `Vector2i` for grid coordinates, `int` for bit-packed flags / alt-tile-id.
- **No setters** — slots are passive data records consumed by `_paint_with_slot`. The layout's `mask_to_atlas` constructs new `AtlasSlot` instances each call; mutation of an existing instance is not a Phase 1 use case.
- LAYOUT-04 specifies these four fields exactly; do not add extras.

**What it must NOT do:**
- Connect to any signal.
- Use `Vector2i.ZERO` for `diagonal_complement_atlas_coords` because `Vector2i.ZERO` is a valid atlas slot — use `Vector2i(-1, -1)` as the "no overlay" sentinel (consistent with v0.1's `atlas_source_id: int = -1` "unset" sentinel at layer line 26).
- Add a `_pack_alternative` method here — that helper lives on `TetraTileLayout` base (LAYOUT-05).

---

### File 3: `tetra_tile_layout.gd` (base) → analog: `tetra_tile_map_layer.gd`

**Excerpt A: Class header + bit-packed const pattern as `_pack_alternative` inspiration (lines 16-19)**
```gdscript
const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
```
**Why this analog:** This is where the project demonstrates that Godot's `TRANSFORM_*` flags are stored as `int` constants and OR'd together. The new `_pack_alternative(alt, flags)` helper packs the same `int` channel — but adds the alt-tile low bits + the `assert(alt < 4096)` guard required by PITFALLS.md §3 (the `alternative_tile` field and `TRANSFORM_FLIP_*` flags share one int, and bit collision causes wrong tiles or no draws).

**What the new file MUST replicate:**

```gdscript
## Abstract base for all TetraTile layout topologies.
## Subclasses implement compute_mask + mask_to_atlas + is_dual_grid.
@tool
class_name TetraTileLayout
extends Resource

@export var template_image: Texture2D                                  # PREVIEW-01: stock inspector preview
@export var fallback_tile_set: TileSet                                 # LAYOUT-03: declared, consumed in Phase 4
@export_multiline var description: String = ""                          # D-22: multiline export
@export var decoder_image: Texture2D                                   # optional override (D-specifics §1)


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	push_error("TetraTileLayout.compute_mask is abstract; subclass must override.")
	return 0


func mask_to_atlas(mask: int) -> TetraTileAtlasSlot:
	push_error("TetraTileLayout.mask_to_atlas is abstract; subclass must override.")
	return null


func is_dual_grid() -> bool:
	push_error("TetraTileLayout.is_dual_grid is abstract; subclass must override.")
	return true


# PITFALLS.md §3 + LAYOUT-05: alt-id and TRANSFORM_FLIP_* flags share one int.
# `alternative_tile` low bits go below 4096; transform flags are >= 4096.
# Always OR via this helper; assert prevents silent collision.
func _pack_alternative(alt_id: int, transform_flags: int) -> int:
	assert(alt_id < 4096, "alternative_tile alt_id must be < 4096; flags share the int")
	return alt_id | transform_flags
```

**What it must NOT do:**
- Implement `compute_mask` / `mask_to_atlas` / `is_dual_grid` with real bodies — they're virtuals (D-02, LAYOUT-01/02). `push_error` makes accidental base-class instantiation surface a loud editor error rather than a silent "no tiles painted" mystery.
- Use `@export_range` on `description` — it's a multiline string, use `@export_multiline`.
- Connect to any signal in `_init`. Resources should only emit `changed` (and only when their own properties mutate); the **subclass setter override** is the right place to call `emit_changed()`.
- Type `mask_to_atlas` return as `Variant` or untyped — strict typing is required so the typed picker / IDE completion works (CONTEXT.md `<code_context>` integration points §1).

---

### File 4: `tetra_tile_layout_tetra_horizontal.gd` → analog: v0.1 `tetra_tile_map_layer.gd`

**Excerpt A: The 16-state match block to RELOCATE VERBATIM (lines 108-152)**
```gdscript
func _paint_display_cell(display_cell: Vector2i) -> void:
	_primary_layer.erase_cell(display_cell)
	_overlay_layer.erase_cell(display_cell)

	var source := _resolve_source_id()
	if source == -1:
		return

	match _mask_at(display_cell):
		0:
			return
		1:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_90)
		2:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_180)
		3:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_180)
		4:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_0)
		5:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_90)
		6:
			# Diagonal masks are two disconnected quadrants, so compose them with the overlay layer.
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_180)
			_set_visual_cell(_overlay_layer, display_cell, source, _OUTER_CORNER, _ROTATE_0)
		7:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_90)
		8:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_270)
		9:
			# Diagonal masks are two disconnected quadrants, so compose them with the overlay layer.
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_90)
			_set_visual_cell(_overlay_layer, display_cell, source, _OUTER_CORNER, _ROTATE_270)
		10:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_270)
		11:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_180)
		12:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_0)
		13:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_0)
		14:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_270)
		15:
			_set_visual_cell(_primary_layer, display_cell, source, _FILL, _ROTATE_0)
```

**Why this analog:** This IS the source code Phase 1 relocates. Bit-identity to v0.1 (TETRA-01) is verified by ensuring the new `mask_to_atlas` returns slots that the layer's `_paint_with_slot` translates back into the same `(source, atlas_coords, transform_flags)` triples as `_set_visual_cell` produces today.

**Excerpt B: The constants the new layout needs (lines 11-14, 16-19)**
```gdscript
const _FILL := 0
const _INNER_CORNER := 1
const _BORDER := 2
const _OUTER_CORNER := 3

const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
```

**Excerpt C: `_mask_at` body to adapt into `compute_mask(coord, sample_fn: Callable)` (lines 21-24, 155-165, 168-169)**
```gdscript
const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)
```
```gdscript
func _mask_at(display_cell: Vector2i) -> int:
	var mask := 0
	if _has_logic_cell(display_cell + _TL):
		mask |= 1
	if _has_logic_cell(display_cell + _TR):
		mask |= 2
	if _has_logic_cell(display_cell + _BL):
		mask |= 4
	if _has_logic_cell(display_cell + _BR):
		mask |= 8
	return mask


func _has_logic_cell(logic_cell: Vector2i) -> bool:
	return get_cell_source_id(logic_cell) != -1
```

**What the new file MUST replicate:**

- Class header: `@tool`, `class_name TetraTileLayoutTetraHorizontal`, `extends TetraTileLayout`.
- The 4 tile-index constants `_FILL/_INNER_CORNER/_BORDER/_OUTER_CORNER` — relocate verbatim.
- The 4 rotation constants `_ROTATE_0..270` — relocate verbatim.
- The 4 corner-offset constants `_TL/_TR/_BL/_BR` — relocate verbatim.
- `is_dual_grid() -> bool: return true`.
- `compute_mask(coord: Vector2i, sample_fn: Callable) -> int` — `_mask_at` body, but instead of `_has_logic_cell(display_cell + _TL)` (which calls the layer's `get_cell_source_id`), use `sample_fn.call(coord + _TL)`. The dispatcher in the layer constructs `sample_fn` as `Callable(self, "_has_logic_cell")` (or equivalent lambda) so the layout doesn't need a back-reference to the layer.
- `mask_to_atlas(mask: int) -> TetraTileAtlasSlot` — the 16-state match relocated, but each `_set_visual_cell(layer, ..., source, tile_index, transform)` call becomes `return _make_slot(tile_index, transform)`. Masks 6 and 9 set `diagonal_complement_atlas_coords` to the secondary tile + use `_pack_alternative` if alt bits are needed (v0.1 doesn't use alternatives, so passes 0).
- `_make_slot` (private helper) constructs a fresh `TetraTileAtlasSlot` per call. Approximate shape:
  ```gdscript
  func _make_slot(tile_index: int, transform_flags: int, complement_tile_index: int = -1, complement_transform: int = 0) -> TetraTileAtlasSlot:
      var s := TetraTileAtlasSlot.new()
      s.atlas_coords = Vector2i(tile_index, 0)        # horizontal: x-axis layout
      s.transform_flags = transform_flags
      if complement_tile_index >= 0:
          s.diagonal_complement_atlas_coords = Vector2i(complement_tile_index, 0)
      return s
  ```

**What it must NOT do:**
- Sample logic cells directly via `get_cell_source_id` — that creates a tight coupling to `TileMapLayer` that breaks the layout's reusability across single-grid pipelines (CONTEXT.md `<domain>` "load-bearing slice"). Use the `sample_fn: Callable` parameter.
- Inline the 16-state match into `compute_mask` — the LAYOUT-02 contract says `mask_to_atlas(mask: int) -> AtlasSlot`, the match goes there.
- Allocate a new `TetraTileAtlasSlot` for masks the dispatcher will then erase (mask 0). Return `null` or a sentinel "erase" slot; the dispatcher's `if slot == null or mask == 0: erase` handles it (D-14 dual-grid mask-0 = erase).

---

### File 5: `tetra_tile_layout_tetra_vertical.gd` → analog: file 4 + v0.1 axis dispatch

**Excerpt: v0.1 axis dispatch (lines 182-185)**
```gdscript
func _atlas_coords(tile_index: int) -> Vector2i:
	if atlas_layout == AtlasLayout.VERTICAL:
		return Vector2i(0, tile_index)
	return Vector2i(tile_index, 0)
```
**Why this analog:** The vertical layout differs from horizontal in EXACTLY this axis swap. The 16-state match is identical; only the `atlas_coords` axis flips. The cleanest implementation is:

```gdscript
@tool
class_name TetraTileLayoutTetraVertical
extends TetraTileLayoutTetraHorizontal

# Override only the slot construction axis. Everything else (compute_mask, the 16-state
# match, transform flags) is inherited from TetraTileLayoutTetraHorizontal.
func _make_slot(tile_index: int, transform_flags: int, complement_tile_index: int = -1, complement_transform: int = 0) -> TetraTileAtlasSlot:
	var s := TetraTileAtlasSlot.new()
	s.atlas_coords = Vector2i(0, tile_index)            # vertical: y-axis layout
	s.transform_flags = transform_flags
	if complement_tile_index >= 0:
		s.diagonal_complement_atlas_coords = Vector2i(0, complement_tile_index)
	return s
```

**What the new file MUST replicate:**
- Subclass `TetraTileLayoutTetraHorizontal` (inheritance chain rather than parallel implementation — keeps Phase 1 LOC at ~30 instead of duplicating 80, per `<code_context>` LOC budget).
- Override `_make_slot` (the only thing that changes).
- Inherit `compute_mask`, `mask_to_atlas`, `is_dual_grid` from horizontal.

**What it must NOT do:**
- Duplicate the 16-state match — Phase 1 LOC budget is 30 LOC for this file. Inheriting parent's match keeps it at 30.
- Subclass `TetraTileLayout` (the base) instead of `TetraTileLayoutTetraHorizontal` — would force re-implementing the match, blowing the LOC budget and re-introducing the dual-source-of-truth bug v0.1 has between `_mask_at` and the implicit assumption that `_atlas_coords` axis matches.
- Override `is_dual_grid()` — already returns `true` in horizontal parent.

---

### File 6: `tetra_tile_map_layer.gd` (MODIFIED) → analog: itself (v0.1)

**Excerpt A: Removals — `AtlasLayout` enum + `atlas_layout` export + `_atlas_coords` (lines 6, 31-34, 182-185)**
```gdscript
enum AtlasLayout { HORIZONTAL, VERTICAL }
```
```gdscript
@export var atlas_layout: AtlasLayout = AtlasLayout.HORIZONTAL:
	set(value):
		atlas_layout = value
		_queue_rebuild()
```
```gdscript
func _atlas_coords(tile_index: int) -> Vector2i:
	if atlas_layout == AtlasLayout.VERTICAL:
		return Vector2i(0, tile_index)
	return Vector2i(tile_index, 0)
```

**Why this is the analog:** D-19 says hard-remove. These are the three call sites that go away. CHANGELOG entry in Phase 5 documents the breaking change.

**Excerpt B: Preserve unchanged — visual layer plumbing (lines 198-214, 217-233, 236-239, 242-245, 248-251, 254-255, 258-260)**

These functions are NOT modified by Phase 1:

```gdscript
func _ensure_visual_layers() -> void:
	if _primary_layer == null or not is_instance_valid(_primary_layer):
		_primary_layer = _get_or_create_visual_layer(_PRIMARY_LAYER_NAME)
	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		_overlay_layer = _get_or_create_visual_layer(_OVERLAY_LAYER_NAME)
	_sync_visual_layers()


func _get_or_create_visual_layer(layer_name: StringName) -> TileMapLayer:
	var existing := get_node_or_null(NodePath(layer_name))
	if existing is TileMapLayer:
		return existing

	var layer := TileMapLayer.new()
	layer.name = layer_name
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer
```

```gdscript
func _queue_rebuild() -> void:
	if is_inside_tree():
		rebuild.call_deferred()
```

**Why preserve verbatim:** ARCHITECTURE.md and CONCERNS.md both flag these as load-bearing. `_apply_logic_layer_opacity` (lines 248-251) is the v0.1 mitigation for PITFALLS §7 (TileMapLayer.visible cleanup); `_ensure_visual_layers` is the lazy-singleton + `is_instance_valid` guard pattern that CONCERNS.md §"Layer validity checks on every edit" explicitly calls out as fragile-but-correct. Phase 1 must not regress.

**Excerpt C: New ADD — `atlas_contract` setter with the locked PITFALLS.md §5 pattern**

The setter pattern is **NOT demonstrated anywhere in the existing codebase** (v0.1's setters are direct-assign-and-call; Resource.changed signal handling is brand-new in Phase 1). Use this verbatim from RESEARCH.md *Architecture* §1 / CONTEXT.md D-08:

```gdscript
@export var atlas_contract: TetraTileAtlasContract:
	set(value):
		if atlas_contract == value:
			return                                                                  # idempotence guard (D-08, PITFALLS §5)
		if atlas_contract != null and atlas_contract.changed.is_connected(_on_contract_changed):
			atlas_contract.changed.disconnect(_on_contract_changed)
		atlas_contract = value
		if atlas_contract != null:
			atlas_contract.changed.connect(_on_contract_changed)
		_queue_rebuild()


func _on_contract_changed() -> void:
	_queue_rebuild()                                                                # already deferred; coalesces multiple emissions per frame
```

**Excerpt D: New ADD — `_resolve_layout()` lazy singleton fallback (D-07 / CONTRACT-04)**

```gdscript
static var _DEFAULT_LAYOUT: TetraTileLayout = null                                  # lazy singleton, allocated once

func _resolve_layout() -> TetraTileLayout:
	if atlas_contract != null and atlas_contract.layout != null:
		return atlas_contract.layout
	if _DEFAULT_LAYOUT == null:
		_DEFAULT_LAYOUT = TetraTileLayoutTetraHorizontal.new()                       # v0.1 horizontal default
	return _DEFAULT_LAYOUT
```

**Excerpt E: New ADD — `_paint_with_slot` helper replacing `_set_visual_cell` direct call**

The v0.1 `_set_visual_cell` (lines 172-179) becomes:
```gdscript
func _set_visual_cell(
		layer: TileMapLayer,
		display_cell: Vector2i,
		source: int,
		tile_index: int,
		transform: int,
) -> void:
	layer.set_cell(display_cell, source, _atlas_coords(tile_index), transform)
```

Replace with a slot-driven version. The new helper accepts the layout's resolved `AtlasSlot`:
```gdscript
func _paint_with_slot(layer: TileMapLayer, slot: TetraTileAtlasSlot, display_cell: Vector2i, source: int) -> void:
	if slot == null:
		layer.erase_cell(display_cell)
		return
	# Pack alt-tile + transform flags into a single int per PITFALLS §3 / LAYOUT-05.
	# (Phase 1 layouts don't use alternatives; alt = 0 here. Phase 3.5 will pass non-zero.)
	var packed_alt := slot.alternative_tile | slot.transform_flags
	layer.set_cell(display_cell, source, slot.atlas_coords, packed_alt)
```

**Excerpt F: New ADD — `_update_cells` dual-grid + single-grid pipeline branch (CONTEXT.md D-06)**

Modify the v0.1 `_update_cells` (lines 67-83) so the affected-cells loop branches on `layout.is_dual_grid()`. The dual-grid branch preserves v0.1 behavior (loop over display cells offset by `-tile_size/2` via `_visual_layer_offset`); the single-grid branch paints at the cell's own position with no half-tile offset. Per RESEARCH.md *Architecture* "Single-grid pipeline (new, Phase 1 ships per D-06)":

```gdscript
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	_ensure_visual_layers()
	if forced_cleanup or tile_set == null:
		_clear_visual_layers()
		return
	_sync_visual_layers()
	if coords.is_empty():
		rebuild()
		return
	var layout := _resolve_layout()
	var source := _resolve_source_id()
	if source == -1:
		return
	var sample_fn := _has_logic_cell                                                # Callable to a method-ref
	var affected: Dictionary = {}
	if layout.is_dual_grid():
		for logic_cell: Vector2i in coords:
			_mark_affected_display_cells(affected, logic_cell)
	else:
		for logic_cell: Vector2i in coords:
			_mark_affected_single_grid_cells(affected, logic_cell)                  # NEW helper for Phase 1
	for display_cell: Vector2i in affected.keys():
		_paint_via_layout(display_cell, layout, source, sample_fn)
```

**What the new file MUST replicate:**
- `_has_logic_cell` (lines 168-169) stays unchanged. The `sample_fn: Callable` is just a method reference to it.
- `_mark_affected_display_cells` (lines 101-105) stays unchanged for the dual-grid branch.
- `_visual_layer_offset` (lines 236-239) stays for the dual-grid branch but is `Vector2.ZERO` for the single-grid branch (the affected-cells loop or `_sync_visual_layers` switches based on `layout.is_dual_grid()`).
- `rebuild()` (lines 86-98) is updated to use the same `_resolve_layout` + branch path so a full rebuild matches an incremental update.

**What it must NOT do:**
- Sample the layout's `compute_mask` then call `mask_to_atlas` for mask 0 — short-circuit `if mask == 0: erase + continue` per RESEARCH.md *Architecture* "universal short-circuit per PITFALLS.md §4". Saves one `AtlasSlot` allocation per empty cell.
- Reintroduce `_atlas_coords(tile_index)` (D-19 says it's removed). The slot already carries `atlas_coords: Vector2i`.
- Set `visible = false` on the logic layer (PITFALLS §7 / CONCERNS §"TileMapLayer visibility behavior"). Continue using `self_modulate.a` per `_apply_logic_layer_opacity` lines 248-251 — preserved unchanged.
- Hold a reference to `_DEFAULT_LAYOUT` outside `_resolve_layout` (singleton allocates once and lives for the script lifetime; do not deep-copy or mutate).
- Cache the resolved layout — it's cheap (Dictionary lookup + null check); the v0.1 "no persistent caches" identity guardrail (CONCERNS.md §Tech Debt) holds.

---

## .tres File Shape Reference

The only existing `.tres` in the repo is `addons/tetra_tile/demo/tetra_tile_ground.tres`. Phase 1's four bundled `.tres` files follow the same `[gd_resource]` + `[ext_resource]` + `[resource]` structure but use `script_class` to pick the custom Resource subclass instead of `type="TileSet"`.

### Verbatim format excerpt (`tetra_tile_ground.tres` 1-19)
```godot-resource
[gd_resource type="TileSet" format=3 uid="uid://dyv1io31sbual"]

[ext_resource type="Texture2D" uid="uid://dy47c7ifxvx8j" path="res://addons/tetra_tile/demo/tetra_tile_ground.png" id="1_2jhym"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_t6276"]
texture = ExtResource("1_2jhym")
0:0/0 = 0
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)
1:0/0 = 0
1:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 0, -8, 0, 8, -8, 8)
1:0/0/physics_layer_0/polygon_1/points = PackedVector2Array(0, 0, 8, 0, 8, 8, 0, 8)
2:0/0 = 0
2:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, 0, 8, 0, 8, 8, -8, 8)
3:0/0 = 0
3:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, 0, 0, 0, 0, 8, -8, 8)

[resource]
physics_layer_0/collision_layer = 1
sources/0 = SubResource("TileSetAtlasSource_t6276")
```

### Adapted shape for `tetra_horizontal_default.tres` (a `TetraTileLayoutTetraHorizontal` instance)
```godot-resource
[gd_resource type="Resource" script_class="TetraTileLayoutTetraHorizontal" format=3 uid="uid://<NEW_UID>"]

[ext_resource type="Script" path="res://addons/tetra_tile/tetra_tile_layout_tetra_horizontal.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://upf13v2hjaqq" path="res://addons/tetra_tile/templates/tetra_horizontal.png" id="2_template"]

[resource]
script = ExtResource("1_script")
template_image = ExtResource("2_template")
description = "TetraTile 4-tile horizontal layout (Fill / Inner Corner / Border / Outer Corner laid out left-to-right)."
```

### Adapted shape for `default_horizontal.tres` (a `TetraTileAtlasContract` instance)
```godot-resource
[gd_resource type="Resource" script_class="TetraTileAtlasContract" format=3 uid="uid://<NEW_UID>"]

[ext_resource type="Script" path="res://addons/tetra_tile/tetra_tile_atlas_contract.gd" id="1_script"]
[ext_resource type="Resource" path="res://addons/tetra_tile/contracts/tetra_horizontal_default.tres" id="2_layout"]

[resource]
script = ExtResource("1_script")
version = 1
layout = ExtResource("2_layout")
variation_seed = 0
```

**Format notes for executors:**
- `format=3` is Godot 4.x. Do NOT use `format=2` (Godot 3.x).
- The `uid` attribute on `[gd_resource]` is auto-generated when Godot first imports the file. Executors do NOT need to hand-write a real UID; they may write `uid="uid://<NEW_UID>"` as a placeholder and let Godot regenerate on first load. Or omit the `uid="..."` attribute entirely from the literal `[gd_resource]` line and let Godot fill it on save. (The demo file has a real UID because Godot generated it; new files Phase 1 ships will too, on first editor open.)
- The `id="1_script"` / `id="2_template"` slugs are local-to-file. Executors can use any short alphanumeric; convention is `<order>_<purpose>` (e.g., `1_script`, `2_layout`, `3_template`).
- The texture UID `uid://upf13v2hjaqq` for `tetra_horizontal.png` was confirmed by reading `addons/tetra_tile/templates/tetra_horizontal.png.import` line 5. The `tetra_vertical.png` UID can be read from its own `.import` sidecar at the same line.
- LF line endings + UTF-8 (`.gitattributes` enforces).

### Where to put them (planner discretion per CONTEXT.md)

CONTEXT.md `### Claude's discretion` leaves the path to the planner. Recommendation: `addons/tetra_tile/contracts/` — a fresh subdirectory keeps the addon root tidy and groups all four bundled `.tres` files. Verified empty: `ls addons/tetra_tile/` shows only `demo/`, `templates/`, `plugin.cfg`, and the v0.1 `.gd` + template PNG. No path collision.

---

## Convention Cross-References

### From `.planning/codebase/CONVENTIONS.md` (load-bearing for Phase 1)

- **§Naming Patterns / Files (line 7-10):** GDScript files use `snake_case`. ALL Phase 1 new files comply (`tetra_tile_atlas_contract.gd`, `tetra_tile_atlas_slot.gd`, `tetra_tile_layout.gd`, `tetra_tile_layout_tetra_horizontal.gd`, `tetra_tile_layout_tetra_vertical.gd`).
- **§Naming Patterns / Classes (line 13):** `class_name` directive with PascalCase. ALL new files declare a `class_name`.
- **§Naming Patterns / Variables (line 25):** Exported properties are `snake_case` without underscores. New exports (`atlas_contract`, `version`, `layout`, `variation_seed`, `template_image`, `fallback_tile_set`, `description`, `decoder_image`, `atlas_coords`, `transform_flags`, `alternative_tile`, `diagonal_complement_atlas_coords`) all comply.
- **§Code Style / Type Annotations (line 39-43):** Return types and parameter types are annotated. ALL new methods comply.
- **§Code Style / Attributes/Decorators (line 45-50):** `@tool` on editor-mutable scripts. The 5 new `.gd` files all use `@tool` (CONTEXT.md `<code_context>` integration points imply they're inspector-edited; `update_configuration_warnings()` requires `@tool`).
- **§Setter Patterns (line 52-59):** Setters trigger deferred coalescing. New `atlas_contract` setter does this PLUS adds the idempotence guard + disconnect-before-reconnect that v0.1 setters DON'T have (D-08 net-new pattern).
- **§Match Statements (line 142-152):** `match` for mask-based routing. The 16-state match relocates from layer to `mask_to_atlas` unchanged in shape.
- **§Deferred Calls (line 164-171):** `call_deferred()` to defer expensive operations. `_queue_rebuild` preserved; `_on_contract_changed` calls into `_queue_rebuild` (no new deferred path needed).

### From `.planning/codebase/CONCERNS.md`

- **§Fragile Areas / Layer validity checks (line 43-47):** `_ensure_visual_layers` is "robust but depends on Godot's `_ready()` and internal layer lifecycle." Phase 1 PRESERVES verbatim. Do not cache layer references across `_update_cells` calls.
- **§Fragile Areas / Atlas layout hard-coded (line 55-59):** v0.1 wart of "changing `atlas_layout` mid-play needs `rebuild()`" goes away in Phase 1 — the new contract setter (D-08 idempotence + Resource.changed) handles mid-play swaps via `emit_changed()` propagation.
- **§Tech Debt / No persistent coordinate cache (line 19-23):** Phase 1 MUST NOT introduce a coordinate cache. Identity guardrail. `_resolve_layout` does a Dictionary lookup; no memoization.
- **§Godot Engine-Specific Concerns / TileMapLayer visibility behavior (line 128-132):** Logic layer NEVER set `visible = false`. Use `self_modulate.a` (already in v0.1 lines 248-251 — preserved). PITFALLS §7.

### From `.planning/research/PITFALLS.md`

- **§3 — `alternative_tile` bit collision:** `_pack_alternative(alt, flags)` helper with `assert(alt < 4096)` — declared on `TetraTileLayout` base (LAYOUT-05). Phase 1 layouts pass `alt = 0`; Phase 3.5 passes non-zero. The assert fires at edit time if a layout subclass authors an out-of-range alt — surfaces the bug before runtime.
- **§5 — Setter loops + `Resource.changed` storms:** The `atlas_contract` setter (Excerpt C above) is the verbatim recipe. Idempotence guard FIRST (so `obj.atlas_contract = obj.atlas_contract` returns instantly without any signal traffic). Then disconnect-OLD before assign. Then connect-NEW after assign. Then `_queue_rebuild` (deferred — coalesces).
- **§7 — `TileMapLayer.visible = false` cleanup:** Already mitigated in v0.1; Phase 1 introduces no new code path that touches `visible` on the logic layer. Verified.

---

## Anti-Pattern Reminders (DO NOT regress)

1. **Do not direct-assign in setters that own a sub-Resource.** The v0.1 layer setters at lines 27-29 / 32-34 do `<name> = value; _queue_rebuild()`. That works for `int` / `bool` / `enum` (value semantics). It will leak `Resource.changed` connections for the new `atlas_contract` (reference semantics). Use the disconnect-before-reconnect pattern.

2. **Do not iterate `affected.keys()` and call `_paint_display_cell` per cell that does its own `_mask_at` lookup.** v0.1 lines 82-83 do that, but the layout-driven version computes `mask` once per cell, short-circuits on 0, and then calls `mask_to_atlas` exactly once. Don't accidentally call `compute_mask` twice.

3. **Do not load `template_image` synchronously in `_init` to populate slot tables.** D-13 says decode at Resource load + cache, but Phase 1's two layouts hardcode their tables — DON'T introduce decoder code yet (Phase 2 lands the first consumer). Adding it untested risks a Phase 1 regression while bringing zero user-visible value.

4. **Do not subclass `TetraTileLayoutTetraVertical` from `TetraTileLayout` (the base).** Per file 5 above: subclass from `TetraTileLayoutTetraHorizontal` and override only `_make_slot`. Bypasses the LOC budget bloat AND keeps the 16-state match as a single source of truth.

5. **Do not call `emit_changed()` from inside `_on_contract_changed()` or any setter that's already inside a `Resource.changed` handler.** Signal storm — PITFALLS §5. The `_queue_rebuild` deferred coalescer is the safety net; don't bypass it.

6. **Do not omit `@tool` from any of the new `.gd` files.** The `TetraTileMapLayer` is `@tool`; if it touches a non-`@tool` Resource at edit time, Godot 4.6 raises a runtime "script is not a tool" error in the inspector. All five Phase 1 `.gd` files need `@tool`.

7. **Do not pre-allocate the singleton `_DEFAULT_LAYOUT` at script-static-init time.** Use lazy-init inside `_resolve_layout()` (Excerpt D above). Static-init ordering with `class_name` is fragile in Godot 4.6 — the lazy pattern is the established v0.1 idiom (see `_ensure_visual_layers`).

8. **Do not use `Vector2i.ZERO` as the "no overlay" sentinel for `diagonal_complement_atlas_coords`.** `Vector2i.ZERO` is a valid atlas slot (the Fill tile in horizontal layout). Use `Vector2i(-1, -1)` per file 2 above.

---

## PATTERN MAPPING COMPLETE

**Phase:** 01 — Contract Skeleton + Tetra Layouts
**Files classified:** 10 (6 .gd + 4 .tres)
**Analogs found:** 10 / 10 — but with the major caveat that **no in-repo Resource-extending `.gd` exists yet**, so file 1-3-4-5 patterns lean on cross-pattern transfer from `tetra_tile_map_layer.gd` plus PITFALLS.md §3/§5 recipes (load-bearing — Phase 1 introduces these to the codebase).

### Coverage
- Files with exact analog (this file IS the source): 1 (`tetra_tile_map_layer.gd` modified)
- Files with same-role-shape analog: 4 (.tres files → `tetra_tile_ground.tres`)
- Files with role-mismatch but pattern-match analog: 5 (.gd Resource files → v0.1 layer setter / const / class-header conventions)
- Files with no in-repo analog at all: 0
- Files relying on PITFALLS.md recipe (no in-repo demo): 1 setter pattern (Resource.changed disconnect-before-reconnect) + 1 helper (`_pack_alternative`)

### Key Patterns Identified
- **Setter discipline upgrade:** v0.1 uses direct-assign-and-call; Phase 1 introduces idempotence + disconnect-before-reconnect on `Resource.changed`. This pattern propagates to every future Resource-owning setter in v0.2-v0.5.
- **Lazy singleton fallback:** v0.1's `_ensure_visual_layers` is the precedent. `_resolve_layout`'s singleton pattern follows the same shape — no eager allocation, validity check + lazy create.
- **Polymorphic strategy via `class_name` + typed `@export`:** D-01's Approach B is implemented through Godot 4.6's typed-picker (`@export var atlas_contract: TetraTileAtlasContract`). No custom Inspector plugin needed (D-21 / `PROJECT.md` identity guardrail).
- **`.tres` script_class pattern:** Custom Resource serialization uses `[gd_resource type="Resource" script_class="..."]` + an `[ext_resource type="Script"]` for the script reference + a `[resource] script = ExtResource(...)` block. The demo `tetra_tile_ground.tres` doesn't show this (it's a stock `TileSet`), so executors should use the adapted excerpts above as the format spec.
- **Tile-index axis swap as inheritance instead of duplication:** Vertical layout subclasses Horizontal and overrides exactly the `_make_slot` axis. 30 LOC budget held.

### File Created
`C:\Programming_Files\Shilocity\TetraTile\.planning\phases\01-contract-skeleton-tetra-layouts\01-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference per-file pattern excerpts in PLAN.md tasks.
