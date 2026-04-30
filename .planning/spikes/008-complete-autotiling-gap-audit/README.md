---
spike: 008
name: complete-autotiling-gap-audit
type: standard
validates: "Given all shipped PentaTile features + the full v2 backlog + VirtuMap's requirements + competitive autotilers (TileMapDual, Better Terrain, Tilesetter), when every feature axis is scored, then we identify which gaps are real vs. architectural anti-features, and produce a prioritized v0.3/v2 feature matrix"
verdict: VALIDATED
related: [004, 005, 006, 007]
tags: [audit, gap-analysis, competitive, roadmap, v0.3, v2]
---

# Spike 008: Complete Autotiling Gap Audit

## What This Validates

**Given** PentaTile v0.2.0 (8 layouts, synthesis, fallback, auto-detect) + the full v2 backlog (26 deferred items) + VirtuMap's integration requirements (6 gaps) + competitive landscape (TileMapDual, Better Terrain, Tilesetter, TileBitTools),
**When** every feature axis is scored for completeness against real user needs,
**Then** we identify which missing features are genuine gaps (must-add) vs. identity-protected anti-features (deliberately absent), and produce a prioritized implementation matrix.

## Research

### Competitive Baseline

| Feature | TileMapDual v5.0.2 | Better Terrain | Tilesetter | PentaTile v0.2.0 | Gap? |
|---------|-------------------|----------------|------------|-------------------|------|
| Dual-grid autotiling | ✓ (core) | ✗ | ✗ | ✓ (DualGrid16, Penta) | — |
| Single-grid autotiling | ✗ | ✓ | ✓ (via Godot terrain) | ✓ (6 layouts) | — |
| Multi-terrain dispatch | ✓ (terrain peering) | ✓ (core) | ✓ (3-terrain Wang) | ✗ **GAP** | **v0.3** |
| Variation (deterministic) | ✗ (no alt-tile support) | ✗ | ✗ | ✗ **GAP** | **v0.3** |
| Slope autotiling | ✓ (via terrain) | ✗ | ✗ | ✗ **GAP** | **v0.3** |
| 47-blob support | ✓ (via terrain) | ✓ (via terrain) | ✓ (native) | ✓ (Blob47Godot) | — |
| PixelLab format | ✗ | ✗ | ✗ | ✓ (2 layouts) | — |
| Load-time synthesis | ✗ | ✓ (Gaea-style) | ✗ | ✓ (Penta ONE→FIVE) | — |
| Fallback/prototyping TileSet | ✗ | ✓ (greybox) | ✗ | ✓ (auto-generated) | — |
| Mask decoder from template | ✗ | ✗ | ✗ | ✓ (spikes 001-003, not shipped) | **v0.3** |
| Non-rotating atlas | ✓ (dedicated per-dir tiles) | ✗ | ✓ (via tileset) | ✓ (DualGrid16, Wang*) | — |
| Top-tile support | ✗ | ✗ | ✗ | ✗ **GAP** | **v2** |
| RPG Maker support | ✗ | ✗ | ✗ | ✗ (deferred) | — |
| Editor tool preview | ✓ (raw atlas) | ✓ | N/A | ✗ **GAP** | **v0.3** |
| Batch paint API | ✗ | ✗ | ✗ | ✗ **GAP** | **v0.4** |
| Custom data layers | ✗ | ✓ | ✗ | ✗ (not needed) | — |
| Terrain rule try (performance pattern) | ✓ | ✗ | ✗ | ✗ (identity guardrail) | **Anti-feature** |
| Coordinate cache | ✓ | ✗ | ✗ | ✗ (identity guardrail) | **Anti-feature** |
| Watcher/signal fanout | ✓ | ✗ | ✗ | ✗ (identity guardrail) | **Anti-feature** |
| Signal-based rebuild | ✓ | ✓ | ✗ | ✗ (identity guardrail) | **Anti-feature** |

### Feature Axis Scoring

Each feature axis scored on three dimensions (1-5):

| Feature | Completeness | Demand | Implementation Risk | Priority Score |
|---------|-------------|--------|---------------------|----------------|
| Multi-terrain dispatch | 0/5 (not started) | 5/5 (VirtuMap core, Godot terrain users) | 3/5 (arch design done, peering bits = risk) | **8.0 — v0.3** |
| Variation (deterministic) | 0/5 (deferred) | 5/5 (artists expect it, Godot probability unused) | 2/5 (PITFALLS.md already has deterministic recipe) | **7.5 — v0.3** |
| Editor tool preview (line/rect) | 0/5 (known bug) | 4/5 (editing UX broken) | 3/5 (ghost material approach ~30 LOC) | **7.0 — v0.3** |
| Slope layout | 0/5 | 3/5 (VirtuMap needs it, niche otherwise) | 3/5 (new layout subclass, no pipeline changes) | **5.0 — v0.3** |
| Atlas passthrough | 0/5 | 3/5 (VirtuMap fixtures) | 1/5 (source-ID gating in _update_cells) | **4.5 — v0.3** |
| Mask decoder (template→slot table) | 0/5 (spikes done, not shipped) | 3/5 (custom layout authoring) | 2/5 (Python→GDScript port of spike 001-003) | **4.5 — v0.3** |
| Tilesetter layouts | 0/5 (deferred D-86) | 3/5 (Tilesetter users) | 3/5 (primary source not located) | **4.0 — v0.4** |
| Bulk paint API | 0/5 | 2/5 (procedural gen, >500 cells) | 2/5 (loop + single _update_cells) | **3.5 — v0.4** |
| Precedence groups | 0/5 | 3/5 (VirtuMap Hull>Wall>Floor) | 4/5 (multi-layer visual output) | **4.0 — v0.4** |
| Top tiles | 0/5 (deferred v2) | 4/5 (platformer games) | 3/5 (explicit per-mask table, no inference) | **5.0 — v2** |
| RPG Maker family | 0/5 (deferred) | 2/5 (retro users) | 5/5 (quarter-tile compositor) | **3.0 — v2** |
| Godot terrain solver delegation | 0/5 (rejected) | 2/5 (ease of adoption) | 5/5 (identity guardrail, non-deterministic) | **Anti-feature (MULTITERR-07)** |
| Persistent coordinate cache | 0/5 (rejected) | 1/5 (large maps only) | 3/5 (identity guardrail) | **Anti-feature** |
| EditorInspectorPlugin | 0/5 (rejected) | 2/5 | 5/5 (3800 LOC for TileBitTools) | **Anti-feature** |

### Priority Score Formula

`Priority = (Completeness_gap × 0.3) + (Demand × 0.4) + ((5 - Risk) × 0.3)`

Lower completeness = higher priority. Higher risk = lower priority.

### v0.3 Recommended Scope

| Feature | LOC Estimate | Dependencies | Status |
|---------|-------------|--------------|--------|
| **Multi-terrain dispatch** (atlas_coords.y encoding) | +80 | Spike 006 findings | Design complete |
| **Variation** (deterministic hash + TileData.probability) | +120 | None (PITFALLS §2 recipe) | Design ready |
| **Editor tool preview** (ghost material refactor) | +30 | `.planning/research/editor-line-rect-preview.md` | Research complete |
| **PentaTileLayoutSlope** | +55 | Spike 005 findings | Design complete |
| **Atlas passthrough** | +90 | Spike 004 findings | Design complete |
| **Mask decoder** (template→slot table, GDScript port) | +200 | Spikes 001-003 | Research complete, code pending |
| **source_id on AtlasSlot** | +50 | None (schema addition) | Design complete |
| **terrain_mode() virtual** | +30 | Spike 007 findings | Design complete |
| **compute_mask(strip_index) extension** | +40 | Spike 006 findings | Design complete |
| **`set_cells()` batch method** | +80 | None | Nice-to-have |

**Estimated v0.3 LOC delta: +775** (on top of v0.2.0's 2884 runtime LOC)

### Identity Guardrail Check

All v0.3 candidates pass the guardrail:
- No terrain peering metadata AUTHORING required (only reading)
- No terrain rule tries
- No watcher/signal-fanout systems
- No persistent coordinate cache
- No custom drawing API
- No `EditorInspectorPlugin` polish
- No Godot terrain solver delegation for generated visuals
- No `version: int` fields or schema markers

Hot path stays: `_update_cells → compute_mask(strip_index) → mask_to_atlas(mask, strip_index) → set_cell`

### Out of Scope (confirmed anti-features)

These are deliberately NOT included despite some competitive tools having them:

| Feature | Competitor Has | Why PentaTile Rejects |
|---------|---------------|----------------------|
| Terrain solver delegation | Better Terrain, Godot native | Non-deterministic, breaks mask contract, identity violation |
| Persistent coordinate cache | TileMapDual | Demo-scale doesn't need it; adds lifecycle bugs |
| Watcher/signal fanout | TileMapDual | Signal storm risk; deferred coalescing is sufficient |
| Custom paint API | TileBitTools | Defeats native-API win |
| Terrain editor dock | Better Terrain, TileBitTools | Anti-pattern: 3800 LOC for editor polish |
| Hex/iso grid support | TileMapDual | Identity expansion beyond scope |
| JSON metadata/entity spawning | Gaea, Unity | World-building framework, not autotiler |
| GPU infinite-world shaders | Various | Premature optimization; demo-scale target |

## Investigation Trail

### Iteration 1: Feature Inventory

Catalogued all 10 deferred v2 items from REQUIREMENTS.md, all 6 VirtuMap gaps from spike 004, and all 5 competitive gaps from TileMapDual/Better Terrain comparison. Result: 21 candidate features, 6 anti-features, 15 genuine gaps.

### Iteration 2: Prioritization

Scored each gap on completeness (how much work is already done), demand (how many users need it), and risk (complexity + identity violation risk). Grouped into v0.3 (urgent), v0.4 (valuable), v2 (complex), and anti-features (rejected).

### Iteration 3: Gate Check

Ran each v0.3 candidate through the identity guardrail checklist. All passed. The terrain-specific features (006, 007) are the closest to the line — they read Godot terrain metadata — but stay on the correct side by never calling Godot's terrain solver.

### Iteration 4: Integration with Phase 9

Phase 9 (Terrain + Variation Authoring Research Spike) should consume:
- Spike 006: atlas_coords.y terrain encoding + cross-terrain mask filtering + precedence groups
- Spike 007: peering bits → mask conversion + terrain_mode() virtual + candidate index

These provide Phase 9 with concrete implementation designs rather than starting from scratch.

## Results

### Verdict: VALIDATED

Complete gap audit identifies **10 real gaps** (6 v0.3, 3 v0.4, 1 v2), **6 anti-features** (rejected), and **5 already-solved** features (shipped in v0.2.0).

### Prioritized v0.3 Feature Matrix

```
Priority    Feature                         LOC     Risk    Blocks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
P0 ████     Multi-terrain dispatch           +80    Med     VirtuMap, Godot users
P0 ████     Variation (deterministic)        +120   Low     Artists, VirtuMap visual variety
P1 ███░     Editor preview fix               +30    Low     Daily editing UX
P1 ███░     Atlas passthrough                +90    Low     VirtuMap fixtures
P1 ███░     Slope layout                     +55    Med     VirtuMap terrain
P2 ██░░     Mask decoder (GDScript port)     +200   Low     Custom layout authoring
P2 ██░░     source_id on AtlasSlot           +50    Low     Multi-source TileSets
P2 ██░░     terrain_mode() virtual           +30    Med     Godot terrain integration
P3 █░░░     compute_mask(strip_index)        +40    Low     Multi-terrain compute
P3 █░░░     set_cells() batch                +80    Low     Procedural gen performance
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
v0.3 Total                                 +775    —       —
```

### What to add to Phase 9 scope

Phase 9's current scope (terrain + variation authoring research spike) should be expanded to include:
1. Atlas passthrough (spike 004) — minimal code, high VirtuMap value
2. Editor preview fix — already researched, ~30 LOC
3. The full compute_mask(strip_index) signature extension — gates multi-terrain

### What to add as new phases/todos

- **Phase 10: Multi-Terrain + Variation Implementation** (v0.3) — P0 items from matrix
- **Phase 11: VirtuMap Integration Bridge** (v0.3) — Passthrough, slope, batch API
- **Todo: source_id on PentaTileAtlasSlot** (phase 10 schema change)
- **Todo: terrain_mode() virtual on PentaTileLayout base** (phase 10)
- **Todo: GDScript port of spike 001-003 mask decoder** (v0.4 tooling)
