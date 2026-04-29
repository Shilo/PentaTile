# Phase 4: Fallback Routing + Doc Sweep + Cross-AI Review - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 ships three braided deliverables before v0.2.0 closes:

1. **Fallback Routing close-out** — verify and formally close `PREVIEW-03` / `PREVIEW-04`. The wiring already shipped in Phase 2 ([penta_tile_map_layer.gd:54-70](../../../addons/penta_tile/penta_tile_map_layer.gd#L54-L70)) — the `layout` setter auto-fills `tile_set` from `layout.get_fallback_tile_set()` and tracks `_tile_set_is_fallback` so user-supplied tilesets are never overwritten. Phase 4 is the verification gate, not greenfield wiring.
2. **Full GDScript doc-comment sweep** — every addon script gets class-level + public-method + @export-property `##` doc comments per [Godot's official doc-comment format](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html). Use BBCode tags (`[param]`, `[code]`, `[Class]`) and structured tags (`@tutorial`, `@experimental`, `@deprecated`).
3. **Two-pass cross-AI review with fixes** — Gemini headless (`gemini -p ...`) → apply valid fixes → Codex (`/gsd-review codex`) → apply valid fixes. Both review the entire codebase + implementation + design + goals + docs and compare against TileMapDual / identity guardrails.

The phase closes when all 4 artifacts (FALLBACK-UAT.md + DOC-SWEEP.md + GEMINI-REVIEW-FIX.md + CODEX-REVIEW-FIX.md) commit and ROADMAP Phase 4 row flips to `[x]`.

New capabilities (variation, top tiles, multi-terrain, additional layouts, demo refresh, README sections, release packaging) are explicitly **out of scope** — those belong in Phase 5 or v0.3+.

</domain>

<decisions>
## Implementation Decisions

### Doc-Comment Sweep

- **D-04-01:** Scope is the **12 addon scripts only** under `addons/penta_tile/` (excluding `tests/` and `demo/`). Tests + demo treated as internal-use, no doc-comment requirement. Files in scope:
  - `addons/penta_tile/penta_tile_map_layer.gd`
  - `addons/penta_tile/penta_tile_synthesis.gd`
  - `addons/penta_tile/penta_tile_atlas_slot.gd`
  - `addons/penta_tile/layouts/penta_tile_layout.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_penta.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd`
  - `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd`

- **D-04-02:** Coverage depth is **class-level + every public method (no leading underscore) + every `@export` property**. Private `_foo` methods get a one-liner only when the WHY is non-obvious (per CLAUDE.md commenting policy). Class-level block describes purpose, slot ordering / mask convention where relevant, and any pitfall references.

- **D-04-03:** Use **full Godot doc-comment tag set**:
  - Structural tags: `@tutorial(label)`, `@experimental`, `@deprecated` where applicable.
  - BBCode inline tags: `[param x]`, `[code]`, `[Class TileMapLayer]`, `[method foo]`, `[member bar]`.
  - `@experimental` flag on `PentaTileLayout` subclassing surface (custom layouts are flagged experimental in PROJECT.md / DOC-03 — surface that in the inspector help).
  - `@tutorial` tags point at relevant `.planning/research/` docs (PITFALLS, ARCHITECTURE, layout taxonomy) and ROADMAP phase entries where useful.

- **D-04-04:** **No doc-coverage lint test** added. Cross-AI review pass at the end of Phase 4 is the verification mechanism. A bespoke lint script is YAGNI for "works in my game" quality bar.

### Fallback Routing Close-out

- **D-04-05:** Phase 4 visual UAT covers **all 8 actually-shipped layouts**: 5 Phase 2 (Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3) + 1 Phase 3 (Blob47Godot) + 2 Phase 3.5 (PixelLabTopDown, PixelLabSideScroller). Tilesetter pair (TBT-01-DEFERRED / TBT-02-DEFERRED) stays out of scope per D-86 (b).

- **D-04-06:** Verification is **belt + suspenders**:
  - **Programmatic:** new `tests/fallback_routing_test.gd` — for each of 8 layouts, instantiate `PentaTileMapLayer` with `tile_set = null`, paint a fixed pattern, blit rendered cells into a virtual canvas, assert non-empty bbox + per-cell solidity. Follows CLAUDE.md Test Methodology #1 (compose canvas + structural invariants).
  - **Manual:** user runs the demo scene with each layout swapped in (no manual `tile_set` assigned), eyeball each one, sign off in `04-FALLBACK-UAT.md`.
  - Plus regression coverage: confirm assigning `tile_set` directly overrides the fallback (PREVIEW-04 contract); confirm clearing `tile_set` re-routes to fallback.

- **D-04-07:** **PREVIEW-03 / PREVIEW-04 close in Phase 4** (not retroactively in Phase 2). Traceability stays mapped to Phase 4; Status flips from `Pending` → `Complete` only when Phase 4 UAT passes for all 8 layouts. Honest attribution: Phase 2 shipped the wiring but no requirement-level cross-layout verification.

- **D-04-08:** Phase 5 LOC + identity audit (formal TileMapDual surface comparison) **stays deferred to Phase 5**. The cross-AI review pass in Phase 4 will surface identity-guardrail violations qualitatively (terrain peering, watcher patterns, parallel APIs) per CLAUDE.md guardrails — that's enough informal signal here.

### Cross-AI Review (Gemini + Codex)

- **D-04-09:** **Two reviewers, both headless: Gemini + Codex.** Original ask was Cursor + Codex; user has no Cursor subscription so Cursor is replaced. Antigravity is also IDE-only (same situation as Cursor). Gemini CLI (`gemini -p ...`) supports headless invocation; Codex is already wired via the existing `/gsd-review codex` skill. Both passes are end-to-end automatable.

- **D-04-10:** **Strict order: Gemini → fix valid → Codex → fix valid.** The second pass sees the post-fix codebase, providing genuine "second-look" coverage. Matches the original "Cursor first, then Codex" framing.

- **D-04-11:** Each reviewer's prompt covers the full review surface:
  - Codebase: `addons/penta_tile/` (12 scripts + tests as supporting evidence).
  - Project context: `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `CLAUDE.md` (especially Identity Guardrails + Critical Pitfalls + Breaking Changes Policy + Coined-Term Discipline).
  - Design comparison: against TileMapDual public docs/repo for surface area, hot-path simplicity, watcher avoidance, terrain-peering avoidance, doc quality.
  - Findings categorized by Severity (Critical | High | Medium | Low | Info) × Theme (Bug | Identity | Goal-misalignment | Doc | Design).

- **D-04-12:** Output artifacts:
  - `04-GEMINI-REVIEW.md` — raw findings from Gemini.
  - `04-GEMINI-REVIEW-FIX.md` — disposition + fix-commit log per finding.
  - `04-CODEX-REVIEW.md` — raw findings from Codex.
  - `04-CODEX-REVIEW-FIX.md` — disposition + fix-commit log per finding.

### Fix-Application Policy

- **D-04-13:** **Severity-tiered auto-fix.** Critical and High findings auto-fix without asking. Medium findings: I propose the fix and you approve before commit. Low/Info: surfaced in summary, you choose to apply or defer to v0.3+. Mirrors the Phase 2 review-fix pattern (eec027d → 7 WR atomic commits) where Warnings auto-applied but Info items were dispositioned individually.

- **D-04-14:** **Standard disqualification list** — a finding is "not valid" (recorded but NOT applied) when it:
  - Suggests backwards-compat shims, deprecation aliases, or version-detection branches (CLAUDE.md HARD RULE — Breaking Changes Policy).
  - Suggests forward-compat versioning fields, schema markers, or speculative extension points (no-forward-compat policy).
  - Proposes features deferred to v2 or v0.3+ in REQUIREMENTS.md (TBT-01/02-DEFERRED, VAR-01, TOP-01, MULTITERR-*, TERRAIN-01, etc.).
  - Asks for changes Phase 5 owns (LOC trim, README rewrite, CHANGELOG, demo refresh, plugin.cfg bump, release zip, `ATTRIBUTION.md` — banned per D-72/D-73).
  - Violates Coined-Term Discipline (proposing "Penta" prefixes for non-5-archetype subsystems).
  - Contradicts a locked decision (D-* in PROJECT.md / STATE.md / prior CONTEXT.md files).
  - Disposition logged in the per-reviewer REVIEW-FIX.md disposition column.

- **D-04-15:** **Atomic commits per finding.** One commit per fix referencing the finding ID, e.g. `fix(04): GEMINI-W-03 — missing @return tag in PentaTileLayout.compute_mask docstring`. Matches Phase 2's WR-fix pattern; clean revert per finding; clean git log.

- **D-04-16:** **Phase-close gate: all 4 must pass.** ROADMAP Phase 4 row flips to `[x]` only when:
  1. Doc-comment sweep covers all 12 addon scripts (per D-04-01 / D-04-02 / D-04-03).
  2. Fallback UAT pass on 8 layouts visually + composed-canvas test green.
  3. Gemini review valid findings dispositioned + fixes committed.
  4. Codex review valid findings dispositioned + fixes committed.
  And all four artifacts (`04-FALLBACK-UAT.md` + `04-DOC-SWEEP.md` + `04-GEMINI-REVIEW-FIX.md` + `04-CODEX-REVIEW-FIX.md`) commit.

### Suggested Plan Sequencing (informational — planner finalizes)

Doc sweep → UAT → Gemini review → fix → Codex review → fix. Doc sweep first so reviewers see the documented codebase (and find doc-quality issues against the new baseline). UAT before reviews because reviewers may want to confirm fallback works before commenting on fallback-related code. Plan-phase has full latitude to reshape this.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Goal-Defining Artifacts

- `.planning/PROJECT.md` — vision, identity guardrail ("visibly smaller and simpler than TileMapDual"), constraints, key decisions.
- `.planning/REQUIREMENTS.md` — PREVIEW-03 / PREVIEW-04 (the 2 v1 requirements Phase 4 closes); v2/v0.3+ deferred list (TBT-01/02-DEFERRED, VAR-01, etc.) for the disqualification policy.
- `.planning/ROADMAP.md` — Phase 4 entry (success criteria 1-4 from Fallback Routing + the expanded scope captured here).
- `CLAUDE.md` — Identity Guardrails, Breaking Changes Policy (HARD RULE — both directions), Coined-Term Discipline, Critical Pitfalls (#1-10), Test Methodology lessons.

### Doc-Comment Source of Truth

- [Godot 4.x GDScript Documentation Comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) — the official format spec. Defines `##` syntax, structural tags (`@tutorial`, `@experimental`, `@deprecated`), and BBCode inline tags (`[param]`, `[code]`, `[Class]`, `[method]`, `[member]`).

### Existing Doc-Comment Patterns (already in codebase)

- `addons/penta_tile/penta_tile_synthesis.gd:1-19` — exemplary class-level `##` block with slot ordering documented + invariant statements + research path references.
- `addons/penta_tile/penta_tile_atlas_slot.gd:1-9` — exemplary field-by-field doc.
- `addons/penta_tile/layouts/penta_tile_layout.gd:1-12` — exemplary class-level block with `See:` paragraph linking to research docs.

### Phase 4 Implementation Anchors

- `addons/penta_tile/penta_tile_map_layer.gd:35-72` — the `layout` setter that already implements PREVIEW-03/04 wiring.
- `addons/penta_tile/penta_tile_map_layer.gd:75-96` — `_tile_set_is_fallback` flag + `_set` user-override hook (PREVIEW-04 contract).
- `addons/penta_tile/penta_tile_map_layer.gd:134-154` — `_init` mirroring the auto-fill chain for the default-instantiated layout.

### Test Methodology

- `CLAUDE.md` § Test Methodology (Phase 2 UAT lessons) — compose canvas + structural invariants; pattern × layout matrix; use the user's actual fixture; save PNG and inspect when in doubt; verify the test catches the regression; trace the full pipeline before patching.
- `tests/comprehensive_bitmask_test.gd` — canonical pattern × layout matrix template.
- `tests/penta_ground_hollow_test.gd` — canonical user-fixture composed-canvas test template.

### Cross-AI Review Pattern (precedent)

- `.planning/phases/03.5-pixellab-layouts-variation-seed-wiring/03.5-REVIEWS.md` — Codex retrospective review on Phase 3.5 plans. Establishes the artifact format Phase 4 follows.
- `.planning/phases/02-native-layouts/02-REVIEW.md` — Phase 2's 3-pass internal code review (eec027d, 49852b9, aa07ac1). Establishes the severity-classified finding format + disposition log pattern.

### Identity Comparison Target

- TileMapDual GitHub repo + README — public source for the cross-AI reviewer's comparison checklist (surface area, hot-path simplicity, watcher avoidance, terrain-peering avoidance, doc quality, leak/crash history).
- `.planning/research/layouts/MASK_UNIFICATION.md` and `.planning/research/PITFALLS.md` — internal anti-pattern register reviewers should reference.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`PentaTileLayout.get_fallback_tile_set()` virtual** ([layouts/penta_tile_layout.gd](../../../addons/penta_tile/layouts/penta_tile_layout.gd)) — base class codegen builds a TileSet from `bitmask_template` PNG. Already used by every shipped subclass. Phase 4 UAT exercises this surface across all 8 layouts.
- **`PentaTileMapLayer._tile_set_is_fallback` storage flag** + `_set` override hook — already implements PREVIEW-04 user-override contract. No new wiring needed.
- **Composed-canvas test framework** — `comprehensive_bitmask_test.gd`, `penta_ground_hollow_test.gd`, `bitmask_bounds_test.gd`. Phase 4's `fallback_routing_test.gd` reuses the blit + bbox + per-cell solidity helpers established in Phase 2 UAT.
- **`run_tests.ps1`** — registry for the 17 existing tests. Phase 4 adds `fallback_routing_test.gd` (target: 18 tests by Phase 4 close).
- **Existing class-level `##` blocks** — `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, `penta_tile_layout.gd` already follow Godot's doc-comment convention. Use as style reference; sweep extends to remaining 9 scripts at the same depth + adds public-method/property coverage to all 12.

### Established Patterns

- **Comment hygiene** (CLAUDE.md): comments explain WHY, not WHAT. Phase 4 doc sweep extends this — `##` blocks describe contract + invariants + pitfall references, not "this method does X" prose.
- **Atomic-commit-per-fix** for review-driven changes — Phase 2's 7 WR fixes (`ea0ba23` … `79af1e3`) are the canonical template.
- **Headless verification scripts** — `_capture_baseline.gd`, `--script` mode for CI-style runs. Gemini/Codex review prompts can reference these as evidence of how the codebase validates itself.

### Integration Points

- **Doc-comment sweep touches every public surface.** The `layout` property's setter (`penta_tile_map_layer.gd:35-72`) already has rich `#` (single-hash) prose comments — those convert to `##` doc comments for the public-facing portion (the property + its contract) while internal explanation stays as `#`.
- **`@experimental` annotation** on `PentaTileLayout` (the abstract base) signals to subclassers that the API is experimental per DOC-03 — drops directly into the existing class-level block in `layouts/penta_tile_layout.gd:1-12`.
- **Cross-AI reviewers see the documented codebase first.** Sequencing the doc sweep before the reviews means review findings about doc quality are against the *new* baseline, not the old one.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly cites [Godot's official doc-comment URL](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) as the source of truth — implementer reads it (via Context7 MCP if useful) before writing the sweep, not memory.
- Two-AI-reviewer pattern matches the user's original "Cursor + Codex" framing; substitution is Gemini-for-Cursor purely on subscription grounds (Antigravity has the same IDE-only constraint as Cursor).
- The disqualification list is the user's `fix anything valid` filter — "valid" means "consistent with locked decisions and milestone scope," not "technically correct in isolation."

</specifics>

<deferred>
## Deferred Ideas

- **Doc-coverage lint test** (proposed during area 1) — deferred to v0.3+ if doc rot becomes a real problem post-v0.2. Not added now per D-04-04.
- **Three-reviewer pass** (Gemini + Antigravity + Codex) — adds the manual-IDE Antigravity step. Skipped per D-04-09 in favor of two headless reviewers; could resurface in a future phase if the two-reviewer pattern misses a class of issues.
- **Phase 5 LOC / identity audit pre-run** — deferred to Phase 5 per D-04-08. The cross-AI review pass surfaces identity-guardrail violations qualitatively, which is enough informal signal at the Phase 4 stage.
- **Doc-sweep on tests + demo** — explicitly out of scope per D-04-01. Tests are internal and rot fast; demo is a runnable example, not a public surface.
- **Codex cross-AI review pass (D-04-10 second leg)** — DEFERRED at Phase 4 closeout (2026-04-29) due to a hard external Codex CLI quota wall (`ERROR: You've hit your usage limit ... try again at 11:29 AM` on both `codex exec --skip-git-repo-check -` and `codex review -`). RESEARCH § 8 Pitfall #14 anticipates this case: "If still failing: surface the failure to the user." User (xida.de@googlemail.com) was prompted via `AskUserQuestion` and elected to skip the Codex pass and continue. Phase 4 ships with single-pass Gemini cross-AI coverage (`status: clean`, 0 findings) rather than the two-pass coverage D-04-10 originally specified. Documented in `04-CODEX-REVIEW.md`, `04-CODEX-REVIEW-FIX.md`, `04-04-SUMMARY.md`, and `04-05-SUMMARY.md`. A follow-up Codex pass against the post-Phase-4 codebase is OPTIONAL — the prompt is preserved at `04-CODEX-PROMPT.md` for re-use when quota resets or the user upgrades. Marginal value of the deferred pass is low given the small Phase 4 surface (annotation-only doc sweep + verification-only fallback test scaffold; no new runtime behavior was added in this phase) and Gemini's clean pass on the same surface.

</deferred>

---

*Phase: 04-fallback-routing*
*Context gathered: 2026-04-29*
