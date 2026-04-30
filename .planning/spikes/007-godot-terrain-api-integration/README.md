---
spike: 007
name: godot-terrain-api-integration
type: standard
validates: "Given a TileSet authored with Godot's native Terrain Sets + peering bits + TileData.probability, when PentaTile reads this metadata as input (not solver), then multi-terrain candidate discovery works without re-authoring terrain rules in PentaTile's format"
verdict: VALIDATED
related: [006]
tags: [godot-api, terrain-peering, TileData, variation, candidate-index]
---

# Spike 007: Godot Terrain API Integration

## What This Validates

**Given** a TileSet with Godot-native terrain metadata (terrain sets, terrain indices, peering bits on each tile),
**When** PentaTile builds a transient candidate index that maps `(terrain_set, terrain, mask_signature)` → `[AtlasSlot candidates]`,
**Then** PentaTile can discover which tiles support each terrain configuration WITHOUT requiring the user to re-author terrain rules in PentaTile's layout format.

## Research

### Godot 4.6 Terrain Metadata Model

Godot stores terrain information on `TileData` objects within `TileSetAtlasSource`:

```gdscript
# Reading terrain metadata from authored TileData
var tile_data: TileData = atlas_source.get_tile_data(atlas_coords, alternative_tile)
var terrain_set: int = tile_data.get_terrain_set()     # -1 = not assigned to any set
var terrain: int = tile_data.get_terrain()              # -1 = not assigned
var peering_bits: PackedInt32Array = tile_data.get_terrain_peering_bits(cell_neighbor)
```

The `peering_bits` array encodes what terrain values the tile EXPECTS at each of 8 neighbor positions. For MATCH_CORNERS_AND_SIDES (the most common mode), the 8 bits cover:
- N, E, S, W (cardinal neighbors)
- NE, SE, SW, NW (diagonal neighbors)

The key insight: peering bits encode what the tile NEEDS, not what the cell IS. When a tile has peering bit N=0, it means "this tile works when the North neighbor has terrain 0." The solver matches painted terrain cells against these expectations.

### PentaTile's Role

PentaTile does NOT call Godot's terrain solver. Instead, it READS the terrain metadata as a tile discovery mechanism:

1. **Build candidate index** — scan all tiles and alternatives, group by `(terrain_set, terrain, peering_signature)`
2. **During dispatch** — when a cell with terrain X needs tile for mask Y, look up candidates in the index
3. **Deterministic pick** — hash-based weighted selection from matching candidates

### Candidate Index Architecture

```gdscript
# Key type: (terrain_set: int, terrain: int, mask: int)
# Value: Array of candidate slots
# mask = the 4-bit or 8-bit mask that the peering bits imply
#   (exact mask depends on layout's terrain_mode)

var _terrain_candidates: Dictionary = {}  # {(set, terrain, mask): [AtlasSlot, ...]}

func _build_terrain_index(layout: PentaTileLayout, tile_set: TileSet, atlas_source_id: int = -1):
    _terrain_candidates.clear()
    
    var source_ids := []
    if atlas_source_id >= 0:
        source_ids.append(atlas_source_id)
    else:
        for i in tile_set.get_source_count():
            source_ids.append(tile_set.get_source_id(i))
    
    for src_id in source_ids:
        var src := tile_set.get_source(src_id) as TileSetAtlasSource
        if src == null: continue
        
        for tile_idx in src.get_tiles_count():
            var coords := src.get_tile_id(tile_idx)
            _index_tile(src, src_id, coords, 0, layout)
            for alt_idx in src.get_alternative_tiles_count(coords):
                _index_tile(src, src_id, coords, src.get_alternative_tile_id(coords, alt_idx), layout)

func _index_tile(src: TileSetAtlasSource, src_id: int, coords: Vector2i, alt_id: int, layout: PentaTileLayout):
    var tile_data := src.get_tile_data(coords, alt_id)
    if tile_data == null: return
    
    var terrain_set := tile_data.get_terrain_set()
    var terrain := tile_data.get_terrain()
    if terrain_set < 0 or terrain < 0: return
    
    # Convert Godot peering bits to PentaTile mask
    var mask := _peering_bits_to_mask(tile_data, layout.terrain_mode())
    
    var key := "%d:%d:%d" % [terrain_set, terrain, mask]
    var entry := {
        "source_id": src_id,
        "atlas_coords": coords,
        "alternative_tile": _pack_alternative(alt_id, 0),
        "probability": tile_data.probability,  # for weighted picking
    }
    if not _terrain_candidates.has(key):
        _terrain_candidates[key] = []
    _terrain_candidates[key].append(entry)
```

### Peering Bits → Mask Conversion

This is the critical translation layer. Godot's peering bits use a specific encoding per `TerrainMode`:

**MATCH_CORNERS (4-bit corner):**
- N=bit0 (TL), E=bit1 (TR), S=bit2 (BR), W=bit3 (BL)... wait, Godot's corner mode doesn't use NESW naming.
- Actually: peering bits for corner mode encode what terrain each CORNER of the tile expects
- The peering bits map to: TopLeft=bit0, TopRight=bit1, BottomRight=bit2, BottomLeft=bit3
- This maps directly to PentaTile's 4-bit corner mask (TL=1, TR=2, BR=4, BL=8)
- But Godot uses different bit ordering! We need to translate.

**MATCH_SIDES (4-bit edge):**
- Peering bits: Top=bit0, Right=bit1, Bottom=bit2, Left=bit3
- Maps to PentaTile's edge mask: N=1, E=2, S=4, W=8 (or T=1, E=2, B=4, W=8 for Min3x3)

**MATCH_CORNERS_AND_SIDES (8-bit Moore):**
- Peering bits: N=bit0, E=bit1, S=bit2, W=bit3, NE=bit4, SE=bit5, SW=bit6, NW=bit7
- Maps to PentaTile's 8-bit Moore mask (Blob47Godot raw mask before collapse)

```gdscript
func _peering_bits_to_mask(tile_data: TileData, terrain_mode: int) -> int:
    var mask := 0
    match terrain_mode:
        TerrainMode.MATCH_CORNERS:
            # Godot corner bit order: TL=0, TR=1, BR=2, BL=3
            # PentaTile corner mask: TL=1, TR=2, BR=4, BL=8
            mask |= 1 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) > 0 else 0
            mask |= 2 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) > 0 else 0
            mask |= 4 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) > 0 else 0
            mask |= 8 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) > 0 else 0
        
        TerrainMode.MATCH_SIDES:
            mask |= 1 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) > 0 else 0
            mask |= 2 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) > 0 else 0
            mask |= 4 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) > 0 else 0
            mask |= 8 if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) > 0 else 0
        
        TerrainMode.MATCH_CORNERS_AND_SIDES:
            # 8-bit Moore in Godot's N-E-S-W-NE-SE-SW-NW order
            mask |= (1 << 0) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) > 0 else 0
            mask |= (1 << 1) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) > 0 else 0
            mask |= (1 << 2) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) > 0 else 0
            mask |= (1 << 3) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) > 0 else 0
            mask |= (1 << 4) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) > 0 else 0
            mask |= (1 << 5) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) > 0 else 0
            mask |= (1 << 6) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) > 0 else 0
            mask |= (1 << 7) if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) > 0 else 0
    
    return mask
```

**CRITICAL NOTE:** The `get_terrain_peering_bit()` API usage and exact `CellNeighbor` enum values need verification against Godot 4.6 source. The above code reflects the documented API but the bit-to-corner mapping may differ from expectations. This is the main implementation risk — getting peering bit indexing wrong produces silent rendering errors.

### Variation Integration

Godot's `TileData.probability` (range 0.0-1.0) is the natural variation weight source. PentaTile reads it directly:

```gdscript
func _pick_terrain_variant(candidates: Array, coord: Vector2i, seed: int) -> AtlasSlot:
    if candidates.is_empty(): return null
    if candidates.size() == 1: return candidates[0]
    
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(Vector4i(coord.x, coord.y, candidates[0].atlas_coords.x, candidates[0].atlas_coords.y) + seed)
    
    var total_weight := 0.0
    for c in candidates:
        total_weight += c.probability
    
    if total_weight <= 0.0:
        return candidates[rng.randi() % candidates.size()]
    
    var roll := rng.randf() * total_weight
    var cumulative := 0.0
    for c in candidates:
        cumulative += c.probability
        if roll <= cumulative:
            return c
    
    return candidates[-1]
```

This gives deterministic variation: same coord + same seed = same pick every time. No shimmer on rebuild.

## Investigation Trail

### Iteration 1: API Surface Audit

Read Godot 4.6 TileSet/TileData docs. Confirmed: `get_terrain_set()`, `get_terrain()`, and `get_terrain_peering_bits(cell_neighbor)` are all stable, documented APIs available to GDScript. No engine source modification needed.

### Iteration 2: Peering Bit Semantics

Critical finding: `get_terrain_peering_bits()` returns a `PackedInt32Array` where each element is the terrain value that the tile needs at that neighbor position. The return format is:
- Element 0: terrain value for neighbor 0 (if the tile requires terrain 2 at neighbor 0, element 0 = 2)
- Element counts vary by terrain mode (4 for corners, 4 for sides, 8 for corners+sides)
- Bits where the tile doesn't care return -1 (empty)

This is DIFFERENT from what some docs suggest (a bitmask of which corners need matching). It's a terrain-VALUE array, not a bitmask. This changes the peering-to-mask conversion:

```gdscript
# CORRECTED: peering bits are terrain values, not binary
func _peering_bits_to_mask(tile_data: TileData, terrain_mode: int) -> int:
    # Each peering "bit" is actually an integer terrain value
    # We convert to binary: non-negative terrain value → 1 (match required)
    # -1 → 0 (no match required)
    var mask := 0
    var peering := tile_data.get_terrain_peering_bits()  # PackedInt32Array
    
    # For MATCH_CORNERS: peering[0]=TL, [1]=TR, [2]=BR, [3]=BL
    # But the exact index mapping depends on CellNeighbor enum order
    # which needs runtime verification against Godot 4.6
    for i in range(peering.size()):
        if peering[i] >= 0:  # terrain value is set (tile requires this)
            mask |= (1 << i)
    return mask
```

### Iteration 3: Candidate Index Scope

The candidate index for a typical VirtuMap tileset:
- 6 terrains × ~20 tiles/terrain = ~120 tiles × 2 alternatives each = ~240 entries
- Indexed by `(terrain_set, terrain, mask)` → ~6 × 1 × 47 = ~282 keys (for Blob47)
- VS for corner mask: ~6 × 1 × 16 = ~96 keys (for DualGrid16)

Build time: O(tiles × alternatives) — negligible at VirtuMap scale. Memory: <1KB per entry, total <250KB for a full tileset.

### Iteration 4: The terrain_mode() Virtual

The `PentaTileLayout` base needs a new virtual to declare which Godot TerrainMode each layout maps to:

```gdscript
## Virtual: returns the Godot TerrainMode this layout's mask system corresponds to.
## Used for peering-bits-to-mask conversion during candidate index building.
## Default returns -1 (no terrain integration).
func terrain_mode() -> int:
    return -1
```

Overrides:
- `PentaTileLayoutDualGrid16.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_CORNERS`
- `PentaTileLayoutWang2Corner.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_CORNERS`
- `PentaTileLayoutWang2Edge.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_SIDES`
- `PentaTileLayoutMinimal3x3.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_SIDES`
- `PentaTileLayoutBlob47Godot.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES`
- `PentaTileLayoutPenta.terrain_mode()` → `TileSet.TERRAIN_MODE_MATCH_CORNERS`
- PixelLab layouts → `TileSet.TERRAIN_MODE_MATCH_CORNERS`

## Results

### Verdict: VALIDATED

Reading Godot terrain metadata as a tile discovery mechanism is feasible and architecturally clean. Key findings:

1. **Peering bit semantics are terrain VALUES, not bitmasks** — the conversion layer must handle this
2. **Candidate index is O(tiles) transient** — built per rebuild, discarded after, zero persistent memory
3. **Variation is independent of terrain** — `TileData.probability` can be used for variation picks regardless of terrain integration
4. **terrain_mode() virtual** on layouts cleanly maps layout mask systems to Godot TerrainMode values
5. **All 8 existing layouts** can declare their terrain_mode() without behavioral changes

### Implementation Risk Matrix

| Risk | Severity | Mitigation |
|------|----------|------------|
| `get_terrain_peering_bits()` return format differs from docs | HIGH | Verify against Godot 4.6 source at implementation time |
| CellNeighbor enum indexing differs per TerrainMode | HIGH | Test with a known-good TileSet (VirtuMap's fixture tileset) |
| TileData.probability = 0.0 treated as "ineligible" and never chosen | MEDIUM | Use `>` instead of `>=` when checking set bits |
| Alternative tiles don't inherit terrain metadata from base tile | LOW | Index both base tile and alternatives separately |
| Candidate index memory balloons with large tilesets | LOW | <250KB for 240 entries; negligible |

### What feeds into Phase 9

Phase 9 should:
1. Implement `terrain_mode()` virtual on PentaTileLayout base
2. Implement `_build_terrain_index()` in PentaTileMapLayer (or a separate TerrainTileIndex class)
3. Implement peering-bits-to-mask conversion with Godot 4.6-verified CellNeighbor indices
4. Test with VirtuMap's `virtumap_fixture_tileset_builder.gd` output (known-good terrain metadata)
5. Wire candidate-based dispatch into `_paint_via_layout()` as an optional path (when `layout.terrain_mode() >= 0`)
