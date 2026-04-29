# Phase 5: Demo Refresh + Documentation + Release - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 is the v0.2.0 ship gate. Three braided deliverables:

1. **Demo refresh** — `penta_tile_demo.tscn` becomes a side-by-side spatial-grid showcase of the 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5). Every instance uses its bundled fallback `TileSet`. No player. Pure layout showcase. (DEMO-01..03)
2. **Documentation** — README gets new sections (Layouts table; Upgrading from 0.1.x; Authoring a Custom Layout; Identity & Footprint), CHANGELOG `[Unreleased]` block converts to `[0.2.0] — <date>`. (DOC-01..04)
3. **Release** — `plugin.cfg` version bumped, tag created, GitHub Release published — all driven by a single manually-triggered GitHub Actions workflow that auto-increments the version, runs automated checks, commits the bump, tags, builds the zip, and publishes the Release in one click. (REL-01..03)

Plus the phase carries the **manual identity audit** as a developer-judgment prerequisite to release (not a CI gate; not a LOC fail criterion — see D-05-11).

New capabilities (variation, top tiles, multi-terrain, editor preview during drag, MkDocs site, Asset Library submission) are **out of scope** — they belong in v0.3+ / v2 backlog.

</domain>

<decisions>
## Implementation Decisions

### Demo Refresh (DEMO-01..03)

- **D-05-01:** Side-by-side spatial grid in `penta_tile_demo.tscn`. 8 `PentaTileMapLayer` instances arranged spatially (planner picks layout — likely 2×4 or 4×2 grid). Each instance is labeled (a `Label` sibling node) so the layout name is visible at a glance. Drag-paint targets the instance under the cursor. Camera fits all 8 OR pans; planner decides between fixed-zoom-fit-all vs. centered-on-active.

- **D-05-02:** All 8 instances use **bundled fallback only** — every `PentaTileMapLayer` has `tile_set = null`, `layout = <bundled .tres>`. `get_fallback_tile_set()` is the sole source of pixels. Proves DEMO-02 explicitly (8-of-8). Existing `addons/penta_tile/demo/penta_tile_ground.{png,tres}` + `_regen_demo_ground.py` are retired from the demo (planner picks delete vs archive).

- **D-05-03:** **No player.** `CharacterBody2D` + `demo_player.gd` + `Godot icon.svg` sprite removed from the demo scene. Reason: the joint constraint of D-05-02 (all-fallback) and D-05-03's original "player on Penta" answer is mathematically incompatible — `get_fallback_tile_set()` ([layouts/penta_tile_layout.gd:140-165](../../../addons/penta_tile/layouts/penta_tile_layout.gd#L140-L165)) ships ZERO physics layers. User chose to drop the player rather than weaken DEMO-02 satisfaction. Demo becomes pure layout showcase.

- **D-05-04:** Demo SCENE refresh is safe relative to the determinism baseline. `determinism_test.gd` / `_capture_baseline.gd` reference `penta_layout_four_horizontal.tres` directly via `--layout-path` CLI flag, NOT the demo scene. The demo's bundled `penta_layout_*.tres` files keep existing; `BASELINE_HASH=2986698704` and `BASELINE_CELLS=46` survive the refresh. Plan-phase verifies this assumption by grepping test scripts; flips to a defensive split (`penta_tile_baseline.tscn` + `penta_tile_demo.tscn`) only if hidden coupling surfaces.

- **D-05-05:** `demo_runtime_painter.gd` stays — drag-paint behavior is preserved per DEMO-03. Updated to handle the side-by-side grid (drag-paint targets the `PentaTileMapLayer` under the cursor; planner decides hover-detection or click-to-arm patterns).

### LOC + Identity Audit (Phase 5 final gate, reframed)

- **D-05-08:** Audit measures **all three axes**: (1) runtime LOC of `addons/penta_tile/*.gd` + `addons/penta_tile/layouts/*.gd` excluding `tests/` and `demo/` (same recipe as Phase 2/3/3.5/4 — current cumulative: 2884 LOC); (2) public surface (count of `@export` properties + public methods + `class_name`'d classes); (3) hot-path complexity (`_update_cells` → `layout.compute_mask` → `layout.mask_to_atlas` → `set_cell` vs. TileMapDual's equivalent path). Each axis reports a number/observation.

- **D-05-09:** TileMapDual comparison uses a **pinned tag**. Plan-phase clones `github.com/pablogila/TileMapDual` at the latest stable release tag, runs identical methodology (`git ls-files | xargs wc -l` recipe on equivalent runtime files; identical exclusion of tests/demo/docs). The pinned tag + commit hash are documented in `05-LOC-AUDIT.md` so the comparison is reproducible.

- **D-05-10:** Audit results live in **README "Identity & Footprint" section** (single source of truth, visible to anyone browsing the repo) plus a **summary line in the GitHub Release notes** linking to that README section. The full working audit lives in `.planning/phases/05-*/05-LOC-AUDIT.md` (the in-flight artifact). CHANGELOG does NOT contain the audit (it's a release-mechanics-and-breaking-changes log; the audit is a different concern). No standalone `addons/penta_tile/AUDIT.md` (overkill).

- **D-05-11:** **Audit framing flips: LOC is signal, not goal.** Performance and optimization are what matter. The audit's fail criterion is **NOT** "LOC > TileMapDual." It is "LOC large AND identifiable inefficiencies / duplicated code." Action triggers:
  - LOC large + clean hot path + zero anti-patterns from the register → **ship.** LOC is reported as data, not a verdict.
  - LOC large + identifiable inefficiencies / duplications → **extract reusable helpers + optimize the hot path before ship.** Cosmetic deletion is explicitly NOT allowed.
  - Any anti-pattern from the register triggered (terrain peering, watcher, coord cache, signal fanout, parallel paint API, EditorInspectorPlugin polish) → fix before ship.
  README "Identity & Footprint" frames identity as **hot-path minimalism + anti-pattern absence**, not "fewer lines than TileMapDual."

- **D-05-12:** **Spec-correction authorization for the planner.** `PROJECT.md` Constraints ("PentaTile must remain visibly smaller and simpler than TileMapDual") and `ROADMAP.md` Phase 5 SC-7 ("`addons/penta_tile/` total surface area stays under TileMapDual's equivalent — the result included in the release notes") are reframed by D-05-11. The planner is authorized to propose wording corrections in a Phase 5 plan that aligns these texts with the perf/optimization framing — preserving "simpler in spirit" while removing the "must be smaller LOC" implication.

- **D-05-13:** The audit is **a manual prerequisite to release, NOT a CI gate.** The developer runs the audit, decides ship/extract-and-optimize per D-05-11, and only then clicks "Run workflow" on the release Action. The CI workflow (D-05-15..18) does NOT check audit existence or LOC metrics — that contradicts the user's "LOC is not a measure of quality" position.

### Release Packaging (REL-01..03, fully automated)

- **D-05-15:** **Single manually-triggered GitHub Actions workflow** (`workflow_dispatch` trigger, no inputs) handles the entire release in one button click. Hard rule from the user: **"if it cannot be automatic, remove it."** Workflow file lives at `.github/workflows/release.yml`. User flow shrinks to: GitHub UI → Actions → "Release" workflow → "Run workflow" button. That is the ONLY manual action in the release.

- **D-05-16:** **Auto-version-increment rule.** Workflow reads current `addons/penta_tile/plugin.cfg` `version=` field and bumps:
  - **Minor +1** by default. Patch stays 0. Examples: `0.1.0 → 0.2.0`, `0.2.0 → 0.3.0`, ..., `0.8.0 → 0.9.0`.
  - **If minor would exceed 9: major +1, minor resets to 0.** Examples: `0.9.0 → 1.0.0`, `1.9.0 → 2.0.0`.
  - No `--input` / no `workflow_dispatch.inputs.version` — entirely auto-derived.
  - Patch-level releases are NOT supported by this scheme; if a v0.2.1-style patch is ever needed, the workflow is bypassed and a hand-rolled release happens. The "remove anything not automatic" rule means we DON'T add patch-bump complexity speculatively.

- **D-05-17:** **Workflow steps (in order):**
  1. Compute next version from current `plugin.cfg` per D-05-16.
  2. **Automated CI checks** (per D-05-14):
     - `godot --import --headless` — imports the project clean.
     - Run all tests in `tests/` (the 18 currently registered) via the existing harness adapted for Linux runner.
     - Headless-open `penta_tile_demo.tscn` and assert no errors in stderr.
     - If any check fails → workflow exits non-zero. No commit/tag/release.
  3. Bump `addons/penta_tile/plugin.cfg` `version=` to the new version.
  4. Rewrite `CHANGELOG.md` header `## [Unreleased] — v0.2 in progress` → `## [<new-version>] — YYYY-MM-DD` (current date).
  5. `git commit -m "chore(release): v<new-version>"` (committed by the GitHub Actions bot).
  6. `git tag -a v<new-version> -m "PentaTile v<new-version>"`.
  7. `git push origin main --tags`.
  8. Build the zip: `git archive --format=zip --prefix=penta_tile-v<new-version>/ -o penta_tile-v<new-version>.zip v<new-version> -- addons/penta_tile/`.
  9. Extract the new CHANGELOG slice (the just-rewritten `[<new-version>]` block, up to but not including the next `[...]` heading) into `release-notes-body.md`.
  10. `gh release create v<new-version> penta_tile-v<new-version>.zip --title "PentaTile v<new-version>" --notes-file release-notes-body.md` (or `softprops/action-gh-release@v2` equivalent).

- **D-05-14:** Automated CI checks (per D-05-13 framing) are: tests + headless project import + headless demo open. **No LOC audit in CI** (LOC is not a quality measure). **No manual eyeball pass** (cannot be automated; per the user's hard rule, removed). REL-03 SC-6 ("downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run") is verified IN-CI by the headless project import + demo open step against the SAME archive contents that the workflow ships — close enough to "fresh project boot" without a separate post-release smoke test.

- **D-05-18:** **Release notes content = CHANGELOG `[<new-version>]` slice paste verbatim.** No hand-written intro, no highlight reel. Single source of truth in CHANGELOG. The slice extraction is mechanical (between `## [<new-version>]` heading and the next `## [...]` heading, exclusive). README's `Identity & Footprint` summary already lives at a known anchor and the CHANGELOG entry can include a `See README § Identity & Footprint for the v0.2.0 audit summary` line if useful.

### Spec Corrections (planner instructions)

The wording in REQUIREMENTS.md, ROADMAP.md, and PROJECT.md drifted between earlier-phase decisions and the current reality. Phase 5 plans must reconcile the following before they ship:

- **SC-A:** `DEMO-01` and `DOC-01` say "all 10 built-in layouts." Reality is **8 actually-shipped** (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5). Tilesetter pair (TBT-01-DEFERRED / TBT-02-DEFERRED) is deferred to v0.3+ per D-86 (b). Plans rewrite to "all 8 actually-shipped layouts" with a clear deferral note pointing at the v0.3+ backlog entries.

- **SC-B:** `REL-03` says "ATTRIBUTION.md is present at the addon root." That is **explicitly banned** per D-72 / D-73 (Phase 3). Plans delete the ATTRIBUTION.md mention from REL-03's success-criteria text; the README "External Resources" section's TileBitTools design-inspiration footnote (already shipping per DOC-05) is the only attribution work in v0.2.0.

- **SC-C:** `PROJECT.md` Constraints + `ROADMAP.md` Phase 5 SC-7 use "visibly smaller and simpler than TileMapDual" / "total surface area stays under TileMapDual's equivalent." Per D-05-11, this is reframed: identity is hot-path minimalism + anti-pattern absence, not raw LOC delta. Plans propose wording updates so the spec matches the audit framing the user locked.

- **SC-D:** `REL-01` says "`plugin.cfg` `version` field bumped from `0.1.0` to `0.2.0`." Per D-05-15..17 this becomes "`plugin.cfg` `version` field bumped by the release workflow per the auto-increment rule (D-05-16)." REL-01 ownership flips from "manual commit task" to "workflow side-effect."

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Goal-Defining Artifacts

- `.planning/PROJECT.md` — vision, identity guardrail (subject to D-05-11/12 reframing in Phase 5 plans), constraints, key decisions table.
- `.planning/REQUIREMENTS.md` — DEMO-01..03, DOC-01..04, REL-01..03 (the 10 v1 requirements Phase 5 closes); v2/v0.3+ deferred list (TBT-01-DEFERRED, TBT-02-DEFERRED, VAR-PIXEL-01, VAR-01, TOP-01, MULTITERR-*) for the disqualification policy and 8-vs-10 reconciliation.
- `.planning/ROADMAP.md` — Phase 5 entry (success criteria 1-7) + 8-actually-shipped-layouts reconciliation (SC-A) + Phase 5 SC-7 reframing (SC-C).
- `CLAUDE.md` — Identity Guardrails, Breaking Changes Policy (HARD RULE — both directions), Coined-Term Discipline, Critical Pitfalls (#1-10), Test Methodology lessons, Quality Bar ("Works in my game"), no-Asset-Library / no-MkDocs distribution constraints.
- `.planning/STATE.md` — Phase 4 closeout summary; cumulative runtime LOC = 2884; identity guardrail AT RISK carry-forward to Phase 5 final audit.

### Prior Phase Decisions (carry forward, do not re-ask)

- `.planning/phases/04-fallback-routing/04-CONTEXT.md` — D-04-08 (LOC + identity audit deferred to Phase 5 — confirmed; D-05-08..14 are the resolution); D-04-13 / D-04-14 severity-tiered fix policy + disqualification list (informs how reviewer-style findings get handled in any cross-AI review during Phase 5).
- `.planning/phases/03-tilebittools-sourced-layouts/03-CONTEXT.md` (and its descendants) — D-72 / D-73 (no `ATTRIBUTION.md`), D-86 (b) (Tilesetter deferred to v0.3+) — both are the source of SC-A and SC-B spec corrections.
- `.planning/phases/03.5-pixellab-layouts-variation-seed-wiring/03.5-CONTEXT.md` — D-91 (VAR-PIXEL-01 deferred to v2) — informs how PixelLab variation is described in the README "Layouts" table.

### Demo / Code Anchors

- `addons/penta_tile/demo/penta_tile_demo.tscn` — current single-layer demo (FOUR-mode horizontal Penta + authored ground.tres + CharacterBody2D player) — the file Phase 5 refreshes per D-05-01..05.
- `addons/penta_tile/demo/demo_runtime_painter.gd` — drag-paint script (preserved, updated for grid).
- `addons/penta_tile/demo/penta_layout_*.tres` — Penta layout demo resources; **must keep existing** — `_capture_baseline.gd` references them via `--layout-path` (D-05-04).
- `addons/penta_tile/demo/penta_tile_ground.{png,tres}` + `_regen_demo_ground.py` + `demo_player.gd` + `demo_player.gd.uid` — retired from the demo per D-05-02 / D-05-03 (planner picks delete vs archive).
- `addons/penta_tile/layouts/penta_tile_layout.gd:140-165` — `get_fallback_tile_set()` codegen — confirms ZERO physics layers, the constraint that drove D-05-03.
- `addons/penta_tile/plugin.cfg` — currently `version="0.1.0"`. Workflow bumps it per D-05-15..17.
- `tests/run_tests.ps1` (+ underlying `--script` / `--headless` invocations) — the existing test harness; CI workflow re-uses (D-05-14, D-05-17 step 2).

### Documentation Anchors

- `README.md` — already has 90% of the documentation surface (brand, "What is a Penta tileset?", Supported Layouts bullet list, PentaTile-vs-TileMapDual table, Addon Layout, Current API, Demo, Implementation Notes, Roadmap, External Resources, Attributions). Phase 5 ADDS: "Layouts" table (DOC-01 enrichment), "Upgrading from 0.1.x" (DOC-02 greenfield), "Authoring a Custom Layout" (DOC-03 greenfield), "Identity & Footprint" (D-05-10 audit summary). UPDATES: "Demo" section to match the new spatial-grid scene; "Roadmap" to reflect v0.2.0 ship + v0.3+ backlog.
- `CHANGELOG.md` — already has `[Unreleased] — v0.2 in progress` accumulating Phase 1.1 + Phase 2 breaking changes. Phase 5 EXTENDS with Phase 3, 3.5, 4, 5 deltas, then the workflow rewrites the header to `[<new-version>] — <date>` per D-05-17 step 4.

### Godot Doc Comment Format (already adopted in Phase 4)

- [Godot 4.x GDScript Documentation Comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) — `@experimental` flag on `PentaTileLayout` flows naturally into DOC-03 ("Authoring a Custom Layout — experimental").

### Identity Comparison Target

- TileMapDual GitHub repo (`https://github.com/pablogila/TileMapDual`) — pinned tag (planner picks the latest stable at audit time) used for D-05-09 comparison.
- `.planning/research/layouts/MASK_UNIFICATION.md`, `.planning/research/PITFALLS.md` — internal anti-pattern register the audit checks against (D-05-11).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`run_tests.ps1`** — registers 18 tests; PowerShell-specific. CI workflow needs a Linux equivalent (bash invocation of `godot --headless --script tests/<name>.gd` per test). Plan-phase decides whether to add `run_tests.sh` or inline the loop into the workflow YAML.
- **`_capture_baseline.gd` + determinism baseline machinery** — already headless-compatible; CI can re-run the baseline check unchanged.
- **`get_fallback_tile_set()` codegen** ([layouts/penta_tile_layout.gd:140-165](../../../addons/penta_tile/layouts/penta_tile_layout.gd#L140-L165)) — already exercised by all 8 layouts in `fallback_routing_test.gd` (Phase 4). The new demo's 8 instances rely on this surface end-to-end at scene-load time.
- **CHANGELOG `[Unreleased]` section** — already accumulating breaking changes through Phase 1.1, 2, 3, 3.5, 4. Phase 5 docs work is "extend through 5" not "write from scratch."
- **README structure** — already at v0.2-shape (Penta diagram, Supported Layouts list, comparison table). DOC-01..03 are insertions/extensions, not rewrites.

### Established Patterns

- **Phase artifact pattern** — every phase ships SUMMARY.md per plan + closing artifacts (e.g., 04-DOC-SWEEP.md, 04-FALLBACK-UAT.md). Phase 5 will ship: 05-LOC-AUDIT.md (the audit working artifact per D-05-08..11), 05-RELEASE-RUNBOOK.md (the workflow's contract — what it does, how to debug a failed run), one SUMMARY.md per plan.
- **Atomic-commit pattern** — Phase 2/3/3.5/4 used atomic-commit-per-plan (closeout commits roll up). Phase 5 release commit is `chore(release): v<X.Y.Z>` per D-05-17 step 5; that's the workflow bot's commit, not a human commit.
- **No formal test suite (GUT)** — quality bar is "works in my game"; the 18 in-tree tests are baseline. Phase 5 adds zero tests (CI-runs-tests is reuse, not new tests).

### Integration Points

- **`.github/workflows/release.yml`** — NEW file; the entire release machinery lives here. Plan-phase writes it. Pre-existing `.github/` directory check: none currently in the repo (it's a private-audience addon). Plan-phase creates the directory + workflow YAML.
- **`gh` CLI in CI runner** — pre-installed on `ubuntu-latest` runners; no install step needed. Authentication via `secrets.GITHUB_TOKEN`.
- **Godot in CI runner** — needs explicit setup. Plan-phase chooses between (a) `barichello/godot-ci` Docker image, (b) direct download of Godot 4.6.x stable Linux headless binary, (c) GitHub Action for Godot setup. Each has tradeoffs.
- **Demo-loads-cleanly headless check** — `godot --import --headless --quit` followed by `godot --headless --quit res://addons/penta_tile/demo/penta_tile_demo.tscn` (or equivalent). Plan-phase verifies the exact invocation that produces a non-zero exit on scene-open errors.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly framed the release flow as "one button = ship." This is a strong constraint — every step must be inside the workflow. The user's hard rule: "if it cannot be automatic, remove it" (rather than fall back to manual instructions). This is the lens for every Phase 5 plan-phase trade-off involving "should the user do X manually?"
- The identity audit's reframe (LOC is signal not goal; perf and optimization are the real metrics) is a meaningful spec evolution. The audit deliverable's headline is no longer "PentaTile has X fewer LOC than TileMapDual" — it's "PentaTile's hot path is _ steps deep, has zero anti-patterns from the register, and (if applicable) extracts identified by the audit have been applied."
- The demo refresh embraces the breaking-changes policy fully — `demo_player.gd`, `penta_tile_ground.{png,tres}`, and `_regen_demo_ground.py` are RETIRED rather than preserved for compat. The file deletion is documented in CHANGELOG as part of the v0.2.0 breaking-change log.
- The 8-vs-10 layout-count reconciliation is across REQUIREMENTS.md (DEMO-01, DOC-01) AND ROADMAP.md Phase 5 description AND any README copy that still says "10 layouts." Plan-phase audits all three before drafting the README "Layouts" section.

</specifics>

<deferred>
## Deferred Ideas

- **Documentation surface + tone** (gray area not selected for discussion) — falls to Claude's discretion in plan-phase. Default approach: extend README in the existing style (concise rows, link-rich, BBCode-friendly), match the established CHANGELOG format ([Keep a Changelog] + [Semantic Versioning]), and keep DOC-03 ("Authoring a Custom Layout") at API-tour depth with one minimal subclass example marked `@experimental` per Phase 4 doc-comment sweep.
- **Build script (`build_release.sh` / `.ps1`) at repo root** — superseded by the GitHub Actions workflow per D-05-15..17. Not adding a sibling script; the workflow is the single source of truth.
- **Patch-version releases (v0.2.1 etc.)** — D-05-16 explicitly does NOT support patch bumps. If ever needed, bypass the workflow and hand-roll. Adding patch-bump complexity speculatively violates the no-forward-compat rule (CLAUDE.md HARD RULE).
- **GitHub Actions input field for explicit version override** — superseded by D-05-16 auto-increment rule; user does not pick the version. If a future need arises (e.g., to skip a number), bypass the workflow.
- **Per-layout sub-scene demos** (option B of demo strategy Q1, alternative C of "Side-by-side + click-to-swap") — superseded by D-05-01 single-scene spatial grid.
- **Runtime layout-switching dropdown UI** (option A of demo strategy Q1) — same; superseded by D-05-01.
- **Penta block uses authored ground.tres for player physics** (option A of "Penta floor" Q5) — superseded by D-05-03 (no player).
- **Scene-level invisible StaticBody2D floor** (option B of "Penta floor" Q5) — superseded by D-05-03.
- **`AUDIT.md` / `IDENTITY.md` standalone file** — superseded by D-05-10 (README + release notes; standalone file is overkill for private-audience addon).
- **Manual eyeball pass on 8 layouts in CI** — explicitly DROPPED per the user's "remove anything not automatic" rule. Cannot be automated; therefore not a release gate. The audit + the side-by-side demo's automated headless-load check + the 18-test suite are the verification surface.
- **LOC audit existence check in CI** — DROPPED per D-05-13. LOC is not a quality measure; CI cannot meaningfully gate on it. The audit is a developer-judgment prerequisite that lives outside CI.
- **Hand-written release notes intro / highlight reel** — superseded by D-05-18 (CHANGELOG slice paste verbatim).

</deferred>

---

*Phase: 05-demo-refresh-documentation-release*
*Context gathered: 2026-04-29*
