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

---

## LDtk Auto-layers

**Version analyzed:** LDtk 1.5.x (current)
**Source:** Official documentation at https://ldtk.io/docs/general/auto-layers/

### Architecture: Two-Layer Separation

LDtk's autotiling has a fundamentally different architecture from Tiled and PentaTile. It **separates the logic layer from the visual layer**:

1. **IntGrid Layer (logic/source):** A grid of integer values (0, 1, 2, 3, ...). Each value has a custom color and a name (e.g., 1 = "walls," 2 = "water," 3 = "grass"). This is where the user *paints* — they assign grid cells to IntGrid values using left-click draw, right-click erase, Shift+drag for rectangles, and Shift+click for fill. This is conceptually identical to PentaTile's logic layer (the hidden `TileMapLayer` with `self_modulate.a = 0`).

2. **Auto-Layer (visual/destination):** A distinct layer type that contains *rules* mapping IntGrid value patterns to tiles from a linked Tileset. The auto-layer does NOT store its own cell data — it reads the IntGrid layer and renders tiles according to the matched rules.

LDtk supports two auto-layer deployment modes:
- **IntGrid layer with rules (combined):** A single layer that stores both the IntGrid values AND the auto-tile rules. This is the simpler, more common setup — everything lives in one layer.
- **Pure auto-layer (separated):** A distinct layer that only contains rules, reading its source data from a *separate* IntGrid layer. This allows rendering multiple visual layers (foreground, background, decoration) from a single IntGrid source — the "one logic source, multiple visual outputs" pattern.

This architecture is the **exact mirror** of PentaTile's current design: LDtk separates the source layer (user-painted IntGrid) from the visual render; PentaTile separates the visual render (visible TileMapLayer) from the hidden logic layer. Both approaches achieve the same goal — user paints one thing, visual output is automated — but the layer ownership is flipped (PentaTile: logic layer is hidden; LDtk: logic layer is the primary interaction surface).

### How Auto-Layer Rules Work

Rules are **grid patterns** that test a cell's IntGrid value against its 3×3 Moore neighborhood. Each rule says: "If the pattern matches, paint this specific tile." Rules are organized into **Rule Groups**, which execute in priority order.

**Rule structure:**
- **Pattern:** A 3×3 grid centered on the target cell. Each of the 9 cells is assigned one of three states:
  - **Required (white):** The cell MUST have this IntGrid value
  - **Forbidden (red/X):** The cell MUST NOT have this IntGrid value
  - **Ignored (empty):** The cell's value doesn't matter (wildcard)
- **Output tile:** The specific tileset tile to paint when the pattern matches
- **Per-tile transforms:** Rules can optionally specify flip/rotate on the output tile (LDtk 1.3+)

**Rule execution model:**
- Rules within a group are evaluated top-to-bottom
- The **first matching rule wins** — later rules are not checked
- If no rule matches, the cell is left empty (or inherits from a default tile if configured)
- Multiple rule groups can coexist on the same layer
- The "Render" toggle (Shift+R) shows/hides auto-layer output to reveal the raw IntGrid values underneath

**Example rules for a simple walls autotile:**
- Rule 1: "If center = walls AND top neighbor ≠ walls → paint wall-top-edge tile"
- Rule 2: "If center = walls AND bottom neighbor ≠ walls → paint wall-bottom-edge tile"
- Rule 3: "If center = walls → paint solid wall tile"

With these rules, when the user paints wall IntGrid values, the auto-layer automatically paints the correct edge tiles for the top and bottom of walls, with solid fill elsewhere.

### Multi-Terrain Separation via IntGrid Values

In LDtk, **different terrains/biomes are represented by different IntGrid values.** For example:
- `1` = wall/stone terrain → triggers wall tiles via one rule group
- `2` = grass terrain → triggers grass tiles via a different rule group
- `3` = water terrain → triggers water tiles via another rule group

Each IntGrid value gets its own **rule group.** The rule groups don't automatically interact — painting value `1` in one area and value `2` in an adjacent area does NOT automatically create transition tiles between them.

**Cross-terrain transitions require explicit user-authored rules.** For example, to create a grass-to-water edge:
- "If center = 2 (grass) AND right neighbor = 3 (water) → paint grass-edge-right tile"

This is simultaneously:
- **More flexible:** The user has complete control over EVERY transition; no unwanted automatic interpolation
- **More laborious:** Every transition must be explicitly authored; there's no "auto-compute transition tiles" equivalent to Tiled's terrain solver

**Workaround for large multi-terrain sets:** LDtk users typically create one rule group per terrain (e.g., "Grass Rules," "Water Rules," "Wall Rules") and use the "pure auto-layer" pattern — a single IntGrid layer stores terrain IDs, and multiple separate auto-layers each handle one terrain's visual rendering. This keeps rule groups small and manageable.

### Variation Handling

LDtk's variation system is based on **manual stamp/random mode** via the tile picker:

1. **Stamp Mode:** The user selects a rectangle of tiles from the tileset. Clicking places the exact selection as a stamp — no randomization. This is for deliberate, authored tile placement.

2. **Random Mode (press R key to toggle):** The user selects a rectangle of tiles from the tileset. Clicking paints tiles randomly from within that rectangle. This is LDtk's primary variation mechanism — the user defines a "variation pool" by selecting a region of tiles, and LDtk randomly picks from that pool.

3. **Per-cell re-randomization on re-paint:** When using random mode, painting over an existing tile replaces it with a new random pick from the pool. The previous tile choice is not preserved — each paint operation is independent.

4. **No probability weighting:** Unlike Tiled, LDtk does NOT support per-tile probability values. Every tile in the selected rectangle has equal chance of being picked. If the user wants some variations more common than others, they must include duplicate entries in the tileset.

5. **No automatic variation inference:** LDtk doesn't "know" which tiles are variations of the same terrain. The random pool is explicitly defined by the user's selection rectangle. Terrain identity comes from the IntGrid value, not from the tileset.

6. **No built-in animation support for tiles:** LDtk doesn't have animated tile frames like RPG Maker's A1 slot. Animation must be handled through external tooling or the game engine.

### Key Insights for PentaTile

1. **LDtk's IntGrid = a potential model for PentaTile's custom data layer.** PentaTile already uses `TileSet.custom_data_layers` for `penta_role` and `penta_lock_rotation`. Extending this to support user-defined terrain IDs (e.g., `penta_terrain = 1` for grass, `2` for water) would directly mirror the IntGrid approach. The user paints tiles with `penta_terrain = 1` and PentaTile's solver dispatches to the correct terrain-specific layout/atlas.

2. **The "pure auto-layer" pattern** (separate logic source → multiple visual outputs) is architecturally elegant for multi-terrain support WITHOUT requiring all terrains to be in one TileSet. Each terrain could have its own visual TileMapLayer reading from the shared logic layer. This maps naturally to PentaTile's existing two-layer design scaled to N visual layers.

3. **Rule-based dispatch is more flexible but higher authoring cost** than Tiled's terrain sets. For PentaTile's target audience ("works in my game"), a Tiled-style terrain set model with automatic transition computation is more appropriate than LDtk-style manual rule authoring.

4. **Random mode via rectangular selection** is simpler than Tiled's probability system but less granular. PentaTile's existing `rand_weighted` deterministic hash approach is closer to Tiled's probability model and offers better control.

5. **The Shift+R "toggle render" pattern** (see raw IntGrid data behind auto-layer output) is a strong UX feature for debugging. PentaTile's logic layer is already toggleable via `logic_layer_opacity` — this could be surfaced as an explicit debug toggle.

6. **LDtk's Rule Groups naturally partition by terrain type.** If PentaTile adopted a terrain-ID model, each terrain's transition rules would map to a dedicated `PentaTileLayout` (one per terrain), with the solver handling cross-terrain dispatch.

### Detailed Rule-Matching System for Multi-Terrain Handling

LDtk's rule engine processes each cell independently through these steps:

1. **Read the cell's IntGrid value** from the source layer
2. **Find the Rule Group** that handles this IntGrid value
3. **Evaluate rules top-to-bottom** within that group:
   - For each rule, check the 3×3 pattern against the actual IntGrid values of the cell's neighbors
   - Each neighbor cell is tested: REQUIRED (must equal the specified value), FORBIDDEN (must NOT equal the specified value), or IGNORED (any value accepted)
   - Pattern matching supports multiple IntGrid values in the same pattern (e.g., "left neighbor = 1 AND right neighbor = 2")
4. **First matching rule fires** — its output tile is painted; remaining rules in the group are skipped
5. **If no rule matches** and the group has a "default tile," that tile is painted; otherwise the cell remains empty

**Multi-terrain dispatch example:**
Given IntGrid values: 1=Wall, 2=Grass, 3=Water
- Rule Group "Walls" (handles value 1):
  - Rule: center=1 AND top≠1 → paint wall-top-edge tile
  - Rule: center=1 AND bottom≠1 → paint wall-bottom-edge tile
  - Rule: center=1 AND top=1 AND bottom=1 AND left=1 AND right=1 → paint wall-fill tile
- Rule Group "Grass" (handles value 2):
  - Rule: center=2 AND top=1 → paint grass-to-wall-top edge tile (explicitly authored cross-terrain rule)
  - Rule: center=2 AND top=3 → paint grass-to-water-top edge tile
  - Rule: center=2 → paint grass-fill tile

This design means the user must explicitly define every cross-terrain transition — there is no automatic "grass adjacent to wall means grass-edge tile" inference.

### Complexity Comparison

| Aspect | LDtk | Tiled |
|--------|------|-------|
| Rule authoring scope | Per IntGrid value (terrain) | Per Terrain Set (transition group) |
| Cross-terrain transitions | Manual (user defines rules) | Automatic (engine computes from terrain markings) |
| Number of rules for 3 terrains | ~20-30 explicit rules | 0 — engine auto-computes from markings |
| Learning curve | Steep (understand pattern logic) | Moderate (mark corners/edges) |
| Debug support | Shift+R toggle to see raw data | Patterns view shows coverage gaps |
| Flexibility | Very high (any custom behavior) | Constrained by terrain set type |

