---
phase: 5
slug: demo-refresh-documentation-release
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-29
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

Phase 5 produces NO new runtime GDScript modules and NO new test files. The validation surface is (a) the existing 18-test suite re-run on Linux via a NEW `run_tests.sh`, (b) headless project-import + headless scene-open of the refreshed demo, and (c) manual eyeball UAT for the demo grid + docs review. The release workflow IS the formalization of `/gsd-verify-work` for REL-01..03 — a successful workflow run with green CI checks + published GitHub Release zip is the evidence.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bespoke headless Godot harness — each test is a `.gd` file with `extends SceneTree` + `_initialize`; runs via `godot --headless --script <path>`. PASS = exit 0 + no `ERROR:`/`SCRIPT ERROR:` in stderr; FAIL = non-zero OR error lines. No GUT, no other framework. |
| **Config file** | `tests/run_tests.ps1` (Windows local dev, registers 18 tests) + `tests/run_tests.sh` (Linux CI mirror, NEW — Plan D Wave 1) |
| **Quick run command** | `pwsh -File tests/run_tests.ps1 -NoPause -Test all` (local Windows, ~2 min) |
| **Full suite command** | `bash tests/run_tests.sh` (Linux CI, executed by release workflow step "Run tests") |
| **Estimated runtime** | ~120 seconds for the 18-test suite; ~5 seconds for headless scene open; ~15 seconds for `godot --import` |

---

## Sampling Rate

- **After every task commit:** Run `pwsh -File tests/run_tests.ps1 -NoPause -Test all` (local Windows, 18 tests must stay green).
- **After every plan wave:** Same — 18-test suite green is the gate. Plus, after Plan A (demo refresh) wave: open `addons/penta_tile/demo/penta_tile_demo.tscn` in the editor and confirm 8 instances render their bundled fallback. After Plan D (workflow) wave: dry-run the workflow on a feature branch via `gh workflow run` to verify YAML parses + Godot binary downloads.
- **Before `/gsd-verify-work`:** Full suite + headless demo-open must be green; one full release workflow run on a throwaway branch must publish a zip artifact (deleted after verification).
- **Max feedback latency:** ~120 seconds for the 18-test suite; ~5 minutes for a full workflow run on `ubuntu-latest`.

---

## Per-Task Verification Map

> Phase 5 has no new runtime tests. The map below ties each requirement to the existing test or CI step that proves it. Plans MAY add `<automated>` blocks that re-invoke these existing checks; they MUST NOT add new GDScript test files.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-A-* | A (Demo refresh) | 1 | DEMO-01 | — | 8 layout instances each render bundled fallback | manual visual | `godot res://addons/penta_tile/demo/penta_tile_demo.tscn` (eyeball) | ❌ scene refresh creates the new scene | ⬜ pending |
| 5-A-* | A (Demo refresh) | 1 | DEMO-02 | — | All 8 instances have `tile_set = null` and resolve via `get_fallback_tile_set()` | composed-canvas test | `pwsh -File tests/run_tests.ps1 -Test fallback_routing_test -NoPause` | ✅ Phase 4 shipped this test | ⬜ pending |
| 5-A-* | A (Demo refresh) | 1 | DEMO-03 | — | Drag-paint targets the instance under cursor | manual visual | demo eyeball | ❌ Plan A UAT step | ⬜ pending |
| 5-B-* | B (Documentation) | 1 | DOC-01 | — | "Layouts" table lists all 8 actually-shipped layouts | manual review | `grep -c '^| ' README.md` (check row count after table) | ❌ Plan B creates the section | ⬜ pending |
| 5-B-* | B (Documentation) | 1 | DOC-02 | — | "Upgrading from 0.1.x" enumerates breaking changes | manual review | `grep -A 50 '## Upgrading from 0.1' README.md` | ❌ Plan B creates the section | ⬜ pending |
| 5-B-* | B (Documentation) | 1 | DOC-03 | — | "Authoring a Custom Layout" includes a minimal `@experimental` subclass example | manual review | `grep -A 100 '## Authoring a Custom Layout' README.md \| grep -E '@experimental\|extends PentaTileLayout'` | ❌ Plan B creates the section | ⬜ pending |
| 5-B-* | B (Documentation) | 1 | DOC-04 | — | CHANGELOG `[Unreleased]` accumulates Phases 3, 3.5, 4, 5 deltas before workflow rewrites the header | manual review | `grep -B 2 -A 80 '## \[Unreleased\]' CHANGELOG.md` | ❌ Plan B extends existing | ⬜ pending |
| 5-C-* | C (Identity audit) | 1 | (manual prerequisite per D-05-13) | — | `05-LOC-AUDIT.md` produced + README "Identity & Footprint" anchor | developer judgment | `git ls-files 'addons/penta_tile/*.gd' 'addons/penta_tile/layouts/*.gd' \| grep -v 'tests/\|demo/' \| xargs wc -l` | ❌ Plan C produces the artifact | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | REL-01 | — | `plugin.cfg` `version=` field bumped via `sed -i -E 's/^version\s*=.*$/version="${NEW_VERSION}"/'` | workflow side-effect | release workflow step "Bump version" | ❌ workflow run produces it | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | REL-02 | — | `git tag -a v<new-version>` cut on the release commit | workflow side-effect | release workflow step "Tag release" | ❌ workflow run produces it | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | REL-03 | — | GitHub Release zip downloads + extracts cleanly to a fresh Godot 4.6 project | CI orchestrated | release workflow steps "Import project" + "Open demo" against the same archive contents that ship in the zip | ❌ workflow run produces it | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | (CI infra) | — | `tests/run_tests.sh` mirrors `run_tests.ps1` semantics on Linux | unit (test runner self-test) | `bash tests/run_tests.sh` (locally on WSL or via workflow dry-run) | ❌ Plan D Wave 1 creates it | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | (CI infra) | — | Headless project import returns clean stderr | CI step | `godot --headless --import --quit-after 2 2> import_stderr.log; ! grep -qE '^(ERROR\|SCRIPT ERROR):' import_stderr.log` | ❌ workflow step | ⬜ pending |
| 5-D-* | D (Release workflow) | 1 | (CI infra) | — | Headless demo open returns clean stderr | CI step | `godot --headless --quit-after 2 res://addons/penta_tile/demo/penta_tile_demo.tscn 2> demo_stderr.log; ! grep -qE '^(ERROR\|SCRIPT ERROR):' demo_stderr.log` | ❌ workflow step | ⬜ pending |
| 5-E-* | E (Closeout) | 1 | (phase gate) | — | Workflow runs once on `main` and produces a published v0.2.0 GitHub Release with attached zip | manual + CI | `gh release view v0.2.0` after one click of "Run workflow" | ❌ Plan E executes it | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] No new GDScript test files needed — Phase 5 reuses Phase 4's 18-test inventory.
- [ ] `tests/run_tests.sh` — NEW Linux mirror of `run_tests.ps1`; Plan D Wave 1 ships it. CI cannot execute Phase 4 tests on `ubuntu-latest` until this exists.
- [x] Determinism baseline (`BASELINE_HASH` + `BASELINE_CELLS` constants in `tests/_capture_baseline.gd`) — already self-contained; no Phase 5 work needed.
- [x] `wget` Godot 4.6.2-stable Linux binary — done inline in workflow step "Setup Godot"; not a Wave 0 dep, just a CI step.

*The single new piece of test infrastructure is `run_tests.sh`. All other validation surface is reused from prior phases.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 8 layout instances visually distinct + correctly named in the spatial grid | DEMO-01, DEMO-03 | Visual; cannot be assertion-checked headless | Open `addons/penta_tile/demo/penta_tile_demo.tscn` in Godot editor, run scene, confirm 8 labeled regions render distinct fallback art, drag-paint into each |
| README "Layouts" table reads cleanly + matches the 8 actually-shipped | DOC-01 | Markdown polish; row count grep is a sanity check, not a quality check | Read README.md after Plan B; verify table mentions Penta (5 modes), DualGrid16, Wang2Edge, Wang2Corner, Min3x3, PixelLabTopDown, PixelLabSideScroller, SingleTile (= 8) |
| README "Upgrading from 0.1.x" covers all real Phase 1.1 → Phase 5 breaking changes | DOC-02 | Subjective completeness check vs. CHANGELOG `[Unreleased]` block | Cross-reference README upgrade section against CHANGELOG breaking-changes entries; confirm parity |
| README "Authoring a Custom Layout" includes a minimal subclass example marked `@experimental` | DOC-03 | Sample code reads correctly | Read the example, confirm it compiles mentally and uses `@experimental` per Phase 4 doc-comment sweep |
| README "Identity & Footprint" frames identity as hot-path minimalism + anti-pattern absence (NOT raw LOC delta) | DOC-01, D-05-10, SC-C | The whole D-05-11 reframe is a wording call | Read the section, confirm framing matches D-05-11 ("LOC is signal, not goal") |
| Identity audit decision: ship vs. extract-and-optimize | D-05-11 | Developer judgment per the audit register | Run the audit recipe, walk the anti-pattern register (PITFALLS.md + MASK_UNIFICATION.md), make the ship/extract call |
| Workflow run produces a usable v0.2.0 GitHub Release | REL-01..03 | Eyeball check that the release page exists with the zip attached | After Plan E click "Run workflow", confirm `gh release view v0.2.0` shows zip + body matching CHANGELOG slice |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Plan D's `run_tests.sh` is the single Wave 0 dep; everything else is verified by existing tests, CI steps, or grep checks)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — most tasks check by grep + the 18-test suite runs on each commit
- [x] Wave 0 covers all MISSING references — only `run_tests.sh` is missing
- [x] No watch-mode flags — all commands are one-shot
- [x] Feedback latency < 120s for the 18-test suite, < 5min for a full workflow run
- [ ] `nyquist_compliant: true` — flip in frontmatter once Plan D Wave 1 ships `run_tests.sh`

**Approval:** pending
