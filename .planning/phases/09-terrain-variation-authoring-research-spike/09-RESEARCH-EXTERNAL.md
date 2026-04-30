# Phase 09 Plan 02: External Editors Analysis

**Researched:** 2026-04-30
**Objective:** Exhaustively research external industry-standard map editors (Tiled, LDtk, RPG Maker) for how they handle terrain types, autotiling, and random variation — with an eye toward what PentaTile can adapt for its own multi-terrain and variation authoring model.

---

## Tiled Map Editor

**Version analyzed:** Tiled 1.12 (current stable), with historical context back to Tiled 0.9
**Source:** Official documentation at https://doc.mapeditor.org/en/stable/manual/terrain/

### Historical Evolution: Wang Sets → Unified Terrain Sets

Tiled has supported autotiling since version 0.9 (2009) with a feature called "Terrains." In version 1.1 (2014), it added a parallel "Wang Sets" feature (named after Hao Wang's 1961 mathematical tiles). These two features co-existed for years. **In Tiled 1.5 (2020), they were unified into a single "Terrain Sets" system**, with the Wang Set XML format becoming the canonical storage mechanism. The `<terraintypes>` element was deprecated; `<wangsets>` is the modern storage format.

### Wang Sets vs Terrains — The Difference

**Pre-1.5 (Tiled 1.1 through 1.4):** Tiled had two separate autotiling systems:

- **Terrains (introduced 0.9):** A simpler concept — the user defines terrain types (e.g., "grass," "dirt") and "marks" the corners of tiles to indicate which terrain they represent. The Terrain Brush then auto-selects tiles whose corner markings match the painted pattern. Terrains always operated on corners only and supported up to 254 terrain types in a single set.

- **Wang Sets (introduced 1.1):** A more mathematical approach based on Wang tile theory. Wang Sets explicitly separated corner colors from edge colors, used a 32-bit integer `wangid` to encode the corner/edge colors of each tile, and supported up to 15 colors. Wang Sets were conceptually more rigorous (matching the mathematical Wang tile model) but were limited to 15 colors due to the 32-bit integer encoding.

**Post-1.5 (Tiled 1.5+, current):** The two systems were merged:
- Wang Sets became the canonical data model (stored as `<wangsets>` in `.tsx` files)
- The UI was simplified to present a unified "Terrain Sets" experience
- The 15-color limit was lifted to 254 (using comma-separated values instead of packed integers)
- Corner-only, edge-only, and mixed-mode sets are all supported under the unified system
- The term "Terrain" in the modern Tiled UI refers to what was previously called a "Wang color" — a named, colored property that can be assigned to tile corners and/or edges

### How Terrain Sets Work

A **Terrain Set** is a collection of terrains (e.g., "grass," "dirt," "sand," "water") that share transition rules. Each tile in the tileset is *marked* — its corners and/or edges are painted with terrain colors — to tell the editor which terrain regions each tile can represent.

Tiled supports three types of Terrain Sets:

| Set Type | Match Rule | Complete Set Size (2 terrains) | Use Case |
|----------|-----------|-------------------------------|----------|
| **Corner Set** | Tiles must match neighboring tiles at their **corners** (4 corners × 2 terrain possibilities = 16 tiles) | 16 tiles | Organic ground transitions (grass → dirt → sand), blob-style autotiling |
| **Edge Set** | Tiles must match neighboring tiles at their **edges/sides** (4 edges × 2 terrain possibilities = 16 tiles) | 16 tiles | Roads, fences, platforms — linear boundary features |
| **Mixed Set** | Tiles match on **both corners AND edges** | 256 tiles (complete), reduced blob set = 47 tiles | Complex transitions; the 47-tile "Blob" tileset from BorisTheBrave uses this type |

A Terrain Set can contain **up to 254 terrains**. Marking is per-corner and/or per-edge — each corner of a tile can be assigned exactly one terrain type.

### Multi-Terrain Architecture

Tiled's model for multiple biomes/terrains has several key properties:

1. **All terrains that transition to each other MUST be in the same Terrain Set.** This is a hard constraint — if "grass" and "dirt" transition to each other, they must be in the same set.

2. **Terrain Sets are per-tileset, NOT per-layer.** A single tileset can have multiple Terrain Sets (e.g., "Ground," "Forest Decorations," "Walls"), but tiles can only belong to one set.

3. **This means: if you have separate terrain biomes that NEVER transition to each other (e.g., "desert" and "ice"), they go in separate Terrain Sets.** The editor treats them as independent — painting with one set doesn't affect cells painted by the other set.

4. **The Terrain Brush automatically adjusts neighboring tiles** when painting new terrain over existing terrain, ensuring correct transitions. If a direct transition doesn't exist (e.g., dirt → cobblestone when only dirt→sand and sand→cobblestone exist), the tool inserts intermediate transitions automatically.

5. **Empty tiles don't need an explicit terrain label.** Tiles that transition to "nothing" (transparent/empty) simply leave those corners unmarked. The engine treats unmarked corners as "empty" terrain that connects to nothing.

### Terrain-to-Tile Solving

The solving algorithm works by:
- When the user paints with a terrain, the engine scans the painted cell's neighbors
- It computes the required corner/edge pattern (what terrain must appear at each corner/edge to satisfy adjacency)
- It looks up which tiles in the Terrain Set have matching terrain marking at those corners/edges
- If multiple tiles match, one is selected (using probability weighting — see below)

### Variation Handling

Tiled has a **probability-based variation system** that operates at two levels:

1. **Terrain-Level Probability:** Each terrain type in a set has a `Probability` property (default: 1.0). When multiple terrains are valid for a position (rare, but possible in complex sets), the terrain with higher probability is favored.

2. **Tile-Level Probability:** Each individual tile has its own `Probability` property (default: 1.0). The *relative probability* of a tile = `tile.probability × product of probabilities of terrains at each marked corner/side`.

3. **Probability = 0 disables a tile** from being auto-selected, but the tile's terrain markings are *still considered* when determining transitions for neighboring cells. This is critical — a tile with probability 0 exists as a "reference tile" that tells the solver what's possible, but is never actually placed.

4. **Decorations as low-probability variations:** A common pattern is to mark decorative tiles (bushes, rocks) as "sand" terrain and set their probability to 0.01. They become rare random scatter that blends seamlessly into the base terrain.

5. **Terrain Fill Mode:** The Stamp Brush, Bucket Fill, and Shape Fill tools have a "Terrain Fill Mode" where:
   - Each cell is randomly chosen from all matching tiles in the set
   - Adjacent edges/corners are always matched (no visual breaks)
   - Internal cells are completely randomized
   - Already-existing tiles with the same terrain are re-randomized with different variations (if multiple variations exist)

### Tile Transformations as Variation Source

Tiled can **automatically flip and rotate tiles** to create additional variations:

| Transformation Option | Effect |
|----------------------|--------|
| **Flip Horizontally** | Mirrors tiles left-right during placement |
| **Flip Vertically** | Mirrors tiles top-bottom during placement |
| **Rotate** | Rotates tiles by 90°, 180°, or 270° during placement |
| **Prefer Untransformed Tiles** | When enabled, original tiles take precedence over transformed variants |

With rotations enabled, the 47-tile Blob tileset can be reduced to **only 15 base tiles** — the engine derives the other 32 through transformation. This is conceptually equivalent to PentaTile's `TRANSFORM_FLIP_H | FLIP_V | TRANSPOSE` bit-flags on alternative tile IDs.

### Patterns View

Tiled's "Patterns" view shows all possible corner/edge combinations for a Terrain Set, darkening patterns that already have a matching tile and highlighting missing ones. This helps tileset authors ensure complete coverage without manually enumerating all possibilities. A set does NOT need to have all patterns — for 3+ terrains, the combinatorial space is huge, and authors intentionally leave certain transitions unsupported.

### Key Insights for PentaTile

1. **Tiled's Terrain Set = a self-contained "transition group."** In PentaTile terms, this maps well to a single `PentaTileLayout` + `TileSet` combination — each layout could support multiple terrains that transition to each other.

2. **Probability for variations uses multiplicative weighting** (tile probability × terrain probability). PentaTile can adopt the same approach but with deterministic hashing instead of `randi()` — the `rand_weighted` approach from the existing variation seed system.

3. **Probability=0 as "reference only" tiles** is an elegant pattern. PentaTile could support this via a `penta_skip` custom data flag — the tile still participates in mask computation but is never selected by the variant picker.

4. **Tile transformations for variation** (flip/rotate) mirror PentaTile's existing dual-grid transform dispatch. The concept of "prefer untransformed" could become a layout-level flag.

5. **The 254-terrain limit** is generous and unlikely to constrain any practical Godot tileset.
