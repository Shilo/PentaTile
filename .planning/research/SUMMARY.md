# Project Research Summary

**Project:** PentaTile v0.2.0 — atlas-contract expansion
**Domain:** Godot 4.6 dual-grid autotiling addon (pure GDScript, no GDExtension)
**Researched:** 2026-04-25
**Confidence:** HIGH (Godot 4.6 APIs verified via Context7 + official docs; competitor inventory cross-checked against TileMapDual / Better Terrain repos)

## Executive Summary

PentaTile is a lean dual-grid autotiler for Godot 4.6 whose v0.1 selling point is "single public node, native `TileMapLayer.set_cell()` painting drives autotiling, ~261 LOC." v0.2 expands the addon's atlas contract along three intertwined axes — Y-axis variation, top tiles, and non-rotating tilesets — without losing the "smaller and leaner than TileMapDual" identity. All four researchers converged on the same shape: a typed `Resource` subclass (`PentaTileAtlasContract`) hung off `PentaTileMapLayer` as an `@export`, with directional/per-tile semantics layered on top of the existing 16-state mask + two-internal-layer composition pipeline. Variation must be implemented inside the addon (Godot's `TileData.probability` is consumed only by the editor's scattering paint tool, never at `set_cell()` time) and must be deterministic per cell coord, otherwise every `rebuild()` will visually shimmer.

The recommended approach is a five-phase build that lands the contract skeleton first (de-risks everything), then variation, then non-rotating mode, then top tiles + per-tile custom_data_layers + v0.1-shape detection, with the demo refresh + release prep as a fifth consuming phase. The atlas contract Resource is the keystone — every other feature reads through it. Per-tile semantics that the contract itself doesn't enumerate (e.g., "is this tile a top cap?", "lock rotation on this tile?") are best authored as TileSet `custom_data_layers` so users tag tiles inside Godot's existing TileSet UI; the contract-Resource and custom-data-layer mechanisms are complementary rather than competing.

The dominant risks are all in the seams. (1) Godot's `alternative_tile` int packs both alt-ID and the `TRANSFORM_FLIP_*` flags — we must always combine via bitwise OR and never let alt-IDs reach the 4096 bit. (2) `Resource` property renames silently drop saved-scene values; pre-1.0 freedom does not extend to scene deserialization, so renames need an `@export_storage` shadow + `__migrate__()` step. (3) Resource `changed` signals will storm the editor unless the layer disconnects-before-reconnects and rides the existing `_queue_rebuild()` deferred coalescer. (4) Non-rotating mode is a 64-cell expansion of the rotating 16-cell table; it must be **generated** from the rotating table at contract-load time, never hand-written. (5) Variation must use a per-cell hash, never `randi()`. With those guardrails, the milestone fits comfortably under a ~500 LOC budget and stays smaller than TileMapDual.

## Key Findings

### Recommended Stack

No third-party libraries enter the project — the entire stack is Godot 4.6 native plus pure GDScript 2. The interesting choices are which Godot APIs to ride and which authoring surfaces to expose.

**Core technologies:**
- **Godot 4.6.x stable** — host engine; `TileMapLayer._update_cells(coords, forced_cleanup)` virtual is stable across 4.5→4.6 with no documented breaking changes.
- **GDScript 2** — `@tool`, `class_name`, typed `Array[Resource]`, `@export_group`/`@export_subgroup` give every authoring surface the milestone needs without `EditorInspectorPlugin`.
- **`TileMapLayer`** (already in use) — single ingress (`set_cell`) and single egress (`_update_cells`) for the addon's autotile loop.
- **`TileSetAtlasSource` + `alternative_tile` int packing** — encodes both rotation (`TRANSFORM_FLIP_H=4096 | TRANSFORM_FLIP_V=8192 | TRANSFORM_TRANSPOSE=16384`) and the variation alt-ID (low bits) in one parameter, OR'd together.
- **Native `Resource` subclassing** — `class_name PentaTileAtlasContract extends Resource` exported on the node is the idiomatic 4.6 way to do "declare what you have," with no custom inspector plugin needed.
- **`TileData.probability`** — read-only weights authored in the stock TileSet inspector; PentaTile runs its own weighted-RNG inside `_update_cells()` because Godot does NOT auto-pick at `set_cell()` time (editor-paint-tool-only behavior, verified in `tutorials/2d/using_tilemaps.html`).
- **`RandomNumberGenerator`** seeded by `hash(cell_coords)` — gives free per-coord determinism that Godot's stock terrain randomization lacks (proposal #10948 confirms the long-standing engine gap).
- **`TileSet.custom_data_layers`** — used only for per-tile semantics the contract Resource cannot enumerate (e.g., a `penta_lock_rotation: bool` tag on a specific tile).

**Distribution:** GitHub Release with `penta_tile-v0.2.0.zip` containing `addons/penta_tile/` at archive root. `plugin.cfg` `version` field bumped to `0.2.0`, `script=""` preserved (no EditorPlugin entrypoint needed). Do NOT add `min_godot_version` / `compatibility_minimum` — neither is a real `plugin.cfg` field.

See full detail in `.planning/research/STACK.md`.

### Expected Features

The audience is the author's own platformer games. Quality bar is "works in my game" — many features that would be table stakes for a public Asset Library addon are explicit anti-features here.

**Must have (table stakes for the milestone):**
- "Declare what you have" atlas contract — keystone; everything else depends on it.
- Mask-to-role resolver with specific-then-generic fallback (this is the migration on-ramp from v0.1 atlases).
- Y-axis variation via `TileData.probability`, sampled with a deterministic per-cell hash by default.
- Top-tile support for platformer caps (the demo asset can't be used at full fidelity without it).
- Non-rotating tileset support — same code path as top tiles with different metadata.
- Per-tile rotation lock (finishes the per-tile knobs story).
- v0.1-shape detection branch in the resolver (keeps the author's in-flight games working).
- Updated demo scene + README "Upgrading from 0.1.x" paragraph.

**Should have (differentiators vs TileMapDual / Better Terrain):**
- TileMapDual's README explicitly says "It currently does not support alternative tiles" — variation is the single biggest competitive gap available this milestone.
- Per-coord deterministic variation (engine's stock terrain randomization is non-deterministic per proposal #10948) — leapfrog at near-zero implementation cost.
- Smooth migration story (TileMapDual ships zero migration docs; engine 3→4 tilemap migration was famously broken per issue #71188) — strictly better than the field.
- Single public node identity preserved (no new `CursorDual`, no `BetterTerrain` autoload).

**Anti-features (deliberately NOT built — must stay aligned with PROJECT.md Out of Scope):**
- Terrain peering metadata (Godot stock + TileMapDual) — would inherit 5-bit-per-side complexity.
- Terrain rule tries / "best fit" search (Better Terrain) — implies a search graph; PentaTile's `_update_cells()` is O(1) per cell by design.
- Multi-terrain transitions — explicit out-of-scope per PROJECT.md.
- Watcher / signal-fanout systems — TileMapDual's issue tracker shows the cost (leaks #75, exported-build crashes #73/#76, HTML5 export failures #59).
- Persistent coordinate cache — adds memory leak risk and lifecycle bugs at zero scale benefit (~100–1k cell target).
- Custom drawing API (`draw_cell`, `fill_tile`, `BetterTerrain.set_cell`) — every parallel painting path defeats the v0.1 win.
- Editor dock / inspector plugin / custom dock for atlas configuration — Asset Library polish, not needed.
- Full MkDocs site / Asset Library submission / formal test suite (GUT) / tileset converter (Wang/blob → PentaTile) / shader fallback for diagonals / auto-collision / large-map perf benchmarks — all explicit Out of Scope per PROJECT.md.

See full detail in `.planning/research/FEATURES.md`.

### Architecture Approach

The v0.2.0 architecture is strictly additive over v0.1: the existing logic-layer-plus-two-visual-layers composition stays, the 16-state mask table stays, and `_update_cells()` stays the single egress. New surface area is one `Resource` subclass (`PentaTileAtlasContract`), one nested `Resource` subclass (`AtlasSlot`), an optional third internal `_top_layer` (lazy-created only when the contract opts in), and two new methods on `PentaTileMapLayer` (`_resolve_slot(mask)` dispatching by `RotationMode`, and `_pick_alternative(slot, coord)` running the deterministic-hash weighted picker).

**Major components:**
1. **`PentaTileMapLayer`** (extended, ~350 LOC est.) — public node; owns logic cells, internal visual layers, contract reference. Public surface unchanged except for one new `@export atlas_contract: PentaTileAtlasContract`.
2. **`PentaTileAtlasContract`** (NEW Resource, ~60 LOC) — declares atlas shape: `version: int`, `rotation_mode: {SYMMETRIC, NON_ROTATING}`, four named symmetric slots, `mask_slots: Array[AtlasSlot]` for non-rotating mode (16 entries), optional `top_overlay_slot`, `variation_seed: int`.
3. **`AtlasSlot`** (NEW Resource, ~30 LOC) — `atlas_coords`, `transform_flags`, `alternative_count`, optional `diagonal_complement_atlas_coords` for masks 6/9 in non-rotating mode. Separate file because inner classes that extend Resource cannot serialize their custom properties.
4. **`_resolve_slot(mask)`** — mode-dispatched lookup. `SYMMETRIC` reads four named slots and computes a transform; `NON_ROTATING` reads `mask_slots[mask]` directly with `transform=0`. Both return the same shape.
5. **`_pick_alternative(slot, coord)`** — `hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed)` → `RandomNumberGenerator.seed` → `rand_weighted(weights_from_TileData_probability)`. Pure function; no cache.
6. **`_top_layer`** (NEW, optional) — third internal `TileMapLayer` (`INTERNAL_MODE_FRONT`), created only when `contract.top_overlay_slot != null`. Painted on masks 4/8/12 for platformer-style caps.

**Key patterns:** Resource-driven configuration; mode-dispatched lookup; lazy internal layer creation; deterministic per-coord hashing for variation. See full detail in `.planning/research/ARCHITECTURE.md`.

### Critical Pitfalls

1. **Variation determinism** — `randi()` will produce visual shimmer on every `rebuild()`, every scene reload, every drag-paint that triggers `coords.is_empty()` fallback to full rebuild. **Avoid** by using a per-cell hash from day one.
2. **`alternative_tile` bit packing** — the int packs both alt-ID (low bits) AND `TRANSFORM_FLIP_*` (≥ 4096). v0.1 code passes only transform flags; v0.2 must combine via bitwise OR. **Avoid** with a `_pack_alternative()` helper + `assert(alt_id < 4096)` + round-trip test.
3. **Resource property renames orphan saved scenes silently** — Godot 4.6 has no automatic property-rename migration. **Avoid** with `@export_storage` shadow + `__migrate__()` two-step pattern (Prvaak blog), CHANGELOG entry per rename, never reorder enum values stored as ints.
4. **Setter loops + `Resource.changed` storms** — setter recursion crashes Godot 4 hard (issues #48437/#52757/#76019); `@onready` race in `@tool` setters; signal storm on every keystroke. **Avoid** with strict setter discipline (only assign + `_queue_rebuild`), idempotence guard, disconnect-before-reconnect on `Resource.changed`, ride existing deferred coalescer.
5. **Non-rotating tileset table errors** — bit drift (TR↔BL swap), transpose-vs-flip rotation-sense confusion, mask-0 trap. **Avoid** by **generating** the lookup mechanically from the 16-entry rotating table; `update_configuration_warnings()` validator; mask 0 special-cased as the FIRST line of the painting function.
6. **Top-tile authoring over-cleverness** — auto-detection bakes platformer assumptions into the addon. **Avoid** by making top-tile assignment **explicit per-mask in the contract**, never inferred.
7. **`_update_cells()` re-entrancy from variation state on the logic layer** — never store the picked alternate in TileData custom data on the logic layer. **Avoid** by keeping variation pick only in visual-layer `set_cell` calls.
8. **Contract scope creep into TileMapDual territory** — "declare what you have" can swell into peering metadata + multi-terrain. **Avoid** with a hard ~500 LOC budget; reject any PR using "terrain" or "peering."

See full detail in `.planning/research/PITFALLS.md`.

## Reconciliations: Where the Researchers Diverge

The four researchers agree on most points but propose subtly different mechanisms in five areas. Each is reconciled below so the roadmapper does not have to re-decide.

### 1. Where the atlas contract lives — typed Resource is the primary path; TileSet custom_data_layers are a complementary annex

**Divergence:** STACK and ARCHITECTURE both recommend a typed `PentaTileAtlasContract extends Resource`. FEATURES additionally proposes augmenting with TileSet `custom_data_layers` (`penta_role`, `penta_lock_rotation`). PITFALLS warns that Resource property renames silently orphan saved scenes (issues #92068, #84981).

**Recommended path (PRIMARY): typed `Resource` subclass.** One `.tres` per layer, attached via `@export var atlas_contract: PentaTileAtlasContract`. Holds: `version: int = 1`, `rotation_mode`, four named `AtlasSlot` references for SYMMETRIC mode, `mask_slots: Array[AtlasSlot]` of length 16 for NON_ROTATING mode, optional `top_overlay_slot`, `variation_seed: int`. This is the source of truth that `_resolve_slot()` reads.

**Recommended path (COMPLEMENTARY): TileSet `custom_data_layers` for per-tile semantics that the contract does NOT enumerate.** `penta_role: String` (per-tile) — useful for the v0.1→v0.2 detection heuristic and for users who prefer to tag tiles inside Godot's existing TileSet UI. `penta_lock_rotation: bool` (per-tile) — opt-out for individual tiles in an otherwise SYMMETRIC contract. Read at paint time only as a per-tile filter on the candidate set; **never** as the source of contract shape.

**Tradeoff for the roadmapper:** The contract Resource is migration-friendlier (single `.tres` retargetable across atlases) but exposed to property-rename traps. Custom data layers are coupled to atlas image refactors (path notation `x:y/alt/key` breaks if the user re-arranges the atlas) but are stable across contract-class evolution. The hybrid takes the best of both: contract owns shape (high-churn surface), custom data layers own per-tile flags (low-churn surface).

**Build-order implication:** Phase 1 ships the Resource only. Custom data layers (`penta_role` / `penta_lock_rotation`) are added in Phase 4 where they earn their keep. Phase 1 should NOT introduce v0.1-detection; that lands in Phase 4 because v0.1-detection is what `penta_role`'s absence signals.

### 2. Mask table size for non-rotating tilesets — 16 runtime entries; non-rotating is generated mechanically from rotating

**Divergence:** ARCHITECTURE argues the table stays at 16 entries with a `RotationMode` flag dispatching between rotating-with-transforms and explicit-per-mask slots. PITFALLS argues non-rotating implies a 64-entry table generated from the 16-entry one.

**Reconciliation:** ARCHITECTURE describes the **runtime lookup table** (`mask_slots: Array[AtlasSlot]` of length 16). PITFALLS describes the **authoring/validation matrix** the user sees (16 masks × 4 orientation slots = 64 conceptual cells, used to compute the 16-entry runtime table at contract-load time). They are not in conflict.

**Recommended path:** Runtime is 16 entries. Authoring is "the user supplies up to 16 unique atlas coords for non-rotating mode; the rotating-symmetric 4-tile fallback is computed mechanically from those." A `_build_lookup_table()` method on `PentaTileMapLayer`, called on contract load, walks the rotating 16-entry table and substitutes user-supplied non-rotating slots where present, falling back to the rotated rotating slot otherwise. The 64-row authoring matrix that PITFALLS warns about does NOT exist as a hand-written table — it is generated.

### 3. Variation determinism — hardcode for v0.2; expose ONE `variation_seed` knob; defer "seeding strategy contract knob" to v0.3+

**Divergence:** All four researchers agree variation must be addon-implemented and `hash(coord)`-stable, but propose different formulations. STACK: `RandomNumberGenerator` seeded by `hash(cell_coords)`. ARCHITECTURE: `hash(coord ^ variation_seed)`. FEATURES: additional `variation_seed_per_paint: bool` exposing per-paint randomness as opt-out. PITFALLS: `hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_salt)` per-instance.

**Recommended path for v0.2:** Hardcode the determinism strategy. Expose ONE knob.
- Picker formula: `rng.seed = hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed); return rng.rand_weighted(weights)` (PITFALLS' four-axis hash protects against same-coord-different-atlas correlation that ARCHITECTURE flagged as a minor cross-atlas detection risk).
- Expose `@export var variation_seed: int = 0` on the contract (re-rollable by the user).
- Do **NOT** expose `variation_seed_per_paint: bool` in v0.2. Per-paint randomness is a legitimate future feature but the deterministic default wins 95% of the time per FEATURES' own analysis.
- Document in user-facing API: "Variation is deterministic per `(cell, atlas_coords, variation_seed)`. Reloading the scene produces identical visuals. To re-roll the whole map, change `variation_seed`."

**Upgrade path for v0.3+:** Add `@export var variation_mode: VariationMode = DETERMINISTIC_PER_COORD` with a second value `RANDOM_PER_PAINT`. Non-breaking addition (new enum value at the END of the enum, never reorder).

### 4. Build order — converged five-phase sequence

**Divergence:** STACK, ARCHITECTURE, FEATURES propose similar but not identical orderings.

**Recommended (CONVERGED):**

| Phase | Name | Rationale |
|-------|------|-----------|
| 1 | Contract skeleton | Introduce Resources; SYMMETRIC mode reads from contract instead of hardcoded constants. Behavior unchanged. **Gates everything else.** |
| 2 | Y-axis variation | Smallest new feature, exercises Godot's alt-tile API in isolation, surfaces transform-bit collision (Pitfall 3) before non-rotating lands. |
| 3 | Non-rotating mode | Largest schema change but conceptually simple once contract + variation are in place. `mask_slots[16]` + generated lookup + diagonal complement. |
| 4 | Top tiles + v0.1-shape detection + per-tile custom_data_layers | Bundled because they all touch the resolver's specific-then-generic fallback chain. Lazy `_top_layer` + `penta_role` / `penta_lock_rotation` + v0.1-detection branch. |
| 5 | Demo refresh + release prep | One expanded demo, README upgrade paragraph, plugin.cfg bump, CHANGELOG, GitHub Release. |

This converges on ARCHITECTURE's ordering with FEATURES' Phase 4 grouping.

### 5. Migration story — bundled default contract is PRIMARY; v0.1-shape detection is BACKUP; both coexist

**Divergence:** FEATURES proposes a v0.1-shape detection branch in the resolver. ARCHITECTURE proposes shipping a bundled default contract `.tres` plus a one-`if` fallback for `atlas_contract == null`.

**Reconciliation:** Both coexist and serve different audiences.
- **Bundled default contract `.tres`** (PRIMARY) — `addons/penta_tile/penta_tile_default_contract.tres` ships with SYMMETRIC mode and v0.1 slot assignments. Users upgrade by referencing it from their scene. Demo references it. README documents this as the explicit, intended migration path.
- **v0.1-shape detection branch** (BACKUP) — one-`if` branch in `_resolve_slot_legacy()` that detects "atlas has 4 tiles in canonical order AND `atlas_contract == null` AND no `penta_role` custom_data_layer is defined" and treats it as the v0.1 contract. Handles users who upgrade the addon without touching their scenes. Lifetime: one minor version (kept through v0.2.x), then removed.

**Roadmap implication:** Both land in Phase 5, not earlier. Phase 1 establishes the `atlas_contract == null → v0.1-hardcoded-fallback` branch, but the v0.1-shape detection heuristic and the bundled `.tres` are user-facing concerns that ship together with the README "Upgrading from 0.1.x" paragraph in Phase 5. The detection heuristic itself is added in Phase 4 because that's when `penta_role` custom_data_layer (the negative signal) is introduced.

## Implications for Roadmap

### Phase 1: Contract Skeleton

**Rationale:** Every other feature depends on the typed Resource being in place. Doing it first lets variation, non-rotating, and top tiles land as small additive changes against a stable schema.

**Delivers:**
- `addons/penta_tile/penta_tile_atlas_contract.gd` — Resource with `version`, `rotation_mode`, four named symmetric slots, empty `mask_slots`, null `top_overlay_slot`, `variation_seed`.
- `addons/penta_tile/penta_tile_atlas_slot.gd` — Resource with `atlas_coords`, `transform_flags`, `alternative_count: int = 1`, `diagonal_complement_atlas_coords`.
- `addons/penta_tile/penta_tile_default_contract.tres` — bundled default reproducing v0.1 HORIZONTAL behavior.
- `@export var atlas_contract` on `PentaTileMapLayer` with disconnect-before-reconnect setter + idempotence guard.
- `_resolve_slot(mask)` reading from contract in SYMMETRIC mode; legacy hardcoded fallback when `atlas_contract == null`.

**Addresses:** "Declare what you have" atlas contract (FEATURES P1).
**Avoids:** Pitfall 5 (setter loops), Pitfall 6 (renames — establishes `__migrate__` discipline), Pitfall 8 (LOC budget).

### Phase 2: Y-Axis Variation

**Rationale:** Smallest feature, biggest competitor gap (TileMapDual: "It currently does not support alternative tiles"). Surfaces Pitfall 3 before non-rotating lands.

**Delivers:**
- `_pick_alternative(slot, display_cell)` — deterministic per-cell hash + `rand_weighted`.
- `_pack_alternative(alt_id, transform_flags)` helper with `assert(alt_id < 4096)` guard.
- Round-trip test: `get_cell_alternative_tile()` returns value passed in.
- Demo atlas extended with 2 fill alternates; visual variation; rebuild does not shimmer.

**Uses:** `TileData.probability` (read-only weights). `RandomNumberGenerator` seeded by 4-axis hash.
**Avoids:** Pitfall 1 (re-entrancy), Pitfall 2 (shimmer), Pitfall 3 (bit collision).

### Phase 3: Non-Rotating Mode

**Rationale:** Largest schema change but conceptually simple once contract + variation are in place.

**Delivers:**
- `RotationMode.NON_ROTATING` + dispatch in `_resolve_slot()`.
- `mask_slots: Array[AtlasSlot]` of length 16 on contract.
- `_build_lookup_table()` generated at contract-load time (rotating fallback merged with non-rotating overrides).
- Diagonal complement field on `AtlasSlot` for masks 6/9.
- `update_configuration_warnings()` validator (errors on missing slots, lists specific missing masks).
- Mask 0 special case at FIRST line of paint function: `if mask == 0: erase; return`.
- Demo: 16-tile non-rotating atlas (`penta_tile_directional.png/.tres`) renders correctly.

**Avoids:** Pitfall 4 (table errors — generated, not hand-written; validator catches gaps; mask 0 special-cased).

### Phase 4: Top Tiles + v0.1-Shape Detection + Per-Tile Custom Data Layers

**Rationale:** Bundled because they all touch the resolver's specific-then-generic fallback chain. Top tiles plug into the existing pipeline as a new lazy `_top_layer`. TileSet `custom_data_layers` enable mixing rotated/non-rotated tiles per Tilesetter-style per-edge "Sources" property and provide the v0.1-shape detection signal.

**Delivers:**
- `top_overlay_slot: AtlasSlot` on contract (optional / null = no top tiles).
- Lazy `_top_layer: TileMapLayer` (`INTERNAL_MODE_FRONT`) created only when `top_overlay_slot != null`.
- Top-mask paint rule for masks 4 / 8 / 12 (explicit, never inferred — MEDIUM confidence; validate against demo art before committing — possibly extend to 5/7/13).
- TileSet custom_data_layer schema: `penta_role: String`, `penta_lock_rotation: bool`.
- v0.1-shape detection in `_resolve_slot_legacy()`.
- Demo: `penta_tile_grass_top.png/.tres` with platformer grass cap; player walks on top correctly.

**Avoids:** Pitfall 7 (over-clever auto-detect — top assignment is explicit per-mask in the contract).

### Phase 5: Demo Refresh + Release Prep

**Rationale:** Demo benefits from API stability across all features. Release prep is a single pass at the end.

**Delivers:**
- One expanded demo with three side-by-side `PentaTileMapLayer` nodes (legacy 4-tile via bundled default, variation, non-rotating, top-tile) OR runtime contract switching.
- README "Upgrading from 0.1.x" paragraph documenting both migration paths (bundled default `.tres` PRIMARY; v0.1-shape detection BACKUP).
- `plugin.cfg` `version` bumped to `0.2.0`; description updated.
- CHANGELOG.md entry per breaking field rename.
- GitHub Release `penta_tile-v0.2.0.zip` with `addons/penta_tile/` at archive root.
- Git tag `v0.2.0` (no `-pre`/`-alpha`/`-dev`).

**Avoids:** Pitfall 6 (migration EditorScript runs cleanly on demo before release), Pitfall 8 (final LOC audit).

### Phase Ordering Rationale

```
Phase 1 (contract skeleton) ──┬──> Phase 2 (variation) ──┬──> Phase 3 (non-rotating)
                              │                          │
                              └──> Phase 4 (top tiles + v0.1 detection + custom data layers)
                                                         │
                                                         └──> Phase 5 (demo + release)
```

- Phase 1 gates everything: every other phase reads through the contract.
- Phase 2 surfaces variation pitfalls (1/2/3) early when easiest to debug.
- Phase 3 locks in non-rotating table generation (Pitfall 4) before per-tile complexity arrives in Phase 4.
- Phase 5 is purely consuming.

### Research Flags

**Phases likely needing deeper research during planning** (`/gsd-research-phase`):
- **Phase 4 (top tiles + custom_data_layers + v0.1-shape detection)** — three open questions: (1) which masks count as "top edge" — 4/8/12 only, or also 5/7/13 for partial caps? (MEDIUM confidence per ARCHITECTURE, validate against demo art). (2) How does the resolver's specific-then-generic fallback chain interact with per-tile `penta_lock_rotation`? (3) v0.1-shape detection heuristic strictness.
- **Phase 3 (non-rotating mode)** — generated lookup mechanics need pinning (transpose-vs-flip rotation-sense bugs in the merge); validator UX in inspector for partial atlases.

**Phases with standard patterns** (skip research):
- **Phase 1** — pure Godot Resource subclass + setter discipline.
- **Phase 2** — picker formula and bit-packing helper fully specified in PITFALLS + ARCHITECTURE.
- **Phase 5** — packaging fully documented in STACK.md.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Godot 4.6 APIs verified directly via Context7 (`/websites/godotengine_en_4_6`) and `docs.godotengine.org/en/4.6` — `_update_cells` signature, `set_cell` + `alternative_tile` packing, transform constants (4096/8192/16384), `TileData.probability`, `TileSet.add_custom_data_layer`, `Array[Resource]` exports. |
| Features | HIGH | Competitor inventory cross-checked against TileMapDual GitHub (verified quote), Better Terrain Asset Library entry, jess-hammer reference impl. Engine determinism gap confirmed via proposal #10948. MEDIUM on top-tile authoring UX (no canonical Godot pattern). |
| Architecture | HIGH | Resource serialization rules, alt-tile + transform flag interaction, `_update_cells` semantics, custom data layer mechanics — all verified against Godot 4.6 docs. MEDIUM on top-tile mask criteria (4/8/12) — validate against demo art in Phase 4. |
| Pitfalls | HIGH | Godot mechanics verified; engine traps cross-referenced to specific GitHub issues (#48437, #92068, #84981, #71188, #57677). MEDIUM on project-specific predictions (e.g., scope creep is a forecast). |

**Overall confidence:** HIGH. The biggest residual uncertainty is the top-tile mask-set definition, which is empirical and best validated against demo art during Phase 4 rather than solved on paper.

### Gaps to Address

- **Top-tile mask set** (MEDIUM): Phase 4 should screenshot the platformer demo with masks 4/8/12 painted as caps, then visually evaluate masks 5/7/13.
- **`update_configuration_warnings()` UX for partial non-rotating atlases** (LOW): Phase 3 should mock the inspector for a contract missing 3 of 16 mask slots; warning may need to list specific missing masks.
- **`tile_set.tile_size` non-uniformity** (FLAG, out-of-scope per PROJECT.md): If "tall top" tiles ever appear, `_visual_layer_offset()` returning `tile_size * -0.5` breaks. Out of scope for v0.2 but flag if it sneaks in.
- **4.5→4.6 upgrade guide content** (MEDIUM per STACK): only TOC was extracted; human read needed before v0.2.0 release commit.

## Sources

### Primary (HIGH confidence)
- Context7: `/websites/godotengine_en_4_6` — `TileSetAtlasSource`, `TRANSFORM_*` constants, `EditorPlugin` virtuals, `TileSet` custom data layers, `TileData` API.
- Context7: `/godotengine/godot-docs` — Resource subclass patterns, `_update_cells`, `set_cell`.
- Official Godot 4.6 docs: `class_tilemaplayer`, `class_tilesetatlassource`, `class_tiledata`, `class_tileset`, `class_randomnumbergenerator`.
- Official Godot 4.6 tutorials: `using_tilesets.html`, `using_tilemaps.html` (scattering = editor-only), `gdscript_exports.html`, `making_plugins.html`, `installing_plugins.html`, `inspector_plugins.html`, `resources.md`.
- PentaTile codebase: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/CONCERNS.md`, `addons/penta_tile/penta_tile_map_layer.gd`.
- Project constraints: `.planning/PROJECT.md`.

### Secondary (MEDIUM confidence)
- TileMapDual GitHub (pablogila/TileMapDual) — verified quote "It currently does not support alternative tiles"; empty Releases page; issue tracker (#59 HTML5, #72 cache refactor, #73/#75/#76 leaks/crashes).
- Better Terrain (Portponky/better-terrain) — feature inventory; runtime API.
- 5-Tile Dual-Grid AutoTiler (Asset Library #4183).
- jess-hammer/dual-grid-tilemap-system-godot — 16-rule reference impl.
- Tilesetter docs — verified per-edge "Sources" property quote.
- BorisTheBrave: Classification of Tilesets, Marching Squares — taxonomy + bit conventions.
- Godot proposals/issues: #10948 (deterministic terrain randomization), #7670 (terrain matching determinism), #71188 (3→4 tilemap migration), #75272 (atlas merging tool), #92068 (Array[CustomResource] rename), #84981 (scene corruption from renames), #48437 / #52757 / #76019 (setter recursion crashes), #57677 (random alt tiles + animations), #72525 (alt tile rotation).
- Prvaak blog: Safely Renaming Exported Variables — `__migrate__()` pattern.
- Godot Forum: more-tool-woes — `@onready` race in tool scripts.

### Tertiary (LOW confidence — needs validation)
- v0.1's `self_modulate.a` workaround for `visible=false` cleanup is project-internal lore (not in upstream Godot docs).
- Top-tile mask-set definition (4/8/12) — designer judgment; validate in Phase 4.
- 4.5→4.6 upgrade guide TileMapLayer breaking-change section — needs human read.
- Mapledev: How to Design a Platformer Tileset — informal description; useful as inspiration not authoritative spec.

---
*Research completed: 2026-04-25*
*Ready for roadmap: yes*
