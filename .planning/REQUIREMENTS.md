# Requirements: TetraTile v0.2.0

**Defined:** 2026-04-25
**Core Value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

## v1 Requirements

Requirements for the v0.2.0 release ("expand the contract" milestone). Each maps to roadmap phases via the Traceability section.

### Atlas Contract (CONTRACT)

The keystone. Every other feature reads through the contract.

- [ ] **CONTRACT-01**: `TetraTileMapLayer` exposes `@export var atlas_contract: TetraTileAtlasContract` accepting a typed `Resource` subclass.
- [ ] **CONTRACT-02**: `TetraTileAtlasContract` Resource declares: `version: int`, `rotation_mode: {SYMMETRIC, NON_ROTATING}`, four named symmetric slots, `mask_slots: Array[AtlasSlot]` (length 16), optional `top_overlay_slot`, `variation_seed: int`.
- [ ] **CONTRACT-03**: `AtlasSlot` Resource declares: `atlas_coords: Vector2i`, `transform_flags: int`, `alternative_count: int = 1`, optional `diagonal_complement_atlas_coords: Vector2i`.
- [ ] **CONTRACT-04**: `_resolve_slot(mask)` reads from the contract in `SYMMETRIC` mode and returns slot+transform. Output for the bundled default contract is bit-identical to v0.1 visuals.
- [ ] **CONTRACT-05**: The `atlas_contract` setter uses an idempotence guard (`if value == _atlas_contract: return`) and disconnects-before-reconnects on `Resource.changed` to prevent signal storms.
- [ ] **CONTRACT-06**: When `atlas_contract` is null, `_resolve_slot()` falls back to v0.1 hardcoded behavior so existing scenes that haven't migrated continue to work.

### Y-Axis Variation (VAR)

Per-cell deterministic variation using Godot's native alt-tile mechanism.

- [ ] **VAR-01**: User can author multiple alternate tiles per slot via Godot's stock TileSet inspector with `TileData.probability` weights.
- [ ] **VAR-02**: `TetraTileMapLayer` picks among alternates deterministically: `RandomNumberGenerator.seed = hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed)` then `rand_weighted()` over `TileData.probability`.
- [ ] **VAR-03**: Calling `rebuild()` produces identical visuals to the prior render (no variation shimmer).
- [ ] **VAR-04**: Changing `variation_seed` on the contract re-rolls the entire map deterministically (same seed → same result, every time).
- [ ] **VAR-05**: `_pack_alternative(alt_id, transform_flags)` helper combines alt-ID and `TRANSFORM_FLIP_*` flags via bitwise OR with `assert(alt_id < 4096)`.

### Non-Rotating Mode (NONROT)

Per-direction tile authoring for atlases that aren't rotationally symmetric.

- [ ] **NONROT-01**: User can set `rotation_mode = NON_ROTATING` on a contract and supply per-mask atlas slots via `mask_slots`.
- [ ] **NONROT-02**: `_build_lookup_table()` generates a 16-entry runtime table at contract-load time, merging non-rotating overrides with rotating fallbacks; the 64-cell authoring matrix is computed, never hand-written.
- [ ] **NONROT-03**: Mask 0 erases the visual cell as the FIRST line of the paint function (special case, never falls into the lookup table).
- [ ] **NONROT-04**: `AtlasSlot.diagonal_complement_atlas_coords` is honored for masks 6 and 9 in NON_ROTATING mode (preserves the two-layer composition without rotation reuse).
- [ ] **NONROT-05**: `update_configuration_warnings()` lists specific missing mask slots when a NON_ROTATING contract is incomplete.

### Top Tiles (TOP)

Designated top-edge visuals for platformer-style caps.

- [ ] **TOP-01**: User can set `top_overlay_slot: AtlasSlot` on the contract to enable platformer-style top caps.
- [ ] **TOP-02**: A third internal `_top_layer` (`TileMapLayer` with `INTERNAL_MODE_FRONT`) is lazily created only when `top_overlay_slot != null`.
- [ ] **TOP-03**: Top-mask paint rule fires explicitly for the masks declared in the contract (default candidate set: 4, 8, 12; final set validated against demo art before release — may extend to 5/7/13).
- [ ] **TOP-04**: TileSet `custom_data_layers` `tetra_role: String` and `tetra_lock_rotation: bool` are defined and read at paint time as a per-tile filter on the candidate set.

### Migration (MIGR)

Smooth on-ramp from v0.1.

- [ ] **MIGR-01**: Bundled `tetra_tile_default_contract.tres` ships in `addons/tetra_tile/` and reproduces v0.1 HORIZONTAL behavior.
- [ ] **MIGR-02**: README contains an "Upgrading from 0.1.x" section documenting both the bundled-default and the v0.1-shape-detection migration paths.
- [ ] **MIGR-03**: v0.1-shape detection branch in `_resolve_slot_legacy()` detects the canonical 4-tile order when `atlas_contract` is null and no `tetra_role` custom_data_layer is defined.

### Demo (DEMO)

One updated demo scene showcasing the new features.

- [ ] **DEMO-01**: One updated demo scene (`tetra_tile_demo.tscn`) showcases all three new features (variation, top tiles, non-rotating mode) playable end-to-end with the existing platformer player.
- [ ] **DEMO-02**: Demo references the bundled default contract or new contract Resources authored specifically for the demo (variation, top, non-rotating).
- [ ] **DEMO-03**: Runtime drag-paint continues to work with all new features.

### Release (REL)

Tagged GitHub release.

- [ ] **REL-01**: `plugin.cfg` `version` field bumped from `0.1.0` to `0.2.0`.
- [ ] **REL-02**: Git tag `v0.2.0` cut on the release commit (no `-pre`/`-alpha`/`-dev` suffixes).
- [ ] **REL-03**: GitHub Release artifact `tetra_tile-v0.2.0.zip` with `addons/tetra_tile/` at the archive root.
- [ ] **REL-04**: `CHANGELOG.md` entry documents all breaking changes, including any property renames and the `atlas_contract` introduction.

## v2 Requirements

Deferred to a future milestone but acknowledged. Tracked here so they don't get re-litigated mid-flight.

### Atlas Tooling

- **TOOL-01**: TetraBake — edit-time utility to procedurally compose a fifth edge/diagonal connector tile.
- **TOOL-02**: Tileset converter — Wang/blob/single-tile inputs → TetraTile-compatible atlas.

### Variation Modes

- **VAR-V2-01**: `variation_mode: VariationMode` enum with `RANDOM_PER_PAINT` value (per-paint randomness as opt-out from deterministic-per-coord). Non-breaking addition (new enum value at end).

### Multi-Terrain

- **TERRAIN-01**: Outer transition tile support — terrain-to-terrain transitions (grass→dirt etc.).

### Performance

- **PERF-01**: Shader fallback — single-pass shader option for diagonal compositing.
- **PERF-02**: Large-map perf benchmarks (>10k cells) with documented limits.

### Tooling

- **TOOL-03**: Collision authoring tools / auto-collision generation.
- **TOOL-04**: MkDocs documentation site.

### Distribution

- **DIST-01**: Godot Asset Library submission.
- **DIST-02**: Formal automated test suite (GUT or similar).

## Out of Scope

Explicitly excluded for v0.2.0. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| TetraBake / atlas tooling | Authoring tooling; deferred until contract design proves out in production |
| Tileset converter (Wang/blob → TetraTile) | Authoring tooling; same rationale |
| Outer transition tile support (multi-terrain) | Distinct R&D track; not a current pain in author's games |
| Shader fallback for diagonal compositing | Performance optimization; demo-scale targets don't require it |
| Collision authoring / auto-collision generation | Existing TileSet-physics path is sufficient |
| MkDocs documentation site | GitHub README is enough for the private audience |
| Godot Asset Library distribution | Audience is private; discoverability not a goal this milestone |
| Formal automated test suite (GUT) | "Works in my game" quality bar |
| Large-map performance benchmarking (>10k cells) | Demo-scale (~100–1k cells) is the target |
| Backwards compatibility for v0.1.0 atlases / API | Pre-1.0; breaking changes accepted with migration notes |
| `EditorInspectorPlugin` / custom inspector polish | Typed `@export` + `@export_group` give enough authoring UX without it |
| Persistent coordinate cache | Adds memory leak risk; demo-scale doesn't need it |
| Watcher / signal-fanout systems | TileMapDual's issue tracker shows the cost (leaks, exported-build crashes, HTML5 export failures) |
| Custom drawing API (`draw_cell`, `fill_tile`) | Every parallel painting path defeats the v0.1 native-API win |
| `variation_mode = RANDOM_PER_PAINT` | Deferred to v0.3+; deterministic-per-coord wins 95% of the time |
| Top-tile auto-detection / inferred top assignment | Bakes platformer assumptions into the addon — assignment is explicit per-mask in the contract |

## Traceability

Which phases cover which requirements. Mapped by `gsd-roadmapper` on 2026-04-25.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONTRACT-01 | Phase 1 | Pending |
| CONTRACT-02 | Phase 1 | Pending |
| CONTRACT-03 | Phase 1 | Pending |
| CONTRACT-04 | Phase 1 | Pending |
| CONTRACT-05 | Phase 1 | Pending |
| CONTRACT-06 | Phase 1 | Pending |
| VAR-01 | Phase 2 | Pending |
| VAR-02 | Phase 2 | Pending |
| VAR-03 | Phase 2 | Pending |
| VAR-04 | Phase 2 | Pending |
| VAR-05 | Phase 2 | Pending |
| NONROT-01 | Phase 3 | Pending |
| NONROT-02 | Phase 3 | Pending |
| NONROT-03 | Phase 3 | Pending |
| NONROT-04 | Phase 3 | Pending |
| NONROT-05 | Phase 3 | Pending |
| TOP-01 | Phase 4 | Pending |
| TOP-02 | Phase 4 | Pending |
| TOP-03 | Phase 4 | Pending |
| TOP-04 | Phase 4 | Pending |
| MIGR-01 | Phase 5 | Pending |
| MIGR-02 | Phase 5 | Pending |
| MIGR-03 | Phase 4 | Pending |
| DEMO-01 | Phase 5 | Pending |
| DEMO-02 | Phase 5 | Pending |
| DEMO-03 | Phase 5 | Pending |
| REL-01 | Phase 5 | Pending |
| REL-02 | Phase 5 | Pending |
| REL-03 | Phase 5 | Pending |
| REL-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30 (100%)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-25*
*Last updated: 2026-04-25 after roadmap creation (gsd-roadmapper)*
