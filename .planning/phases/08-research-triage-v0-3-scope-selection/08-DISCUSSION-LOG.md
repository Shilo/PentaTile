# Phase 08: Research Triage + v0.3 Scope Selection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `08-CONTEXT.md` - this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 08-research-triage-v0-3-scope-selection
**Areas discussed:** v0.3 package direction, multi-terrain scope, refactor boundary, external testing gate, variation coupling, scope firewall, existing plan handling

---

## v0.3 Package Direction

| Option | Description | Selected |
|--------|-------------|----------|
| Terrain Research Spike first | Validate multi-terrain feasibility before implementation. | |
| Art Quality Pack | Deterministic variation + PixelLab variation banks + explicit top tiles. | |
| Adoption/UX Pack | Editor drag preview + docs/distribution polish. | |
| Ecosystem Pack | Tilesetter layouts + converter research. | |
| Terrain + Variation Authoring Research Spike | Research terrain and variation together as a coupled TileSet-authoring problem. | yes |

**User's choice:** Approved Terrain + Variation Authoring Research Spike.
**Notes:** The user is mainly worried about implementation-heavy work such as multi-terrain support requiring refactoring. The selected direction is research/spike first, not implementation.

---

## Multi-Terrain Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Research-only spike | Produce findings, prototype notes, fixture requirements, and go/no-go criteria. | yes |
| Single-grid implementation first | Implement Wang2Edge, Wang2Corner, Min3x3, and Blob47Godot first. | |
| Full staged roadmap | Single-grid first, dual-grid second, Penta terrain banks third. | |
| Defer terrain entirely | Keep in backlog until a real game need forces it. | |

**User's choice:** Research-only first.
**Notes:** The user expects serious research and external testing before production implementation.

---

## Refactor Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Prototype can be messy | Spike may create throwaway code/fixtures, but no production architecture changes. | yes |
| Minimal production seam only | Allow tiny preparatory cleanup if clearly useful outside terrain. | |
| Plan full refactor now | Candidate index, source-aware output, and terrain sampling become planned implementation. | |
| No code changes in spike | Research docs only; user tests externally and reports back. | |

**User's choice:** Prototype allowed; production refactor forbidden until spike passes.
**Notes:** Phase 8 should not quietly commit the project to candidate-index or dispatcher refactors.

---

## External Testing Gate

| Option | Description | Selected |
|--------|-------------|----------|
| Hard gate | No implementation phase until user tests real Godot-authored TileSets outside this repo. | yes |
| Soft gate | Implementation can begin with checkpoints for external testing. | |
| Agent-only validation | Rely on repo fixtures and generated tests. | |
| Hybrid | Agent builds small fixtures; user validates one real workflow before finalizing scope. | |

**User's choice:** Hard gate.
**Notes:** The user explicitly expects to test outside this project before production implementation proceeds.

---

## Variation Coupling

| Option | Description | Selected |
|--------|-------------|----------|
| Separate variation phase | Safer; deterministic variation can land without terrain complexity. | |
| Fold into terrain spike | Research shared candidate/weight design, but do not implement both yet. | yes |
| Implement variation first | Use variation as a stepping stone before terrain. | |
| Bundle variation with terrain implementation | Efficient if candidate index is certain, risky if not. | |

**User's choice:** Variation must be researched together with multi-terrain.
**Notes:** User correction: variation depends heavily on how TileSets are created. The best TileSet layout for automated terrain plus automated variation is unknown and needs significant brainstorming. Do not choose a variation API, seed shape, Y-axis convention, alternative strategy, or terrain-bank layout before this spike.

---

## Scope Firewall

| Option | Description | Selected |
|--------|-------------|----------|
| Hard firewall | Reject framework-scale systems unless project identity changes. | yes |
| Soft backlog language | Say "not v0.3" rather than "do not pursue." | |
| Two-tier firewall | Hard reject framework items; soft-defer plausible tools. | |
| Reopen identity | Reconsider whether PentaTile should become broader. | |

**User's choice:** Hard firewall.
**Notes:** Preserve PentaTile's small hot-path identity. Godot terrain metadata may be input, but Godot terrain-solver delegation remains rejected for generated visuals.

---

## Existing Phase 8 Plans

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `08-01`, patch `08-02` through `08-04` | Preserve evidence artifacts; update remaining scope-selection work. | yes |
| Replan all remaining Phase 8 plans | Cleaner, heavier. | |
| Redo all Phase 8 from scratch | Cleanest conceptually, unnecessary. | |
| Write context only, pause | No more planning/execution until manual review. | |

**User's choice:** Keep completed `08-01`; patch or replan remaining Phase 8 work.
**Notes:** `08-01` evidence is still useful. The remaining plans must reflect Terrain + Variation Authoring Research Spike and external-testing gates.

---

## Agent Discretion

- Exact artifact shape for the spike recommendation can be chosen by the planner/executor.
- The agent may patch existing remaining plans or re-run plan-phase, as long as `08-CONTEXT.md` is consumed before continuing.

## Deferred Ideas

- Direct production multi-terrain implementation.
- Standalone variation implementation before terrain/variation authoring research.
- Full dual-grid terrain blending, Penta terrain transitions, and framework-scale terrain systems.
