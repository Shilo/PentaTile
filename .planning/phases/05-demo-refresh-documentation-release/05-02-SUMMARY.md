---
phase: 05-demo-refresh-documentation-release
plan: 02
subsystem: documentation
tags: [docs, changelog, readme, spec-correction, identity-reframe]
requires:
  - .planning/phases/05-demo-refresh-documentation-release/05-CONTEXT.md
  - .planning/phases/05-demo-refresh-documentation-release/05-RESEARCH.md
  - .planning/phases/05-demo-refresh-documentation-release/05-02-PLAN.md
provides:
  - README.md sections — Layouts table, Upgrading from 0.1.x, Authoring a Custom Layout, Identity & Footprint placeholder
  - CHANGELOG.md [Unreleased] block accumulating Phase 3 / 3.5 / 4 / 5 deltas
  - REQUIREMENTS.md / ROADMAP.md / PROJECT.md / CLAUDE.md spec corrections (SC-A through SC-D + 1 additional ROADMAP.md:303 fix)
affects:
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/PROJECT.md
  - CLAUDE.md
  - README.md
  - CHANGELOG.md
tech-stack:
  added: []
  patterns: [grep-anchored-edits, identity-reframe, atomic-doc-commits]
key-files:
  created:
    - .planning/phases/05-demo-refresh-documentation-release/05-02-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md (4 edits — SC-A x 2, SC-B x 1, SC-D x 1)
    - .planning/ROADMAP.md (8 edits — SC-A x 4, SC-B x 1, SC-C x 3)
    - .planning/PROJECT.md (2 edits — SC-B x 1, SC-C x 1)
    - CLAUDE.md (1 edit — SC-C x 1)
    - README.md (5 edits — TOC update + Layouts insertion + Demo rewrite + 3 new sections + Roadmap restructure)
    - CHANGELOG.md (1 edit — appended 6 H3 subsections + 3 migration bullets within preserved [Unreleased] heading)
decisions:
  - "Applied 15 spec corrections instead of 14: added the planner-flagged 5th SC-C edit at ROADMAP.md:303 (Phase 6 SC block) so the deferred phase no longer carries the old 'visibly smaller and simpler than TileMapDual' phrasing — the self-check grep now fully passes"
  - "CHANGELOG [Unreleased] heading preserved verbatim — release workflow (Plan D, D-05-17 step 4) handles the rewrite at ship time"
  - "Identity & Footprint section deliberately scaffolded as a Plan-C-fillable placeholder anchored on 05-LOC-AUDIT.md path — section header + intro reframe is in place; audit summary fills in once Plan C runs"
  - "Authoring a Custom Layout example uses mask_to_atlas(_mask: int) without the strip_index parameter — illustrative documentation per planner direction; readers writing real subclasses will follow the actual virtual signature in penta_tile_layout.gd"
  - "Worktree-vs-main-repo edit slip recovered cleanly: initial Task 1 edits hit the main repo's copies of these files; recovered by reverting the 4 affected files in the main repo (only those 4, leaving unrelated worktree-derived changes alone) and re-applying every edit against the worktree-prefixed paths"
metrics:
  duration_minutes: ~17
  tasks_completed: 3
  files_modified: 6
  files_created: 1
  commits: 3
  lines_added: ~209
  lines_removed: ~26
completed: 2026-04-29
---

# Phase 5 Plan 02: Documentation + Spec Corrections Summary

Documentation-extension plan covering DOC-01..04 plus the SC-A..SC-D spec-correction sweep — README gains 4 new sections, CHANGELOG accumulates 4 phases of deltas in the preserved [Unreleased] block, and the four canonical planning files (REQUIREMENTS / ROADMAP / PROJECT / CLAUDE) are reframed to match v0.2.0 reality (8 actually-shipped layouts, no ATTRIBUTION.md, hot-path-minimalism identity, workflow-driven REL-01).

## Inputs

- `.planning/phases/05-demo-refresh-documentation-release/05-02-PLAN.md` — 3 atomic tasks (Task 1: 14 spec corrections; Task 2: 5 README edits; Task 3: 1 CHANGELOG accumulation block)
- `.planning/phases/05-demo-refresh-documentation-release/05-CONTEXT.md` — D-05-10 (README single source of truth), D-05-11 (LOC reframe), D-05-12 (planner spec-correction authorization), D-05-17 step 4 (workflow rewrites CHANGELOG header at ship time)
- `.planning/phases/05-demo-refresh-documentation-release/05-RESEARCH.md` — § "Spec Correction Surface (SC-A through SC-D)" line-by-line edit table
- `.planning/REQUIREMENTS.md` / `.planning/ROADMAP.md` / `.planning/PROJECT.md` / `CLAUDE.md` — pre-edit canonical specs
- `README.md` — pre-edit anchor for TOC + Penta-System Template terminator + Demo terminator + Roadmap section
- `CHANGELOG.md` — pre-edit anchor for the migration-notes-7 / `---` / `[0.1.0]` boundary

## Outputs

- 3 atomic commits (`42523ee` spec corrections, `0b9430e` README extensions, `8477790` CHANGELOG accumulation)
- README.md gains 137 lines (4 new sections + Demo rewrite + Roadmap restructure)
- CHANGELOG.md gains 58 lines (6 H3 subsections + 3 migration bullets within the existing [Unreleased] block)
- 4 canonical planning files have 15 spec-correction edits applied (14 planned + 1 ROADMAP.md:303 follow-up)
- All grep-anchored self-checks PASS (SC-A 6 of 6 replacements, SC-B 3 of 3 reframes, SC-C 5 of 5 reframes, SC-D REL-01 reframe)

## What Got Built

### Task 1: Spec Corrections (commit `42523ee`)

| SC | Files | Edits | Verification |
|----|-------|-------|--------------|
| SC-A | REQUIREMENTS.md DEMO-01, DOC-01; ROADMAP.md Phase 5 entry / Goal / SC-1 / SC-4 | 6 | `grep -E "10 (built-in )?layouts" .planning/REQUIREMENTS.md .planning/ROADMAP.md README.md` → 0 results; `grep -c "8 actually-shipped"` REQ+ROADMAP cumulative = 11 (>= 6 required) |
| SC-B | REQUIREMENTS.md REL-03 (disclaiming rewrite); ROADMAP.md Phase 5 SC-6 (delete); PROJECT.md Active checklist line | 3 | `grep -E "Downloading the v0\.2\.0.*ATTRIBUTION" .planning/ROADMAP.md` → 0 results; PROJECT.md `^- \[ \] .*ATTRIBUTION\.md.*TileBitTools` → 0 results |
| SC-C | PROJECT.md Identity constraint; ROADMAP.md Phase 5 SC-7 + Identity Guardrails preamble + Phase 6 LOC-checkpoint bullet; CLAUDE.md Identity Guardrails | 5 (4 planned + 1 follow-up at ROADMAP.md:303) | `grep "smaller and simpler than TileMapDual" .planning/PROJECT.md .planning/ROADMAP.md CLAUDE.md` → 0 results; `grep -c "hot-path minimalism"` PROJECT.md + ROADMAP.md + CLAUDE.md = 4 (>= 3 required) |
| SC-D | REQUIREMENTS.md REL-01 ownership flip | 1 | `grep "auto-increment rule (D-05-16)" .planning/REQUIREMENTS.md` → present |

**The 5th SC-C edit at ROADMAP.md:303** was added per the planner's flagged warning — the original 4-edit set left the deferred Phase 6 SC block carrying the old phrasing, so the SC-C self-check grep continued to find a match. Reframed in-place to match the rest of the canonical files (`hot-path minimalism + anti-pattern absence per D-05-11; LOC reported as signal, not verdict`).

**Plan-internal inconsistency noted**: 05-02-PLAN.md says "13 spec corrections" in one place but the math is 6 + 3 + 4 + 1 = 14. Per the plan's instruction, executor records the actual applied count: **15 corrections** (14 planned + 1 added at ROADMAP.md:303 per the planner's pre-flagged warning).

### Task 2: README Sections (commit `0b9430e`)

5 anchored Edit tool operations:

- **Edit A** (Table of Contents): expanded from 12 entries to 16 entries — adds Layouts, Authoring a Custom Layout, Upgrading from 0.1.x, Identity & Footprint
- **Edit B** (Layouts insertion): new `🧱 Layouts` section with 8-row table (one row per actually-shipped layout) listing class, atlas grid, tile count, mask type, and convention source. Links Tilesetter v0.3+ deferral and PixelLab first-cell-pick variation behavior. Inserted after the Penta-System Template section.
- **Edit C** (Demo rewrite): replaces the platformer-player description with the spatial-grid showcase. No CharacterBody2D / capsule collision / arrow-key movement references remain.
- **Edit D** (3 new sections after Demo): `🛠️ Authoring a Custom Layout` (DOC-03 — `@experimental` example, 3-virtual table), `⬆️ Upgrading from 0.1.x` (DOC-02 — 14-row migration table), `🔍 Identity & Footprint` (placeholder for Plan C — anchors `05-LOC-AUDIT.md`).
- **Edit E** (Roadmap restructure): replaces the bulleted future-ideas list with `v0.2.0 (current)` summary + `v0.3+ backlog` itemized list (TBT-01-DEFERRED, VAR-PIXEL-01, VAR-01, TOP-01, MULTITERR-01..05, TERRAIN-01, etc.).

**Plan-C handoff anchor**: the Identity & Footprint section's first paragraph is `> **Filled in by Plan C of Phase 5** (the manual identity audit). This placeholder will be replaced with a 3-axis audit summary (LOC, public surface, hot-path depth) and an anti-pattern register check against TileMapDual v5.0.2.` Plan C will replace this blockquote with the audit's executive summary and link to the full `05-LOC-AUDIT.md` artifact.

### Task 3: CHANGELOG Accumulation (commit `8477790`)

Single Edit tool operation appending 6 new H3 subsections + 3 migration bullets within the existing `[Unreleased] — v0.2 in progress` block, BEFORE the `---` separator and `[0.1.0]` heading.

H3 subsections added:

1. `### Added — Phase 3: Public-Convention Layout (Blob 47 Godot)` — Blob47Godot layout, 8-Moore propagation patch, TileBitTools acknowledgment (no ATTRIBUTION.md), 3 new tests
2. `### Added — Phase 3.5: PixelLab Layouts` — Top-Down + Side-Scroller twin classes, role-to-mask bijection, first-cell row-major dispatch, 2 new tests, matrix 108 → 144 combos
3. `### Added — Phase 4: Fallback Routing + Doc-Comment Sweep + Cross-AI Review` — PREVIEW-03/04 verification, doc-sweep across 12 scripts, Gemini clean / Codex deferred, fallback_routing_test
4. `### BREAKING — Phase 5: Demo Refresh` — 10 retired demo files (demo_player.gd, penta_tile_ground.png/tres/import, _regen_demo_ground.py, 4 single-variant .tres orphans), 8-instance spatial-grid replacement, demo_runtime_painter.gd hover-target rewrite
5. `### Added — Phase 5: Documentation extensions` — README Layouts / Upgrading / Authoring / Identity & Footprint sections (DOC-01..04)
6. `### Added — Phase 5: Release automation` — .github/workflows/release.yml, run_tests.sh Linux mirror, single-button-ship workflow per D-05-15..18

3 migration bullets appended (8, 9, 10) covering: demo file retirement (Migration 8), demo_runtime_painter map_path removal (Migration 9), godot --import bootstrap after extracting a release zip (Migration 10).

**Heading preservation**: `## [Unreleased] — v0.2 in progress` was NOT touched. The release workflow (Plan D, D-05-17 step 4) rewrites it via `sed -i -E "s/^## \[Unreleased\][^\n]*$/## [${NEW_VERSION}] — ${RELEASE_DATE}/"` at ship time. CHANGELOG retains exactly 1 `^## \[Unreleased\]` and 1 `^## \[0\.1\.0\]` heading.

## Process Notes

### Worktree slip + recovery

Initial Task 1 edits accidentally targeted the main repo's copies of the canonical planning files (`C:\Programming_Files\Shilocity\PentaTile\.planning\REQUIREMENTS.md` etc.) instead of the worktree's copies (`...\.claude\worktrees\agent-ae89158e22c1fb09f\.planning\REQUIREMENTS.md`). Detected when `git status` in the worktree returned `nothing to commit` while edits had been applied — comparison of file sizes between main repo and worktree copies confirmed the slip. Recovered cleanly by `git -C "<main-repo>" checkout -- .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md CLAUDE.md` (only those 4 files; leaving unrelated main-repo state alone) and re-applying every edit using worktree-prefixed absolute paths. Final canonical state matches between worktree and main repo at the per-file content level — only the worktree carries the new commits.

### Coined-Term Discipline

No new "Penta" prefix coined. The new sections use established terms: `Penta tileset`, `Penta layout family`, `PentaTileLayoutPenta`, `PentaTileLayout` (abstract base), `PentaTileMapLayer`, `PentaTileAtlasSlot`, `PentaTileSynthesis`. The reframed identity language in PROJECT.md / ROADMAP.md / CLAUDE.md uses generic descriptors (`hot-path minimalism`, `anti-pattern absence`) — neutral terminology per CLAUDE.md § Coined-Term Discipline.

### Breaking Changes Policy

CHANGELOG Phase 5 BREAKING block enumerates 10 retired demo files explicitly (no compat shims; clean delete). Aligns with CLAUDE.md HARD RULE — pre-1.0 breakage is documented in CHANGELOG, no deprecation aliases.

## Deviations from Plan

None — plan executed as written. The one judgment call (5th SC-C edit at ROADMAP.md:303) was pre-flagged in the executor prompt's `<critical_constraints>` section with explicit authorization under D-05-12; execution chose the "5th edit" option (vs the alternative "narrow the self-check grep") so the canonical specs read uniformly without preserving the deferred-Phase-6 carve-out.

## Plan-C Handoff

The `🔍 Identity & Footprint` section in README.md is a deliberate placeholder. Plan C of Phase 5 (the manual identity audit) reads this section's anchor (the `05-LOC-AUDIT.md` link) and replaces the blockquote `> **Filled in by Plan C of Phase 5** ...` with the audit's executive summary. The audit-deliverable artifact lives at `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` (Plan C produces it). Until Plan C runs, the placeholder text + the static identity-statement paragraph + the hot-path pipeline diagram + the 5-anti-patterns-not-included list provide enough orientation that a reader who hits the section knows the section is incomplete and where the full audit lives.

## Self-Check: PASSED

- 3 commits exist in worktree branch:
  - `42523ee docs(05-02): apply 15 spec corrections (SC-A through SC-D)` — FOUND
  - `0b9430e docs(05-02): add 4 README sections + rewrite Demo + restructure Roadmap` — FOUND
  - `8477790 docs(05-02): accumulate CHANGELOG with Phase 3 / 3.5 / 4 / 5 deltas` — FOUND
- All 6 modified files exist in worktree: `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md` — FOUND
- All 4 README new sections present: 🧱 Layouts, 🛠️ Authoring a Custom Layout, ⬆️ Upgrading from 0.1.x, 🔍 Identity & Footprint — FOUND
- All 8 layout class names present in README Layouts table — FOUND
- 6 CHANGELOG H3 subsections present — FOUND
- All 8 demo retired filenames present in CHANGELOG Phase 5 BREAKING block — FOUND
- CHANGELOG `[Unreleased]` heading preserved verbatim, count = 1 — FOUND
- CHANGELOG `[0.1.0]` heading preserved, count = 1 — FOUND
- All grep self-checks for SC-A / SC-B / SC-C / SC-D pass in worktree — FOUND
