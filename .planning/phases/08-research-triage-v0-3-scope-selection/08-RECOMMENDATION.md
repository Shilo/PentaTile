# Phase 8 v0.3 Recommendation

## Recommendation

**Recommended package:** Terrain + Variation Authoring Research Spike.

**Included requirement IDs:** `VAR-01`, `VAR-PIXEL-01`, `MULTITERR-01..08`; informs later `TERRAIN-01`.

**Excluded requirement IDs:** `TOP-01`, `TBT-01-DEFERRED`, `TBT-02-DEFERRED`, `TOOL-01`, `TOOL-02`, `PERF-02`, `DIST-01`, Phase 6 editor preview.

**Why it fits:** The package is research/spike work only. It keeps PentaTile's small hot path intact while answering the highest-risk design question: how real Godot TileSets should be authored when automated terrain selection and automated variation both want to influence the final `set_cell(source_id, atlas_coords, alternative_tile)` tuple.

**Required spike comparisons:**

- Variation by alternatives plus `TileData.probability`.
- Atlas rows or banks for variation and terrain.
- Multiple atlas sources inside one `TileSet`.
- Godot `TileData.terrain` / `terrain_set` / peering metadata as input.
- PixelLab-style variation banks.
- Penta terrain banks.

**Hard gates:** Production terrain/variation refactors are blocked until the spike produces findings and the user completes manual Godot testing outside this repo with real authored TileSets.

## Alternates

### Alternate 1: Art Quality Pack

**Included requirement IDs:** `VAR-01`, `VAR-PIXEL-01`, `TOP-01`.

**Excluded requirement IDs:** `MULTITERR-01..08`, `TBT-01-DEFERRED`, `TBT-02-DEFERRED`, `TOOL-01`, `TOOL-02`, `PERF-02`, `DIST-01`, Phase 6 editor preview.

**Why it fits:** This improves visible output while keeping behavior deterministic and layout-local. It fits if the user decides terrain research is too broad for v0.3.

**Trigger to choose instead:** Choose this if a real game urgently needs variation/top-tile polish before terrain support, and if the variation strategy can be limited without foreclosing the later terrain design.

### Alternate 2: Adoption / UX Pack

**Included requirement IDs:** Phase 6 editor preview, `DIST-01`; optionally docs polish if Asset Library submission exposes gaps.

**Excluded requirement IDs:** `VAR-01`, `VAR-PIXEL-01`, `TOP-01`, `MULTITERR-01..08`, `TBT-01-DEFERRED`, `TBT-02-DEFERRED`, `TOOL-01`, `TOOL-02`, `PERF-02`.

**Why it fits:** This avoids runtime refactors and improves usability/discoverability. It is the lowest-risk v0.3 package.

**Trigger to choose instead:** Choose this if the next priority is public adoption rather than new autotiling capability.

## Exclusions

The recommendation does not authorize:

- Godot terrain-solver delegation for generated visuals.
- Global solvers, backtracking, terrain-rule tries, or Better Terrain-style framework scope.
- Terrains dock/editor wizard/bulk terrain-bit editor work.
- Persistent coordinate caches.
- Custom paint APIs parallel to `set_cell()` / `erase_cell()`.
- Scriptable rule engines or metadata/entity-spawning systems.
- Hex/isometric/grid-agnostic expansion.
- GPU/procedural world generation.
- Compatibility shims, deprecation aliases, migration branches, version fields, schema markers, or speculative extension points.
- Production terrain/variation refactors before the spike and user-side manual testing pass.

## Exact Next Command

```text
/gsd-add-phase "Terrain + Variation Authoring Research Spike"
/gsd-plan-phase <new phase number>
```

After the new phase number is assigned, plan that phase before any implementation. The phase should produce research findings, fixture/testing instructions, and go/no-go criteria for production terrain/variation work.
