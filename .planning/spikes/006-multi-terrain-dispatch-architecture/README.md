---
spike: 006
name: multi-terrain-dispatch-architecture
type: standard
validates: "Given an atlas with 3+ terrain strips (Floor/Wall/Hull), when a paint call specifies a terrain ID, then the correct strip is selected per-cell and neighboring cells' terrain IDs inform the mask computation"
verdict: VALIDATED
related: [004, 007]
tags: [multi-terrain, dispatch, strip, terrain-id, precedence, multi-strip]
---

# Spike 006: Multi-Terrain Dispatch Architecture

## What This Validates

**Given** a painted logic cell that carries a terrain ID (e.g., `set_cell(coord, source, Vector2i(slot, TERRAIN))` where `TERRAIN=0=Floor, 1=Wall, 2=Hull`),
**When** `_update_cells()` dispatches that cell through the layout's `compute_mask()` and `mask_to_atlas()`,
**Then** the correct terrain strip is selected, neighbor cells of different terrain types correctly inform the mask, and the visual output shows terrain boundaries at the right positions.

## Research

### Approach Comparison

| Approach | Pros | Cons | Loc Delta | Verdict |
|----------|------|------|-----------|---------|
| **A: One PentaTileMapLayer per terrain** | Zero new code; works today. Each terrain has its own layer, layout, and dual-grid offset. | Explodes node count (6 terrains → 6 layers per canonical VirtuMap layer). Cross-terrain mask computation must run across layers (non-trivial). | 0 | **Fallback only** |
| **B: Single layer + atlas_coords.y encoding** | Uses existing AUTO_STRIP per-strip dispatch. Terrain = strip index. Simple mental model. | Every terrain must share the SAME mask topology (all Penta or all DualGrid16). Cross-terrain transitions only work if strips share a visual language. | +80 LOC | **Chosen v0.3** |
| **C: Godot terrain metadata as dispatch key** | Leverages existing TileSet terrain peering bits. Authoring uses Godot's terrain editor. | Requires Godot terrain peering bit authoring (what PentaTile was designed to AVOID). Breaks the "no manual bitmask" promise. | +200 LOC | **v0.4+ only** |
| **D: Layout-per-terrain with shared strip dispatch** | Each terrain can have its OWN layout (Wall=Penta, Floor=DualGrid16, Slope=SlopeLayout). Maximum flexibility. | Requires layout-per-terrain mapping, multi-layout dispatch, and cross-layout mask composition. Most complex. | +400 LOC | **v0.4+** |

**Chosen approach: B (atlas_coords.y encoding)** for v0.3 initial multi-terrain support.

### Architecture Design

#### Model B: Terrain-as-Strip-Index

The logic layer paints cells with `atlas_coords = Vector2i(slot, terrain_id)`:
- `atlas_coords.x` = slot (which archetype tile in the strip)
- `atlas_coords.y` = terrain ID (Floor=0, Wall=1, Hull=2, Slope=3, etc.)

The PentaTileLayout's `resolve_display_strip(coord, sample_fn)` samples neighbors to determine which strip (terrain) the visual cell belongs to. For multi-terrain, this function gains a `strip_index` parameter:

```gdscript
func compute_mask(coord: Vector2i, sample_fn: Callable, strip_index: int = 0) -> int:
    # Sample only neighbors that belong to the SAME strip_index
    # or coerce cross-terrain boundaries in a terrain-specific way
    var mask := 0
    for corner in _CORNERS:
        var neighbor_coord := coord + CORNER_OFFSETS[corner]
        var neighbor_data := sample_fn.call(neighbor_coord)
        if neighbor_data and neighbor_data.has("atlas_coords"):
            # Only count this corner as "filled" if neighbor shares terrain
            if neighbor_data["atlas_coords"].y == strip_index:
                mask |= (1 << corner)
    return mask
```

#### Strip Index Injection

The existing `_update_cells()` pipeline already has `resolve_display_strip()` for AUTO_STRIP. For multi-terrain, two changes:

1. **`set_cell()` stores terrain ID**: The `atlas_coords.y` encodes the terrain. On `set_cell(logic_coord, source, Vector2i(slot, terrain))`, the terrain index is read during `_paint_via_layout()`.

2. **`compute_mask()` receives strip_index**: The mask computation uses the terrain strip to filter which neighbor cells contribute to the mask. A Floor cell ignores Wall neighbors (they're different terrain), so the Floor/Wall boundary produces correct edge masks on each side.

#### Penta PentaTileLayoutPenta Multi-Terrain

For Penta layouts specifically, multi-terrain means each terrain has its own Penta strip:

```
Atlas layout (HORIZONTAL, 5 slots × 3 terrains):
         Col 0       Col 1       Col 2       Col 3       Col 4
Row 0: [Floor-Iso] [Floor-Fill] [Floor-Bor] [Floor-InC] [Floor-OpC]
Row 1: [Wall-Iso]  [Wall-Fill]  [Wall-Bor]  [Wall-InC]  [Wall-OpC]
Row 2: [Hull-Iso]  [Hull-Fill]  [Hull-Bor]  [Hull-InC]  [Hull-OpC]
```

AUTO_STRIP auto-detects 3 strips (rows 0, 1, 2), each with 5 slots. The terrain ID maps directly to strip index.

#### Dual-Grid Multi-Terrain

Dual-grid adds complexity: each display cell's 4 corners may come from different terrain strips. Example: a display cell at the boundary between Wall (top-left) and Floor (bottom-right):

```
Logic coords:        Display cell at offset:
[Wall]  [Wall]        ┌──────┬──────┐
                      │ Wall │ Wall │
[Wall]  [Floor]       ├──────┼──────┤
                      │ Wall │Floor │
                      └──────┴──────┘
```

The display cell's 4 corners sample: TL=Wall(strip1), TR=Wall(strip1), BL=Wall(strip1), BR=Floor(strip0). This produces mask 7 (InnerCorner) for the Wall strip AND mask 1 (OuterCorner) for the Floor strip. Two tiles must be painted: the Wall tile on the visual layer (top priority) and the Floor tile below it.

**This is the precedence group problem.**

For v0.3 (Model B), the simple solution: the display cell renders the tile from the HIGHEST-PRECEDENCE terrain strip. Wall (precedence=2) paints over Floor (precedence=1). The Floor tile at that cell is simply not rendered — the Wall tile covers it. This is acceptable because:
- Wall always paints OVER floor (physical correctness)
- Hull always paints OVER wall
- Fixture/decor always paints OVER structure

The precedence information comes from the layout's `terrain_precedence` array: `[0, 1, 2]` means Floor=0, Wall=1, Hull=2.

### Key Decision: Terrain Boundary Masking

When two cells of different terrain types are neighbors, should the mask computation see the neighbor as "filled" or "empty"?

**Rule: Each terrain only sees same-terrain cells as "filled".** A Wall cell next to a Floor cell sees the Floor as "empty" — the Wall renders its own edge tiles at the boundary. The Floor also sees the Wall as "empty" and renders ITS edge tiles. This produces clean boundaries on both sides.

Exception: **Slope terrain** may use information from the parent terrain (e.g., a Slope cell uses the Floor cell's fill state to determine the slope direction). This is a layout-specific override.

### What PentaTileMapLayer Must Change

Current: `_paint_via_layout(display_cell, ...)` → `layout.compute_mask(display_cell, sample_fn)` → `layout.mask_to_atlas(mask)`

New: `_paint_via_layout(display_cell, ...)` → `layout.compute_mask(display_cell, sample_fn, strip_index)` → `layout.mask_to_atlas(mask, strip_index)`

Where `strip_index` comes from:
1. For single-grid: the painted logic cell's `atlas_coords.y`
2. For dual-grid: the highest-precedence terrain among the 4 corner neighbors (for the display cell)

#### Precedence Resolution (Dual-Grid)

```gdscript
func _resolve_precedence_strip(display_cell: Vector2i, sample_fn: Callable, layout: PentaTileLayout) -> int:
    var terrains := []
    var offsets := [Vector2i(0,0), Vector2i(0,-1), Vector2i(-1,-1), Vector2i(-1,0)]
    for offset in offsets:
        var logic_coord := display_cell + offset
        var cell_data := sample_fn.call(logic_coord)
        if cell_data and cell_data.has("atlas_coords"):
            terrains.append(cell_data["atlas_coords"].y)
    if terrains.is_empty():
        return 0
    # Return the terrain with highest precedence
    var precedence := layout.terrain_precedence if layout.has_method("terrain_precedence") else [0]
    var best_terrain := terrains[0]
    var best_prec := precedence[best_terrain] if best_terrain < precedence.size() else 0
    for t in terrains:
        var tp := precedence[t] if t < precedence.size() else 0
        if tp > best_prec:
            best_prec = tp
            best_terrain = t
    return best_terrain
```

## Investigation Trail

### Iteration 1: One-Layer-Per-Terrain (Approach A)

Tested: 6 PentaTileMapLayer nodes, each with a PentaLayoutPenta(axis=HORIZONTAL, tile_count=ONE). Each layer has one terrain Penta tile.

Problem: Cross-terrain mask computation can't work across layers. Each layer's `compute_mask()` only sees its own cells. A Wall layer next to a Floor layer doesn't produce the right Wall edge. Viable only for the simplest cases.

### Iteration 2: Strip-as-Terrain (Approach B)

Tested: Single PentaTileMapLayer with atlas_coords.y = terrain_index. Works for single-grid layouts (Wang2Edge, Min3x3, etc.) because each cell's mask is computed independently from same-layer neighbors.

**Discovery:** PentaTileLayoutPenta's AUTO_STRIP already handles per-strip mask computation via `resolve_display_strip()`. The terrain-to-strip mapping is a natural extension — just parameterize `compute_mask()` with the strip index.

### Iteration 3: Single-Grid First

Tested with Wang2Edge layout across 3 terrains (Floor, Wall, Hull). Important finding: single-grid multi-terrain works with MINIMAL changes because `_mark_affected_single_grid_cells()` already marks the cell + 8 Moore neighbors. The `compute_mask()` just needs to filter neighbors by terrain.

### Iteration 4: Cross-Terrain Mask Filtering

The critical design question: what does mask computation look like when neighbors are different terrains?

Test pattern: Wall cell at (1,1), Floor cell at (1,2). Wall sees Floor as empty → Wall's mask = 12 (top edge). Floor sees Wall as empty → Floor's mask = 3 (bottom edge). Both render correctly — the boundary is clean.

Edge case: Wall cell at (1,1) with Floor at (1,1) too? Can't happen — only one cell at each logic coordinate. Dual-grid display cells may have mixed terrain corners, handled by precedence resolution.

## Results

### Verdict: VALIDATED

Multi-terrain dispatch is feasible via the atlas_coords.y = terrain_index encoding with cross-terrain mask filtering. Three implementation milestones:

| Milestone | Scope | Complexity | LOC |
|---|---|---|---|
| v0.3: Single-grid multi-terrain | Terrain-as-strip for Wang2Edge, Wang2Corner, Min3x3, Blob47Godot. Cross-terrain mask filtering. | 4/10 | +80 |
| v0.3: Penta multi-terrain banks | Terrain-per-strip for PentaTileLayoutPenta. Existing AUTO_STRIP handles per-strip dispatch. | 3/10 | +30 |
| v0.4: Dual-grid multi-terrain | Precedence groups for DualGrid16. Multiple visual layers. | 7/10 | +150 |

### What feeds into Phase 9

Phase 9 (Terrain + Variation Authoring Research Spike) should:
1. Use atlas_coords.y = terrain_index as the terrain encoding mechanism
2. Implement cross-terrain mask filtering (same-terrain-only corner sampling)
3. Test with 2-3 terrains on single-grid layouts first
4. Design the `compute_mask(coord, sample_fn, strip_index=0)` signature extension
5. Implement precedence groups only after single-grid multi-terrain is validated
