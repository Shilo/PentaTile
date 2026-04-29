---
phase: 03
slug: tilebittools-sourced-layouts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `03-RESEARCH.md` § 10 "Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Godot 4.6 headless (`Godot --headless --script ...`) — no GUT, project policy ("works in my game") |
| **Config file** | None — tests are standalone `extends SceneTree` `_initialize` scripts in `addons/penta_tile/tests/` |
| **Quick run command** | `.\addons\penta_tile\tests\run_tests.ps1 -Test <test_name>` |
| **Full suite command** | `.\addons\penta_tile\tests\run_tests.ps1` |
| **Estimated runtime** | ~3-5 minutes for full suite (12 Phase 2 tests + ~6 Phase 3 additions = ~18 tests) |

---

## Sampling Rate

- **After every task commit:** Run `run_tests.ps1 -Test <relevant_test>` for the test most directly tied to the task (~5-15s per test).
- **After every plan wave:** Run `run_tests.ps1` (full suite, ~3-5 min).
- **Before `/gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 15 seconds for per-task; 5 minutes for per-wave.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-XX-01 | XX | 0c | D-87 prerequisite | — | N/A | rendering | `run_tests.ps1 -Test single_grid_8_moore_propagation_test` | ❌ W0c | ⬜ pending |
| 03-XX-02 | XX | 1 | TBT-03 (Blob47Godot) | — | N/A | unit | `run_tests.ps1 -Test blob_47_collapse_test` | ❌ W4 | ⬜ pending |
| 03-XX-03 | XX | 1 | TBT-03 | — | N/A | rendering | `run_tests.ps1 -Test comprehensive_bitmask_test` (extended) | ✅ extends | ⬜ pending |
| 03-XX-04 | XX | 1 | TBT-03 | — | N/A | rendering | `run_tests.ps1 -Test blob_47_hollow_test` | ❌ W4 | ⬜ pending |
| 03-XX-05 | XX | 2 | TBT-01 (TilesetterWang15) | — | N/A | unit | `run_tests.ps1 -Test tilesetter_wang_15_dispatch_test` | ❌ W4 | ⬜ pending |
| 03-XX-06 | XX | 2 | TBT-01 | — | N/A | rendering | `run_tests.ps1 -Test comprehensive_bitmask_test` (extended) | ✅ extends | ⬜ pending |
| 03-XX-07 | XX | 2 | TBT-02 (TilesetterBlob47) | — | N/A | unit | `run_tests.ps1 -Test tilesetter_blob_47_collapse_test` | ❌ W4 | ⬜ pending |
| 03-XX-08 | XX | 2 | TBT-02 | — | N/A | rendering | `run_tests.ps1 -Test comprehensive_bitmask_test` (extended) | ✅ extends | ⬜ pending |
| 03-XX-09 | XX | 3 | TEMPLATE-02 | — | N/A | rendering / file | `run_tests.ps1 -Test bitmask_bounds_test` (extended) | ✅ extends | ⬜ pending |
| 03-XX-10 | XX | 3 | TBT-04 (rewritten) + DOC-05 | — | N/A | file existence + grep | `run_tests.ps1 -Test readme_footnote_test` (or PowerShell `Test-Path`) | ❌ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> **Note:** Plan IDs and Task IDs are placeholders — the planner will assign concrete IDs (e.g. `03-01-PLAN.md` Task 1 → `03-01-01`) and update this table during plan generation.

---

## Wave 0 Requirements

Wave 0 covers prerequisite test infrastructure and the load-bearing pipeline patch:

- [ ] **Wave 0a — Tilesetter D-86 gate resolution** (planner-driven, not a test): user decision on Tilesetter primary-source path. Blocks Wave 2 generation.
- [ ] **Wave 0b — TBT-DEEP-AUDIT.md** (planner-driven, not a test): the design-audit deliverable per D-84. No tests; reviewed at phase verification.
- [ ] **Wave 0c — Single-grid 8-Moore pipeline patch + test:**
  - [ ] `addons/penta_tile/penta_tile_map_layer.gd:234-239` — extend `_mark_affected_single_grid_cells` from 4 cardinals to 8 Moore neighbors per RESEARCH § 5 Finding 1.
  - [ ] `addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd` — verifies painting a cell re-renders all 8 Moore neighbors of an existing cell. Catches regression of the 4-cardinal short-circuit.

Wave 4 (test additions tied to layout deliveries):
- [ ] `addons/penta_tile/tests/blob_47_collapse_test.gd` — 256-mask enumeration; asserts every collapse hits a valid `_MASK_TO_ATLAS` entry. Covers TBT-03 + TBT-02 collapse algorithm (D-78).
- [ ] `addons/penta_tile/tests/blob_47_hollow_test.gd` — hollow 5×5 ring rendering; catches diagonal-bleed regressions (Phase 2 lessons-learned methodology).
- [ ] `addons/penta_tile/tests/tilesetter_wang_15_dispatch_test.gd` — 4-bit corner mask completeness; asserts `mask_to_atlas(0) == Vector2i(5, 0)` (D-79 stray-fill slot).
- [ ] `addons/penta_tile/tests/tilesetter_blob_47_collapse_test.gd` — same shape as `blob_47_collapse_test.gd`; may be merged if collapse algorithm identical and only the dict differs.
- [ ] Extend `addons/penta_tile/tests/comprehensive_bitmask_test.gd` — add `Blob47Godot`, `TilesetterWang15`, `TilesetterBlob47` to layouts array; add 1-3 new patterns from RESEARCH § 8 to exercise 8-Moore corner-with-both-edges configurations (e.g., 3×3 plus + diagonals, X with diagonals, ring with diagonal).
- [ ] Extend `addons/penta_tile/tests/bitmask_bounds_test.gd` — add 3 new bundled PNG paths (`penta_tile_layout_blob_47_godot.png`, `penta_tile_layout_tilesetter_wang_15.png`, `penta_tile_layout_tilesetter_blob_47.png`).
- [ ] Extend `addons/penta_tile/tests/run_tests.ps1` — register new test names.

**Existing test infrastructure templates** (cite when implementing):
- `addons/penta_tile/tests/comprehensive_bitmask_test.gd` — pattern × layout matrix (canonical for new layouts).
- `addons/penta_tile/tests/penta_ground_hollow_test.gd` — fixture-based hollow test (template for `blob_47_hollow_test.gd`).
- `addons/penta_tile/tests/bitmask_bounds_test.gd` — bundled PNG slot-position verification (template for TEMPLATE-02 visual regression).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `03-TBT-DEEP-AUDIT.md` quality (D-84) | TBT-04 / D-84 | Audit is a markdown deliverable; quality is judgmental (ADOPT/PARTIAL/REJECT classification, TileMapDual cross-reference, backlog seeds for ADOPT-deferred patterns). | Reviewer reads the audit and confirms: (1) every TBT pattern from RESEARCH §6 is present with classification + reasoning, (2) cross-reference column is filled, (3) backlog seeds exist for PARTIAL/ADOPT-deferred items, (4) NO code/data lift surfaces in the recommendations. |
| Tilesetter visual regression on user-provided atlas (if D-86 resolves to (a)) | TBT-01 / TBT-02 | If user provides their own Tilesetter export, the slot-table fidelity check is "paint a known pattern in the user's source atlas, paint the same pattern via the new layout, eyeball-compare." Hash-based regression is brittle against cosmetic atlas changes. | Open Godot demo. Add a `PentaTileMapLayer` with each Tilesetter layout. Paint hollow ring + plus shape + L-shape. Visually confirm each cell silhouette matches the user-source atlas's intent. Save rendered PNG via `Image.save_png("user://tilesetter_uat.png")` and inspect. |

*If D-86 resolves to (b) defer, the Tilesetter manual-only entry is N/A — the Tilesetter layouts don't ship.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (the 8-Moore pipeline patch, test infrastructure scaffolding)
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s per-task / < 5min per-wave
- [ ] `nyquist_compliant: true` set in frontmatter (after planner fills the per-task table with concrete plan/task IDs)

**Approval:** pending
