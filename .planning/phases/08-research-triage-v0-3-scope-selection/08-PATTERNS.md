# Phase 08: Research Triage + v0.3 Scope Selection - Pattern Map

**Mapped:** 2026-04-30
**Files analyzed:** 9 likely new/modified planning artifacts
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-PLAN.md` | plan | batch / transform | `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-PLAN.md` | exact |
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-VERIFIED-CLAIMS.md` | research artifact | source-verification / transform | `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md` | role-match |
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-CANDIDATE-MATRIX.md` | decision artifact | batch / transform | `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` | role-match |
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-SCOPE-FIREWALL.md` | decision artifact | source-verification / transform | `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` | role-match |
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-RECOMMENDATION.md` | decision artifact | batch / transform | `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md` | exact |
| `.planning/phases/08-research-triage-v0-3-scope-selection/08-SUMMARY.md` | closeout | batch / traceability | `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md` | exact |
| `.planning/REQUIREMENTS.md` | requirements | traceability / transform | `.planning/phases/05-demo-refresh-documentation-release/05-02-PLAN.md` | exact |
| `.planning/ROADMAP.md` | roadmap | traceability / transform | `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md` | exact |
| `.planning/STATE.md` | state | event-log / traceability | `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md` | exact |

## Pattern Assignments

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-PLAN.md` (plan, batch / transform)

**Analog:** `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-PLAN.md`

**Header and metadata pattern** (lines 1-5):
```markdown
# Phase 7 Plan: Repo Restructure + MkDocs + LLM-Friendly Docs

**Phase:** 7
**Status:** Executed inline under autonomous request
**Created:** 2026-04-29
```

**Goal pattern** (lines 7-14):
```markdown
## Goal

Ship three post-v0.2.0 repository hygiene deliverables without changing
runtime addon behavior:

1. Move tests out of the addon package to root `tests/`.
2. Add a minimal MkDocs documentation site.
3. Decide whether LLM agents need a generated flat docs artifact.
```

**Requirements list pattern** (lines 16-28):
```markdown
## Requirements

- **REPO-01:** `addons/penta_tile/tests/` is moved to root `tests/`.
- **REPO-02:** test runners, sample image imports, release CI, README, AGENTS,
  CLAUDE, and current planning docs point at root `tests/`.
- **DOCS-08:** LLM docs decision artifact records direct-source vs flat-artifact
  tradeoff and recommendation.
```

**Task breakdown and non-goals pattern** (lines 30-65):
```markdown
## Execution Tasks

1. Audit path references.
2. Move tests.
3. Add MkDocs.
4. Decide LLM docs pipeline.
5. Verify.

## Non-Goals

- No Phase 6 editor-preview implementation.
- No Phase 8 multi-terrain or v0.3 research implementation.
- No runtime `PentaTileMapLayer` or layout behavior changes.
- No compatibility shims, version fields, or speculative docs generation.
```

**Apply to Phase 8:** Use the same compact one-plan shape. The Phase 8 plan should enumerate research-triage deliverables, not code tasks: verify claims, disposition recommendations, rank v0.3 candidates, update backlog/state, and produce recommendation. Non-goals must explicitly firewall implementation work and off-identity terrain-framework scope.

---

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-VERIFIED-CLAIMS.md` (research artifact, source-verification / transform)

**Analog:** `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md`

**Decision-artifact heading pattern** (lines 1-5):
```markdown
# Phase 7 Decision: LLM-Friendly Documentation Surface

**Decision:** Use MkDocs source + GDScript doc comments directly. Do not add an
auto-generated flat text artifact in Phase 7.
```

**Options table pattern** (lines 6-12):
```markdown
## Options Considered

| Option | Benefit | Cost / Risk |
| --- | --- | --- |
| Direct source: `docs/`, `AGENTS.md`, `addons/penta_tile/**/*.gd`, `tests/` | Single source of truth; no generated file drift; agents can inspect implementation and tests beside narrative docs; no workflow surface added. | Agents must read multiple files, but the repo is small and paths are obvious. |
```

**Recommendation and revisit trigger pattern** (lines 13-35):
```markdown
## Recommendation

Keep the direct-source approach for now:

- `AGENTS.md` remains the project contract and pitfall index.
- `docs/` provides task-facing prose.

## Revisit Trigger

Add a flat artifact later only if a concrete consumer appears, such as:
```

**Apply to Phase 8:** Replace "Options Considered" with a verified-claims table:

```markdown
| Claim | Source Checked | Local Repo Check | Disposition | Notes |
| --- | --- | --- | --- | --- |
```

Each accepted claim must cite a primary source or local artifact. Stale claims should be corrected in-place, especially claims that PentaTile lacks dual-grid support or v0.2 release outputs.

---

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-CANDIDATE-MATRIX.md` (decision artifact, batch / transform)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`

**Preamble pattern** (lines 1-8):
```markdown
# Phase 5 - Identity Audit

**Performed:** 2026-04-29
**PentaTile commit:** `905596c4e0c6d89b99abdfd32e84eef1f378ddf9`
**TileMapDual reference:** v5.0.2 (commit `9ff1e24f80be1816cfcd7aeec32800a699a94ccb`, dated 2026-01-03)
**Decision (per D-05-11):** **SHIP**
```

**Comparison table pattern** (lines 80-88):
```markdown
### Comparison

| Repo | Runtime LOC | Files | Notes |
|------|------------:|------:|-------|
| PentaTile | 2884 | 12 | 8 layouts + map layer + synthesis engine + base + slot resource |
| TileMapDual v5.0.2 | 2126 | 14 | Includes legacy v4.3 fallback and a preset author-helper |
| Delta | +758 | -2 | PentaTile's biggest file carries load-time synthesis. |
```

**Decision logic pattern** (lines 314-330):
```markdown
## Decision per D-05-11

**Outcome:** **SHIP**

Rationale:

- **LOC:** ...
- **Public surface:** ...
- **Hot-path:** ...
- **Anti-pattern register:** ...

**Action items:** None - ship as-is per D-05-11.
```

**Apply to Phase 8:** Use a ranked matrix with explicit scoring columns:

```markdown
| Candidate | User Value | Risk | Dependency Coupling | Identity Fit | Suggested Disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| `VAR-01` + `VAR-PIXEL-01` | high | medium | high | high | recommend package A |
```

Required candidates from ROADMAP success criteria: `VAR-01`, `VAR-PIXEL-01`, `TOP-01`, `TBT-01/02-DEFERRED`, `TOOL-01/02`, `PERF-02`, `DIST-01`, Phase 6, and Phase 7 follow-ups. Include `MULTITERR-01..08` because the focused terrain research supersedes the earlier blanket rejection.

---

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-SCOPE-FIREWALL.md` (decision artifact, source-verification / transform)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`

**Anti-pattern register pattern** (lines 270-312):
```markdown
## Anti-Pattern Register Check

### CLAUDE.md Identity Guardrails

| Anti-pattern | Grep query | Result | Status |
|--------------|-----------|-------:|--------|
| Terrain peering metadata or terrain rule tries | `grep -rn "terrain_peering\|peering_bit\|TerrainSet" addons/penta_tile/` | 0 matches | ABSENT |
| Watcher / signal-fanout systems | `grep -rn "Watcher\|signal_fanout\|signal.*broadcast" addons/penta_tile/` | 0 matches | ABSENT |

### Aggregate

- **CLAUDE.md guardrails: 6 of 6 ABSENT.**
- **PITFALLS.md AP-1..AP-10: 10 of 10 ABSENT.**
```

**Apply to Phase 8:** Copy this as a firewall table, but change `Status` to `Disposition` and include `accept`, `defer`, `reject`, or `allowed input only`. The mandatory reject/quarantine list from ROADMAP Phase 8 success criteria:

- global solvers/backtracking
- Godot terrain solver as PentaTile renderer
- Terrains dock/editor wizard/bulk terrain-bit editor
- persistent coordinate caches
- scriptable rule engines
- metadata/entity-spawning systems
- grid-agnostic hex/isometric support
- GPU/procedural world generation

Special rule from `08-MULTI-TERRAIN-RESEARCH.md`: Godot terrain metadata is allowed as authoring/indexing input; calling Godot terrain solver for generated output is rejected.

---

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-RECOMMENDATION.md` (decision artifact, batch / transform)

**Analog:** `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md`

**Recommendation pattern** (lines 13-24):
```markdown
## Recommendation

Keep the direct-source approach for now:

- `AGENTS.md` remains the project contract and pitfall index.
- `docs/` provides task-facing prose.
- `addons/penta_tile/**/*.gd` contains authoritative API doc comments.
- `tests/` demonstrates rendered-output regression methodology.

This fits the project's identity guardrails: small maintained surface, no
speculative pipeline, no generated artifact that future agents might treat as
more authoritative than source.
```

**Revisit-trigger pattern** (lines 26-35):
```markdown
## Revisit Trigger

Add a flat artifact later only if a concrete consumer appears, such as:

- a docs host that needs single-page export,
- a model/tool with poor repository traversal,
- or repeated agent failures caused by missing cross-file context.
```

**Apply to Phase 8:** Produce one recommended v0.3 package and two alternates. Each package should name exact next command target, likely `/gsd-plan-phase <new phase number>` after the planner creates/inserts that phase. Include triggers for deferred alternatives.

Expected shape:

```markdown
## Recommendation

Recommend Package A: <name>

- Why now:
- Included requirements:
- Excluded requirements:
- Next command:

## Alternates

| Package | When to choose it | Requirements | Tradeoff |
| --- | --- | --- | --- |

## Revisit Trigger
```

---

### `.planning/phases/08-research-triage-v0-3-scope-selection/08-SUMMARY.md` (closeout, batch / traceability)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md`

**Frontmatter pattern** (lines 1-48):
```markdown
---
phase: 05-demo-refresh-documentation-release
plan: 05
subsystem: closeout
tags: [closeout, milestone, traceability, ship, v0.2.0, github-release]
requires:
  - .planning/phases/05-demo-refresh-documentation-release/05-01-SUMMARY.md
provides:
  - "v0.2.0 milestone shipped end-to-end (GitHub Release published)"
key-files:
  created:
    - .planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
---
```

**Narrative and metadata pattern** (lines 50-76):
```markdown
# Phase 5 Plan 05: Closeout - v0.2.0 SHIPPED

PentaTile v0.2.0 is live on GitHub...

## Released Version Metadata

| Field | Value |
|-------|-------|
| Version | `0.2.0` |
| Release date | 2026-04-29 |
```

**Traceability table pattern** (lines 77-92):
```markdown
## 10 Flipped Requirement IDs with Traceability

| Req ID | Plan | Commit reference | Status |
|--------|------|------------------|--------|
| DEMO-01 | 05-01 | `8addacc` | Complete - penta_tile_demo.tscn rewritten as 8-instance spatial-grid showcase |

**Coverage tally:** 58 / 58 v1 requirements satisfied (zero pending).
```

**Self-check pattern** (lines 134-161):
```markdown
## Self-Check: PASSED

**Files modified (this plan):**
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

**Acceptance criteria checks:**
- 10 rows of `| ... | Complete` - `grep -cE` returns 10
- 17-test suite ALL GREEN at HEAD = `a3223b9`
```

**Apply to Phase 8:** Closeout should record artifacts created, canonical recommended package, requirements/backlog rows changed, ROADMAP/STATE updates, and exact next command. Do not include release metadata; replace with "v0.3 scope selection metadata".

---

### `.planning/REQUIREMENTS.md` (requirements, traceability / transform)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-02-PLAN.md`

**YAML plan metadata pattern for modified canonical docs** (lines 1-15):
```yaml
---
phase: 05-demo-refresh-documentation-release
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - README.md
  - CHANGELOG.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/PROJECT.md
  - CLAUDE.md
autonomous: true
requirements: [DOC-01, DOC-02, DOC-03, DOC-04]
---
```

**Grep-anchored requirements edit pattern** (lines 74-87):
```markdown
<task type="auto" tdd="false">
  <name>Task 1: Apply 14 spec corrections ... via grep-anchored edits</name>
  <files>.planning/REQUIREMENTS.md, .planning/ROADMAP.md, .planning/PROJECT.md, CLAUDE.md</files>
  <read_first>
    - .planning/phases/05-demo-refresh-documentation-release/05-RESEARCH.md
    - .planning/REQUIREMENTS.md
  </read_first>
  <action>
    Apply 14 edits using grep-anchored search-and-replace (do NOT trust line numbers).
```

**Old-string/new-string table pattern** (lines 88-122):
```markdown
| File | old_string (verbatim) | new_string |
|------|-----------------------|------------|
| `.planning/REQUIREMENTS.md` | `...old requirement text...` | `...new requirement text...` |
```

**Verification pattern** (lines 141-174):
```markdown
<verify>
  <automated>
    # SC-A - zero stale text remaining:
    ! grep -E "10 (built-in )?layouts" .planning/REQUIREMENTS.md .planning/ROADMAP.md README.md
  </automated>
</verify>
<acceptance_criteria>
  - `grep -E "10 (built-in )?layouts" ...` returns 0 results
</acceptance_criteria>
```

**Apply to Phase 8:** REQUIREMENTS updates should be grep-anchored. Expected edits:

- Refine `TRIAGE-01..06` from draft to final.
- Ensure `MULTITERR-01..08` carries the terrain-metadata-as-input / no-Godot-solver distinction.
- Add or update "do not pursue" notes for rejected research suggestions.
- Add re-trigger conditions for deferred v0.3 candidates.
- Do not add compatibility shims, version fields, schema markers, or speculative extension points.

---

### `.planning/ROADMAP.md` (roadmap, traceability / transform)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md`

**Roadmap flip pattern** (lines 100-104):
```markdown
3. **Task 3 - Flip ROADMAP Phase 5 row.** `.planning/ROADMAP.md` edits:
Phase 5 row in top-of-file Phases bullet `[ ]` -> `[x]` with closure date + workflow run id;
Progress table row `0/TBD / Not started` -> `5/5 / Complete.` with same metadata;
Plans subsection 5 plan rows all flipped from `[ ]` to `[x]`.
```

**Acceptance check pattern** (lines 151-153):
```markdown
- ROADMAP.md Phase 5 top-of-file row begins with `- [x] **Phase 5: Demo Refresh`
- ROADMAP.md Progress table row matches `| 5. Demo Refresh + Documentation + Release | 5/5`
- ROADMAP.md Phase 5 Plans subsection has 5 `[x]` entries
```

**Apply to Phase 8:** ROADMAP should mark Phase 8 as planned/executed only after the phase completes. It should add the next recommended v0.3 phase package with dependencies and success criteria if Phase 8 decides scope. Preserve Phase 6 deferred status unless scope selection intentionally reprioritizes it.

---

### `.planning/STATE.md` (state, event-log / traceability)

**Analog:** `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md`

**State update pattern** (lines 104-106):
```markdown
4. **Task 4 - Update STATE.md.** 6 atomic Edit ops on `.planning/STATE.md`:
frontmatter `status: planning -> shipped`, `stopped_at: Phase 5 context gathered -> v0.2.0 SHIPPED`,
`completed_phases: 6 -> 7`, `total_plans: 32 -> 37`, `last_updated`/`last_activity` retimed;
Current Position section updated; Roadmap Evolution gained a Phase 5 closeout entry.
```

**Files-modified and workflow-side-effect pattern** (lines 134-146):
```markdown
## Self-Check: PASSED

**Files modified (this plan):**
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md`

**Workflow side-effects (not authored by this plan, but verified):**
- `addons/penta_tile/plugin.cfg`
- `CHANGELOG.md`
```

**Apply to Phase 8:** STATE update should add a `Roadmap Evolution` entry summarizing the triage decision, a `Current Position` update pointing to the next exact phase/command, and a `Deferred Items` cleanup if the recommendation changes priorities. Avoid stale wording: Phase 8 follows Phase 7; do not leave "next planning step remains /gsd-plan-phase 7".

## Shared Patterns

### Traceability First

**Source:** `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md` lines 77-92

Use a table tying requirement IDs to plan/artifact evidence:

```markdown
| Req ID | Plan | Commit reference | Status |
|--------|------|------------------|--------|
| DEMO-01 | 05-01 | `8addacc` | Complete - penta_tile_demo.tscn rewritten as 8-instance spatial-grid showcase |
```

For Phase 8, replace commit refs with artifact refs if execution is planning-doc-only and no code commit exists yet:

```markdown
| Req ID | Artifact | Status |
| --- | --- | --- |
| TRIAGE-01 | `08-VERIFIED-CLAIMS.md` | Complete - claims verified against primary sources and local repo |
```

### Source Verification Before Recommendation

**Source:** `.planning/phases/08-research-triage-v0-3-scope-selection/08-RESEARCH-TRIAGE.md` and `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md` lines 6-24

The pattern is: options or claims table first, recommendation second, revisit triggers last. Do not recommend a v0.3 package until accepted/rejected claims are written down.

### Identity Guardrail Framing

**Source:** `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` lines 314-330

Use explicit decision logic:

```markdown
## Decision per <decision-id>

**Outcome:** **<ACCEPT / DEFER / REJECT / RECOMMEND>**

Rationale:
- **User value:** ...
- **Implementation risk:** ...
- **Identity fit:** ...
- **Dependency coupling:** ...
```

For Phase 8, every accepted candidate should explain why it preserves small hot-path identity and native `set_cell()` usage. Every rejected candidate should state the specific forbidden territory it crosses.

### Anti-Pattern Register / Scope Firewall

**Source:** `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` lines 270-312

Copy the table shape. For Phase 8, the firewall is not just code absence; it is disposition of research suggestions:

```markdown
| Suggestion | Disposition | Identity Rationale | Allowed Narrow Form |
| --- | --- | --- | --- |
| Godot terrain solver delegation | reject | Replaces PentaTile's deterministic solver | Read `TileData` metadata as input only |
```

### Closeout Shape

**Source:** `.planning/phases/05-demo-refresh-documentation-release/05-05-SUMMARY.md` lines 163-177

End Phase 8 with an inheritance note for future agents:

```markdown
## Closeout Pattern (for future-Claude inheritance)

This plan's commit shape ...

## Output Spec Confirmation

- Recommended package:
- Alternates:
- Next command:
```

### Project-Specific Constraints to Preserve

**Source:** `AGENTS.md` / `CLAUDE.md`

Apply these to all Phase 8 artifacts:

- PentaTile remains smaller in hot-path shape than TileMapDual: no terrain-rule tries, watcher systems, persistent coordinate caches, or parallel paint APIs.
- Breaking changes are allowed; do not add compatibility shims or deprecation machinery.
- No forward-compat versioning: no `version` fields, schema markers, or speculative extension points.
- "Penta" remains reserved for the 5-archetype tileset format. Do not coin `Penta*` names for unrelated research/tooling concepts.
- Godot terrain metadata may be accepted as input for future multi-terrain work, but Godot's terrain solver must not become PentaTile's renderer.

## No Analog Found

No likely Phase 8 files lack a close planning-document analog. This is a planning/design phase; recent Phase 5 and Phase 7 artifacts cover plan structure, decision artifacts, audit matrices, traceability updates, and closeout summaries.

## Metadata

**Analog search scope:** `.planning/phases/05-demo-refresh-documentation-release`, `.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs`, `.planning/phases/04-fallback-routing-doc-sweep-cross-ai-review`, `.planning/phases/03.5-pixellab-layouts-variation-bank-wiring`
**Files scanned:** 21 planning artifacts in Phase 5 and Phase 7 plus requested Phase 8 context files
**Pattern extraction date:** 2026-04-30
**Tooling note:** `rg` was attempted first but blocked by Windows app-package access denial; PowerShell `Get-ChildItem`, `Select-String`, and `Get-Content` were used as the read-only fallback.
