---
phase: 5
slug: demo-refresh-documentation-release
status: passed
verified: 2026-04-29
release: v0.2.0
release_url: https://github.com/Shilo/PentaTile/releases/tag/v0.2.0
release_sha: a3223b97346af2b049249790d465be70192ecee8
must_haves_score: 10/10
---

# Phase 5 — Verification Report

> Goal-backward verification: did Phase 5 actually deliver what its goal promised?

**Phase goal:** Ship v0.2.0. Three braided deliverables: (1) `penta_tile_demo.tscn` refreshed into a side-by-side spatial-grid showcase of the 8 actually-shipped layouts using bundled fallback only (no player); (2) Documentation extended (4 new README sections + accumulated CHANGELOG) and 14 spec corrections applied across REQUIREMENTS/ROADMAP/PROJECT/CLAUDE; (3) Single manually-triggered GitHub Actions workflow that auto-increments version, runs CI checks, commits, tags, builds zip, and publishes the GitHub Release. Plus a manual three-axis identity audit (LOC + public surface + hot-path complexity) as a developer-judgment prerequisite to release per D-05-13.

## Verdict: PASSED

All 10 v1 requirement IDs satisfied. v0.2.0 milestone shipped to GitHub Releases.

## Must-Haves Verified

| Must-Have | Evidence | Status |
|-----------|----------|--------|
| 8 layout instances render bundled fallback in demo | `git show 8addacc:addons/penta_tile/demo/penta_tile_demo.tscn`; visual UAT approved by Plan 05-01 checkpoint | ✓ |
| Hover-target drag-paint works across grid | `git show d0e9849:addons/penta_tile/demo/demo_runtime_painter.gd`; manual UAT confirmed | ✓ |
| 4 README sections present (Layouts, Upgrading, Authoring, Identity & Footprint) | `git show 0b9430e -- README.md`; later filled by `9ad9083` for Identity & Footprint | ✓ |
| CHANGELOG accumulated through Phase 5 then auto-rewritten by workflow | header now reads `## [0.2.0] — 2026-04-29` (workflow commit `a3223b9` rewrote per D-05-17 step 4) | ✓ |
| 15 spec corrections applied across REQUIREMENTS/ROADMAP/PROJECT/CLAUDE | commit `42523ee` (14 planned + 1 follow-up at ROADMAP.md:303) | ✓ |
| Identity audit produced with 3 axes + ship/extract decision | `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`; decision: **SHIP** (clean hot path + 16/16 anti-patterns absent) | ✓ |
| `.github/workflows/release.yml` exists and ran successfully | run 25131034672, 30s wall-clock, all 13 steps green | ✓ |
| `tests/run_tests.sh` Linux mirror exists | `git show 3d0ced3 -- tests/run_tests.sh`; 105 lines, 17-test inventory | ✓ |
| All 12 phase-specific pitfalls mitigated in workflow YAML | Plan 04 SUMMARY enumerates each mitigation; CI checks proved Pitfall #1 fix works (import + demo-open exit cleanly) | ✓ |
| v0.2.0 published to GitHub Releases with zip artifact | https://github.com/Shilo/PentaTile/releases/tag/v0.2.0 — `penta_tile-v0.2.0.zip` (208024 bytes), digest `sha256:5bf1f0579e60...` | ✓ |

## Requirement Coverage

All 10 v1 requirement IDs flipped to Complete in `.planning/REQUIREMENTS.md`:

| REQ | Plan | Evidence Commit / Run |
|-----|------|----------------------|
| DEMO-01 | 05-01 | `8addacc` (8-instance spatial-grid scene) |
| DEMO-02 | 05-01 | `8addacc` (every instance has `tile_set = null`, fallback engages) |
| DEMO-03 | 05-01 | `d0e9849` (hover-target painter) |
| DOC-01 | 05-02 | `0b9430e` (Layouts table — 8 actually-shipped per SC-A) |
| DOC-02 | 05-02 | `0b9430e` (Upgrading from 0.1.x) |
| DOC-03 | 05-02 | `0b9430e` (Authoring a Custom Layout, `@experimental`) |
| DOC-04 | 05-02 | `8477790` + `a3223b9` (CHANGELOG accumulation + workflow rewrite) |
| REL-01 | 05-04 + workflow | run 25131034672: plugin.cfg `0.1.0 → 0.2.0` |
| REL-02 | 05-04 + workflow | run 25131034672: tag `v0.2.0` cut on `a3223b9` |
| REL-03 | 05-04 + workflow | run 25131034672: zip published at v0.2.0 Release |

## CI Evidence

Release workflow run `25131034672` (30s wall-clock):

- ✓ `actions/checkout@v6` — base commit `43aa007c53c2677d154999b29a741810d35cbdca`
- ✓ Version bump: `0.1.0` → `0.2.0` (sed regex preserved quoted form per Pitfall #7)
- ✓ Godot 4.6.2-stable downloaded
- ✓ Headless import: exit 0, "Import clean" (Pitfall #1 mitigation: `--quit-after 2` + stderr grep)
- ✓ Headless demo open: exit 0, "Demo open clean"
- ✓ plugin.cfg updated to 0.2.0
- ✓ CHANGELOG header rewritten to `[0.2.0] — 2026-04-29`
- ✓ `chore(release): v0.2.0` committed and pushed by `github-actions[bot]`
- ✓ `git tag v0.2.0` cut on the release commit
- ✓ `git archive` zip built (208024 bytes, prefix `penta_tile-v0.2.0/`, addon-only pathspec)
- ✓ `softprops/action-gh-release@v3` published the Release with zip attached

The CI's headless import + demo-open against the same archive contents that ship in the zip is the proxy for REL-03 SC-6 ("downloading the zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors") per D-05-14.

## Identity Guardrail

Phase 5 SC-7 identity guardrail flipped from **AT RISK** (Phase 4 carry-forward) to **PASSED**:

- LOC: 2884 PentaTile vs 2126 TileMapDual v5.0.2 (Δ +758) — reported as data per D-05-11, NOT as a fail criterion
- Hot path: 4 frames (`_update_cells` → `layout.compute_mask` → `layout.mask_to_atlas` → `set_cell`) vs TileMapDual's 8+ frames
- Anti-pattern register: 16/16 absent (6 CLAUDE.md guardrails + 10 AP-1..AP-10 from PITFALLS.md)
- Decision: **SHIP** per D-05-11 (clean hot path + zero anti-patterns + cosmetic deletion explicitly NOT allowed)

Full audit: `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`. Audit summary published in README "Identity & Footprint" section. TileMapDual reference pinned at commit `9ff1e24f80be1816cfcd7aeec32800a699a94ccb` (v5.0.2 tag, 2026-01-03).

## Constraints Honored

- **Breaking Changes Policy HARD RULE (both directions):** 10 demo files deleted cleanly (no `.deprecated` suffix); workflow has zero `workflow_dispatch.inputs` per D-05-16 (no patch-bump speculation); Plan 01 retired `penta_ground_hollow_test` rather than preserve compat with the deleted authored ground.
- **Coined-Term Discipline:** workflow file `release.yml`, job `release` (generic); zero `PentaCI` / `PentaWorkflow` / `PentaRelease` coined terms introduced; existing PentaTile prefix preserved correctly.
- **D-05-13 enforcement:** CI workflow does NOT check `05-LOC-AUDIT.md` existence and does NOT run LOC counters; the audit is a developer-judgment prerequisite that the developer ran before triggering the workflow.
- **Quality Bar "Works in my game":** 17/17 tests green at HEAD `9204fdb`; the test harness (`run_tests.ps1` + new Linux `run_tests.sh` mirror) is the verification surface; no GUT, no new test framework added.

## Test Methodology

No new test files were added in Phase 5 (per the validation strategy). The existing 17-test inventory is the test surface (was 18 before Plan 01 retired `penta_ground_hollow_test` along with the deleted authored ground). The CI workflow runs all 17 tests via the new `run_tests.sh` Linux mirror, which exited 0 in the workflow run (run 25131034672) confirming the inventory translates correctly across platforms.

## Cross-Phase Awareness

- Phase 4 carry-forward "identity guardrail AT RISK" — RESOLVED by Plan 05-03 audit decision SHIP.
- Phase 4 cumulative LOC = 2884 — confirmed unchanged for runtime files (`addons/penta_tile/*.gd` + `addons/penta_tile/layouts/*.gd` excluding tests/demo) post-Phase-5; Plan 01 only modified `demo/` files (excluded from the audit recipe), Plan 04 added `tests/run_tests.sh` (also excluded).
- Phase 3.5 D-91 (VAR-PIXEL-01 deferred to v2) — propagated correctly into README "Layouts" table per DOC-01 row count of 8.

## Notable Deviations

- **Plan 01:** test inventory reduced from 18 to 17 (`penta_ground_hollow_test` retired with the deleted `penta_tile_ground.tres`). Documented in Plan 01 SUMMARY § Deviations and propagated to Plan 04's `run_tests.sh`. Per CLAUDE.md HARD RULE this is a clean break, not a regression.
- **Plan 02:** 15 spec corrections applied (planned 14 + 1 follow-up at ROADMAP.md:303 to satisfy SC-C self-check grep cleanly across the deferred Phase 6 block). Added per D-05-12 planner authorization.
- **Plan 04:** Pattern mapper agent hit the org's monthly usage limit; planner proceeded without PATTERNS.md (non-blocking per workflow). Plan-checker verified plan quality without it; executor used the workflow YAML skeleton in RESEARCH.md "Code Examples" as the analog template.

## Conclusion

Phase 5 fully delivered the v0.2.0 milestone. All 10 v1 requirements validated by the published GitHub Release. Identity guardrail re-validated. The release workflow is a single-button-click operation per the user's hard rule ("if it cannot be automatic, remove it"). Future patch releases (v0.2.1) deliberately bypass this workflow per D-05-16's anti-speculation stance.

**Phase 5 — CLOSED.**
**v0.2.0 — SHIPPED.**
