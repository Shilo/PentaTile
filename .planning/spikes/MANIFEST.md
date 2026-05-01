# Spike Manifest

## Idea

PentaTile v0.2.0 shipped 8 layouts plus synthesis and fallback routing. The next leap is a "highly complete" autotiling solution that supports multi-terrain, variation, slopes, and VirtuMap's procedural generation needs. These spikes research the feasibility, architecture, and concrete implementation path for every identified gap — producing verified knowledge that feeds directly into Phase 9 (terrain+variation research spike) and new roadmap items.

See `.planning/spikes/004-virtumap-integration-requirements/README.md` for the VirtuMap-driven origin of this spike cluster.

## Requirements

Design decisions emerging from spike findings — non-negotiable for the real build.

- **Atlas passthrough via source-ID gating**: Fixture/overlay cells painted with non-layout `source_id` skip autotiling and render to a dedicated `_PentaTilePassthrough` child layer at `Vector2.ZERO` offset (no dual-grid half-tile shift). Source-ID gate in `_update_cells()`. ~90 LOC. (Spike 004)
- **Terrain as atlas_coords.y encoding**: Multi-terrain dispatch uses `atlas_coords.y` as terrain strip index. `compute_mask(coord, sample_fn, strip_index)` filters neighbor sampling to same-terrain cells only. Dual-grid display cells use highest-precedence terrain among 4 corner neighbors. (Spike 006)
- **Slope layout: 16-state corner mask with 8 authored tiles**: `PentaTileLayoutSlope` (single-grid, 4-bit corner mask). Diagonals (masks 5, 10) carry slope triangle tiles. All other masks share same fill/empty/corner/edge shapes as DualGrid16 via rotation symmetry. 8 authored tiles cover all 16 states. ~55 LOC. (Spike 005)
- **Godot terrain metadata as tile-discovery input (NOT solver)**: Read `TileData.terrain_set`, `terrain`, `peering_bits` into a transient candidate index keyed by `(terrain_set, terrain, mask)`. Peering bits are terrain VALUES (not bitmasks). `terrain_mode()` virtual on `PentaTileLayout` maps Godot `TerrainMode` per subclass. (Spike 007)
- **source_id field on PentaTileAtlasSlot**: Optional field (`int = -1`). When `>= 0`, `_paint_with_slot` uses it; when `-1`, falls back to `_resolve_source_id()`. Non-breaking schema addition. ~50 LOC. (Spike 004/006/007)
- **Deterministic variation via TileData.probability**: Enumerate alternatives at dispatched atlas coord. Build weighted list from `TileData.probability`. Deterministic hash pick (PITFALLS.md §2). Independent of terrain — ships before multi-terrain. ~120 LOC. (Spike 007)
- **Auto-detect terrains from atlas grid (no custom Resource)**: Terrain count = sum of `atlas_grid_size.y` across all TileSetAtlasSources. Godot native `TerrainSets` store names/colors only (not used for solving). Per-tile `TileData.terrain = atlas_coords.y` maps tiles to terrain strips. `auto_setup_terrains()` is idempotent — snapshot-old-names pattern preserves user customizations. Single `layout` on `PentaTileMapLayer` drives schema for all terrains. No `PentaTileTerrainGroup` Resource needed. ~120 LOC. (Spike 009)

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | template-decoder-feasibility | standard | Given a greybox template PNG, when sampled per a fixed anchor + 3×3 majority rule, the decoded mask table matches the documented mask convention without hand-authored slot data | ✓ VALIDATED | decoder, layouts, image-sampling, gdscript-port-pending |
| 002 | blob47-decoder-generalization | standard | Decoder generalizes across template styles (alpha-encoded TT greyboxes + color-encoded dandeliondino silhouettes), tile sizes (16, 64 px), and mask topologies (corner-only, edge-only, blob47), with the unified "not-transparent-not-white = bit set" rule | ✓ VALIDATED | decoder, blob47, dandeliondino, color-encoding, tile-size, gdscript-port-pending |
| 003 | pixellab-bit-mapping | standard | PixelLab Aseprite native (8×8 atlas, top-down or side-scroller) decodes via locked role-to-mask bijection. Mapping `[4,10,13,12,9,14,15,7,2,3,11,5,0,8,6,1]` is bit-identical across both layouts and verified against 12/16 samples (4 partials = AI noise, not mapping issues) | ✓ VALIDATED | pixellab, aseprite-extension, wang-16, role-mapping, variation-bank |
| 004 | virtumap-integration-requirements | standard | Given VirtuMap's 6-terrain paint pipeline + slope tiles + fixture passthrough, when we map each requirement to PentaTile's current architecture, then we produce a concrete delta of new layouts/features needed with feasibility verdicts | ✓ VALIDATED | virtumap, multi-terrain, slope, passthrough, integration |
| 005 | slope-layout-architecture | standard | Given a PentaTileLayout subclass design fed 4-bit corner masks + slope-corner handling, when implemented against the existing single-grid paint pipeline, then 45-degree slope transitions compose correctly without new pipeline code | ✓ VALIDATED | slope, layout, single-grid, dualgrid16, mask-system |
| 006 | multi-terrain-dispatch-architecture | standard | Given an atlas with 3+ terrain strips (Floor/Wall/Hull), when a paint call specifies a terrain ID, then the correct strip is selected per-cell and neighboring cells' terrain IDs inform the mask computation | ✓ VALIDATED | multi-terrain, dispatch, strip, terrain-id, precedence |
| 007 | godot-terrain-api-integration | standard | Given a TileSet authored with Godot's native Terrain Sets + peering bits + TileData.probability, when PentaTile reads this metadata as input (not solver), then multi-terrain candidate discovery works without re-authoring terrain rules in PentaTile's format | ✓ VALIDATED | godot-api, terrain-peering, TileData, variation, candidate-index |
| 008 | complete-autotiling-gap-audit | standard | Given all shipped PentaTile features + the full v2 backlog + VirtuMap's requirements + competitive autotilers (TileMapDual, Better Terrain, Tilesetter), when every feature axis is scored, then we identify which gaps are real vs. architectural anti-features, and produce a prioritized v0.3/v2 feature matrix | ✓ VALIDATED | audit, gap-analysis, competitive, roadmap, v0.3, v2 |
| 009 | auto-terrain-detection | standard | Given a TileSet with atlas sources, when terrain count is auto-computed from atlas grid dimensions and Godot native terrain sets are used for name/color storage, then multi-terrain dispatch works without a custom TerrainGroup Resource | ✓ VALIDATED | terrain, auto-detection, godot-terrain-sets, simplification, v0.3 |
