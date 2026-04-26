# Roadmap: TetraTile v0.2.0

**Milestone:** v0.2.0 — "Expand the Contract"
**Created:** 2026-04-25
**Granularity:** standard (5 phases)

## Overview

TetraTile v0.1.0 ships a fixed 4-tile dual-grid autotiler with rotational symmetry baked in. v0.2.0 expands the addon's atlas contract along three intertwined axes — Y-axis variation, top tiles, and non-rotating tilesets — without losing the "smaller and leaner than TileMapDual" identity. The five-phase plan lands the typed `TetraTileAtlasContract` Resource first to gate everything else, then builds variation, non-rotating mode, and top tiles + custom data layers as additive features that read through the contract. A consuming fifth phase refreshes the demo and cuts the GitHub release.

The contract is the keystone: every feature reads through it, every migration path passes through it, and the LOC budget (`< TileMapDual`) is enforced against it. The phases are ordered to surface the highest-risk pitfalls (alt-tile bit packing, variation determinism, non-rotating table generation) early so they land before the cumulative complexity of Phase 4.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4, 5): Planned milestone work
- Decimal phases (e.g. 2.1): Reserved for urgent inserts (none currently)

- [ ] **Phase 1: Contract Skeleton** - Introduce `TetraTileAtlasContract` + `AtlasSlot` Resources, route SYMMETRIC mode through the contract, fall back to v0.1 hardcoded behavior when null.
- [ ] **Phase 2: Y-Axis Variation** - Add deterministic per-cell `_pick_alternative` + `_pack_alternative` helper; consume `TileData.probability`; demo atlas extended with alternates.
- [ ] **Phase 3: Non-Rotating Mode** - Add `RotationMode.NON_ROTATING` dispatch, `mask_slots[16]`, generated `_build_lookup_table`, diagonal complement, validator, mask-0 special case.
- [ ] **Phase 4: Top Tiles + Custom Data Layers + v0.1 Detection** - Add lazy `_top_layer`, `top_overlay_slot`, `tetra_role`/`tetra_lock_rotation` custom_data_layers, and v0.1-shape detection branch.
- [ ] **Phase 5: Demo Refresh + Release Prep** - One updated demo scene, README "Upgrading from 0.1.x", `plugin.cfg` bump, CHANGELOG, `v0.2.0` tag, GitHub Release zip.

## Phase Details

### Phase 1: Contract Skeleton
**Goal**: A typed `TetraTileAtlasContract` Resource is the source of truth for atlas shape; SYMMETRIC mode reads through it; v0.1 scenes that don't migrate continue to render unchanged.
**Depends on**: Nothing (first phase)
**Requirements**: CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04, CONTRACT-05, CONTRACT-06
**Success Criteria** (what must be TRUE):
  1. Setting `atlas_contract` to the bundled default contract on the demo scene produces visuals bit-identical to v0.1 (visual regression: side-by-side screenshot of the same painted layout matches pixel-for-pixel for all 16 mask states).
  2. Leaving `atlas_contract` null on a v0.1-style scene produces visuals bit-identical to v0.1 (the hardcoded fallback path renders the canonical 4-tile atlas correctly).
  3. Reassigning `atlas_contract` to the same Resource value triggers zero rebuilds (idempotence guard verified by counting `_queue_rebuild` calls in a debug build).
  4. Editing a property on a connected `TetraTileAtlasContract` Resource triggers exactly one rebuild per edit (no signal storm — `Resource.changed` is connected once, disconnected before reassignment).
  5. The `addons/tetra_tile/` LOC count after Phase 1 (Resources included) stays under the cumulative budget on the way to "< TileMapDual" — checkpoint logged in the phase summary.
**Plans**: TBD

### Phase 2: Y-Axis Variation
**Goal**: Users author multiple alternates per slot in Godot's stock TileSet inspector; the addon picks among them deterministically per cell coordinate so painting and rebuilding never shimmer.
**Depends on**: Phase 1
**Requirements**: VAR-01, VAR-02, VAR-03, VAR-04, VAR-05
**Success Criteria** (what must be TRUE):
  1. Painting 100 cells of fill, then calling `rebuild()` 10 times, produces identical visuals each time (no variation shimmer — verified by capturing the visual layer's `get_cell_atlas_coords` and `get_cell_alternative_tile` after each rebuild and asserting equality).
  2. Authoring two fill alternates with `TileData.probability` weights 1.0 and 3.0 produces a roughly 1:3 distribution across a 1000-cell painted block (statistical sanity check, not a strict assertion — visual evidence in the demo).
  3. Changing `variation_seed` on the contract re-rolls the entire painted map (visuals differ from prior render); reverting `variation_seed` restores the original render exactly.
  4. `_pack_alternative(alt_id, transform_flags)` round-trips: passing the packed value to `set_cell` and reading back via `get_cell_alternative_tile` returns the original packed int for `alt_id < 4096`.
  5. Painting with `alt_id >= 4096` triggers the `assert` and halts in a debug build (asserts the bit-collision guard is wired, not silently masked).
**Plans**: TBD

### Phase 3: Non-Rotating Mode
**Goal**: Users can author atlases that are not rotationally symmetric (per-direction T/B/L/R tiles) by setting `rotation_mode = NON_ROTATING` and supplying `mask_slots`; the lookup table is generated mechanically from the rotating fallback to prevent transpose-vs-flip bit-drift bugs.
**Depends on**: Phase 1, Phase 2 (variation lands first to surface transform-bit collision before non-rotating arrives)
**Requirements**: NONROT-01, NONROT-02, NONROT-03, NONROT-04, NONROT-05
**Success Criteria** (what must be TRUE):
  1. Loading a `NON_ROTATING` contract that omits mask 5 surfaces a configuration warning naming mask 5 specifically (validator output viewable in the editor inspector via `update_configuration_warnings()`).
  2. A complete `NON_ROTATING` 16-tile directional atlas paints all 16 mask states correctly in the demo (visual inspection: each mask renders the user-supplied tile, not a rotated rotating-mode fallback).
  3. Erasing a logic cell that drops a display cell to mask 0 clears the visual cell on the FIRST line of the paint function — even when `_resolve_slot` is set up to throw on missing slots, mask 0 never reaches the lookup table (verified by setting `mask_slots[0]` to `null` intentionally and confirming no error fires).
  4. Masks 6 and 9 in `NON_ROTATING` mode honor `AtlasSlot.diagonal_complement_atlas_coords` and produce the two-layer composition (overlay layer paints the complement tile; visual matches a hand-built reference render).
  5. A `NON_ROTATING` contract that supplies only 4 mask slots and leaves the rest null falls back to rotating-mode equivalents in the generated lookup table (mixed-mode authoring works; `_build_lookup_table` is generated, never hand-written).
**Plans**: TBD

### Phase 4: Top Tiles + Custom Data Layers + v0.1 Detection
**Goal**: Designated top-edge tiles render via a lazy third internal layer for platformer caps; per-tile `tetra_role` / `tetra_lock_rotation` custom data layers add per-tile overrides without bloating the contract; the v0.1-shape detection branch keeps unmigrated v0.1 scenes rendering correctly.
**Depends on**: Phase 3 (top tiles use the same generated-lookup approach as non-rotating mode)
**Requirements**: TOP-01, TOP-02, TOP-03, TOP-04, MIGR-03
**Success Criteria** (what must be TRUE):
  1. Setting `top_overlay_slot` on the contract creates a third internal `TileMapLayer` (`INTERNAL_MODE_FRONT`) lazily; leaving `top_overlay_slot` null does NOT create the layer (verified by counting child nodes on `TetraTileMapLayer`).
  2. Painting a horizontal platform of fill cells produces top-cap visuals on the masks declared in the contract (default candidate set 4/8/12 — final set validated against the demo art before commit; player can walk along the platform and stand on the cap).
  3. A tile tagged `tetra_lock_rotation = true` in the TileSet's custom data layer renders with `transform_flags = 0` regardless of the mask's normal rotation (per-tile filter overrides the contract's symmetric rotation).
  4. Opening a v0.1 demo scene with the v0.2.0 addon and no `atlas_contract` set renders identically to v0.1 (the `_resolve_slot_legacy` v0.1-shape detection branch fires when `atlas_contract == null` AND the TileSet has no `tetra_role` custom data layer defined).
  5. Adding a `tetra_role` custom data layer to a v0.1-shaped TileSet (without setting `atlas_contract`) opts that scene OUT of the v0.1-shape detection path (the absence of `tetra_role` is the explicit signal for the legacy branch).
**Plans**: TBD
**UI hint**: yes

### Phase 5: Demo Refresh + Release Prep
**Goal**: One updated demo scene showcases all three new features end-to-end with the existing platformer player; the GitHub Release ships a clean zip with `addons/tetra_tile/` at archive root, tagged `v0.2.0`, with README and CHANGELOG documenting the upgrade path.
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4
**Requirements**: MIGR-01, MIGR-02, DEMO-01, DEMO-02, DEMO-03, REL-01, REL-02, REL-03, REL-04
**Success Criteria** (what must be TRUE):
  1. Downloading the `tetra_tile-v0.2.0.zip` GitHub Release artifact and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run (`addons/tetra_tile/` extracts at archive root; demo opens and plays).
  2. The updated `tetra_tile_demo.tscn` exhibits all three new features (variation visible across painted fill cells; non-rotating directional tiles for at least one region; top-cap tiles on platform tops) and the platformer player can interact with each region (runtime drag-paint still works).
  3. README contains an "Upgrading from 0.1.x" section describing both migration paths (referencing the bundled `tetra_tile_default_contract.tres` as PRIMARY; v0.1-shape detection as BACKUP) — the text passes a "follow the steps in a fresh v0.1 project" smoke test.
  4. `plugin.cfg` `version` field reads `0.2.0` exactly (no `-pre` / `-alpha` / `-dev` suffix); CHANGELOG.md has a v0.2.0 entry that names every property rename and the `atlas_contract` introduction.
  5. The `v0.2.0` git tag points at the release commit; `tetra_tile-v0.2.0.zip` is attached to the GitHub Release page; final LOC audit confirms `addons/tetra_tile/` total stays under TileMapDual's equivalent surface area.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Contract Skeleton | 0/TBD | Not started | - |
| 2. Y-Axis Variation | 0/TBD | Not started | - |
| 3. Non-Rotating Mode | 0/TBD | Not started | - |
| 4. Top Tiles + Custom Data Layers + v0.1 Detection | 0/TBD | Not started | - |
| 5. Demo Refresh + Release Prep | 0/TBD | Not started | - |

## Coverage

All 30 v1 requirements mapped to exactly one phase. No orphans, no duplicates.

| Phase | Requirements (count) |
|-------|----------------------|
| 1. Contract Skeleton | CONTRACT-01..06 (6) |
| 2. Y-Axis Variation | VAR-01..05 (5) |
| 3. Non-Rotating Mode | NONROT-01..05 (5) |
| 4. Top Tiles + Custom Data Layers + v0.1 Detection | TOP-01..04, MIGR-03 (5) |
| 5. Demo Refresh + Release Prep | MIGR-01, MIGR-02, DEMO-01..03, REL-01..04 (9) |
| **Total** | **30 / 30** |

## Identity Guardrails

The PROJECT.md identity constraint — "TetraTile must remain visibly smaller and simpler than TileMapDual" — is checked at three points across the roadmap:

- **End of Phase 1:** LOC checkpoint after Resources land. Contract surface is the largest schema addition; if Phase 1 already pushes the budget, downstream phases have less room.
- **End of Phase 4:** LOC checkpoint after the largest functional additions land (top layer, custom data layers, legacy detection branch). This is where scope-creep risk is highest.
- **Phase 5 final audit:** Total `addons/tetra_tile/` LOC compared against TileMapDual's equivalent surface; result included in the release notes.

Per PROJECT.md, the quality bar is "works in my game" — visual regression on the demo is the primary verification mechanism, not a formal test suite. Demo-scale (~100–1k cells) is the only perf target; success criteria deliberately do NOT gate on perf.

---
*Roadmap created: 2026-04-25*
