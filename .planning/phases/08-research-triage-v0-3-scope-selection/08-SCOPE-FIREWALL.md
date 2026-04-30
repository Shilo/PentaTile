# Phase 8 Scope Firewall

This artifact records which tempting research suggestions are rejected, quarantined, or allowed only in narrow form. It exists so the recommended spike stays smaller than TileMapDual and does not become a general terrain framework.

| Suggestion | Disposition | Identity Rationale | Allowed Narrow Form | Requirement / Note |
| --- | --- | --- | --- | --- |
| Global solvers/backtracking | reject | Replaces the layout-dispatch model with framework-scale terrain solving. | None unless PROJECT.md identity is renegotiated first. | Out of Scope; `TRIAGE-04` |
| Godot terrain solver as PentaTile renderer | reject | `set_cells_terrain_connect()` / `set_cells_terrain_path()` would make Godot choose generated visuals instead of PentaTile layouts. | Read Godot terrain metadata only; PentaTile still writes with `set_cell()`. | `MULTITERR-07` |
| Godot `TileData` terrain metadata as authoring/indexing input | allowed input only | Metadata can describe authored terrain identity without surrendering the solver. | Read `terrain_set`, `terrain`, peering bits, and probability into research fixtures or a future transient index. | `MULTITERR-01..08` |
| Terrains dock/editor wizard/bulk terrain-bit editor | reject | Turns the addon into editor-tooling territory like Better Terrain or TileBitTools. | Documentation and fixture recipes are allowed. | Out of Scope; `TRIAGE-04` |
| Persistent coordinate caches | reject | Conflicts with the demo-scale hot path and current identity guardrails. | Transient tile-definition indexes may be researched; no coordinate cache. | `PERF-02`, `MULTITERR-02` |
| Custom paint APIs parallel to `set_cell()` | reject | Defeats the public native painting API that makes PentaTile small. | Existing `set_cell()` / `erase_cell()` interception only. | PROJECT identity guardrail |
| Scriptable rule engines | reject | Creates an open-ended framework rather than pluggable layout resources. | Fixed layout resources and documented authoring tables only. | Out of Scope |
| Metadata/entity-spawning systems | reject | Scene/entity spawning is world-building scope, not autotile visual generation. | Godot custom data may be preserved as tile metadata, not as a PentaTile subsystem. | Out of Scope |
| Hex/isometric/grid-agnostic expansion | reject | TileMapDual territory; expands grid model beyond current square-grid addon identity. | None for v0.3. | Out of Scope |
| GPU/procedural world generation | reject | Premature and outside demo-scale quality bar. | Benchmarks first via `PERF-02`; no shader path until measured. | `PERF-02` |
| Compatibility shims | reject | Breaking changes are allowed pre-1.0; shims increase surface area. | CHANGELOG/release notes only. | No-backwards-compat policy |
| Version fields/schema markers | reject | Forward-compat speculation is explicitly forbidden. | None. Future work can add real migration machinery only when actually needed. | No-forward-compat policy |
| Speculative extension points | reject | Adds hooks for hypothetical futures instead of current need. | Concrete virtuals only when a current phase needs them. | No-forward-compat policy |
| Production terrain/variation refactors before spike completion | reject | Would commit the hot path before the authoring model is understood. | Throwaway spike prototypes and fixture experiments only. | `08-CONTEXT.md`, `VAR-01`, `VAR-PIXEL-01`, `MULTITERR-01..08` |
| Throwaway spike fixtures/prototypes | allowed narrow form | Research code can answer design questions without hardening architecture too soon. | Must be clearly disposable; no production API, no persisted schema, no compatibility layer. | `08-CONTEXT.md` |
| User-side manual Godot testing outside this repo | required gate | Real TileSet authoring workflow cannot be proven from repo fixtures alone. | Spike must produce concrete instructions or fixture requirements for the user to test. | `MULTITERR-08`, `08-CONTEXT.md` |

## Firewall Rule

For v0.3 planning, the narrow allowed path is: research Godot-authored TileSet layouts, variation banks, terrain banks, alternatives, probabilities, and multiple sources; document candidate designs and test fixtures; then wait for user-side manual Godot testing before production terrain or variation implementation.
