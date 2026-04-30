# Phase 8 Backlog Cleanup

| Requirement / Topic | Change Applied | Source Artifact | Trigger / Constraint |
| --- | --- | --- | --- |
| `TRIAGE-03` | Added external-test burden and the Terrain + Variation Authoring Research Spike to the required candidate matrix coverage. | `08-CONTEXT.md`, `08-CANDIDATE-MATRIX.md` | Candidate ranking must account for user-side testing and coupled terrain/variation uncertainty. |
| `TRIAGE-04` | Expanded firewall language to include Godot terrain-solver delegation, pre-spike production refactors, compatibility shims, version/schema markers, and speculative extension points; preserved Godot terrain metadata as input only. | `08-SCOPE-FIREWALL.md` | Metadata input allowed; solver delegation and framework-scale systems rejected. |
| `TRIAGE-05` | Added the spike-plus-user-testing gate to backlog refinement examples. | `08-CONTEXT.md` | Production terrain/variation work waits for spike findings and outside-repo Godot testing. |
| `VAR-01` | Added un-defer trigger requiring the spike to compare alternatives/probability, atlas rows/banks, multiple atlas sources, PixelLab-style banks, and Penta terrain banks. | `08-CONTEXT.md`, `08-CANDIDATE-MATRIX.md` | Variation API/seed/authoring strategy stays undecided until spike completes. |
| `VAR-PIXEL-01` | Clarified that PixelLab bank pick un-defers with `VAR-01` after shared candidate/weight design is resolved. | `08-CONTEXT.md`, `08-CANDIDATE-MATRIX.md` | Do not implement PixelLab variation as a separate shortcut. |
| `TOP-01` | Added explicit un-defer trigger for art-quality package and per-layout top-tile table shape. | `08-DISPOSITION-MATRIX.md` | Top tiles remain explicit, never inferred from "tile below". |
| `MULTITERR` intro | Added 2026-04-30 context reframe and hard block on production implementation before spike plus user testing. | `08-CONTEXT.md`, `08-MULTI-TERRAIN-RESEARCH.md` | Multi-terrain remains promising but research-heavy. |
| `MULTITERR-08` | Added user-side manual Godot testing outside this repo as a required pre-production gate. | `08-CONTEXT.md` | Repo fixtures support the spike but cannot replace user workflow testing. |
| `TOOL-01` | Renamed the visible backlog label from a Penta-prefixed tool name to Penta-format composition helper and added tooling-package trigger. | AGENTS.md coined-term discipline, `08-SCOPE-FIREWALL.md` | Avoid coining Penta-prefixed subsystems outside the Penta format. |
| `TOOL-02` | Added target-package trigger and no-compat-shim constraint. | `08-SCOPE-FIREWALL.md` | Converter tooling must not become migration machinery. |
| `PERF-02` | Added trigger requiring a real target map size or scene beyond demo-scale behavior. | `08-DISPOSITION-MATRIX.md`, `05-LOC-AUDIT.md` | Benchmark before optimizing; no caches/shaders/workers before evidence. |
| `DIST-01` | Added adoption/distribution package trigger. | `08-CANDIDATE-MATRIX.md` | Asset Library waits until public adoption is selected. |
| Out of Scope | Updated tooling label, clarified terrain solver rejection, corrected editor-terrain rationale, and added pre-spike production terrain/variation refactor rejection. | `08-SCOPE-FIREWALL.md` | Rejected systems remain visible instead of being rediscovered. |

## Terrain + Variation Coupling

Variation should not be planned as a quick standalone implementation because the same final `set_cell(source_id, atlas_coords, alternative_tile)` tuple has to carry terrain identity, variation choice, atlas/source routing, transform flags, and weights. The spike must decide how real TileSets should be authored before production code chooses a seed property, bank layout, source-index shape, or PixelLab-specific API.

## No-Compat / No-Forward-Compat Check

No compatibility shims, deprecation aliases, version fields, schema markers, migration branches, or speculative extension points were added. The requirements edits clarify triggers and constraints only.
