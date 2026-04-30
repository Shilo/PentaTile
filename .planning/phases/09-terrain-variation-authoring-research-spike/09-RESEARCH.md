# Phase 09: Terrain + Variation Authoring Research Spike - Technical Research

## Objective
Determine how to effectively plan and structure the research spike defined in Phase 9.

## Findings
Since Phase 9 is a pure research spike with no production implementation, the execution phase will involve heavy reading, web searching, and synthesis rather than code modification. 

To prevent context exhaustion and ensure exhaustive coverage (as requested in `D-01` and `D-02`), the planning must break the research down into parallelizable or distinct sequential domains.

The target domains are:
1. **Godot Native:** `TileData` terrains, `probability`, variations, explicit setter APIs.
2. **Godot Addons:** 
   - `TileMapDual` (`C:\Programming_Files\Godot\TileMapDual`)
   - `tile_bit_tools` (`C:\Programming_Files\Godot\tile_bit_tools`)
   - `better-terrain` (`C:\Programming_Files\Godot\better-terrain`)
3. **External Editors:** Tiled, LDtk, RPG Maker.
4. **Integration & Architecture Synthesis:** Combining the findings into a viable architecture for `PentaTileMapLayer` that fulfills VirtuMap's slope/multi-terrain requirements.

## Planning Directives
- **Plan 1: Godot & Addons Analysis**
  - Task 1: Audit Godot Native TileMap/TileSet docs for terrain and variation APIs.
  - Task 2: Audit TileMapDual source.
  - Task 3: Audit TileBitTools source.
  - Task 4: Audit BetterTerrain source.
  - Output: `09-RESEARCH-GODOT.md`
- **Plan 2: External Editors Analysis**
  - Task 1: Research Tiled's Wang sets and terrains.
  - Task 2: Research LDtk's Auto-layer rules.
  - Task 3: Research RPG Maker's Autotile format.
  - Output: `09-RESEARCH-EXTERNAL.md`
- **Plan 3: Architecture Synthesis**
  - Task 1: Combine findings from Plan 1 and Plan 2.
  - Task 2: Design the optimal multi-terrain and variation architecture for PentaTile.
  - Output: `09-ARCHITECTURE-RECOMMENDATION.md`
