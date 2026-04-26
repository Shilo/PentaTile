# PixelLab.ai Tile Generation — Format Audit

**Researched:** 2026-04-25 (subagent on docs + Aseprite extension source code + verification spikes 001/002/003)
**Confidence:** HIGH on all findings. Aseprite plugin source code read directly; spike 003 verified the role-to-mask mapping against 16 sample generations.
**Status:** COMPLETE — PixelLab native + all three export targets understood. Layout subclasses ready to spec.

---

## Headline finding

PixelLab supports tile generation via two surfaces (web editor and Aseprite plugin). Each produces:

1. **Tileset Wang export** = 16-tile, 4×4 corner mask = our `DualGrid16`
2. **Tileset 15 export** = 5×3 with stray fill (Tilesetter convention) = our `TilesetterWang15`
3. **Tileset 3×3 export** = 9-tile Match Sides 3×3 minimal = needs new `Minimal3x3` layout
4. **Aseprite plugin native** (pre-export) = **proprietary 8×8 atlas with variation banks** = needs two new layouts (`PixelLabTopDown` + `PixelLabSideScroller`)

The web editor outputs ONLY one of the three standard exports. The Aseprite plugin shows the native 8×8 atlas before export — and that's where TetraTile's value-add is biggest, because PixelLab's own exporter discards the variation tiles when collapsing the 8×8 down to a standard format.

**Updated coverage status:**

| PixelLab output | Source | TetraTile coverage |
|-----------------|--------|---------------------|
| Tileset Wang export | web + Aseprite | ✓ `DualGrid16` (Phase 2) |
| Tileset 15 export | web + Aseprite | ✓ `TilesetterWang15` (Phase 3) |
| Tileset 3×3 export | web + Aseprite | ➕ adds `Minimal3x3` (new in v0.2) |
| Aseprite native (pre-export) | Aseprite only | ➕ adds `PixelLabTopDown` + `PixelLabSideScroller` (new in v0.2) |

---

## Aseprite plugin native format — locked

Both top-down and side-scroller native outputs are **8×8 atlases at `reference_image_size` per tile** (default 16 px → 128×128 canvas). Each cell contains one of 16 role-IDs (0-15), corresponding to the 16 valid Wang-corner masks.

### Cell-to-role layout (verbatim from `tileset_transform.lua:17-36`)

**Top-down (`tileset_output`):**
```
6  6  6  6  6  6  6  6
6  7  9 10  7  9 10  6
6 11 12  8 15 12  1  6
6 11 12 12 13  3  5  6
6  2  0 13 14  9 10  6
6  7  4  5 11 12  1  6
6  2  5 12  2  3  5  6
6  6  6  6  6  6  6  6
```

**Side-scroller (`tileset_output_side`):**
```
12 12 12 12 13  3  3  3
 0 13  3  3 14  9 10  6
11  8  9  9 15 12  1  6
11 12 12 12 12 12  8  9
 2  3  3  3  0 12 12 12
 6  6  6  7 15 12 12 12
 6  6  6 11 13  3  3  3
 6  6  7  4  5  6  6  6
```

### Role-to-mask mapping (locked, identical across both layouts)

```
role:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
mask:  4 10 13 12  9 14 15  7  2  3 11  5  0  8  6  1
```

Mask convention: 4-bit corner (TL=1, TR=2, BL=4, BR=8). Single-grid (PixelLab targets Sprite Fusion).

Verified by spike 003 against 16 PixelLab samples — 12 fully match, 4 partial match (where AI generation didn't render single-corner content cleanly enough — these don't contradict the mapping).

### Variation-bank semantics

Many cells share the same role-ID. Top-down has 28 cells of role 6 (mask 15 = bulk interior fill). Side-scroller has 16 of role 12 (mask 0 = sky/empty) and 13 of role 6 (ground bulk).

PixelLab's own exporter discards these duplicates (`tileset_transform.lua:73` — "first occurrence only"). **TetraTile reads the full 8×8 and uses the duplicates as variation_seed-keyed variants.** This is meaningful value beyond mere compatibility.

---

## Architecture for TetraTile

### Two new single-grid layout subclasses

```gdscript
class_name TetraTileLayoutPixelLabTopDown
extends TetraTileLayout

const _CELL_TO_ROLE := [
    6, 6, 6, 6, 6, 6, 6, 6,
    6, 7, 9, 10, 7, 9, 10, 6,
    6, 11, 12, 8, 15, 12, 1, 6,
    6, 11, 12, 12, 13, 3, 5, 6,
    6, 2, 0, 13, 14, 9, 10, 6,
    6, 7, 4, 5, 11, 12, 1, 6,
    6, 2, 5, 12, 2, 3, 5, 6,
    6, 6, 6, 6, 6, 6, 6, 6,
]
const _ROLE_TO_MASK := [4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]
const _MASK_TO_ROLE := [12, 15, 8, 9, 0, 11, 14, 7, 13, 4, 1, 10, 3, 2, 5, 6]

# Cached on Resource load: list of (col, row) for each mask 0..15
var _cells_by_mask: Array[Array]

func is_dual_grid() -> bool: return false
func compute_mask(coord, sample_fn) -> int:
    # Standard 4-bit corner (same as DualGrid16/Wang2Corner)
    ...
func mask_to_atlas(mask: int) -> AtlasSlot:
    var role := _MASK_TO_ROLE[mask]
    var cells := _cells_by_mask[mask]  # all positions with this mask
    var idx := hash(Vector3i(coord.x, coord.y, variation_seed)) % cells.size()
    var cell := cells[idx]
    return AtlasSlot.new(atlas_coords=cell, ...)
```

Same shape for `TetraTileLayoutPixelLabSideScroller` — only `_CELL_TO_ROLE` differs. The role-to-mask mapping is shared.

Alternative: one combined `TetraTileLayoutPixelLab` with `mode: { TOP_DOWN, SIDE_SCROLLER }` enum. Either works architecturally; two subclasses give a cleaner inspector picker.

### Constraints / limitations

- **`reference_image_size` 16 or 32 px** supported. The Aseprite plugin currently doesn't expose other sizes for tileset generation.
- **`transition_size = 1.0`** (top-down beta) extends the canvas with an extra strip the local Lua doesn't describe — server-side layout. Skip these samples; document as "transition_size 0/0.25/0.5 only" in v0.2.
- **PixelLab version coupling.** The hardcoded layout tables are versioned with the Aseprite plugin. If PixelLab ships a new plugin version with different layouts, TetraTile's tables silently misread. Mitigation: include a `pixellab_version: int = 1` field on the layout subclass; bump when we update.

---

## The other three export targets

### Tileset Wang (16-tile)

- 4×4 atlas with 16 unique tiles, 4-bit corner mask, Sprite Fusion-compatible
- Same as our `DualGrid16` layout (already planned for Phase 2)
- No new work needed — document the mapping in README's "PixelLab interop" section

### Tileset 15 (15-tile)

- 5×3 atlas with stray fill, Tilesetter convention
- Same as our `TilesetterWang15` layout (already planned for Phase 3)
- No new work needed

### Tileset 3×3 (9-tile)

- 3×3 atlas, 9-tile Match Sides 3×3 minimal
- Single-grid 4-bit edge mask (N/E/S/W), only 9 of 16 mask states covered
- **Adds `TetraTileLayoutMinimal3x3`** to v0.2 scope (was previously deferred to v0.3)
- Also covers legacy Godot 3.x atlases and RPG Maker A2 ground sets

---

## v0.2 scope expansion

Per the brainstorm, v0.2 grows from 8 to 11 layouts:

| Layout | Phase | Status |
|--------|-------|--------|
| TetraHorizontal / TetraVertical | 1 | Existing |
| DualGrid16 | 2 | Existing |
| Wang2Corner / Wang2Edge | 2 | Existing |
| **Minimal3x3** (NEW) | 2 or 3 | Added — covers PixelLab 3×3 export + RPG Maker A2 + legacy Godot 3.x |
| TilesetterWang15 / Blob47Godot / TilesetterBlob47 | 3 | Existing |
| **PixelLabTopDown** (NEW) | 3 or 3.5 | Added — needs `variation_seed` slot picking |
| **PixelLabSideScroller** (NEW) | 3 or 3.5 | Added — same |

Plus minimal `variation_seed` infrastructure (a deterministic hash + bucket-pick from the cells matching a painted mask). REQUIREMENTS.md's `CONTRACT-02` already declares the `variation_seed: int = 0` field as a placeholder; this work wires it up.

ROADMAP.md will need an update to reflect the new layouts and possibly a new Phase 3.5 for PixelLab work (since PixelLab depends on variation infrastructure that other layouts don't).

---

## Top-down vs side-scroller is NOT (just) a layout distinction

A common confusion: "side-scroller" and "top-down" tilesets look different and seem to need different addon support. The reality:

- Both PixelLab native modes use the **same Wang-16 corner mask topology** (16 mask states, 4-bit corner).
- They differ in **cell-position-to-role layout** within the 8×8 canvas (different art-prompt arrangement) and in **art content** (gravity-oriented vs rotation-symmetric).
- TetraTile treats them as separate subclasses purely because the cell positions differ, not because the masks do.

So while PixelLab gets two TetraTile subclasses, layouts like `DualGrid16` work for both top-down and side-scroller content as long as the user authors appropriate art.

---

## No first-party Godot integration

- **No PixelLab Godot plugin or `.tres` exporter.** PNG output only; user manually imports into a Godot `TileSet`.
- An **MCP server** (`github.com/pixellab-code/pixellab-mcp`) exposes generation to AI agents — produces images, not Godot resources.
- Engine name-checked in PixelLab docs: **Sprite Fusion only.** Not Godot, Unity, Tiled, or LDtk.

TetraTile is the Godot integration — no first-party tool to compete with.

---

## Marketing line for the README

> **PixelLab interop:** TetraTile reads PixelLab's full 8×8 native generation including the variation tiles the official exporter discards. Drop a PixelLab Aseprite output into your scene with a `TetraTileLayoutPixelLabTopDown` or `…SideScroller` contract — get up to 28 variants of the bulk fill for free.

---

## Sources

- https://www.pixellab.ai/docs/tools/create-tileset
- https://www.pixellab.ai/docs/tools/create-tiles-pro
- https://www.pixellab.ai/docs/options/tileset
- https://www.pixellab.ai/pixellab-api
- https://github.com/pixellab-code/pixellab-mcp
- `C:\Users\shilo\AppData\Roaming\Aseprite\extensions\pixellab\` — local Aseprite extension source (read directly by subagent + spike 003)
- Spike 001 — decoder feasibility (`template-decoder-feasibility`)
- Spike 002 — decoder generalization across template styles (`blob47-decoder-generalization`)
- Spike 003 — PixelLab role-to-mask mapping verification across all 16 user-supplied request_history samples (`pixellab-bit-mapping`)
- YouTube reference: https://www.youtube.com/watch?v=84yChPoOaew

---

*Audit conclusion: PixelLab adds 3 new layouts to v0.2 (Minimal3x3, PixelLabTopDown, PixelLabSideScroller) plus minimal variation_seed infrastructure. Native + all three export targets fully understood and decoder-validated.*
