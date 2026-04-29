# Phase 3: Public-Convention Layouts (Blob47 + Tilesetter) — Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 14 (8 NEW + 6 MODIFIED) + 5 documentation/state files
**Analogs found:** 14 / 14 (100%) — every Phase 3 file has a strong precedent in the Phase 2 codebase

> **Key insight:** Phase 3 is structurally a Phase 2 clone. Three new layouts mirror the `Wang2Corner` / `Wang2Edge` / `Min3x3` shape exactly (single-grid, Resource subclass, abstract-virtual overrides). Tests mirror `comprehensive_bitmask_test.gd` / `bitmask_bounds_test.gd` / `penta_ground_hollow_test.gd`. PNG generation mirrors `gen_wang_2_corner` / `gen_minimal_3x3`. The ONLY genuinely new patterns are: (a) 8-bit Moore mask, (b) BorisTheBrave 256→47 collapse algorithm, (c) the 1-line layer patch to extend single-grid affected-cell radius from 4-cardinal to 8-Moore.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` | Resource subclass / layout | request-response (mask → atlas slot) | `penta_tile_layout_wang_2_corner.gd` + `penta_tile_layout_dual_grid_16.gd` const-dict | exact (single-grid + dispatch dict) |
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png` | bundled asset / fallback PNG | data | `penta_tile_layout_wang_2_corner.png` (gen via `gen_wang_2_corner`) | role-match |
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.gd` | Resource subclass / layout | request-response | `penta_tile_layout_wang_2_corner.gd` (corner mask + mask=0 dispatch) | exact |
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.png` | bundled asset / fallback PNG | data | `penta_tile_layout_wang_2_corner.png` | role-match |
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.gd` | Resource subclass / layout | request-response | same as `blob_47_godot.gd` (sibling 47-blob) | exact |
| **NEW** `addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.png` | bundled asset / fallback PNG | data | `penta_tile_layout_wang_2_corner.png` | role-match |
| **NEW** `addons/penta_tile/tests/blob_47_collapse_test.gd` | unit test (algorithmic) | batch (256 masks → assert dict coverage) | `bitmask_bounds_test.gd` (per-slot enumeration) | role-match (new flavor: pure-math collapse, no rendering) |
| **NEW** `addons/penta_tile/tests/blob_47_hollow_test.gd` | integration test (composed canvas) | batch (paint pattern → composed canvas → bbox assertions) | `penta_ground_hollow_test.gd` | exact |
| **NEW** `addons/penta_tile/tests/tilesetter_wang_15_dispatch_test.gd` | unit test (dispatch) | batch | `bitmask_bounds_test.gd` | role-match |
| **NEW** `addons/penta_tile/tests/tilesetter_blob_47_collapse_test.gd` | unit test (algorithmic) | batch | `bitmask_bounds_test.gd` (per-slot enumeration) | role-match |
| **NEW** `addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd` | integration test (pipeline) | event-driven (set_cell → re-render verification) | `comprehensive_bitmask_test.gd` `_test_combo` (paint + assert visual) | role-match |
| **NEW** `.planning/phases/03-tilebittools-sourced-layouts/03-TBT-DEEP-AUDIT.md` | research deliverable | document | `.planning/research/layouts/TILEBITTOOLS.md` | role-match (extends prior audit with ADOPT/PARTIAL/REJECT verdicts) |
| **MOD** `addons/penta_tile/penta_tile_map_layer.gd` (lines 234-239) | core layer / dispatch helper | event-driven (paint → mark affected cells) | self (`_mark_affected_display_cells` lines 222-227 has 4 corner offsets pattern) | exact (mechanical extension: 4-cardinal → 8-Moore) |
| **MOD** `addons/penta_tile/_generate_bitmasks.py` | build script (Pillow image gen) | batch | self (`gen_wang_2_corner`, `gen_minimal_3x3`, `draw_corner_mask`, `draw_edge_mask`) | exact |
| **MOD** `addons/penta_tile/tests/comprehensive_bitmask_test.gd` | extend layout matrix | batch | self (lines 66-72 layouts array) | exact |
| **MOD** `addons/penta_tile/tests/bitmask_bounds_test.gd` | extend PNG bounds checks | batch | self (lines 40-58 _check_atlas calls) | exact |
| **MOD** `addons/penta_tile/tests/run_tests.ps1` | extend test inventory | batch | self (lines 53-66 `$allTests` array) | exact |
| **MOD** `README.md` | docs (project root) | document | self (existing footnote conventions) | role-match |
| **MOD** `.planning/REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md` | docs (planning) | document | self | exact |

---

## Pattern Assignments

### `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` (Resource subclass, request-response)

**Primary analog:** `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` (single-grid + diagonal-neighbor mask + greybox PNG)
**Secondary analog:** `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd` (mask-keyed atlas dispatch via `mask % N, mask / N` formula)

**File-header pattern** (Wang2Corner.gd lines 1-26 — adapt for 47-blob):
```gdscript
@tool
## Blob47Godot — 47-tile blob layout, 8-bit Moore mask, single-grid.
##
## Mask convention (D-76): N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128.
## NOT the canonical CR31 clockwise ordering — see _collapse_8bit_moore for
## the conversion. The 256→47 collapse rule per BorisTheBrave's reference
## (https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html):
## "A corner bit only matters if both adjacent edges are set."
##
## Atlas: <COLS>×<ROWS> (per BorisTheBrave reference; plan-phase locks).
## Single-grid: yes — paints directly at the logic cell.
##
## Slot table sourced from: https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html
class_name PentaTileLayoutBlob47Godot
extends PentaTileLayout
```

**Neighbor-offset constants** (extend Wang2Corner lines 27-30 from 4 to 8 directions; D-76 ordering — N first per low-nibble cardinal-anchored convention):
```gdscript
const _N := Vector2i(0, -1)
const _E := Vector2i(1, 0)
const _S := Vector2i(0, 1)
const _W := Vector2i(-1, 0)
const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)
```

**Const dispatch dict** (DualGrid16 has no dict but const Dictionary is the precedent; copy shape from the RESEARCH.md skeleton):
```gdscript
# 47 entries keyed on D-76-ordered, COLLAPSED masks → atlas (col, row) coords.
const _MASK_TO_ATLAS: Dictionary = {
    0:   Vector2i(0, 0),   # mask=0 → "lonely tile" / isolated cell (D-80)
    # ... 46 more entries — locked by plan-phase from BorisTheBrave's mapping ...
    255: Vector2i(?, ?),
}
```

**`is_dual_grid()` pattern** (Wang2Corner lines 33-34, copied verbatim):
```gdscript
func is_dual_grid() -> bool:
    return false
```

**`compute_mask` pattern** (extend Wang2Corner lines 37-43 to 8 bits, with D-76 bit ordering):
```gdscript
func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    var mask := 0
    if sample_fn.call(coord + _N):  mask |= 1
    if sample_fn.call(coord + _E):  mask |= 2
    if sample_fn.call(coord + _S):  mask |= 4
    if sample_fn.call(coord + _W):  mask |= 8
    if sample_fn.call(coord + _NE): mask |= 16
    if sample_fn.call(coord + _SE): mask |= 32
    if sample_fn.call(coord + _SW): mask |= 64
    if sample_fn.call(coord + _NW): mask |= 128
    return mask
```

**`mask_to_atlas` pattern** — branches on collapse-then-dict-lookup. **CRITICAL**: D-80 + Pitfall C — mask=0 must return a valid slot (`Vector2i(0, 0)` for the "lonely tile"), NEVER null. Compare against Wang2Corner lines 46-55:
```gdscript
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var collapsed := _collapse_8bit_moore(mask)
    var slot := PentaTileAtlasSlot.new()
    slot.atlas_coords = _MASK_TO_ATLAS.get(collapsed, Vector2i(0, 0))   # mask=0 fallback per D-80
    slot.transform_flags = 0
    slot.alternative_tile = 0
    return slot
```

**Collapse helper** (NEW pattern; D-78 algorithmic rule — keep `static`; total/idempotent so unit-testable in isolation):
```gdscript
# D-78: 256→47 collapse via BorisTheBrave's algorithmic rule.
# A corner bit only survives if both adjacent edges are set.
static func _collapse_8bit_moore(raw: int) -> int:
    var n := raw & 1
    var e := raw & 2
    var s := raw & 4
    var w := raw & 8
    var collapsed := raw & 15  # edges pass through
    if n != 0 and e != 0 and (raw & 16)  != 0: collapsed |= 16
    if s != 0 and e != 0 and (raw & 32)  != 0: collapsed |= 32
    if s != 0 and w != 0 and (raw & 64)  != 0: collapsed |= 64
    if n != 0 and w != 0 and (raw & 128) != 0: collapsed |= 128
    return collapsed
```

**Fallback declarations** (Wang2Corner lines 58-63, copied verbatim with new path + grid):
```gdscript
func _default_bitmask_template_path() -> String:
    return "res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png"


func _fallback_atlas_grid_size() -> Vector2i:
    return Vector2i(<COLS>, <ROWS>)   # plan-phase locks per BorisTheBrave reference (likely 7×7 Caeles or 12×4)
```

---

### `addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.gd` (Resource subclass, request-response)

**Primary analog:** `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` (corner mask, single-grid, mask=0 dispatch)

**File header** (Wang2Corner doc-comment template adapted — D-79 stray-fill slot at `Vector2i(5, 0)`):
```gdscript
@tool
## TilesetterWang15 — Tilesetter's exported 15-tile Wang autotile + 1 stray-fill slot.
##
## Mask convention: 4-bit corner (NE=1, SE=2, SW=4, NW=8 per CR31 conventions
## already used by Wang2Corner). Single-grid: yes. Tilesetter exports a 5×3
## main grid; PentaTile reserves a 16th 'stray fill' slot at (5, 0) per D-79.
##
## Atlas: 6×3 (5×3 main + 1 stray-fill column at (5, 0)).
## Slot table sourced from: <Tilesetter manual URL — locked by plan-phase Wave 0a research, gated by D-86>
class_name PentaTileLayoutTilesetterWang15
extends PentaTileLayout
```

**Neighbor consts** (Wang2Corner lines 27-30, copied verbatim — same CR31 NE/SE/SW/NW convention):
```gdscript
const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)
```

**`compute_mask`** — copy Wang2Corner lines 37-43 verbatim.

**`mask_to_atlas`** — BRANCHES on mask=0 to stray-fill, then dispatches via const dict (Tilesetter ships a fixed 5×3 ordering — plan-phase locks slot positions). Pattern composes Wang2Corner's mask=0 branch + DualGrid16's const-dict approach:
```gdscript
const _MASK_TO_ATLAS: Dictionary = {
    # 15 entries keyed on 4-bit corner masks 1..15 → Vector2i(col, row) within 5×3 grid.
    # Plan-phase locks per Tilesetter manual.
}

func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var slot := PentaTileAtlasSlot.new()
    if mask == 0:
        slot.atlas_coords = Vector2i(5, 0)  # D-79: stray-fill slot
    else:
        slot.atlas_coords = _MASK_TO_ATLAS.get(mask, Vector2i(5, 0))
    slot.transform_flags = 0
    slot.alternative_tile = 0
    return slot
```

**Fallback declarations:**
```gdscript
func _default_bitmask_template_path() -> String:
    return "res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.png"


func _fallback_atlas_grid_size() -> Vector2i:
    return Vector2i(6, 3)   # 5×3 main + stray-fill column
```

---

### `addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.gd` (Resource subclass, request-response)

**Primary analog:** `penta_tile_layout_blob_47_godot.gd` (sibling — same D-76 8-Moore mask, same `_collapse_8bit_moore` algorithm, same `_MASK_TO_ATLAS` const dict pattern)

**Differences from `blob_47_godot.gd`:**
- **Source:** Tilesetter manual (D-75, D-86 gated) instead of BorisTheBrave reference (D-74).
- **Atlas:** `Vector2i(11, 5)` per Phase 2 research (with sub-block gaps documented in class doc-comment).
- **Slot positions:** different from Blob47Godot — Tilesetter uses its own canonical ordering.
- **Class name:** `PentaTileLayoutTilesetterBlob47`.
- **PNG path:** `res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.png`.

**Reuse:** `_collapse_8bit_moore` is identical (algorithmic rule, mask convention is layout-agnostic — D-78). Each layout has its own `static func` copy (D-77 forbids a base-class helper). Tests verify the COLLAPSED mask hits the dict; test logic is identical, only the dict differs.

---

### `addons/penta_tile/penta_tile_map_layer.gd` lines 234-239 — 1-line patch (core layer, event-driven)

**Analog:** self — `_mark_affected_display_cells` (lines 222-227, 4 dual-grid corner offsets) AND existing `_mark_affected_single_grid_cells` (4 cardinal offsets).

**Current code** (lines 234-239):
```gdscript
func _mark_affected_single_grid_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
    affected[logic_cell] = true
    affected[logic_cell + Vector2i.UP] = true
    affected[logic_cell + Vector2i.DOWN] = true
    affected[logic_cell + Vector2i.LEFT] = true
    affected[logic_cell + Vector2i.RIGHT] = true
```

**Patched code** (D-87 prerequisite — extend to 8-Moore for 47-blob compatibility):
```gdscript
func _mark_affected_single_grid_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
    affected[logic_cell] = true
    affected[logic_cell + Vector2i.UP] = true
    affected[logic_cell + Vector2i.DOWN] = true
    affected[logic_cell + Vector2i.LEFT] = true
    affected[logic_cell + Vector2i.RIGHT] = true
    affected[logic_cell + Vector2i(1, -1)]  = true   # NE
    affected[logic_cell + Vector2i(1, 1)]   = true   # SE
    affected[logic_cell + Vector2i(-1, 1)]  = true   # SW
    affected[logic_cell + Vector2i(-1, -1)] = true   # NW
```

**Doc comment update** (line 230-233 above the function): change "Marks cell + 4 cardinal neighbors" → "Marks cell + 8 Moore neighbors (cardinal + diagonal)". Add D-87 reference.

**Verification:** new test `single_grid_8_moore_propagation_test.gd` (see below) MUST fail on broken code (4-cardinal only) and pass on patched code. Per CLAUDE.md "Test Methodology" #5: "Verify the test catches the regression."

---

### `addons/penta_tile/_generate_bitmasks.py` — extend with 3 generators (build script, batch)

**Analog:** self — existing helpers `new_atlas` (line 39-41), `draw_corner_mask` (line 59-75), `draw_edge_mask` (line 78-95), `gen_dual_grid_16` (line 181-193), `gen_wang_2_corner` (line 210-235), `gen_minimal_3x3` (line 238-260), `main()` (line 263-279).

**Existing `gen_wang_2_corner` body** (lines 228-235) — paste-and-modify template for `gen_tilesetter_wang_15`:
```python
def gen_wang_2_corner() -> Image.Image:
    """4x4 atlas greybox for the SINGLE-GRID Wang2Corner layout.
    ..."""
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for col in range(4):
        for row in range(4):
            x0, y0 = col * TILE, row * TILE
            draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)
            draw_slot_outline(draw, col, row)
    return img
```

**`gen_tilesetter_wang_15` pattern** — 6×3 atlas (5×3 main + stray-fill at (5, 0)). Solid 32×32 per slot (single-grid silhouette pattern from `gen_wang_2_corner`). Atlas-occupancy gaps stay transparent (already default per `new_atlas` transparent fill).

**`gen_blob_47_godot` + `gen_tilesetter_blob_47`** — these need a NEW helper `draw_47_blob_silhouette(draw, col, row, mask)` which decomposes the collapsed 8-Moore mask into:
- edge strips (low nibble): copy `draw_edge_mask` solid 32×32 logic but for partial bands
- corner squares (high nibble, only if both adjacent edges set): paste `draw_corner_mask` 16×16 quadrant logic conditionally

**D-85 implementation note:** for atlas-occupancy gaps (Tilesetter's 11×5 has documented sub-block gaps), simply skip the `draw.rectangle` call for those (col, row) — the transparent base from `new_atlas` shows through.

**`main()` extension** (after line 277):
```python
gen_blob_47_godot().save(OUT_LAYOUTS / "penta_tile_layout_blob_47_godot.png")
gen_tilesetter_wang_15().save(OUT_LAYOUTS / "penta_tile_layout_tilesetter_wang_15.png")
gen_tilesetter_blob_47().save(OUT_LAYOUTS / "penta_tile_layout_tilesetter_blob_47.png")
```

**Existing module docstring update (line 11-16)** — add new mask-convention lines:
```
- Blob47Godot / TilesetterBlob47: 8-bit Moore mask N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128 (D-76)
- TilesetterWang15: 4-bit corner mask NE=1, SE=2, SW=4, NW=8 (CR31, like Wang2Corner) + stray-fill slot at (5, 0)
```

---

### `addons/penta_tile/tests/blob_47_collapse_test.gd` (unit test, batch)

**Analog:** `addons/penta_tile/tests/bitmask_bounds_test.gd` (per-slot enumeration pattern); structure also borrows from `extends SceneTree` + `_failures` + `quit(0/1)` from `comprehensive_bitmask_test.gd` lines 32-86.

**Header pattern** (copy `bitmask_bounds_test.gd` lines 1-39 framework):
```gdscript
## Pure-math test: enumerate all 256 D-76 8-bit Moore masks, apply
## PentaTileLayoutBlob47Godot._collapse_8bit_moore, assert every result
## is a key in _MASK_TO_ATLAS. Catches 47-entry dict transcription errors
## (Pitfall A from 03-RESEARCH.md).
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/blob_47_collapse_test.gd
extends SceneTree

const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")

var _failures: Array = []


func _initialize() -> void:
    print("=== blob_47_collapse_test ===")
    var dict: Dictionary = _Blob47GodotSc._MASK_TO_ATLAS  # const access via class
    for raw in range(256):
        var collapsed := _Blob47GodotSc._collapse_8bit_moore(raw)
        if not dict.has(collapsed):
            _failures.append("raw mask %d → collapsed %d not in _MASK_TO_ATLAS" % [raw, collapsed])
    if dict.size() != 47:
        _failures.append("_MASK_TO_ATLAS has %d entries, expected exactly 47" % dict.size())

    print("\n=== summary ===")
    if _failures.is_empty():
        print("ALL PASS")
        quit(0)
    else:
        printerr("FAIL (%d):" % _failures.size())
        for f in _failures:
            printerr("  - " + f)
        quit(1)
```

**Acceptance:** runs headless, exits 0, prints `ALL PASS`. **Verify-the-regression step:** introduce a deliberate transcription error (delete one dict entry), confirm test fails with specific raw-mask number, restore. (CLAUDE.md "Test Methodology" #5.)

---

### `addons/penta_tile/tests/blob_47_hollow_test.gd` (integration test, composed canvas)

**Analog:** `addons/penta_tile/tests/penta_ground_hollow_test.gd` (paint hollow ring → compose canvas → assert opaque-pixel bbox + hole emptiness). This is the ONE-FOR-ONE template per CLAUDE.md "Test Methodology" #1 + #2.

**Header pattern** (penta_ground_hollow_test.gd lines 36-90 — copy structure, swap layout):
```gdscript
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")

var _failures: Array = []


func _initialize() -> void:
    print("=== blob_47_hollow_test ===")

    # Hollow ring: 8x8 outer cells with a 4x4 hole at the center.
    var paint_cells: Array = _build_hollow_ring(0, 0, 8, 8, 2, 2, 4, 4)
    await _test_layout(paint_cells, "Blob47Godot", _Blob47GodotSc)

    print("\n=== summary ===")
    if _failures.is_empty():
        print("ALL PASS")
        quit(0)
    else:
        printerr("FAIL (%d):" % _failures.size())
        for f in _failures:
            printerr("  - " + f)
        quit(1)
```

**Body pattern** — copy `_test_mode` from `penta_ground_hollow_test.gd` lines 92-256, but: (a) skip the dual-grid origin offset (single-grid: `canvas_origin = c_min * tile_size`, no half-tile shift), (b) drop `_apply_transform` since 47-blob layouts have `transform_flags = 0`, (c) keep all bbox + hole-emptiness assertions (Pitfall B + C catch).

**Helpers to copy verbatim:** `_build_hollow_ring` (lines 82-89), `_record` (lines 287-289).

**Critical assertions to preserve** (penta_ground_hollow_test.gd lines 211-228):
- Opaque bbox stays within user-painted bounds (single-grid: clean rectangle).
- Hole interior (4×4 center) is fully transparent.

---

### `addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd` (integration test, event-driven)

**Analog:** `comprehensive_bitmask_test.gd` `_test_combo` (lines 97-263 — paint cells, assert visual rendering).

**Test body sketch:**
```gdscript
extends SceneTree
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")
var _failures: Array = []

func _initialize() -> void:
    print("=== single_grid_8_moore_propagation_test ===")
    var layer = _LayerScript.new()
    layer.layout = _Blob47GodotSc.new()
    get_root().add_child(layer)
    await process_frame
    await process_frame

    # Paint cell (1,1) FIRST — record its dispatched atlas (mask=0, isolated).
    layer.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))
    await process_frame
    await process_frame
    var primary = layer.get("_primary_layer")
    var initial_atlas: Vector2i = primary.get_cell_atlas_coords(Vector2i(1, 1))

    # Paint diagonal neighbor (0,0). 4-cardinal radius MISSES this — (1,1) won't
    # re-render. 8-Moore radius INCLUDES it — (1,1) re-renders with new mask.
    layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
    await process_frame
    await process_frame

    var post_atlas: Vector2i = primary.get_cell_atlas_coords(Vector2i(1, 1))
    if post_atlas == initial_atlas:
        _failures.append("cell (1,1) did NOT re-render after diagonal neighbor (0,0) was painted — 8-Moore propagation broken (D-87)")

    layer.queue_free()
    print("\n=== summary ===")
    if _failures.is_empty():
        print("ALL PASS")
        quit(0)
    else:
        printerr("FAIL (%d):" % _failures.size())
        for f in _failures: printerr("  - " + f)
        quit(1)
```

**Verify-the-regression:** stash the layer-patch (revert lines 234-239 to 4-cardinal only), confirm this test fails, re-apply patch, confirm test passes.

---

### `addons/penta_tile/tests/comprehensive_bitmask_test.gd` — extend layouts array (modify, batch)

**Analog:** self — lines 34-39 (preloads), lines 66-72 (`layouts` array).

**Add preloads** (after line 39):
```gdscript
const _Blob47GodotSc      = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")
const _TilesetterWang15Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.gd")
const _TilesetterBlob47Sc = preload("res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.gd")
```

**Extend layouts array** (after line 71):
```gdscript
{"name": "Blob47Godot",      "script": _Blob47GodotSc,      "is_dual_grid": false},
{"name": "TilesetterWang15", "script": _TilesetterWang15Sc, "is_dual_grid": false},
{"name": "TilesetterBlob47", "script": _TilesetterBlob47Sc, "is_dual_grid": false},
```

**Optionally extend patterns array** (after line 63) — D-83 + Pitfall B note 8-Moore-revealing patterns:
```gdscript
{"name": "L_with_diag",   "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(1,1)]},  # exercises corner+both-edges
{"name": "diag_chain",    "cells": [Vector2i(0,0), Vector2i(1,1), Vector2i(2,2), Vector2i(3,3)]},  # diagonal-only
{"name": "moore_3x3_box", "cells": _rect(0, 0, 3, 3)},  # tile (1,1) gets all 8 neighbors → mask=255 (collapsed=255)
```

---

### `addons/penta_tile/tests/bitmask_bounds_test.gd` — extend with 3 PNG paths (modify, batch)

**Analog:** self — lines 40-58 (`_check_atlas` calls per layout).

**Add three `_check_atlas` calls** (after line 58):
```gdscript
_check_atlas("Blob47Godot",
    "res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png",
    Vector2i(<COLS>, <ROWS>),  # plan-phase locks per BorisTheBrave reference
    _blob_47_silhouette)

_check_atlas("TilesetterWang15",
    "res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_wang_15.png",
    Vector2i(6, 3),
    _wang_2_corner_silhouette)  # reuse — every slot is solid 32×32 in Tilesetter's authoring model

_check_atlas("TilesetterBlob47",
    "res://addons/penta_tile/layouts/penta_tile_layout_tilesetter_blob_47.png",
    Vector2i(11, 5),
    _blob_47_silhouette)
```

**Add `_blob_47_silhouette` helper** — for atlas-occupancy gaps return empty `[]` (the slot must be transparent); for occupied slots return the expected silhouette rect(s) per the 8-Moore mask. Pattern mirrors `_corner_mask_silhouette` (lines 165-176), branching on slot position.

---

### `addons/penta_tile/tests/run_tests.ps1` — extend `$allTests` (modify, batch)

**Analog:** self — lines 53-66 `$allTests` array.

**Patch:**
```powershell
$allTests = @(
    "paint_test",
    "all_layouts_test",
    "visual_render_test",
    "strict_pixel_test",
    "penta_one_mode_test",
    "auto_strip_axis_test",
    "layout_swap_test",
    "all_layouts_swap_pixel_test",
    "bitmask_bounds_test",
    "comprehensive_bitmask_test",
    "penta_ground_hollow_test",
    "determinism_test",
    "blob_47_collapse_test",                  # NEW
    "blob_47_hollow_test",                    # NEW
    "tilesetter_wang_15_dispatch_test",       # NEW (D-86 conditional)
    "tilesetter_blob_47_collapse_test",       # NEW (D-86 conditional)
    "single_grid_8_moore_propagation_test"    # NEW
)
```

---

### `addons/penta_tile/tests/tilesetter_wang_15_dispatch_test.gd` (D-86 conditional)

**Analog:** mirrors `blob_47_collapse_test.gd` shape but enumerates 16 corner masks instead of 256:
- `for mask in range(16)`: assert `mask_to_atlas(mask).atlas_coords` is in valid grid bounds (`Vector2i(0, 0)..(5, 2)`).
- Special-case `mask == 0` → assert `Vector2i(5, 0)` (D-79).

**Skip if D-86 resolves to "defer"** — planner generates this only if D-86 outcome is (a) user-supplied export OR (c) empirical-tag accepted.

---

### `addons/penta_tile/tests/tilesetter_blob_47_collapse_test.gd` (D-86 conditional)

**Analog:** copy of `blob_47_collapse_test.gd` with class swapped to `PentaTileLayoutTilesetterBlob47`. Same 256-mask enumeration, same dict-coverage assertion, dict size check (47).

---

### `.planning/phases/03-tilebittools-sourced-layouts/03-TBT-DEEP-AUDIT.md` (research deliverable)

**Analog:** `.planning/research/layouts/TILEBITTOOLS.md` (existing TBT background audit; the new deliverable extends it with explicit ADOPT/PARTIAL/REJECT verdicts cross-referenced against TileMapDual).

**Required structure per D-84:**
1. **Per-pattern table** — one row per TBT pattern (BitData hierarchy, EditorInspectorPlugin, custom_tags, tiles_preview SubViewport, theme harmonization, save dialog, Project Settings, Paul Tol palette, 12 .tres curation pattern). Columns: Pattern | TBT location | TileMapDual equivalent | Verdict (ADOPT/PARTIAL/REJECT) | Reasoning grounded in PROJECT.md.
2. **Backlog seed entries** — `.planning/todos/pending/` items for ADOPT-deferred / PARTIAL patterns with phase suggestions.
3. **No code lift** — recommendations in PentaTile's own style; pseudo-code only.

**Length:** ~600-1000 lines per Phase 3 scope estimate.

---

### `README.md` — 1-line design-inspiration footnote (modify, document)

**D-72 + D-73 mandate:** ATTRIBUTION.md is NOT created. Single-line README footnote replaces it.

**Insertion point:** add as a new bullet in the "External Resources" section near the bottom (line ~280+, location plan-phase confirms), or as a footnote-style paragraph after the "Supported Layouts" section.

**Suggested wording** (locked by plan-phase, but conforms to D-73 "design inspiration only"):
> **Design inspiration:** PentaTile's layout architecture takes design inspiration from the [TileBitTools](https://github.com/dandeliondino/tile_bit_tools) Godot addon. No code or data is copied; PentaTile reimplements every layout from each format's primary reference.

**No ATTRIBUTION.md.** No license file changes. Per D-73: nothing to attribute since nothing is lifted.

---

### `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` (modify, planning docs)

**REQUIREMENTS.md changes** (D-72.2):
- Rewrite **TBT-04** ("ATTRIBUTION.md credits TileBitTools") → "addons/penta_tile/README.md acknowledges TBT as design inspiration in a 1-line footnote."
- Rewrite **DOC-05** correspondingly.
- Update Phase 3 row in the Coverage table — drop ATTRIBUTION.md from owned outputs.

**ROADMAP.md changes** (D-72.1):
- Phase 3 entry retitled: "TileBitTools-Sourced Layouts" → "Public-Convention Layouts (Blob47 + Tilesetter)".
- Phase 3 description: remove "transcribed from TBT" + "Add ATTRIBUTION.md" clauses; add "from each format's primary reference" + "1-line design-inspiration footnote in README".

**STATE.md changes** (D-72.4):
- Reflect new Phase 3 title in any "current phase" reference.

**Optional:** rename phase directory slug `03-tilebittools-sourced-layouts` → `03-public-convention-layouts` via `git mv` (D-72.3, planner discretion).

---

## Shared Patterns

> **I-3 note:** Patches (Plan 01) and pure-math tests (e.g., `blob_47_collapse_test`) do NOT use the layout class skeleton — they operate on the layer pipeline directly (Plan 01) or on static layout helpers without instantiating a full layout (collapse tests). The shared pattern templates in this section apply to NEW layout subclasses + their integration tests.


### Layout class skeleton (applies to all 3 NEW layout files)

**Source:** `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` lines 1-26 (header) + lines 33-34 (`is_dual_grid`) + lines 58-63 (fallback declarations).
**Apply to:** `penta_tile_layout_blob_47_godot.gd`, `penta_tile_layout_tilesetter_wang_15.gd`, `penta_tile_layout_tilesetter_blob_47.gd`.

**Boilerplate every layout file MUST include:**
```gdscript
@tool
## <one-line layout name + purpose>
##
## Mask convention: <bit semantics — D-76 for 8-bit Moore, D-79 stray-fill for Wang15>
## Single-grid: yes — paints directly at the logic cell.
##
## Atlas: <COLS>×<ROWS>.
## Slot table sourced from: <primary reference URL>
class_name PentaTileLayout<Name>
extends PentaTileLayout

# <neighbor offset consts>

func is_dual_grid() -> bool:
    return false

func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    # ... per-layout sample bits ...

func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    # ... per-layout dispatch (mask=0 + dict lookup) ...

func _default_bitmask_template_path() -> String:
    return "res://addons/penta_tile/layouts/<slug>.png"

func _fallback_atlas_grid_size() -> Vector2i:
    return Vector2i(<COLS>, <ROWS>)
```

### `mask_to_atlas` MUST always return a non-null slot for single-grid layouts

**Source:** Pitfall #9 in CLAUDE.md (single-grid, mask=0 dispatches to a default atlas slot).
**Apply to:** all 3 NEW layouts.
**Anti-pattern:** returning `null` (Pitfall C in 03-RESEARCH.md). DualGrid16 line 41 returns `null` on mask=0 — that is DUAL-GRID behavior. Single-grid layouts return a valid slot.

**Correct pattern** (Wang2Corner lines 46-55 verbatim — `mask=0` falls through to `(mask % 4, mask / 4) = (0, 0)`):
```gdscript
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var slot := PentaTileAtlasSlot.new()
    slot.atlas_coords = <derived from mask, never null>
    slot.transform_flags = 0
    slot.alternative_tile = 0
    return slot
```

### Test file `extends SceneTree` framework

**Source:** `addons/penta_tile/tests/comprehensive_bitmask_test.gd` lines 32-86 + `bitmask_bounds_test.gd` lines 29-80.
**Apply to:** all 5 NEW test files.

**Boilerplate:**
```gdscript
## <test description>
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/<name>.gd
extends SceneTree

const _<DepName> = preload("<path>")

var _failures: Array = []


func _initialize() -> void:
    print("=== <test_name> ===")
    # ... run assertions, append to _failures ...

    print("\n=== summary ===")
    if _failures.is_empty():
        print("ALL PASS")
        quit(0)
    else:
        printerr("FAIL (%d):" % _failures.size())
        for f in _failures:
            printerr("  - " + f)
        quit(1)


func _record(label: String, msg: String) -> void:
    _failures.append("[" + label + "] " + msg)
    printerr("  FAIL " + label + ": " + msg)
```

**Why critical:** `run_tests.ps1` (lines 143-148) reads exit codes — `0 = PASS`, non-zero `= FAIL`. The runner's regex (lines 122-124) parses `ALL PASS` / `FAIL` markers for color coding. Tests that don't follow this contract are silently misreported.

### Composed-canvas testing for visual layouts

**Source:** `penta_ground_hollow_test.gd` lines 158-203 + `comprehensive_bitmask_test.gd` lines 220-261.
**Apply to:** `blob_47_hollow_test.gd`, optionally `single_grid_8_moore_propagation_test.gd`.

**Why critical:** CLAUDE.md "Test Methodology" #1 — "Compose the rendered canvas in tests, don't just check dispatch. Source-atlas pixel checks pass while rotation-bleed bugs persist." For 47-blob layouts in Phase 3, composed-canvas tests catch (a) collapse-rule transcription errors, (b) Pitfall #9 mask=0 missing-cell bugs, (c) Pitfall B 4-cardinal-radius mask-staleness bugs.

**Helper to copy:** `_apply_transform` (penta_ground_hollow_test.gd lines 261-284) — only needed if any Phase 3 layout uses `transform_flags != 0`. **Phase 3 layouts use `transform_flags = 0` exclusively** (no rotation reuse — every blob/wang slot is hand-drawn per D-77 + the layouts' descriptions), so this helper can be **omitted** from Phase 3 tests.

### `_generate_bitmasks.py` extension contract

**Source:** `_generate_bitmasks.py` lines 263-279 (`main()`) + lines 33-95 (existing helpers).
**Apply to:** the modify pass on `_generate_bitmasks.py`.

**Constants to reuse verbatim:** `TILE = 32`, `GREY = (136, 136, 136, 255)`, `OUTLINE = (68, 68, 68, 255)`, `TRANSPARENT = (0, 0, 0, 0)`, `OUT_LAYOUTS = Path(__file__).parent / "layouts"`.
**Helpers to call:** `new_atlas(cols, rows)`, `draw_slot_outline(draw, col, row)` (no-op currently, kept for symmetry per Phase 2 fix).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `_collapse_8bit_moore` static method | algorithmic helper | pure-math transform | NEW concept introduced by D-78 (BorisTheBrave 256→47 collapse rule). Algorithmic shape from RESEARCH.md §"Code Examples" Example 1 lines 950-960. Per D-77 lives per-layout (each 47-blob layout has its own copy), not on base class. |
| `draw_47_blob_silhouette` Python helper | image-gen helper | pixel manipulation | NEW concept — no existing layout draws partial-edge bands AND conditional-corner-quadrant silhouettes. Plan-phase decides whether to compose `draw_corner_mask` + `draw_edge_mask` or write a dedicated function (per D-85 + Claude's discretion). |
| `03-TBT-DEEP-AUDIT.md` ADOPT/PARTIAL/REJECT verdict structure | research doc | document | New deliverable shape. `.planning/research/layouts/TILEBITTOOLS.md` is informational; the new audit produces actionable verdicts cross-referenced against TileMapDual. |

---

## Metadata

**Analog search scope:**
- `addons/penta_tile/layouts/*.gd` (6 layouts read)
- `addons/penta_tile/tests/*.gd` (3 representative tests read: `comprehensive_bitmask_test.gd`, `bitmask_bounds_test.gd`, `penta_ground_hollow_test.gd`)
- `addons/penta_tile/penta_tile_map_layer.gd` (lines 175-300 — paint dispatch + affected-cell helpers)
- `addons/penta_tile/_generate_bitmasks.py` (full file)
- `addons/penta_tile/penta_tile_atlas_slot.gd` (full file)
- `addons/penta_tile/tests/run_tests.ps1` (full file)
- `README.md` (header + supported-layouts section)
- `.planning/phases/03-tilebittools-sourced-layouts/03-CONTEXT.md` (full)
- `.planning/phases/03-tilebittools-sourced-layouts/03-RESEARCH.md` (file structure section + Code Examples)

**Files scanned:** 13 source/test/script files + 2 planning docs.
**Pattern extraction date:** 2026-04-28.

**Anti-patterns identified (DO NOT introduce in Phase 3):**
1. `mask_to_atlas` returning `null` for single-grid layouts (Pitfall #9 + Pitfall C).
2. Generic 8-Moore helper on `PentaTileLayout` base class (D-77 forbids).
3. Lifting TBT `.tres` data or `_decode_tbt_templates.py` (D-73 forbids).
4. `addons/penta_tile/ATTRIBUTION.md` file (D-72/D-73 — replaced by README footnote).
5. `version: int` fields on Resources (CLAUDE.md "Breaking Changes Policy").
6. Penta-prefixed names for blob/wang layout concepts (CLAUDE.md "Coined-Term Discipline").

**Cross-cutting verifications (every Phase 3 task should reference at least one):**
- All 3 NEW layouts MUST follow the Wang2Corner skeleton (header + virtuals + fallback declarations).
- All 5 NEW tests MUST follow the `extends SceneTree` + `_failures` + `quit(0/1)` framework.
- The layer patch MUST be verified by `single_grid_8_moore_propagation_test.gd` failing on the un-patched code.
- The README footnote MUST be a single line; ATTRIBUTION.md MUST NOT exist after Phase 3.
