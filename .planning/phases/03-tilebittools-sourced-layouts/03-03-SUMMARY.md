---
phase: 03-tilebittools-sourced-layouts
plan: 03
subsystem: docs
tags: [phase-3, doc-rewrite, no-attribution-md, footnote, d-72, d-73, public-convention-layouts]

# Dependency graph
requires:
  - phase: 03-tilebittools-sourced-layouts
    provides: D-72 / D-73 policy decisions (CONTEXT.md)
provides:
  - ROADMAP.md Phase 3 retitled "Public-Convention Layouts (Blob47 + Tilesetter)"
  - REQUIREMENTS.md TBT-04 + DOC-05 rewritten to README footnote (no ATTRIBUTION.md)
  - REQUIREMENTS.md Out of Scope table rows banning ATTRIBUTION.md + TBT code/data lift
  - README.md External Resources gains 1-line TileBitTools design-inspiration footnote
affects: [03-04-PLAN, 03-05-PLAN, 03-06-PLAN, plan-phase verifiers, future plan-checkers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Public-convention layout naming (formats sourced from each format's primary reference; no transcription from inspiration source)"
    - "Design-inspiration footnote pattern in README External Resources (replaces dedicated ATTRIBUTION.md)"

key-files:
  created:
    - .planning/phases/03-tilebittools-sourced-layouts/03-03-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - README.md

key-decisions:
  - "D-72 ratified across docs: Phase 3 retitled to 'Public-Convention Layouts (Blob47 + Tilesetter)'"
  - "D-73 ratified across docs: NO addons/penta_tile/ATTRIBUTION.md created; TBT is design-inspiration only; layouts implemented from each format's primary reference"
  - "Directory slug 03-tilebittools-sourced-layouts/ intentionally NOT renamed (RESEARCH § 11 Q7 — rename overhead exceeds doc-hygiene benefit; documented in commit message for future readers)"
  - "Single atomic commit for all 3 file changes (policy ratification is cohesive, not 3 independent edits)"

patterns-established:
  - "Single atomic commit for cohesive policy ratification across multiple docs (rather than per-file commits when changes are coupled)"
  - "Out-of-scope table is the canonical home for explicit policy bans (vs. v2 backlog which is for deferrals)"

requirements-completed: [TBT-04, DOC-05]

# Metrics
duration: 3min
completed: 2026-04-29
---

# Phase 3 Plan 3: D-72 + D-73 Doc Ratification Summary

**Phase 3 retitled to "Public-Convention Layouts (Blob47 + Tilesetter)" across ROADMAP/REQUIREMENTS; TBT-04 + DOC-05 rewritten from "ATTRIBUTION.md credits TBT" to "1-line README footnote acknowledging TBT as design inspiration"; addons/penta_tile/ATTRIBUTION.md formally banned via Out-of-Scope table.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-29T07:08:24Z
- **Completed:** 2026-04-29T07:11:08Z
- **Tasks:** 2
- **Files modified:** 3
- **Files created:** 1 (this SUMMARY.md)

## Accomplishments

- ROADMAP.md Phase 3 entry retitled in BOTH the Phases-list line (line 26) AND the detail-block heading (line 120). Goal description rewritten to cite primary references (BorisTheBrave for 47-blob; Tilesetter manual for Tilesetter Wang/Blob).
- ROADMAP.md Success Criteria #1-5 reworded: SC#1/SC#2 cite "Tilesetter's primary reference (D-75 outcome)" instead of `tilesetter_wang.tres` / `tilesetter_blob.tres`; SC#3 cites "BorisTheBrave's 47-blob reference (D-74)" instead of "the matching TBT template `.tres`"; SC#4 replaces "ATTRIBUTION.md exists, credits TBT..." with "README.md External Resources contains a 1-line footnote..."; SC#5 fixes the obsolete generator-script reference (`_generate_greybox_templates.py` → `_generate_bitmasks.py`).
- REQUIREMENTS.md TBT section preamble re-grounded on primary-source policy with explicit D-72/D-73/D-74/D-75/D-86 cross-references.
- REQUIREMENTS.md TBT-04 rewritten to README-footnote pattern with D-72 + D-73 citations.
- REQUIREMENTS.md DOC-05 rewritten to match TBT-04 (footnote exists; NO ATTRIBUTION.md).
- REQUIREMENTS.md Out of Scope table gains 2 new rows banning ATTRIBUTION.md + TBT code/data lift, with explicit decision-ID rationale.
- README.md External Resources section gains the 1-line TileBitTools design-inspiration footnote (verbatim wording locked by RESEARCH § 11 Q6 + plan-phase).

## Task Commits

Both tasks committed atomically (single commit per the plan's directive — policy ratification is cohesive across docs):

1. **Task 1: Rewrite ROADMAP.md Phase 3 entry per D-72** + **Task 2: Rewrite REQUIREMENTS.md TBT-04 + DOC-05 + README footnote** — `fcfb9e4` (docs)

The commit covers all 3 file modifications (ROADMAP.md, REQUIREMENTS.md, README.md) per the plan's `Edit 4` action specifying ONE atomic commit.

**Plan metadata commit:** TBD (final docs commit covering this SUMMARY.md + STATE.md + ROADMAP progress update)

## Files Created/Modified

- `.planning/ROADMAP.md` — Phase 3 retitled in 2 places; Success Criteria #1-5 rewritten; generator script reference fixed.
- `.planning/REQUIREMENTS.md` — TBT section preamble re-grounded; TBT-04 + DOC-05 rewritten; Out of Scope table gains 2 rows.
- `README.md` — External Resources section gains 1-line TBT design-inspiration footnote (after the "Drawing Only 5 Tiles" bullet, before the Excalibur.js bullet).
- `.planning/phases/03-tilebittools-sourced-layouts/03-03-SUMMARY.md` — this summary.

## Decisions Made

- **Single atomic commit for cohesive policy ratification.** The plan explicitly directed combining all 3 file changes into ONE commit (Edit 4's commit-message block). Followed the directive: ROADMAP + REQUIREMENTS + README all land in `fcfb9e4`. Rationale: D-72/D-73 is one policy decision across surfaces, not three independent doc edits; reviewer reads it once.
- **Directory slug intentionally NOT renamed.** Per the plan's anti-pattern guard (citing RESEARCH § 11 Q7) and at Claude's discretion, kept `03-tilebittools-sourced-layouts/` rather than renaming to `03-public-convention-layouts/`. Documented in commit message body so future readers understand the docs talk about "Public-Convention Layouts" but the directory still says `tilebittools`.

## Anti-pattern Verifications

All passed before commit:

- [x] `.planning/ROADMAP.md` contains "Public-Convention Layouts (Blob47 + Tilesetter)" exactly 2 times (Phases list + detail block).
- [x] `.planning/ROADMAP.md` contains 0 occurrences of `Add ATTRIBUTION.md`.
- [x] `.planning/ROADMAP.md` contains 0 occurrences of `transcribed from TBT` and `transcribed from TileBitTools`.
- [x] `.planning/ROADMAP.md` SC#4 references both `1-line footnote` and `https://github.com/dandeliondino/tile_bit_tools`.
- [x] `.planning/ROADMAP.md` references `_generate_bitmasks.py` (no occurrences of obsolete `_generate_greybox_templates.py`).
- [x] `.planning/REQUIREMENTS.md` TBT-04 contains both `1-line footnote` and `design inspiration`.
- [x] `.planning/REQUIREMENTS.md` DOC-05 contains `TileBitTools design-inspiration footnote` AND `NO ` addons/penta_tile/ATTRIBUTION.md` is created`.
- [x] `.planning/REQUIREMENTS.md` Out of Scope table gains both `addons/penta_tile/ATTRIBUTION.md` row (citing D-72 + D-73) and `Code or data lift from TileBitTools` row (citing D-73).
- [x] `.planning/REQUIREMENTS.md` TBT preamble references `BorisTheBrave's published 47-blob reference (D-74)`, `Tilesetter's manual`, and `D-86 outcome`.
- [x] `README.md` contains exactly 1 occurrence of `tile_bit_tools` link (no duplicate footnote).
- [x] `README.md` contains both `Design inspiration for PentaTile's layout-Resource architecture` and `no code or data is copied`.
- [x] `addons/penta_tile/ATTRIBUTION.md` does NOT exist on disk (D-73 guard via `test -e`).
- [x] `addons/penta_tile/ATTRIBUTION.md` is NOT tracked in git (`git ls-files | grep ATTRIBUTION` returns no matches).
- [x] `git log -1 --format=%s` matches `docs(03-03):` prefix.
- [x] No unexpected file deletions in commit `fcfb9e4` (`git diff --diff-filter=D HEAD~1 HEAD` returns empty).

## D-72 / D-73 Ratification Notes

Before this plan, the canonical references for Phase 3 scope (ROADMAP.md, REQUIREMENTS.md) still described the old "transcribe TBT slot tables + ship ATTRIBUTION.md" premise that the user explicitly overrode in the discuss-phase. Future plan-phase agents (and especially the verifier in Plan 06) need the canonical docs to reflect the policy as-locked, otherwise:

- Plan 04 (Blob47Godot) might cite TBT's `.tres` as primary source instead of BorisTheBrave's reference.
- Plan 05 (Tilesetter) might create the deprecated `_decode_tbt_templates.py`.
- Plan 06 verifier might mark Phase 3 incomplete because `ATTRIBUTION.md` is missing.

This plan ratifies D-72 + D-73 in the canonical docs so all downstream plans inherit the policy without re-litigating. Out of Scope table now formally bans `ATTRIBUTION.md` + TBT code/data lift, making any accidental future re-introduction trivially flag-able.

## Deviations from Plan

None — plan executed exactly as written. Both tasks committed atomically per the plan's `Edit 4` commit-message block, all 3 file modifications landing in commit `fcfb9e4`.

## Issues Encountered

- **PowerShell positional-args verification command** in the plan's `<verify>` blocks failed when bash interpolated `$txt`/`$req`/`$rm`/`$att` before passing the string to PowerShell. Worked around by running the equivalent `Grep` and `test -e` checks directly via the available tools (Grep + Bash); the actual verification logic was satisfied. No code or doc impact — just a tool-channel quirk on Windows.

## Next Plan Readiness

- **Plan 04 (Blob47Godot)** — fully unblocked. Depends only on Plan 01 pipeline patch (8-Moore propagation; D-87 audit) and BorisTheBrave's 47-blob reference (D-74). Can ship implementation that tests grep `Public-Convention Layouts` in ROADMAP and `design inspiration` in REQUIREMENTS to verify D-72/D-73 wording stuck.
- **Plan 05 (Tilesetter Wang15 + Blob47)** — depends on Plan 01's D-86 user gate outcome AND Plan 04's PNG generator helper. Plan 03 doesn't gate it.
- **Plan 06 (Phase 3 closeout)** — checks `Public-Convention Layouts` in ROADMAP/REQUIREMENTS; verifies `addons/penta_tile/ATTRIBUTION.md` does NOT exist. This plan's outputs are the canonical inputs for that verification.

## Self-Check: PASSED

Files verified to exist:
- FOUND: `.planning/ROADMAP.md` (modified)
- FOUND: `.planning/REQUIREMENTS.md` (modified)
- FOUND: `README.md` (modified)
- FOUND: `.planning/phases/03-tilebittools-sourced-layouts/03-03-SUMMARY.md` (this file)

Commits verified to exist:
- FOUND: `fcfb9e4` — `docs(03-03): rewrite TBT-04/DOC-05 + ROADMAP Phase 3 + README footnote (D-72, D-73)`

D-73 guard verified:
- DOES_NOT_EXIST: `addons/penta_tile/ATTRIBUTION.md`
- NOT_TRACKED: `addons/penta_tile/ATTRIBUTION.md` (not in `git ls-files`)

---
*Phase: 03-tilebittools-sourced-layouts*
*Completed: 2026-04-29*
