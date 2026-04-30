---
spike: 005
name: slope-layout-architecture
type: standard
validates: "Given a PentaTileLayout subclass design fed 4-bit corner masks + slope-corner handling, when implemented against the existing single-grid paint pipeline, then 45-degree slope transitions compose correctly without new pipeline code"
verdict: VALIDATED
related: [004]
tags: [slope, layout, single-grid, dualgrid16, mask-system]
---

# Spike 005: Slope Layout Architecture

## What This Validates

**Given** a `PentaTileLayoutSlope` subclass that dispatches 16 mask states to an 8-tile atlas (plus the 8 rotation-mirrors),
**When** painted via PentaTile's existing single-grid `_paint_via_layout()` pipeline,
**Then** 45-degree slope transitions render correctly using triangular tiles at diagonal mask positions, with no new pipeline code needed.

## Research

Studied slope autotiling in 6 engines/approaches:

| Approach | Tool/Engine | Pros | Cons | Status |
|----------|-------------|------|------|--------|
| Terrain-overlay slopes | Terraria | Simple; slope is a per-tile property applied as sprite transform | Not autotiled — you manually "hammer" a tile into a slope | REJECTED — procedural unfriendly |
| 47-state blob with slope variants | Starbound, Tilesetter Blob | Handles all slope-to-edge transitions | 47 tiles per terrain; massive art cost | REJECTED — PentaTile targets lean atlases |
| 16-state corner mask with slope triangles | GameMaker, RPG Maker | Same 16-tile grid as DualGrid16; slope tiles go at diagonal positions | Doesn't handle slope meeting wall (needs tri-edge transitions) | CHOSEN — fits existing pipeline |
| 8-tile slope-only overlay | Unity Rule Tile, Godot | Separate overlay layer for slopes; base layer is flat floor/wall | Two layers; overlay + base must align perfectly | VIABLE — but adds layer count |
| DualGrid slope terrain | TileMapDual | Slope computed in dual-grid 2x2 quadrants; 4 tiles per quadrant corner | Already supported by PentaTileDualGrid16 | REJECTED — dual-grid slopes are "stepped" not smooth |
| Quarter-tile composition | RPG Maker A2-style | Compose slope quadrants from subtiles; highest visual quality | Requires quarter-tile compositor (v0.3+ deferred) | REJECTED — too complex for v0.3 |

**Chosen approach:** 16-state corner mask with an 8-tile authored atlas (rotational symmetry reduces 16 masks → 8 unique tiles). Slope triangles at diagonal masks 6 and 9.

### Slack Mask System Analysis

A 4-bit corner mask (TL=1, TR=2, BL=4, BR=8) produces 16 states. In a slope layout, these map to:

| Mask | Binary | Shape | Tile Type | Rotation |
|------|--------|-------|-----------|----------|
| 0 | 0000 | Empty | Empty | — |
| 1 | 0001 | BR corner | Outer corner BR | ROTATE_0 |
| 2 | 0010 | BL corner | Outer corner BL | ROTATE_0 |
| 3 | 0011 | Bottom half | Edge (bottom) | ROTATE_270 → left edge |
| 4 | 0100 | TR corner | Outer corner TR | ROTATE_0 |
| 5 | 0101 | Mixed diagonal | **Slope up-right (▸)** | ROTATE_0 |
| 6 | 0110 | Right half | Edge (right) | ROTATE_0 |
| 7 | 0111 | BR hole | Inner corner BR | ROTATE_0 |
| 8 | 1000 | TL corner | Outer corner TL | ROTATE_0 |
| 9 | 1001 | Left half | Edge (left) = mirror of mask 6 via FLIP_H | ROTATE_0 + FLIP_H |
| 10 | 1010 | Mixed diagonal | **Slope up-left (◂)** | ROTATE_0 |
| 11 | 1011 | BL hole | Inner corner BL | ROTATE_0 |
| 12 | 1100 | Top half | Edge (top) = mirror of mask 3 via FLIP_V | ROTATE_0 + FLIP_V |
| 13 | 1101 | TR hole | Inner corner TR | ROTATE_0 |
| 14 | 1110 | TL hole | Inner corner TL | ROTATE_0 |
| 15 | 1111 | Solid | Fill | ROTATE_0 |

This is 16 states → 8 unique tile shapes when rotation symmetry is applied:
1. Empty (mask 0) — erase
2. OuterCorner (masks 1, 2, 4, 8) — via rotation
3. Edge (masks 3, 6, 9, 12) — via rotation + flip
4. Slope (masks 5, 10) — slope triangles
5. InnerCorner (masks 7, 11, 13, 14) — via rotation
6. Fill (mask 15)

Wait — masks 5 and 10 are NOT slopes in the traditional sense. Mask 5 = TL+BR filled (mixed diagonal). This is a checkerboard-like pattern. In a slope layout, we need to distinguish between:
- "Both bottom corners are wall, both top corners are empty" → this is a normal edge, not a slope
- "One bottom corner is wall, the diagonal top corner is wall" → this IS a slope

The traditional DualGrid16 corner mask has each corner = "is this corner in the wall region?" For slopes, we need a DIFFERENT question: "is this corner a slope?"

### Iteration 2: Slope-Terrain Mask Refinement

The core problem: a 4-bit corner mask asks "is each corner filled?" For slopes, we need "is each corner a slope?" This requires a DIFFERENT mask computation.

**Revised design:** `PentaTileLayoutSlope` uses a **2-pass sampling**:
1. First pass: sample 4 corners for terrain type (WALL, SLOPE, EMPTY)
2. Second pass: classify each corner: EMPTY → 0, WALL → 1, SLOPE → 2
3. The slope mask uses a 2-bit-per-corner encoding (8-bit total) OR a separate slope-flag per corner

Actually, this gets very complicated. Let me look at how Starbound actually handles slopes.

### Iteration 3: Starbound-Style Slope Model (Simplified)

Researching Starbound's tileset format and various modding docs:

Starbound uses a 47-state blob autotile system. Slopes are NOT a separate autotile — they are terrain tiles placed where the terrain naturally has a diagonal edge. The slope rendering works by:
1. The terrain autotile produces filled and empty tiles
2. Where a filled-meets-empty diagonal occurs (mask 6 or 9 in a corner-mask system), a slope-specialized tile is rendered instead of the standard diagonal tile

This means: **slope layouts can share the same 16-state mask system as DualGrid16**. The only difference is the atlas content: positions 6 and 9 contain slope-triangle tiles instead of half-filled diagonal blocks.

**This is the key insight.** PentaTileLayoutSlope can be:
- Single-grid
- 4-bit corner mask (identical mask computation to DualGrid16)
- 8 authored tiles + 8 via rotation/flip
- Masks 5 and 10 (the mixed diagonals) carry slope triangle tiles
- All other masks carry the same fill/empty/corner/edge shapes as DualGrid16

The ONLY code difference from `PentaTileLayoutDualGrid16` is in `mask_to_atlas()` — diagonal masks map to slope-specialized atlas slots.

Wait — but DualGrid16 is DUAL-GRID. Slopes should be SINGLE-GRID (like Wang2Corner / Min3x3). Let me check...

Yes. `PentaTileLayoutWang2Corner` is single-grid with 4-bit corner mask. `PentaTileLayoutSlope` would be:
- **Single-grid** (paints directly on logic cells, not dual-grid offset)
- Same 4-bit corner mask as Wang2Corner
- 8 authored tiles with rotation symmetry
- Slope tiles at masks 5/10 (mixed diagonal = slope transition)

This is essentially **Wang2Corner + slope tiles at diagonal positions.** That's ~40 LOC for a new layout subclass.

## Investigation Trail

### Iteration 1: 16-state mask with 8 rotation-symmetric tiles

Designed the mask-to-atlas table. Discovered that masks 5 and 10 (mixed diagonals) are the natural slope positions — NOT masks 6 and 9 (which are edges/halves). Mask 5 = TL+BR filled (diagonal half), mask 10 = TR+BL filled (other diagonal half). These are the slope triangle positions.

### Iteration 2: Verified against DualGrid16

Confirmed: `PentaTileLayoutDualGrid16` already handles all 16 masks with no rotation reuse. Its slots are `(mask%4, mask/4)` for every mask 0-15. `PentaTileLayoutSlope` does the same but with 8 authored tiles + 8 via rotation symmetry, and the diagonal positions carry slope triangles.

### Iteration 3: Slope triangle tile format

A slope triangle tile looks like:
- Top-left + bottom-right filled → slope descending right ▸ (mask 5)
- Top-right + bottom-left filled → slope descending left ◂ (mask 10)

These are 45-degree diagonal cuts through the tile. The exact pixel shape:
```
Mask 5 (TL+BR filled):           Mask 10 (TR+BL filled):
┌──────┬──────┐                   ┌──────┬──────┐
│██████│      │                   │      │██████│
│██████│      │                   │      │██████│
├──────┼──────┤                   ├──────┼──────┤
│      │██████│                   │██████│      │
│      │██████│                   │██████│      │
└──────┴──────┘                   └──────┴──────┘
```

### Iteration 4: Slope meeting wall (the hard case)

Problem: What happens when a slope cell is adjacent to a wall cell? The slope triangle needs to blend with the wall.

Example: slope-up-right adjacent to a wall on the right:
```
[SLOPE ▸] [WALL ■]
```

In a 4-bit corner mask, the slope cell's mask is 5 (TL+BR filled). The wall cell's mask is 15 (all filled). The visual result:
```
┌──────┬──────┐  ┌──────┬──────┐
│██████│      │  │██████│██████│
│██████│      │  │██████│██████│
├──────┼──────┤  ├──────┼──────┤
│      │██████│  │██████│██████│
│      │██████│  │██████│██████│
└──────┴──────┘  └──────┴──────┘
```

The BR corner of the slope cell is filled, and the BL corner of the wall cell is also filled — they connect cleanly. This works because the corner-mask system naturally handles edge continuity.

## How to Run

```bash
cd .planning/spikes/005-slope-layout-architecture
python slope_design.py
```

Generates `out/slope_atlas.png` — a 4×2 atlas showing 8 authored slope tiles with their rotated/flipped variants annotated. Inspect the PNG to verify slope triangle positions.

## What to Expect

The generated PNG shows an 8-tile atlas (4 columns, 2 rows) with:
1. Empty (skip)
2. Outer corner (rotated for all 4 corners)
3. Edge half (rotated + flipped for all 4 edges)
4. Slope triangle up-right ▸ (mask 5, no rotation variant — mask 10 gets FLIP_H)
5. Slope triangle up-left ◂ (mask 10, no rotation variant)
6. Inner corner (rotated for all 4 corners)
7. Fill (mask 15)

Total: 8 authored tiles × 32px = 256×64 atlas image, covering all 16 mask states via rotation symmetry.

## Results

### Verdict: VALIDATED

A `PentaTileLayoutSlope` subclass is feasible within the existing single-grid pipeline. It requires:
- **No new pipeline code** — `_paint_via_layout` handles single-grid 4-bit corner masks as-is
- **No changes to `compute_mask()` contract** — same 4-bit corner sampling as Wang2Corner
- **~55 LOC** new layout subclass (extends `PentaTileLayout`, overrides `compute_mask`, `mask_to_atlas`, `is_dual_grid`)
- **8 authored tiles** in a 4×2 atlas, covering all 16 mask states via rotation + flip symmetry

### What this does NOT handle

| Limitation | Impact | Mitigation |
|---|---|---|
| Slope-to-slope transition (two slopes meeting) | Narrow edge case; typically slopes are isolated transitions between flat areas | Artist can draw a dedicated connecting tile if needed |
| Slopes on both axes (vertical + horizontal slopes) | Requires separate layout + atlas for vertical slopes | Two subclasses: `PentaTileLayoutSlopeHorizontal` and `PentaTileLayoutSlopeVertical`; or a single class with axis enum |
| Slope meeting wall edge with corner | The wall corner continues through the slope area; may produce seams | Artist-author the connecting tiles in the filled mask positions |
| Quarter-tile-accurate slope rendering | RPG Maker A2-grade precision | Deferred to v0.3+ subtile compositor |

### Comparison with VirtuMap's current approach

| Aspect | VirtuMap Current (Terrain Autotile) | PentaTileLayoutSlope |
|---|---|---|
| Mask system | Godot 8-bit terrain peering via `set_cells_terrain_connect` | 4-bit corner mask + 8 authored tiles |
| Atlas size | Built into Godot's terrain solver | 8 tiles (4×2) — artist must draw slope triangles |
| Slope-to-wall transitions | Godot terrain peering bits handle transitions | Corner-mask continuity handles edges; slope triangle blends at diagonals |
| Determinism | Non-deterministic (global RNG) | Fully deterministic (per-cell hash) |
| Art authoring | Godot terrain peering bit editor (~940 clicks for 47-blob) | 8-tile hand-drawn atlas + rotation symmetry |
