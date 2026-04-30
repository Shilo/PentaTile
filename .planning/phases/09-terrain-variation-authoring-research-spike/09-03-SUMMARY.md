---
phase: 09-terrain-variation-authoring-research-spike
plan: 03
subsystem: architecture
tags: [godot, terrain, variation, autotile, multi-terrain, TileData, terrain-sets, slope, VirtuMap]

# Dependency graph
requires:
  - phase: 09
    provides: Wave 1 Godot/addon research (09-RESEARCH-GODOT.md — Godot native, TileMapDual, TileBitTools, BetterTerrain terrain + variation architectures)
  - phase: 09
    provides: Wave 1 external editor research (09-RESEARCH-EXTERNAL.md — Tiled, LDtk, RPG Maker autotile conventions)
  - phase: 09
    provides: User context and design decisions (09-CONTEXT.md — D-01 through D-06)

provides:
  - Formal architecture recommendation for PentaTile multi-terrain and variation support
  - PentaTileTerrainGroup Resource design for grouping N layouts per terrain type
  - Terrain identity model via penta_terrain_id custom data layer with Godot TileData.terrain auto-detection
  - Hot-path dispatch design preserving O(1) mask_to_atlas while adding terrain awareness
  - Slope handling architecture as 3-state terrain within existing mask pipeline
  - Atlas passthrough design for VirtuMap decorations/fixtures
  - Godot terrain sets PDF analysis extracted and factored into recommendation
  - Implementation blueprint across 6 phases (~440 LOC estimated)
  - Identity guardrail compliance verification

affects: [virtumap-integration, terrain-implementation-phase, variation-implementation-phase]

# Tech tracking
tech-stack:
  added: [PentaTileTerrainGroup (proposed), penta_terrain_id custom data layer, PentaTileLayoutSlope (proposed)]
  patterns: [terrain-id-per-cell, transient-terrain-index, auto-detection-with-manual-override, per-terrain-layout-grouping]

key-files:
  created: [.planning/phases/09-terrain-variation-authoring-research-spike/09-ARCHITECTURE-RECOMMENDATION.md]

key-decisions:
  - "TerrainGroup co-owns layouts: one PentaTileTerrainGroup holds N PentaTileLayout instances (one per terrain) with boundary-transition rules"
  - "Custom data layer penta_terrain_id stores per-cell terrain identity, auto-detected from Godot TileData.terrain on -1"
  - "Transient terrain index rebuilt on setter, never persisted — no watcher/signal-fanout needed"
  - "Hot-path unchanged: O(1) mask_to_atlas with pre-built index, no trie walk, no per-cell scoring loop"
  - "Godot terrain solver confirmed editor-only C++ with zero GDScript API — PentaTile must run its own solver"
  - "Slopes as standard PentaTileLayout subclass with 3-state (empty/floor/wall) mask computation"
  - "VirtuMap integration: 6 PentaTileMapLayer nodes collapse to 1 with terrain group"
  - "Option B (TerrainGroup) selected over Option C (BetterTerrain-style scoring) and Option D (TileMapDual-style trie) for minimal surface area"

patterns-established:
  - "Terrain identity prefix: penta_terrain_id follows existing penta_role/penta_lock_rotation custom data layer convention"
  - "Auto-detection fallback chain: custom data → TileData.terrain → default(0)"
  - "Transient index pattern: built on setter, discarded on change, zero cache invalidation"

requirements-completed: [D-03, D-04, D-05, D-06]

# Metrics
duration: 35min
completed: 2026-04-30
---

# Phase 9 Plan 3: Architecture Synthesis Summary

**Formal architecture recommendation for PentaTile multi-terrain and variation support — introduces PentaTileTerrainGroup, per-cell terrain IDs via custom data layers, and a transient terrain index that preserves the existing O(1) hot-path**

## Performance

- **Duration:** 35 min
- **Started:** 2026-04-30T16:40:00Z
- **Completed:** 2026-04-30T17:15:00Z
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments

- Synthesized all Wave 1 research findings (Godot/addon + external editor audits) into one cohesive architecture document
- Extracted and factored the complete 42-page Godot terrain sets PDF specification into the recommendation
- Designed `PentaTileTerrainGroup` — a lightweight Resource that groups N `PentaTileLayout` instances (one per terrain) with boundary-transition overrides
- Defined per-cell terrain identity via `penta_terrain_id` custom data layer with Godot `TileData.terrain` auto-detection fallback
- Preserved the existing hot-path architecture: O(1) `mask_to_atlas` lookup, no trie walk, no per-cell scoring loop, no watchers
- Addressed VirtuMap's specific integration requirements: slope handling, multi-terrain on one layer, atlas passthrough
- Estimated implementation at ~440 LOC across 6 phases — well within PentaTile's identity budget
- Verified identity guardrail compliance across all 8 guardrail dimensions

## Task Commits

Each task was committed atomically:

1. **Task 1: Draft formal architecture recommendation** — `84a2484` (feat)

## Files Created/Modified

- `.planning/phases/09-terrain-variation-authoring-research-spike/09-ARCHITECTURE-RECOMMENDATION.md` (564 lines) — Complete architecture recommendation covering: problem space, Godot terrain sets API analysis, external architecture comparison (TileMapDual, BetterTerrain, TileBitTools, Tiled, LDtk, RPG Maker), proposed PentaTileTerrainGroup design, per-cell terrain identity model, terrain index building, runtime dispatch, variation handling, slope architecture, atlas passthrough, dual vs single grid considerations, identity guardrail compliance, alternative comparison (Options A-D), implementation blueprint (6 phases), VirtuMap integration path, risks/mitigations, and appendices with PDF extractions and Phase 8 cross-reference

## Decisions Made

1. **TerrainGroup over multiple layer nodes** — one `PentaTileTerrainGroup` groups N layouts on a single PentaTileMapLayer rather than creating N separate PentaTileMapLayer nodes. Reduces VirtuMap's node count 6→1 while enabling cross-terrain transitions.

2. **Custom data layer for terrain IDs** — `penta_terrain_id` follows the existing `penta_role`/`penta_lock_rotation` convention. Falls back to Godot's native `TileData.terrain` when unset (-1). No new `@export` properties needed on the node.

3. **Transient index, no watchers** — The terrain index maps terrain_id → (layout, tile_list) and is rebuilt on `terrain_group` setter. Never persisted, never cached — zero invalidation complexity. Directly contradicts TileMapDual's watcher/signal-fanout pattern.

4. **Mask-to-atlas dispatch preserved** — The hot path stays `compute_mask → mask_to_atlas → set_cell`. Terrain resolution adds ~15 lines to determine which layout's atlas slot to use. No trie walk, no scoring loop, no per-cell linear scan of candidates.

5. **Godot solver is editor-only — confirmed by PDF** — The 42-page `terrain_sets_docs.pdf` confirms Godot's terrain resolution is C++ editor code with zero GDScript API. PentaTile was architecturally correct to bypass it from v0.1.

6. **Option B selected over C and D** — BetterTerrain's scoring-based solver (Option C) conflicts with hot-path minimalism identity guardrail. TileMapDual's trie (Option D) requires watcher infrastructure. TerrainGroup (Option B) adds the smallest surface area (~125 runtime LOC).

7. **Slopes as standard layout subclass** — `PentaTileLayoutSlope` extends the base layout with 3-state (empty/floor/wall) mask computation. No separate solver, no special pipeline. Standard `mask_to_atlas` 16-entry table handles 3-state dispatch.

8. **Atlas passthrough for decorations** — `set_cell_passthrough()` marks cells with `penta_passthrough = true` custom data, skipping the autotile solver. VirtuMap's fixtures/decorations bypass terrain dispatch entirely.

## Deviations from Plan

None — plan executed exactly as written. The single task (synthesize architecture recommendation) was completed in one atomic commit with all acceptance criteria and verification checks passing.

## Issues Encountered

- **PDF extraction failure (PyPDF2 not installed):** Initial attempt to programmatically read `terrain_sets_docs.pdf` failed due to missing PyPDF2 library. Resolved by installing PyMuPDF (fitz) which was pre-available, extracting all 42 pages of text. Godot's terrain sets specification was fully extracted and factored into the recommendation.
- **All findings successfully cross-referenced:** Wave 1 research (Godot/addons + external editors) and the PDF specification produced no contradictions — all sources agree on the key architectural facts (Godot solver editor-only, peering bits as neighbor-match language, probability for weighted variation, terrain sets as transition groups).

## Next Phase Readiness

This architecture recommendation is **ready for user review**. Before production implementation can be planned:

1. **User-side Godot terrain testing needed** — the user must manually paint multi-terrain sets in the Godot editor to validate peering bit behavior and confirm the editor-only solver limitation
2. **VirtuMap adapter spike** — verify that the proposed `penta_terrain_id` custom data layer works with VirtuMap's existing render batch pipeline
3. **Slope layout feasibility** — verify that 3-state corner-mask computation correctly dispatches to VirtuMap's existing slope tiles

The implementation blueprint (6 phases, ~440 LOC) is gated on these three confirmations. The architecture itself is fully specified and identity-guardrail-compliant.

---

*Plan: 09-03*
*Completed: 2026-04-30*
