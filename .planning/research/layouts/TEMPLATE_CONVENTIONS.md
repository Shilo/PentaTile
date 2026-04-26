# Template Conventions — Prior Art Synthesis

**Researched:** 2026-04-25 (parallel subagents on Godot terrain docs, Better Terrain, dandeliondino terrain-docs)
**Status:** Reference for the v0.2 decoder design — feeds Phase 1 CONTEXT.md
**Confidence:** HIGH on dandeliondino templates (decoded programmatically, tile counts verified vs PDF body text); HIGH on Better Terrain (source-read); HIGH on Godot (already documented in `GODOT_TERRAIN.md`).

> Companion to `.planning/research/layouts/GODOT_TERRAIN.md` (the stock-terrain reference) and `.planning/spikes/001-template-decoder-feasibility/README.md` (the decoder feasibility validation).

---

## 1. dandeliondino's terrain-docs templates — the load-bearing reference

Repo: https://github.com/dandeliondino/godot-4-tileset-terrains-docs (CC BY 3.0). Carries the orphaned Godot docs PR `godot-docs#7789` plus four reference template images at 64 × 64 px tile size.

### Universal encoding rule

Every tile in every template draws **9 sub-regions** as a Godot-inspector-style bitmask preview:

```
   TL  T  TR
   L   C   R
   BL  B  BR
```

Each sub-region is either **blue** (`#478cbf`, peering bit set) or **white** (empty). Light-grey grid lines mark slot boundaries.

- **Marker placement is fixed by mode.** Corner-mode templates only mark TL/TR/BL/BR (and C). Sides-mode only marks T/R/B/L (and C). Corners-and-sides marks all 8 + C.
- **Center is always blue** except for the one explicit "fully empty" tile present in `template_corners` and `template_corners_and_sides` (representing "this cell has no terrain set").
- **Color palette is binary** per region — no per-terrain colors in the printed templates. Inspector overlays the user's chosen terrain color at edit time.

### The four reference templates

| File | Atlas | Tiles | Mode | Marker pattern |
|------|-------|-------|------|----------------|
| `template_sides.png` | 4×4 @ 64 px (256×256) | 16 | Match Sides | C + 4 edge midpoints (T/R/B/L). All 2⁴ = 16 combinations. |
| `template_corners.png` | 4×4 @ 64 px (256×256) | 16 | Match Corners (connected layout) | C + 4 corners (TL/TR/BL/BR). All 2⁴ = 16 combinations. |
| `template_corners_alt.png` | 5×3 @ 64 px (320×192) | 15 | Match Corners (outside/inside-corner) | Same encoding — 15 tiles, blank omitted. **This is the layout most public tilesheets ship (Kenney, etc.).** |
| `template_corners_and_sides.png` | 12×4 @ 64 px (768×256) | 47 + 1 blank = 48 | Match Corners and Sides | C + 4 corners + 4 edges. The canonical "blob 47" set. |

### Canonical tile counts per mode

- **Match Sides:** 16 (2⁴ — every combination is reachable)
- **Match Corners:** 16 connected, OR 15 in the outside-corner-layout convention
- **Match Corners and Sides:** 47 + 1 blank = 48 (256 raw masks, only 47 reachable since corners require both adjacent sides)

### Terminology used by the Godot-doc PDF

- "bitmask" = the per-tile peering record
- "center bit" + "peering bits" — explicitly two concepts; center is the tile's identity, peering bits are neighbor expectations
- "Match Sides", "Match Corners", "Match Corners and Sides" — the three modes
- Does **NOT** use "blob", "wang", or "decarpeting" — that's external community vocabulary

---

## 2. Better Terrain (Portponky) — the click-driven peering-bit territory to avoid

Repo: https://github.com/Portponky/better-terrain. **4,158 LOC GDScript** across 9 files (~16× larger than TetraTile v0.1.0). 60% is editor-side UI for click-painting peering bits.

### Key takeaways

- **No template-image authoring exists in Better Terrain.** Every peering bit is assigned by clicking a polygon overlay on each tile. Validates that template-image decoding is genuinely orthogonal prior art.
- **Match modes:** `MATCH_TILES` (sides + corners; replaces Godot's blob47), `MATCH_VERTICES` (corners only; replaces Godot's wang-corner), `CATEGORY` (abstract grouping; never placed), `DECORATION` (sparse overlay tiles, treated as empty by other terrains).
- **Stores peering as `Object.set_meta` Dictionary** keyed by `CellNeighbor` integers (0–15). Each direction holds an Array of accepted terrain IDs (multi-match). Avoids Godot's native peering-bit fields.
- **Symmetry types:** `NONE / MIRROR / FLIP / REFLECT / ROTATE_CW / ROTATE_CCW / ROTATE_180 / ALL / ROTATE_ALL`. Useful design reference if TetraTile ever surfaces explicit symmetry per slot — but TetraTile's "rotation-reuse via TRANSFORM_FLIP_*" already covers this implicitly for the Tetra layouts.
- **README quote:** stock Godot terrains have "tricky behaviors", are "quite slow", and the API "is difficult to use at runtime."

### What TetraTile borrows (zero, deliberately)

Better Terrain is exactly what `PROJECT.md`'s identity guardrail warns against: peering tries, watcher/signal infrastructure, ~1,000 LOC editor dock. The `CATEGORY` and `DECORATION` concepts are interesting parking-lot items for v0.3+ multi-terrain work, but nothing here imports into v0.2 scope.

---

## 3. Godot 4.6 stock terrains — the baseline

Already covered in `GODOT_TERRAIN.md`. Key facts relevant to the decoder:

- **Center is implicit** via `TileData.terrain` (the tile's identity field). No clickable center polygon. The center bit is "this terrain", set automatically once `terrain_set` + `terrain` are assigned.
- **`MATCH_SIDES` has disputed semantics** — issue #79411 still open as of fetch, no PR, no maintainer fix. Community guidance is to prefer `MATCH_CORNERS_AND_SIDES` or `MATCH_CORNERS`; avoid `MATCH_SIDES`.
- **Authoring burden:** 376+ click-bits per terrain for a single 47-tile blob set. This is the headline pain TetraTile attacks.

---

## 4. Synthesis for TetraTile's decoder

### Adopt dandeliondino's marker geometry verbatim

- 9-region sample plan (1 center + 4 corners + 4 edges) at fixed positions.
- White/blue/grey palette, BUT TetraTile decodes by **alpha** rather than by exact blue match — this lets users paint over the templates with any opaque color while preserving the encoding.
- **Center can be ignored by TetraTile.** Per the user's stated intuition (and consistent with the dual-grid logic): if any peering bit is set, the cell is filled; if no peering bits are set, mask = 0 = no draw. We don't need to author or decode a center bit.

So the TetraTile decoder samples **8 anchors per slot** (not 9): 4 corner-quadrant centers + 4 edge midpoints. Layout subclass declares which subset matters.

### Per-layout sample subset

| Layout | Sampled anchors | Why |
|--------|-----------------|-----|
| TetraHorizontal / TetraVertical | 4 corners | Mask is 4-bit corner (TL/TR/BL/BR) |
| DualGrid16 | 4 corners | Same — dual-grid corner mask |
| Wang2Corner | 4 corners | CR31 corner naming, same physical anchors |
| Wang2Edge | 4 edges | Mask is 4-bit edge (N/E/S/W) |
| Blob47Godot / TilesetterBlob47 | 4 corners + 4 edges | 8-bit blob mask |
| TilesetterWang15 | 4 corners | Tilesetter's authored convention is corner-mask |

The 8-anchor sampler covers every planned v0.2 layout. Tile count derivation falls out from each layout's `compute_mask` topology.

---

## 5. Dual-grid vs single-grid — the distinction TetraTile must surface

**TetraTile v0.1 is dual-grid.** Logic cells live at the layer level; visual cells are offset by half a tile, so display cells live at 4-corner intersections of logic cells. The mask at each display cell is computed from the 4 surrounding logic cells.

**Most layouts in v0.2 are NOT dual-grid.** Wang-edge, Wang-corner (in the CR31 single-grid convention), Blob47 — all of these compute the mask from a logic cell's OWN neighbors (4 sides for Wang-edge; 4 corners for Wang-corner; 8 for Blob47), and the painted tile lives at the SAME coordinate as the logic cell.

### Classification of the 8 planned v0.2 layouts

| Layout | Mask | Grid model |
|--------|------|------------|
| TetraHorizontal | 4-bit corner | **Dual-grid** (v0.1 inheritance) |
| TetraVertical | 4-bit corner | **Dual-grid** (v0.1 inheritance) |
| DualGrid16 | 4-bit corner | **Dual-grid** (the "DG16" name is literal) |
| Wang2Corner | 4-bit corner | Single-grid |
| Wang2Edge | 4-bit edge | Single-grid |
| TilesetterWang15 | 4-bit corner | Single-grid |
| Blob47Godot | 8-bit blob | Single-grid |
| TilesetterBlob47 | 8-bit blob | Single-grid |

3 of 8 dual-grid; 5 of 8 single-grid.

### Cannot be auto-detected

- Mask topology doesn't determine grid model — both DualGrid16 (dual) and Wang2Corner (single) use 4-bit corner masks.
- Template visuals are identical for the two cases.
- Conclusion: **the layout subclass must declare its grid model explicitly.**

### Recommended API

```gdscript
# tetra_tile_layout.gd  (base)
@export var description: String = ""
# ... existing exports ...

func is_dual_grid() -> bool:
    push_error("TetraTileLayout subclass must override is_dual_grid()")
    return false

func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    push_error(...)
    return 0

func mask_to_atlas(mask: int) -> AtlasSlot:
    push_error(...)
    return null
```

`is_dual_grid()` (or equivalent property) is a virtual on the base class. Subclasses override with a single literal return. Inspector doesn't need to expose it as a per-instance toggle — it's an architectural decision baked into the layout subclass.

### Architectural impact on TetraTileMapLayer

`_update_cells()` needs two paint pipelines:

1. **Dual-grid (existing v0.1):** for each logic cell that changed, mark the 4 surrounding display cells as affected, paint each display cell with mask = 4-corner-OR of logic-cell occupancy.
2. **Single-grid (new):** for each logic cell that changed, mark itself + its neighbors (4 or 8, depending on layout topology) as affected, paint each affected logic cell with mask = `layout.compute_mask(cell, has_logic_fn)` directly to the visual layer (no half-tile offset).

The layer's `_resolve_layout()` reads `layout.is_dual_grid()` and routes accordingly. The two pipelines share the erase + `_pick_alternative` infrastructure but differ in (a) which cells are affected by a given logic-cell change, (b) where the visual tile is painted (display cell vs logic cell), and (c) whether the diagonal-overlay layer is needed (single-grid layouts encode all states explicitly so masks 6/9 don't need composition).

This is a real expansion of `tetra_tile_map_layer.gd`. Probably +60–80 LOC for the single-grid pipeline. Still well under TileMapDual's surface area.

---

## 6. What this means for Phase 1

The base `TetraTileLayout` Resource needs at minimum:

- `compute_mask(coord, sample_fn) -> int` virtual
- `mask_to_atlas(mask) -> AtlasSlot` virtual
- `is_dual_grid() -> bool` virtual
- `template_image: Texture2D` export
- `fallback_tile_set: TileSet` export
- `description: String` export
- (Optional, for the auto-decoder) `decoder_image: Texture2D` export — when null, the addon decodes from `template_image`; when set, the user's explicit decoder overrides

`TetraTileLayoutTetraHorizontal` and `TetraTileLayoutTetraVertical` (Phase 1 deliverables) both override `is_dual_grid()` to return `true`. Their `compute_mask` is the existing 4-bit corner OR; their `mask_to_atlas` produces the 16-state table (with rotation reuse encoded via `transform_flags` on the AtlasSlot).

Phase 1 must ship the dual-grid pipeline (that's just preserving v0.1's behavior under the new architecture). The single-grid pipeline can ship in Phase 1 OR Phase 2 — Phase 2's first single-grid layout (DualGrid16 doesn't count, it's also dual-grid; first true single-grid is Wang2Corner) is when the pipeline is genuinely needed.

### Recommendation: ship single-grid pipeline in Phase 1

Even though no Phase-1 layout uses single-grid, shipping the pipeline now means Phase 2's three layouts are pure subclass adds with no `tetra_tile_map_layer.gd` changes. Phase 1 stays the load-bearing architecture phase; Phases 2/3 stay layout-only.

---

## 7. Decoder rules — finalized after this synthesis

The decoder samples **up to 8 anchors per slot** (4 corners + 4 edges; center ignored):

```
Corner anchors (TL, TR, BL, BR):
  position = (quarter, quarter), (tile-quarter-1, quarter),
             (quarter, tile-quarter-1), (tile-quarter-1, tile-quarter-1)
  where quarter = tile // 4

Edge anchors (N, E, S, W):
  position = (half-1, 2), (tile-3, half-1),
             (half-1, tile-3), (2, half-1)
  where half = tile // 2
```

Each anchor: 3×3 majority vote on alpha-opacity (≥5 of 9 pixels with alpha > threshold = bit set). Layout subclass declares which subset of {TL, TR, BL, BR, N, E, S, W} are bits in its mask.

Performance (extrapolating from spike 001): ≤1 ms decode for any v0.2 atlas, runs once at Resource load.

---

*Reference document. Read alongside `GODOT_TERRAIN.md` (Godot's stock-terrain mechanics) and `MASK_UNIFICATION.md` (the polymorphic-Resource architecture choice).*
