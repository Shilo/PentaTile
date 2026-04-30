# Phase 09: Terrain + Variation Authoring Research Spike - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Research how Godot natively, TileMapDual, TileBitTools, and BetterTerrain handle multi-terrain and variations. Figure out the optimal approach to support multiple terrains, variations, and atlases per PentaTileMapLayer across all layout systems (dual grid and single grid). The solution should be intuitive but not heavily restricted, addressing the current limitation of a single `bitmask_template` image preventing multi-terrain/variations. Additionally, heavily research third-party map editors (Tiled, LDtk, RPG Maker) to find the most optimal approach.

</domain>

<decisions>
## Implementation Decisions

### Research Scope & Focus Areas
- **D-01:** Exhaustively research Godot native tilesets, TileMapDual, TileBitTools, and BetterTerrain on their approach to terrains and variations.
- **D-02:** Investigate third-party editors (Tiled, LDtk, RPG Maker) exhaustively for how they handle multiple terrains and variations.
- **D-03:** The proposed solution MUST support multiple terrains, variations, and atlases per `PentaTileMapLayer`.
- **D-04:** The approach MUST work across ALL layout systems (both dual grid and single grid).
- **D-05:** Evaluate ways to automatically detect configurations while still allowing optional customization for extra power/flexibility (unlike native Godot which explicitly sets terrain/variations per tile).
- **D-06:** Address the integration requirements outlined in VirtuMap's `PentaTile_Integration_Research.md` (multi-terrain support, slope handling, atlas passthrough).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Research & Integration Context
- `C:\Programming_Files\Shilocity\VirtuMap\.planning\references\PentaTile_Integration_Research.md` — VirtuMap integration research, detailing multi-terrain and slope requirements.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-MULTI-TERRAIN-RESEARCH.md` — Prior focused multi-terrain research.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-RESEARCH-TRIAGE.md` — Initial triage artifact containing broader competitive research.
- `https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html` — Godot 4 TileMap documentation.
- `https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html` — Godot 4 TileSet documentation.

### External Codebases for Research
- `C:\Programming_Files\Godot\TileMapDual` — TileMapDual source code.
- `C:\Programming_Files\Godot\tile_bit_tools` — TileBitTools source code.
- `C:\Programming_Files\Godot\better-terrain` — BetterTerrain source code.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PentaTileMapLayer` — Current logic/visual layer separation.
- `PentaTileLayout` — Current base layout resource that forces a single `bitmask_template`.

### Established Patterns
- Single-grid vs Dual-grid dispatch pipelines (currently hardcoded to one atlas/layout per layer).

</code_context>

<specifics>
## Specific Ideas

- The current design forces a certain layout based on `bitmask_template` and restricts multiple terrains/variations. We need a creative way to handle this automatically detected while allowing optional customization.
- Must consider VirtuMap's use case where multiple terrain sets (Floor, Wall, Hull, Slope, Platform, Beam) exist and need to be handled.
- Compare how Godot explicitly sets terrain/variations per tile versus how PentaTile can automatically detect this but still offer per-tile manual overrides for extra power/flexibility.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
