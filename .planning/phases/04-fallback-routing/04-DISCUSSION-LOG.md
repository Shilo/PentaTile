# Phase 4: Fallback Routing + Doc Sweep + Cross-AI Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 04-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-29
**Phase:** 04-fallback-routing
**Areas discussed:** Doc-comment scope & depth, PREVIEW-03/04 closure & UAT scope, Cross-AI review mechanism, Fix-application policy

**User trigger:** "/gsd-discuss-phase 4 can you just update it first. so that we have full GDScript documentation on every script. and supprted by [https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html] and also at the end of doing everythign we need to run a subagent on cursor to review the entire code base, implementation, design, goal, documentations and compare it to TileMapDual, and then fix anything valid, and then after, run /gsd-review codex to have codex have the same exact review process and then fix anything valid again"

User explicitly expanded Phase 4's scope from the original ROADMAP definition (just "Fallback Routing" — wire `tile_set==null → layout.get_fallback_tile_set()` + visual regression) to a three-deliverable phase: routing close-out + full GDScript doc-comment sweep + two-pass cross-AI review with fixes.

---

## Doc-Comment Scope & Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Addon scripts only (12 .gd) | 12 files in `addons/penta_tile/` outside tests/demo. Public surface — what users see in their IDE. Tests + demo treated as internal-use. Smallest scope, biggest signal/effort ratio. (Recommended) | ✓ |
| Addon + demo (14 .gd) | Add `demo_player.gd` + `demo_runtime_painter.gd`. Tests still excluded. | |
| Everything (38 .gd) | All 12 addon + 2 demo + 24 tests. Tests get doc comments explaining what they catch. Highest cost; tests rot fast. | |

**User's choice:** Addon scripts only (12 .gd) (Recommended)
**Notes:** Locked as D-04-01.

| Option | Description | Selected |
|--------|-------------|----------|
| Class + public methods + @export properties | Class-level `##`, `##` on every public method + every @export property. Private `_foo` methods get a one-liner only when non-obvious. (Recommended) | ✓ |
| Class + ALL methods + ALL properties | Every method (public AND private) + every member. Most thorough; biggest LOC growth. | |
| Class-level only | Single `##` block at top of each script. Fast and shippable; little IDE-surfaced help on individual methods. | |

**User's choice:** Class + public methods + @export properties (Recommended)
**Notes:** Locked as D-04-02. Aligns with CLAUDE.md "default to writing no comments — explain WHY only when non-obvious" for private helpers.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — full tag usage | `@tutorial`, `@experimental`, `@deprecated` plus BBCode `[param]`, `[code]`, `[Class]`. `@experimental` on PentaTileLayout subclassing surface per DOC-03. (Recommended) | ✓ |
| Plain prose only | Just `##` prose, no BBCode tags. Faster but loses inspector hyperlinks + Open Tutorial button. | |

**User's choice:** Yes — full tag usage (Recommended)
**Notes:** Locked as D-04-03. Implementer pulls Godot's spec via Context7 MCP at write time per project convention.

| Option | Description | Selected |
|--------|-------------|----------|
| No — visual review only | Cross-AI review pass at end of Phase 4 catches missing/poor doc comments. YAGNI. (Recommended) | ✓ |
| Yes — add `doc_coverage_test.gd` | Programmatic check: scan each in-scope `.gd` file, assert every public method/property has a preceding `##` block. Catches drift in future PRs. | |

**User's choice:** No — visual review only (Recommended)
**Notes:** Locked as D-04-04. Lint test deferred to v0.3+ if doc rot becomes a real problem.

---

## PREVIEW-03/04 Closure & UAT Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All 8 actually-shipped | 5 Phase 2 + 1 Phase 3 (Blob47Godot) + 2 Phase 3.5 (PixelLab top-down + side-scroller). Tilesetter pair correctly excluded per D-86 (b). (Recommended) | ✓ |
| 8 + try Tilesetter | Check the deferred Tilesetter pair too. Adds noise; not wired in v0.2 by design. | |
| Smoke test on 1–2 layouts | Just confirm Penta + one block layout. Risks regressions in less-exercised layouts. | |

**User's choice:** All 8 actually-shipped (Recommended)
**Notes:** Locked as D-04-05.

| Option | Description | Selected |
|--------|-------------|----------|
| Programmatic composed-canvas + eyeball | New `fallback_routing_test.gd` with composed-canvas + bbox + per-cell solidity assertions per CLAUDE.md Test Methodology #1. Plus user runs demo and visually confirms. Belt + suspenders. (Recommended) | ✓ |
| Programmatic only | Test assertions only; no manual demo loop. Fastest; risks the same gap that bit Phase 2 (programmatic dispatch passed while visual seams broke). | |
| Manual eyeball only | Just paint each layout in demo, eyeball it. Quick to ship; nothing catches regressions in future PRs. | |

**User's choice:** Programmatic composed-canvas + eyeball (Recommended)
**Notes:** Locked as D-04-06. Phase 2 UAT lessons (CLAUDE.md Test Methodology) explicitly call for both.

| Option | Description | Selected |
|--------|-------------|----------|
| Close in Phase 4 after UAT | Keep PREVIEW-03/04 mapped to Phase 4 in REQUIREMENTS.md; flip Complete only when UAT passes for all 8 layouts. (Recommended) | ✓ |
| Retroactively mark Phase 2 | Edit Traceability: PREVIEW-03/04 → Phase 2. Phase 4 then bundles only doc-sweep + cross-AI review. | |

**User's choice:** Close in Phase 4 after UAT (Recommended)
**Notes:** Locked as D-04-07. Honest attribution: Phase 2 shipped wiring but no requirement-level cross-layout verification.

| Option | Description | Selected |
|--------|-------------|----------|
| Defer to Phase 5 | Phase 5's formal gate handles the LOC audit + TileMapDual writeup. Phase 4 cross-AI review surfaces identity-guardrail violations qualitatively. (Recommended) | ✓ |
| Pre-run informally in Phase 4 | Take a measurement now (LOC, hot-path complexity, surface comparison). Cost: another doc artifact; risks anchoring Phase 5's gate on a stale snapshot. | |

**User's choice:** Defer to Phase 5 (Recommended)
**Notes:** Locked as D-04-08.

---

## Cross-AI Review Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| I write prompt; you run Cursor Agent | I produce the prompt, user runs Cursor Agent in IDE, saves findings, I apply fixes. | |
| Skip Cursor; use general-purpose Task subagent | General-purpose Claude subagent imitating Cursor's review style. Loses the cross-AI signal. | |
| You have a cursor-agent CLI I missed | If the user has a `cursor-agent` binary set up, name the path. | |

**User's choice:** "I dont have a cursor subscription, so anything that needs cursor should be Codex or Antigravity instead"
**Notes:** Cursor binary in PATH is IDE-only (same finding as Phase 3.5 review). Antigravity is also IDE-only. Substituted Cursor → Gemini headless after detecting `gemini` CLI with `-p/--prompt` non-interactive flag. Codex unchanged. Locked as D-04-09.

| Option | Description | Selected |
|--------|-------------|----------|
| Gemini + Codex (both headless, fully automated) | First pass: `gemini -p` writes 04-GEMINI-REVIEW.md. I apply fixes, commit. Second pass: `/gsd-review codex` writes 04-CODEX-REVIEW.md. I apply fixes, commit. End-to-end automatable. (Recommended) | ✓ |
| Antigravity (manual IDE) + Codex (headless) | I write Antigravity prompt; user drives Antigravity Agent; I auto-fix. Then Codex headless. | |
| Codex twice (two distinct prompts) | Run Codex with broad-architecture prompt then narrow-implementation prompt. Loses cross-AI signal. | |
| Gemini + Codex + Antigravity (3 reviewers) | Three rounds. Diminishing returns; most token cost + manual driving. | |

**User's choice:** Gemini + Codex (both headless, fully automated) (Recommended)
**Notes:** Locked as D-04-09 (mechanism) + D-04-10 (order: strict Gemini → fix → Codex → fix).

| Option | Description | Selected |
|--------|-------------|----------|
| Full codebase + design vs TileMapDual + identity guardrails | Reviewer reads addon code + project planning docs, compares to TileMapDual public docs/repo. Findings categorized by Severity × Theme. (Recommended) | ✓ |
| Code-quality only — skip TileMapDual comparison | Bugs, dead code, doc quality, GDScript idioms. No TileMapDual diff. | |
| TileMapDual diff only — skip code review | Pure architecture/surface comparison. | |

**User's choice:** Full codebase + design vs TileMapDual + identity guardrails (Recommended)
**Notes:** Locked as D-04-11. Matches user's original ask verbatim ("review the entire code base, implementation, design, goal, documentations and compare it to TileMapDual").

| Option | Description | Selected |
|--------|-------------|----------|
| REVIEW.md + REVIEW-FIX.md per reviewer | Two artifacts per reviewer: raw findings + disposition/fix log. Matches Phase 2 review-pass pattern. (Recommended) | ✓ |
| Single combined REVIEW.md | One artifact with both reviewers interleaved. Easier to consume; harder to track which reviewer found what. | |

**User's choice:** REVIEW.md + REVIEW-FIX.md per reviewer (Recommended)
**Notes:** Locked as D-04-12.

| Option | Description | Selected |
|--------|-------------|----------|
| Strict: Gemini → fix → Codex → fix | Two distinct review passes; second sees post-fix codebase. (Recommended) | ✓ |
| Parallel: both review main, merge findings | Faster; loses second-look-after-fixes signal. | |

**User's choice:** Strict: Gemini → fix → Codex → fix (Recommended)
**Notes:** Locked as D-04-10. Matches user's wording exactly.

---

## Fix-Application Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Severity-tiered | Critical/High auto-fix. Medium proposed → user approves. Low/Info surfaced in summary, deferred or applied at user choice. (Recommended) | ✓ |
| All valid findings auto-fix | Every finding I judge valid gets fixed atomically. | |
| Gate every single fix | I propose every fix; you approve each. Highest control; slowest. | |

**User's choice:** Severity-tiered (Recommended)
**Notes:** Locked as D-04-13. Mirrors Phase 2 review-fix pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Standard disqualification list | Reject findings that suggest backwards-compat shims, forward-compat versioning, v2/v0.3+ scope, Phase 5 work, Coined-Term violations, or contradict locked decisions. (Recommended) | ✓ |
| Trust reviewers — no disqualification list | Apply every finding I judge correct. Risks contradicting locked decisions. | |

**User's choice:** Standard disqualification list (Recommended)
**Notes:** Locked as D-04-14. Disposition logged per finding in REVIEW-FIX.md.

| Option | Description | Selected |
|--------|-------------|----------|
| Atomic per finding | One commit per fix, finding ID in commit message. Matches Phase 2 WR-fix pattern. (Recommended) | ✓ |
| Batched by reviewer + category | One commit per (reviewer, category) tuple. Fewer commits; harder to revert one bad fix. | |
| One commit per reviewer | Single commit per reviewer. Easiest; loses traceability. | |

**User's choice:** Atomic per finding (Recommended)
**Notes:** Locked as D-04-15.

| Option | Description | Selected |
|--------|-------------|----------|
| All 4 must pass | Doc sweep + UAT + Gemini fixes + Codex fixes. ROADMAP Phase 4 row flips to `[x]` only when all 4 artifacts commit. (Recommended) | ✓ |
| Reviews are advisory — only UAT + doc sweep block close | Reviewer findings logged but not gated. Risks reopening Phase 4 later. | |

**User's choice:** All 4 must pass (Recommended)
**Notes:** Locked as D-04-16.

---

## Claude's Discretion

User accepted all recommended defaults. No areas deferred to Claude judgment beyond the implementation-detail latitude reserved for plan-phase (e.g., exact prompt text for Gemini/Codex reviews, plan-task ordering within the suggested doc-sweep → UAT → Gemini → Codex sequence, specific `@tutorial` paths per script).

## Deferred Ideas

- **Doc-coverage lint test** — deferred to v0.3+ if doc rot becomes a real problem post-v0.2. Not added now per D-04-04.
- **Three-reviewer pass** (Gemini + Antigravity + Codex) — adds manual-IDE Antigravity step. Skipped per D-04-09; could resurface in a future phase if the two-reviewer pattern misses a class of issues.
- **Phase 5 LOC / identity audit pre-run** — deferred to Phase 5 per D-04-08. Cross-AI review surfaces guardrail violations qualitatively, which is enough informal signal at the Phase 4 stage.
- **Doc-sweep on tests + demo** — explicitly out of scope per D-04-01. Tests rot fast; demo is a runnable example, not a public surface.
