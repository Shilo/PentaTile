---
phase: 4
slug: fallback-routing
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-29
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Godot 4.6 native — `godot --headless --script <test>.gd` (no GUT, per "works in my game" quality bar) |
| **Config file** | `addons/penta_tile/tests/run_tests.ps1` (registry of all test scripts) |
| **Quick run command** | `& "C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path . --script addons/penta_tile/tests/fallback_routing_test.gd` |
| **Full suite command** | `pwsh addons/penta_tile/tests/run_tests.ps1` |
| **Estimated runtime** | ~6–10 seconds for full suite (17 tests today, 18 after Phase 4) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the script just touched (or full suite if cross-cutting)
- **After every plan wave:** Run the full suite (`run_tests.ps1`)
- **Before `/gsd-verify-work`:** Full suite must be green AND `04-FALLBACK-UAT.md` signed off
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

> Per-task verification contract. One row per task across all 5 plans (15 tasks total: Plan 01 has 4 tasks including Wave 0 anchor; Plans 02 and 04 have 3 each; Plan 03 has 4; Plan 05 has 1).
>
> For manual-only tasks (Plan 03 Task 1 manual UAT eyeball, Plan 03 Task 4 Gemini fix-loop, Plan 04 Task 3 Codex fix-loop), the Test Type is `manual` or `process` and the steps reference the "Manual-Only Verifications" table below. Per the B2 fix from the checker, those tasks now run as `type="auto"` with grep-checkable acceptance criteria proving the manual flow happened (sign-off lines flipped, anchor-bounded commit count, status: all_dispositioned), so the gate is deterministic — no checkpoint mode needed.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-0 | 01 | 1 | PREVIEW-03 / PREVIEW-04 (B4 anchor support) | T-04-01-05 | Anchor SHA recorded immutably for downstream commit-count gates | unit | `test -f .planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt && grep -cE '^[a-f0-9]{40}$' .planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt` | ✅ W0 | ⬜ pending |
| 01-1 | 01 | 1 | PREVIEW-03 / PREVIEW-04 / SC-4 | T-04-01-01..04 | N/A (test infrastructure; failures land in stderr per `_record`) | unit | `& "C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path . --script addons/penta_tile/tests/fallback_routing_test.gd` | ✅ W0 | ⬜ pending |
| 01-2 | 01 | 1 | PREVIEW-03 / PREVIEW-04 (registry wiring) | — | N/A | unit | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -Test fallback_routing_test -NoPause` | ✅ W0 | ⬜ pending |
| 01-3 | 01 | 1 | PREVIEW-03 / PREVIEW-04 (UAT skeleton) | — | N/A (skeleton has 9 `Signed-off: pending` lines awaiting Plan 03 sign-off; B2 fix grep gate) | unit | `test -f .planning/phases/04-fallback-routing/04-FALLBACK-UAT.md && grep -c '^### [1-9]\. ' .planning/phases/04-fallback-routing/04-FALLBACK-UAT.md` | ✅ W0 | ⬜ pending |
| 02-1 | 02 | 1 | DOC (sweep on 3 core scripts) | T-04-02-01..04 | N/A (annotation-only; logic-equivalence verified by test suite) | unit | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` | ✅ W0 | ⬜ pending |
| 02-2 | 02 | 1 | DOC (sweep on PentaTileLayout base + 5 native + Penta layouts) | T-04-02-01..04 | N/A | unit | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` | ✅ W0 | ⬜ pending |
| 02-3 | 02 | 1 | DOC (sweep on Blob47 + 2 PixelLab layouts) | T-04-02-01..04 | N/A | unit | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` | ✅ W0 | ⬜ pending |
| 03-1 | 03 | 2 | PREVIEW-03 / PREVIEW-04 (manual UAT eyeball pass) | T-04-03-04 (UAT trust signal) | N/A (humans verify visual correctness; sign-off lines pin gate per B2 fix) | manual | `test -f .planning/phases/04-fallback-routing/04-FALLBACK-UAT.md && grep -c '^Signed-off:' .planning/phases/04-fallback-routing/04-FALLBACK-UAT.md returns ≥ 9 AND grep -c '^Signed-off: pending$' returns 0` | ✅ W0 | ⬜ pending |
| 03-2 | 03 | 2 | DOC (12-row coverage table summary) | T-04-02-03 | N/A | unit | `test -f .planning/phases/04-fallback-routing/04-DOC-SWEEP.md && grep '^status: complete$' .planning/phases/04-fallback-routing/04-DOC-SWEEP.md` | ✅ W0 | ⬜ pending |
| 03-3 | 03 | 2 | REVIEW (Gemini prompt + raw findings) | T-04-03-01..05, T-04-03-07 | Prompt embeds 7 content-aware disqualification triggers + Coined-Term + identity guardrails verbatim (W5 fix) | unit | `test -s .planning/phases/04-fallback-routing/04-GEMINI-PROMPT.md && grep -c '^reviewer: gemini$' .planning/phases/04-fallback-routing/04-GEMINI-REVIEW.md` | ✅ W0 | ⬜ pending |
| 03-4 | 03 | 2 | REVIEW (Gemini fix-loop disposition log) | T-04-03-01..03, T-04-03-06 | Anchor-bounded commit count matches `applied` count (B4 fix); no D-04-14 trigger findings applied | process | `ANCHOR=$(cat .planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt) && git log --oneline ${ANCHOR}..HEAD \| grep -c 'fix(04): GEMINI-' returns ≥ {applied count from 04-GEMINI-REVIEW-FIX.md frontmatter}` | ✅ W0 | ⬜ pending |
| 04-1 | 04 | 3 | REVIEW (Codex prompt with 7a guard) | T-04-04-01, T-04-04-04, T-04-04-07 | Prompt embeds 7 content-aware disqualification triggers + 7a Gemini-already-dispositioned guard verbatim (W5 + W6 fixes) | unit | `wc -l .planning/phases/04-fallback-routing/04-CODEX-PROMPT.md returns ≥ 80 AND grep -ci 'already.dispositioned\|7a\|do NOT re-file\|do not re.file' returns ≥ 1` | ✅ W0 | ⬜ pending |
| 04-2 | 04 | 3 | REVIEW (Codex raw findings) | T-04-04-01, T-04-04-02, T-04-04-05 | N/A (post-Gemini-fix codebase per D-04-10 strict order) | unit | `test -s .planning/phases/04-fallback-routing/04-CODEX-REVIEW.md && grep -c 'reviewer: codex' .planning/phases/04-fallback-routing/04-CODEX-REVIEW.md` | ✅ W0 | ⬜ pending |
| 04-3 | 04 | 3 | REVIEW (Codex fix-loop disposition log) | T-04-04-01..03, T-04-04-06 | Anchor-bounded commit count matches `applied` count (B4 fix); sequential-apply on conflicts with Gemini fixes; no 7a-violations applied | process | `ANCHOR=$(cat .planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt) && git log --oneline ${ANCHOR}..HEAD \| grep -c 'fix(04): CODEX-' returns ≥ {applied count from 04-CODEX-REVIEW-FIX.md frontmatter}` | ✅ W0 | ⬜ pending |
| 05-1 | 05 | 4 | PREVIEW-03 / PREVIEW-04 (phase close) | T-04-05-01..05 | Pre-flight gate verifies all 4 closeout artifacts; close-out commit modifies only REQUIREMENTS.md / ROADMAP.md / STATE.md | unit | `grep -E '^\- \[x\] \*\*Phase 4:' .planning/ROADMAP.md && grep -cE '^\| PREVIEW-0[34] \| 4 \| Complete' .planning/REQUIREMENTS.md && pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` | ✅ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `.planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt` — pre-Phase-4 commit anchor SHA captured by Plan 01 Task 0 (B4 fix; anchor for Plans 03+04 commit-count grep ranges)
- [x] `addons/penta_tile/tests/fallback_routing_test.gd` — composed-canvas test exercising all 8 actually-shipped layouts via `tile_set = null` (5 Phase 2 + Blob47Godot + 2 PixelLab; Tilesetter pair excluded per D-86 b); now includes SC-4 user-tileset-preserved sub-test (B3 fix)
- [x] `addons/penta_tile/tests/run_tests.ps1` — register `fallback_routing_test.gd` so the full-suite command picks it up

*Existing infrastructure (composed-canvas helpers in `comprehensive_bitmask_test.gd` and `penta_ground_hollow_test.gd`) is reused; no new framework install required.*

*Wave 0 anchor task (Plan 01 Task 0): captures the pre-Phase-4 commit SHA. The anchor file is the foundation of the B4 fix that replaces fragile `--since="1 day ago"` time filters with content-bounded `${ANCHOR}..HEAD` ranges in Plans 03 + 04 commit-count gates.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fallback eyeball pass on demo | PREVIEW-03 | Visual regression — automated test cannot judge "looks like a tileset" qualitatively | Open `addons/penta_tile/demo/penta_tile_demo.tscn`, swap each of the 8 layouts in turn (set `tile_set = null` first), drag-paint, confirm visible greybox tiles; flip each row's `result:` and `Signed-off:` line in `04-FALLBACK-UAT.md` from `pending` to a non-pending value (B2 fix grep gate). |
| `tile_set` user-override regression | PREVIEW-04 | Inspector-driven — confirms `_tile_set_is_fallback` flag flips correctly when user assigns a custom TileSet, then clears it | Open inspector on `PentaTileMapLayer`, assign a custom TileSet → confirm fallback overridden (no warnings); set `tile_set = null` → confirm fallback returns; record in `04-FALLBACK-UAT.md` row 9. SC-4 (B3 fix) is verified programmatically via `_test_preview_04_user_tileset_preserved` in `fallback_routing_test.gd`; the manual eyeball pass corroborates by changing layout while a user TileSet is bound and confirming the TileSet survives. |
| Cross-AI review (Gemini) findings + dispositions | — (process artifact, not REQ-mapped) | Reviewer output is text, dispositions are human judgment | Run `gemini -p "<prompt>"` per RESEARCH § 3, capture output, classify findings, log dispositions in `04-GEMINI-REVIEW-FIX.md`; atomic commits per applied fix. Per the B4 fix, the gate is `git log --oneline ${ANCHOR}..HEAD | grep -c 'fix(04): GEMINI-'` matching the `applied` count in REVIEW-FIX.md frontmatter (anchor file at `.planning/phases/04-fallback-routing/04-PRE-PHASE-ANCHOR.txt` from Plan 01 Task 0). |
| Cross-AI review (Codex) findings + dispositions | — (process artifact, not REQ-mapped) | Reviewer output is text, dispositions are human judgment | Run `/gsd-review codex` (or `codex exec --skip-git-repo-check -` per Phase 3.5 precedent), capture output, classify findings, log dispositions in `04-CODEX-REVIEW-FIX.md`; atomic commits per applied fix. Same anchor-based commit-count gate as Gemini, with `CODEX-` prefix. |
| Doc-comment sweep coverage | DOC-related (Phase 4 SC #5) | Reviewer-as-validator per D-04-04 — no lint test added | Cross-AI review pass surfaces missed `##` blocks / wrong tag usage as `Doc`-themed findings; sweep summary in `04-DOC-SWEEP.md` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (manual-only tasks for review/UAT/doc-sweep are acceptable per the table above; B2 fix replaced placeholder `echo` gates with grep-checkable artifact-state checks)
- [x] Wave 0 covers all MISSING references (`04-PRE-PHASE-ANCHOR.txt` + `fallback_routing_test.gd` + registry update)
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — Plans 01–05 mapped row-by-row above; checker B1 (VALIDATION populated) + B2 (no `echo` placeholder gates — grep-checkable artifact state) + B3 (SC-4 sub-test added to Plan 01 Task 1) + B4 (anchor-based commit count) + W2/W4/W5/W6 fixes all reflected in the per-task command column.
