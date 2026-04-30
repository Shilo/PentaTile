# Phase 08: Research Triage + v0.3 Scope Selection - Context

**Gathered:** 2026-04-30
**Status:** Ready for replanning

<domain>
## Phase Boundary

Phase 8 selects and documents the next v0.3 direction. It verifies supplied competitive-autotiling research, filters recommendations through PentaTile's identity guardrails, updates backlog guidance, and recommends the next planning target. It does not implement terrain, variation, editor tooling, or runtime refactors.

</domain>

<decisions>
## Implementation Decisions

### v0.3 Package Direction
- **D-01:** Recommend a **Terrain + Variation Authoring Research Spike** as the next v0.3 package, not a direct implementation phase.
- **D-02:** The spike must treat terrain support and automated variation support as one coupled authoring problem because both depend on how users create TileSets, organize terrain banks, variation banks, atlas sources, alternatives, and weights.
- **D-03:** Do not recommend `VAR-01`, `VAR-PIXEL-01`, or `MULTITERR-*` as isolated implementation work until the spike compares real TileSet layout strategies.

### Multi-Terrain Scope
- **D-04:** Multi-terrain is promising but research-heavy. Phase 8 should label it as a spike/research candidate with explicit go/no-go criteria, not as implementation-ready scope.
- **D-05:** First terrain investigation should focus on single-grid layouts (`Wang2Edge`, `Wang2Corner`, `Minimal3x3`, `Blob47Godot`) before dual-grid or Penta terrain-bank support.
- **D-06:** Dual-grid multi-terrain and Penta terrain-bank support are later complexity tiers. Do not bundle them into the first implementation recommendation.

### Refactor Boundary
- **D-07:** Exploratory prototype code or throwaway fixtures are allowed during the spike, but production refactors are forbidden until the spike passes.
- **D-08:** The spike may identify candidate seams such as source-aware output records, terrain-aware sampling, deterministic weighted candidate selection, and fixture requirements, but it must not add compatibility shims, version fields, schema markers, or speculative extension points.

### External Testing Gate
- **D-09:** User-side manual Godot testing outside this repository is a hard gate before production implementation. The spike must produce concrete external testing instructions or fixture requirements for real Godot-authored TileSets.
- **D-10:** Agent-only validation is insufficient for the terrain + variation package. Repo fixtures and composed-canvas tests can support the spike, but the final go/no-go requires the user's own external testing.

### Variation Coupling
- **D-11:** Variation needs heavy brainstorming with multi-terrain implementation. The best tileset layout for automated terrain selection plus automated variation selection is unknown.
- **D-12:** The spike must compare at least these authoring/indexing options: variation by alternatives and `TileData.probability`, atlas rows/banks, multiple atlas sources, Godot `TileData.terrain` identity, PixelLab-style variation banks, and Penta terrain banks.
- **D-13:** Do not choose a `variation_seed` property shape, Y-axis convention, alternative-tile strategy, terrain-bank layout, or PixelLab variation-bank API before the terrain + variation spike resolves authoring direction.

### Scope Firewall
- **D-14:** Keep a hard firewall for framework-scale systems: no global solvers/backtracking, no Godot terrain-solver delegation for generated visuals, no terrain-rule editor dock, no persistent coordinate caches, no parallel paint API, no scriptable rule engine, no metadata/entity spawning framework, no hex/iso expansion, and no GPU infinite-world architecture unless PROJECT.md intentionally renegotiates PentaTile's identity first.
- **D-15:** Godot terrain metadata may be read as authoring/indexing input only when PentaTile remains the deterministic solver and generated visuals still flow through native `set_cell()` output.

### Existing Phase 8 Plans
- **D-16:** Keep completed Plan `08-01` as valid evidence work. Its verified claims and disposition matrix are still useful.
- **D-17:** Replan or patch remaining plans `08-02` through `08-04` so the final recommendation becomes Terrain + Variation Authoring Research Spike with hard external-testing and no-production-refactor gates.

### Agent Discretion
- Exact spike artifact names and table formats are flexible as long as they preserve the decisions above and remain checkable.
- The agent may decide whether to patch the existing `08-02`..`08-04` plans or re-run plan-phase, provided the completed `08-01` evidence artifacts are preserved.

</decisions>

<specifics>
## Specific Ideas

- User concern: multi-terrain or other implementation-heavy features may require serious refactoring and must not be smuggled in as ordinary implementation work.
- User expects to test real Godot workflows outside this repo before any production implementation proceeds.
- User specifically does not yet know the best TileSet layout for combined automated terrain support and automated variation support; this uncertainty is the core spike question.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 Source Artifacts
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-RESEARCH-TRIAGE.md` - Initial research-triage findings and identity-filtered recommendations.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-MULTI-TERRAIN-RESEARCH.md` - Focused terrain metadata research and staged feasibility notes.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-VERIFIED-CLAIMS.md` - Primary-source and local evidence gate from Plan 08-01.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-DISPOSITION-MATRIX.md` - Accept/reject/defer matrix from Plan 08-01.
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-PATTERNS.md` - Planning-document patterns and analog artifacts for Phase 8.

### Project Constraints
- `.planning/PROJECT.md` - Core value, identity constraints, breaking-change policy, and current project shape.
- `.planning/REQUIREMENTS.md` - TRIAGE-01..06, VAR-01, VAR-PIXEL-01, TOP-01, MULTITERR-01..08, PERF-02, DIST-01, and out-of-scope firewall.
- `.planning/ROADMAP.md` - Phase 8 boundary, success criteria, and progress table.
- `AGENTS.md` - Project-specific implementation guardrails, critical pitfalls, testing methodology, and coined-term discipline.

### Prior Evidence
- `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` - Identity audit and anti-pattern absence evidence.
- `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-SUMMARY.md` - Post-release docs and test-layout context.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Root `tests/` visual regression harnesses compose rendered output and should inspire spike validation for terrain + variation fixtures.
- Existing layout subclasses already separate mask computation from atlas dispatch, but current production behavior is still fundamentally binary occupancy.

### Established Patterns
- PentaTile preserves a short runtime path: `_update_cells()` samples logic cells, layouts compute masks, slots resolve atlas output, and generated visuals are written with `set_cell()`.
- The project rejects persistent coordinate caches, watcher/signal-fanout systems, and parallel painting APIs.
- Variation determinism must use stable per-cell hashing and never `randi()`.

### Integration Points
- Any future terrain + variation implementation will likely touch sampling semantics, source-aware output selection, `alternative_tile` packing, `TileData.probability`, and visual regression fixtures.
- These integration points are reasons to spike first, not permission to refactor in Phase 8.

</code_context>

<deferred>
## Deferred Ideas

- Production multi-terrain implementation is deferred until the Terrain + Variation Authoring Research Spike passes.
- Standalone deterministic variation implementation is deferred until the spike resolves whether variation should share terrain candidate machinery.
- Dual-grid multi-terrain, Penta terrain banks, and true terrain-to-terrain transition art remain later stages after single-grid feasibility is understood.
- Tilesetter layouts, converter tooling, Asset Library submission, and editor preview remain candidate alternates, not the approved v0.3 recommendation.

</deferred>

---

*Phase: 08-research-triage-v0-3-scope-selection*
*Context gathered: 2026-04-30*
