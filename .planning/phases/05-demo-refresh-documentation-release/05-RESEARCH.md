# Phase 5: Demo Refresh + Documentation + Release - Research

**Researched:** 2026-04-29
**Domain:** GitHub Actions release automation + Godot 4.6 headless CI + scene refresh + README/CHANGELOG documentation + manual identity audit (no new runtime code)
**Confidence:** HIGH overall (Standard Stack HIGH, Architecture HIGH, Pitfalls HIGH; LOW only for one TileMapDual-comparison detail addressed via fallback)

## Summary

Phase 5 is the v0.2.0 ship gate. There are NO new runtime GDScript modules — the work is (1) a `penta_tile_demo.tscn` scene refresh into a side-by-side spatial-grid showcase of the 8 actually-shipped layouts, (2) README extension with four new sections plus DOC-04 CHANGELOG accumulation, (3) a single `workflow_dispatch`-triggered GitHub Actions release pipeline that auto-increments the version, runs CI checks (import + 18-test suite + headless demo open), commits, tags, builds the zip via `git archive`, and publishes the GitHub Release via `softprops/action-gh-release@v3`, plus (4) a manual three-axis identity audit (LOC + public surface + hot-path complexity) that lives in a working `05-LOC-AUDIT.md` and a README "Identity & Footprint" summary. The audit is a developer-judgment prerequisite to release, NOT a CI gate (D-05-13).

The single largest research finding: **TileMapDual now has 10 tags, latest stable v5.0.2 (2026-01-03)**, which is the pinned reference for D-05-09. The earlier assumption that there might be no released tag is moot — v5.0.2 is the audit target and its commit hash should be recorded in `05-LOC-AUDIT.md`.

Three CI pitfalls are load-bearing for the release workflow design: (a) `godot --import --headless --quit` sometimes returns non-zero on success and zero on failure (must use `--quit-after 2` and parse stderr for `ERROR:` lines), (b) `git push origin main --tags` from inside a workflow that committed during the same run requires `permissions: contents: write` AT THE JOB LEVEL plus the default `actions/checkout@v6` `persist-credentials: true` (default) — but commits to `main` from a workflow that was triggered from `main` need a clean push from HEAD, not an explicit ref, (c) auto-version-increment regex must handle `version="0.1.0"` (quoted in plugin.cfg, which is the actual format here).

**Primary recommendation:** Plan Phase 5 as four parallel-ish work threads — (1) demo refresh + retire `demo_player.gd`/`penta_tile_ground.{png,tres}`/`_regen_demo_ground.py`, (2) README extensions + CHANGELOG accumulation, (3) `.github/workflows/release.yml` + sibling `addons/penta_tile/tests/run_tests.sh` Linux test runner, (4) manual identity audit producing `05-LOC-AUDIT.md` and the README "Identity & Footprint" anchor — then a closeout plan that runs the workflow once, verifies the published v0.2.0 release, flips ROADMAP / STATE / REQUIREMENTS Traceability.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Side-by-side spatial demo grid | Godot Scene (`.tscn`) | Demo runtime painter (GDScript) | Pure scene-tree composition; runtime painter unchanged in shape |
| Hover-to-target drag-paint | Demo runtime painter (GDScript) | — | Existing painter resolves target via NodePath; new logic resolves target via cursor-cell intersection — single GDScript file |
| 8 layout instances binding to bundled fallback | Layout Resources (`.tres`) + `PentaTileLayout.get_fallback_tile_set()` | Scene `[ext_resource]` references | Reuses existing Phase 4 fallback contract; no new runtime code |
| Documentation extensions | README.md + CHANGELOG.md (markdown) | — | Pure docs; no code generation |
| Release workflow | GitHub Actions YAML (`.github/workflows/release.yml`) | bash inside workflow steps + `addons/penta_tile/tests/run_tests.sh` (NEW) | CI tier owns version bump, commit, tag, push, archive, release publish |
| Test runner on Linux | bash sibling to `run_tests.ps1` | Godot 4.6 binary on Ubuntu runner | Existing PowerShell runner is Windows-only; CI needs a Linux equivalent that loops over `*.gd` test files identically |
| Identity audit (LOC + surface + hot-path) | Phase artifact (`05-LOC-AUDIT.md`) + README anchor | Manual git/grep work, NOT CI | Per D-05-13 — explicitly NOT a CI gate; lives outside the workflow |
| Headless demo-loads-cleanly check | CI step inside workflow | Godot 4.6 Linux binary + parsed stderr | Verifies the new spatial-grid scene loads with no `ERROR:` lines via stderr grep (because Godot exit codes are unreliable — Pitfall #1) |
| CHANGELOG slice extraction | bash inside workflow (`awk` between `## [` headings) | — | Mechanical; no LLM in CI |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.6.2-stable Linux x86_64 | Headless CI test/import/scene-open runner | The exact version in CLAUDE.md; matches the local Windows install; published Apr 2025 [VERIFIED: github.com/godotengine/godot/releases/tag/4.6.2-stable] |
| `actions/checkout` | v6 (latest) | Repo checkout in workflow; default `persist-credentials: true` enables push-back via `GITHUB_TOKEN` | Recommended GitHub-official action; v6 examples from Context7 [VERIFIED: Context7 /actions/checkout 2026-04-29] |
| `softprops/action-gh-release` | v3.0.0 (released 2026-04-12) | GitHub Release publish with `tag_name`, `body_path`, `files` inputs | Most-used release action; v3 requires Node 24 runtime which `ubuntu-latest` provides [VERIFIED: Context7 /softprops/action-gh-release; benchmark score 93.25] |
| `gh` CLI | pre-installed on `ubuntu-latest` | Optional alternative to `softprops/action-gh-release` | Available without install step; auth via `GH_TOKEN=${{ secrets.GITHUB_TOKEN }}` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `git archive` | bundled with git on runner | Build `penta_tile-v0.2.0.zip` with `addons/penta_tile/` prefix | D-05-17 step 8 — `git archive --format=zip --prefix=penta_tile-v0.2.0/ -o penta_tile-v0.2.0.zip v0.2.0 -- addons/penta_tile/` |
| `awk` | bundled on runner | Extract CHANGELOG `[<new-version>]` slice between `## [` headings | D-05-17 step 9 — single one-liner; no python/node needed |
| `sed` | bundled on runner | In-place version bump in `plugin.cfg` and `## [<version>] — <date>` rewrite in CHANGELOG.md | Robust to `version="0.1.0"` quoted form actually present in the file |
| `grep` | bundled on runner | Parse Godot stderr for `ERROR:` / `SCRIPT ERROR:` lines as the real failure detector | Mitigation for Pitfall #1 (Godot CLI exit codes unreliable) |

**Installation (CI step, NOT package-managed):**

```bash
# Inside .github/workflows/release.yml — explicit Godot download
GODOT_VERSION="4.6.2-stable"
wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O godot.zip
unzip -q godot.zip
mv "Godot_v${GODOT_VERSION}_linux.x86_64" godot
chmod +x godot
```

[CITED: github.com/godotengine/godot/releases/tag/4.6.2-stable]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct Godot binary download | `barichello/godot-ci:4.6.2` Docker container | Container adds layer of indirection + tagged at v4.3 in upstream sample workflow; direct download is 2 lines and pins version explicitly. Recommend direct download. [CITED: github.com/aBARICHELLO/godot-ci] |
| `softprops/action-gh-release@v3` | `gh release create v0.2.0 file.zip --title "..." --notes-file body.md` (CLI) | CLI is one fewer dependency but provides less ergonomic input (env var auth, no glob support). Recommend the action — it's first-class for body_path + files. Both work. |
| `git archive` for the zip | `zip -r penta_tile-v0.2.0.zip addons/penta_tile/` | `git archive` excludes untracked/ignored files automatically (matches what's IN the tag); plain `zip` would include local artifacts. Recommend `git archive`. |
| Auto-increment regex in bash | `npm version` / `tbump` / dedicated action | None of those parse Godot's `plugin.cfg` format. Inline awk/sed is simplest and pins the format. |
| Single-line `awk` for CHANGELOG slice | `markdown-extract` / `submark` CLI | Need to install the tool first. Inline `awk` is zero-dep. |

**Version verification (run before commit):**

```bash
# Verify GitHub action versions are current
# As of research date 2026-04-29:
#   actions/checkout      v6 (Context7 examples use v6; v4 is also widely deployed)
#   softprops/action-gh-release v3.0.0 (released 2026-04-12)
#   barichello/godot-ci   v4.3 latest published (NOT current at 4.6.2)
```

[VERIFIED: Context7 /actions/checkout, Context7 /softprops/action-gh-release, github.com/aBARICHELLO/godot-ci]

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│  Phase 5 Workflow                                                    │
└──────────────────────────────────────────────────────────────────────┘

  Plan A: Demo refresh
     ┌──────────────────────────────────────────────┐
     │ penta_tile_demo.tscn (NEW, 8-instance grid)  │
     │   ├─ Camera2D (fit-all OR pan)                │
     │   ├─ DemoRuntimePainter (Node2D)              │
     │   ├─ Layout 1: Penta FOUR + Label "Penta"     │
     │   ├─ Layout 2: DualGrid16   + Label           │
     │   ├─ Layout 3: Wang2Edge    + Label           │
     │   ├─ Layout 4: Wang2Corner  + Label           │
     │   ├─ Layout 5: Min3x3       + Label           │
     │   ├─ Layout 6: Blob47Godot  + Label           │
     │   ├─ Layout 7: PixelLabTopDown + Label        │
     │   └─ Layout 8: PixelLabSide + Label           │
     │ All 8: tile_set = null, layout = <bundled>    │
     └──────────────────────────────────────────────┘
     Retire: demo_player.gd, penta_tile_ground.{png,tres},
             _regen_demo_ground.py, demo_player.gd.uid

  Plan B: Documentation
     ┌──────────────────────────────────────────────┐
     │ README.md                                    │
     │   + § Layouts (table, 8 rows)                │
     │   + § Upgrading from 0.1.x                   │
     │   + § Authoring a Custom Layout (experimental)│
     │   + § Identity & Footprint (audit summary)   │
     │   ~ Demo section (rewrite)                   │
     │   ~ Roadmap (v0.2 → v0.3+ shape)             │
     ├──────────────────────────────────────────────┤
     │ CHANGELOG.md                                 │
     │   ~ [Unreleased] += Phase 3, 3.5, 4, 5       │
     │   (workflow rewrites header in Plan D)       │
     └──────────────────────────────────────────────┘

  Plan C: Identity audit (manual, prerequisite to D)
     ┌──────────────────────────────────────────────┐
     │ Clone TileMapDual @ v5.0.2 → /tmp/tmd        │
     │ Measure 3 axes:                              │
     │   1. LOC  (git ls-files | xargs wc -l)       │
     │   2. Public surface (grep @export, public fn,│
     │      class_name)                              │
     │   3. Hot-path depth (manual call-graph trace)│
     │ Anti-pattern register check (PITFALLS+CLAUDE)│
     │ Output: 05-LOC-AUDIT.md (working artifact)   │
     │ Output: README § Identity & Footprint summary│
     └──────────────────────────────────────────────┘

  Plan D: Release workflow (.github/workflows/release.yml)
     workflow_dispatch  ──►  Run on push to main, no inputs
       │
       ▼
     ┌──────────────────────────────────────────────┐
     │ Step 1: Checkout main (persist-credentials)  │
     │ Step 2: Read plugin.cfg version → compute    │
     │         next per D-05-16 minor+1, rolls major│
     │ Step 3: Download Godot 4.6.2-stable Linux    │
     │ Step 4: godot --headless --import            │
     │         --quit-after 2 + stderr ERROR check  │
     │ Step 5: Run 18 tests via run_tests.sh        │
     │ Step 6: Headless-open demo (stderr ERROR chk)│
     │ Step 7: Bump plugin.cfg + rewrite CHANGELOG  │
     │         header to ## [<v>] — <date>          │
     │ Step 8: Commit + tag + push origin main+tag  │
     │ Step 9: git archive → penta_tile-v<v>.zip   │
     │ Step 10: awk-extract CHANGELOG slice →       │
     │          release-notes-body.md               │
     │ Step 11: softprops/action-gh-release@v3     │
     │          (tag_name, body_path, files)        │
     └──────────────────────────────────────────────┘

  Plan E: Closeout
     - Verify v0.2.0 release exists on GitHub
     - Flip ROADMAP Phase 5 [x]
     - Mark DEMO/DOC/REL traceability Complete
     - STATE.md milestone: v0.2.0 SHIPPED
```

### Recommended Project Structure

```
.github/                                                  # NEW directory (none exists currently)
└── workflows/
    └── release.yml                                       # NEW — single manually-triggered workflow per D-05-15

addons/penta_tile/
├── plugin.cfg                                            # MODIFIED — version="0.1.0" → workflow bumps to 0.2.0
├── demo/
│   ├── penta_tile_demo.tscn                              # MODIFIED — spatial grid of 8
│   ├── demo_runtime_painter.gd                           # MODIFIED — hover-target detection (D-05-05)
│   ├── demo_runtime_painter.gd.uid                       # KEEP
│   ├── penta_layout_*.tres                               # KEEP (still referenced by _capture_baseline.gd via --layout-path)
│   ├── demo_player.gd                                    # DELETE (D-05-03)
│   ├── demo_player.gd.uid                                # DELETE (D-05-03)
│   ├── penta_tile_ground.png                             # DELETE (D-05-02)
│   ├── penta_tile_ground.png.import                      # DELETE (D-05-02)
│   ├── penta_tile_ground.tres                            # DELETE (D-05-02)
│   ├── _regen_demo_ground.py                             # DELETE (D-05-02 — supports the deleted ground.tres)
│   ├── penta_tile_dual_grid_16.tres                      # DECIDE: needed if demo binds via this resource? Currently UNUSED in demo.tscn — DELETE
│   ├── penta_tile_minimal_3x3.tres                       # Same — currently UNUSED — DELETE
│   ├── penta_tile_wang_2_corner.tres                     # Same — DELETE
│   └── penta_tile_wang_2_edge.tres                       # Same — DELETE
└── tests/
    ├── run_tests.ps1                                     # KEEP (Windows local dev runner)
    └── run_tests.sh                                      # NEW — Linux/CI mirror of run_tests.ps1

CHANGELOG.md                                              # MODIFIED — accumulate Phase 3..5 deltas; workflow rewrites header
README.md                                                 # MODIFIED — 4 new sections + 2 rewrites
```

### Pattern 1: workflow_dispatch with no inputs

**What:** GitHub Actions workflow triggered manually via "Run workflow" UI button, no parameters.

**When to use:** D-05-15 — the entire release flow is one button click.

**Example:**

```yaml
# Source: Context7 /actions/checkout (v6 syntax)
# Source: Context7 /softprops/action-gh-release v3 (release notes from file pattern)
name: Release

on:
  workflow_dispatch:           # No inputs per D-05-16

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write          # Required to push commit + tag, and create release
    steps:
      - uses: actions/checkout@v6
        # persist-credentials defaults to true; enables git push via GITHUB_TOKEN
      # ... (steps inline below)
```

[VERIFIED: Context7 /actions/checkout 2026-04-29; /softprops/action-gh-release 2026-04-29]

### Pattern 2: Auto-version-increment from plugin.cfg

**What:** Read current `version="X.Y.Z"` in `addons/penta_tile/plugin.cfg`, compute next per D-05-16 (minor +1; if minor>9 then major+1, minor=0, patch=0).

**Example:**

```bash
# Source: original to this codebase (no Context7/web pattern matches Godot's quoted plugin.cfg format)
PLUGIN_CFG="addons/penta_tile/plugin.cfg"

# Extract current version. Robust to optional quotes, optional whitespace.
CURRENT=$(grep -E '^version\s*=' "$PLUGIN_CFG" | sed -E 's/^version\s*=\s*"?([^"]+)"?$/\1/')

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

if [ "$MINOR" -ge 9 ]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
else
  MINOR=$((MINOR + 1))
fi
PATCH=0   # Per D-05-16: patches not supported by this scheme

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Bumping ${CURRENT} → ${NEW_VERSION}"
echo "NEW_VERSION=${NEW_VERSION}" >> "$GITHUB_ENV"

# Robust write back, preserving the existing quoted format.
sed -i -E "s/^version\s*=.*$/version=\"${NEW_VERSION}\"/" "$PLUGIN_CFG"
```

[ASSUMED for the regex precision — confirmed against the actual file content `version="0.1.0"` at addons/penta_tile/plugin.cfg:5]

### Pattern 3: Godot headless project import with reliable failure detection

**What:** Run `godot --import --headless` and detect import errors despite Godot's exit-code unreliability (Pitfall #1).

**Example:**

```bash
# Source: combination of github.com/godotengine/godot/issues/77508 (--quit-after 2 workaround)
# and github.com/godotengine/godot/issues/85062 (parse stderr because exit codes are unreliable)
set -e

# Run import. --quit-after 2 (NOT --quit) per issue #77508 — gives the engine
# enough frames to actually import resources.
./godot --headless --path . --import --quit-after 2 2> import_stderr.log || true

# Real failure detector: stderr contains "ERROR:" or "SCRIPT ERROR:" lines.
if grep -qE '^(ERROR|SCRIPT ERROR):' import_stderr.log; then
  echo "::error::Godot import produced errors:"
  cat import_stderr.log
  exit 1
fi

echo "Import clean."
```

[CITED: github.com/godotengine/godot/issues/77508 (--quit-after 2); github.com/godotengine/godot/issues/85062 (exit codes unreliable); github.com/godotengine/godot/issues/83042 (export 0-on-error)]

### Pattern 4: CHANGELOG slice extraction (mechanical, awk-only)

**What:** Extract the just-rewritten `## [<new-version>] — <date>` block up to (but not including) the next `## [` heading.

**Example:**

```bash
# Source: AWK pattern from
#   gist.github.com/Integralist/57accaf446cf3e7974cd01d57158532c (changelog extraction)
#   adapted for our exact heading shape "## [<v>] — <date>"
awk -v ver="$NEW_VERSION" '
  /^## \[/ {
    if (in_section) { exit }
    if (index($0, "[" ver "]") > 0) { in_section = 1; print; next }
  }
  in_section { print }
' CHANGELOG.md > release-notes-body.md

# Trim trailing blank lines.
sed -i -e :a -e '/^\s*$/{$d;N;ba' -e '}' release-notes-body.md

# Sanity: file must be non-empty.
test -s release-notes-body.md || { echo "::error::release-notes-body.md is empty"; exit 1; }
```

[CITED: gist.github.com/Integralist/57accaf446cf3e7974cd01d57158532c]

### Pattern 5: Side-by-side spatial demo grid in `.tscn`

**What:** Eight `PentaTileMapLayer` instances arranged in a 2×4 or 4×2 grid with sibling `Label` nodes; one shared Camera2D; existing painter resolves cursor → instance under cursor.

**Plan-phase decision points:**
- **Grid shape:** Recommend 2 rows × 4 columns (16:9-friendly aspect). Each instance reserves a ~16-cell × 12-cell paintable area (512 × 384 px at 32px tiles), with 2-cell gutters (64 px) and a `Label` above each instance. Total scene world bounds: ~2256 × 928 px. Camera `position = Vector2(1128, 464)` and `zoom = Vector2(0.4, 0.4)` to fit.
- **Camera approach:** Recommend Camera2D **fit-all-fixed**. The PanCamera2D pattern is overkill for a showcase scene; user wants every layout visible without panning.
- **Hover-detect vs. click-to-arm:** Recommend **hover-detect** — the existing `_apply_at_event_position` already converts cursor to canvas position; extend it to iterate child instances and pick the one whose `local_to_map(to_local(canvas_pos))` falls inside its painted bounds (or, simpler, whose Rect2 footprint contains the cursor).
- **Instance naming:** Use the layout class as the suffix — `Layout_Penta`, `Layout_DualGrid16`, ... so `find_child("PentaTileMapLayer", true, false)` in `_capture_baseline.gd` no longer matches anything (forcing the script to be updated to look for `Layout_Penta` specifically — see Pitfall #6 below).

### Pattern 6: Existing `get_fallback_tile_set()` codegen — already wired

The codegen lives at [`addons/penta_tile/layouts/penta_tile_layout.gd:140-165`](../../../addons/penta_tile/layouts/penta_tile_layout.gd#L140-L165) (verified by direct read). It builds a fresh `TileSet` from `bitmask_template` with grid size from `_fallback_atlas_grid_size()`. Each of the 8 actually-shipped layouts overrides `_fallback_atlas_grid_size()` (verified in Phase 4 by `fallback_routing_test.gd`). The generated `TileSet` has **zero `physics_layers`** (verified line 157: `var ts := TileSet.new()` with no physics setup) — this is the exact constraint that drove D-05-03 (no player).

### Anti-Patterns to Avoid

- **Don't add a build script to repo root** (`build_release.sh`, `Makefile`, `npm scripts`). The workflow IS the build script — sole source of truth per D-05-15. Anything that duplicates workflow logic locally invites drift.
- **Don't add `workflow_dispatch.inputs` for explicit version override.** D-05-16 explicitly forbids this. If a future hand-rolled patch release is needed, bypass the workflow.
- **Don't try to parse Godot exit codes alone.** Godot 4.6 exit codes for `--headless` are unreliable in BOTH directions (issues #83042, #85062, #83449). The CI must check stderr for `ERROR:` lines as the source of truth.
- **Don't add `ATTRIBUTION.md`** — explicitly banned per D-72/D-73. SC-B is the spec correction.
- **Don't reference `find_child("PentaTileMapLayer", ...)` after the demo refresh.** `_capture_baseline.gd` does this. Either rename one demo instance to `PentaTileMapLayer` (most boring) OR update the script to take a `--node-path=` flag (cleaner). Plan-phase decides.
- **Don't try to ship two-pass cross-AI review here.** Phase 4 already did Gemini-only (Codex deferred); Phase 5 is documentation+release. Cross-AI doesn't fit the scope.
- **Don't compute LOC by `find . -name "*.gd"`** — use the existing recipe `git ls-files 'addons/penta_tile/*.gd' 'addons/penta_tile/layouts/*.gd' | grep -v 'tests/' | grep -v 'demo/' | xargs wc -l`. Methodology continuity with Phase 2/3/3.5/4 audits matters.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto-bump semver in plugin.cfg | Custom bash regex from scratch | The verified bash one-liner in Pattern 2 above (sed -E preserving quotes) | Quoted vs unquoted format, missing whitespace, missing patch=0 reset are common bugs |
| GitHub Release publishing | `curl https://api.github.com/repos/.../releases` | `softprops/action-gh-release@v3` | Asset upload, body_path, retry logic, error reporting all batteries-included [VERIFIED: Context7 benchmark 93.25] |
| Zip building | Manual `find / xargs zip` | `git archive --format=zip --prefix=...` | Auto-excludes untracked/ignored; matches what's in the tag exactly; output is reproducible |
| CHANGELOG slice extract | Hand-rolled while-loop in bash | `awk` Pattern 4 above | Edge case "first heading after `# Changelog`" + "last heading in file" both handled by the in_section flag |
| Godot CI test loop | Inline `for f in tests/*.gd` in YAML | `addons/penta_tile/tests/run_tests.sh` sibling to `run_tests.ps1` | Maintainability — local dev can run `bash run_tests.sh` for a Linux-style check; CI invokes the same script; single source of truth for the 18-test inventory |
| Godot Linux CI runtime | `barichello/godot-ci` Docker container | Direct binary download from github.com/godotengine/godot/releases | Pins exact 4.6.2 vs container's 4.3 default; one fewer abstraction layer |

**Key insight:** This is a release/automation phase, not a runtime phase. Most "don't hand-roll" wins come from using the official GitHub Actions ecosystem (`actions/checkout@v6`, `softprops/action-gh-release@v3`, `gh` CLI) and the engine's primary distribution channel (direct download from godotengine/godot releases) — not from inventing CI machinery.

## Runtime State Inventory

> Phase 5 deletes files from the repo (`demo_player.gd`, `penta_tile_ground.{png,tres}`, `_regen_demo_ground.py`) and refreshes `penta_tile_demo.tscn`. This is a **partial refactor**, so the runtime-state-inventory check applies. Note: this phase does NOT do a string rename; it does file deletions + scene structure change.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Godot project has no databases. The only "stored state" is the `.godot/` cache (gitignored, regenerable per project) and `.uid` sidecars (regenerated by Godot import). | None — `.godot/` is excluded from `git archive` automatically (gitignored); `.uid` sidecars track currently-existing scripts/resources only. |
| Live service config | None — no n8n, no Datadog, no external services. The single GitHub Actions workflow is in-tree and version-controlled. | None. |
| OS-registered state | None — no Windows scheduled tasks, no systemd units, no pm2 processes. | None. |
| Secrets / env vars | `secrets.GITHUB_TOKEN` (auto-provided by GitHub Actions). No SOPS, no `.env`. | None — token is implicit. |
| Build artifacts | (a) `.godot/` editor cache — gitignored, regenerated on `--import`. (b) `.uid` files for `demo_player.gd` (DELETED) — must delete `demo_player.gd.uid` atomically with `demo_player.gd`. (c) Any cached imports in `addons/penta_tile/demo/` for `penta_tile_ground.png.import` — must delete with the parent file. (d) Existing `penta_tile_demo.tscn`'s saved `[ext_resource]` references to deleted scripts will produce errors on next load — the rewrite of the scene file IS the fix. | (1) Delete `demo_player.gd.uid` with `demo_player.gd`. (2) Delete `penta_tile_ground.png.import` with the PNG. (3) Verify the new `.tscn` does NOT reference any deleted file via `[ext_resource]` (greppable). (4) Re-import the project locally + in CI to verify no warnings. |
| Saved scene `[ext_resource]` references | Current `penta_tile_demo.tscn` references `demo_player.gd` (id 3_ojcmv), `penta_tile_ground.tres` (id 7_2ilat), `brand/penta_tile_icon.png` (id 6_ywdfk), `five_horizontal.png` (4_0ou8x), `penta_tile_layout_blob_47_godot.png` (8_qyqi1), `penta_tile_layout_blob_47_godot.gd` (9_2ilat). | The new `.tscn` rewrite drops all six demo-specific references; introduces 8 new ones (one per layout instance) plus 8 fallback bitmask PNGs from `addons/penta_tile/layouts/`. |

**The canonical question:** *After every file in the repo is updated, what runtime systems still have the old state cached?*

Answer: only the project's `.godot/` directory + `.uid` sidecars on the next Godot run. Both are auto-rebuilt from the file system. Before pushing the workflow commit, the developer should locally `--import` once to regenerate, observe no warnings, then commit. CI also imports cleanly as part of step 4.

## Common Pitfalls

### Pitfall 1: Godot CLI exit codes are unreliable in CI [CRITICAL]

**What goes wrong:** `godot --headless --import --quit` returns exit code 0 even when import fails (issue #83042); returns exit code 1 even on first-time-success import (issue #83449); `--quit` flag races against pending imports (issue #77508).

**Why it happens:** Long-standing Godot bug; no reliable fix in 4.6.x at research time. The export and import paths both have process-lifecycle bugs that confuse the OS exit code.

**How to avoid:**
1. Use `--quit-after 2` instead of `--quit` to give the engine 2 frames to actually finish work.
2. Capture stderr to a log file. Detect failures by grep on `^(ERROR|SCRIPT ERROR):` not by `$?`.
3. Same applies to scene-open in step 6 (D-05-17): `godot --headless --quit-after 2 res://addons/penta_tile/demo/penta_tile_demo.tscn 2> open_stderr.log` then `! grep -qE '^(ERROR|SCRIPT ERROR):' open_stderr.log`.

**Warning signs:** A green CI build that "passes" while local dev shows red error popups. Or a red build that the developer reproduces locally and sees no errors.

[CITED: github.com/godotengine/godot/issues/83042; #85062; #83449; #77508 — all confirmed open as of training cutoff and verified relevant via WebSearch 2026-04-29]

### Pitfall 2: `permissions: contents: write` must be at the JOB level, not workflow level

**What goes wrong:** Setting permissions at workflow level grants write to ALL jobs; principle-of-least-privilege violation; a future second job runs without explicit limit and inherits write.

**How to avoid:** Set `permissions: { contents: write }` ONLY on the release job. Other jobs (none for now, but future addition) get default minimal.

[CITED: docs.github.com/en/actions/writing-workflows ... controlling-permissions-for-github_token]

### Pitfall 3: `actions/checkout@v6` `persist-credentials` is the magic for git push

**What goes wrong:** Without `persist-credentials: true` (the default in v6), the checked-out repo doesn't have `GITHUB_TOKEN` configured for git remote operations; `git push` fails with auth error.

**How to avoid:** Don't override `persist-credentials`. Default value in v6 is `true`; leave it. Configure `git config user.name/email` to `github-actions[bot] / 41898282+github-actions[bot]@users.noreply.github.com` (the official bot identity).

```yaml
- uses: actions/checkout@v6
- run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    # ... bump, commit, tag, push
    git push origin HEAD:main
    git push origin "v${NEW_VERSION}"
```

[VERIFIED: Context7 /actions/checkout 2026-04-29 — "Push commit using built-in token with actions/checkout and git" example]

### Pitfall 4: `git push origin main` from a workflow on `main` can race the workflow trigger

**What goes wrong:** If the workflow is triggered ON push (not workflow_dispatch), pushing to main re-triggers the same workflow — infinite loop. Even with `workflow_dispatch`, if main has new commits between checkout and push, push fails with non-fast-forward.

**How to avoid:**
1. We're using `workflow_dispatch` with no automatic re-trigger — Pitfall does not apply directly.
2. Use `git push origin HEAD:main` (NOT `git push --force`). The `HEAD:main` form uses the local commit and pushes to the remote `main` ref — fails fast if remote has diverged. That's the correct behavior; the developer can then merge and re-run.

### Pitfall 5: `softprops/action-gh-release@v3` requires Node 24, available on `ubuntu-latest`

**What goes wrong:** Older runners or pinned `runs-on:` to ubuntu-20.04 may not have Node 24; the action fails with cryptic "Cannot find module" error.

**How to avoid:** Use `ubuntu-latest` (currently aliased to ubuntu-24.04), which has Node 24 pre-installed. Don't pin `ubuntu-22.04` or older.

[CITED: github.com/softprops/action-gh-release README — "v3.0.0 requires a GitHub Actions runtime that supports Node 24"]

### Pitfall 6: The new demo scene breaks `_capture_baseline.gd` (manual, not CI)

**What goes wrong:** `addons/penta_tile/tests/_capture_baseline.gd:46` does `find_child("PentaTileMapLayer", true, false)`. After the demo refresh, the scene has 8 layer instances with different names — this `find_child` matches the FIRST one in tree-order, which may or may not be the FOUR-mode Penta the script expects.

**Why it doesn't break CI:** `_capture_baseline.gd` is a UTILITY script (manually invoked when re-capturing the determinism baseline), NOT a test in `run_tests.ps1`. The 18-test suite's `determinism_test.gd` is fully self-contained — builds its own layer with the bundled FOUR-mode greybox. Confirmed by reading both files.

**How to avoid:** Plan-phase has two clean options:
- (a) Name the FOUR Penta instance literally `PentaTileMapLayer` in the new demo so `find_child` matches it. Trivial backwards-compat preservation.
- (b) Update `_capture_baseline.gd` to accept an optional `--node-path=Layout_Penta` CLI flag (mirroring the existing `--layout-path=` flag). Cleaner long-term; minor task.

Recommend (a) for minimal surface change; document choice in the plan.

[VERIFIED: read of `_capture_baseline.gd` lines 22-79 + `determinism_test.gd` lines 1-167 + `run_tests.ps1` lines 53-72 — `_capture_baseline.gd` is NOT in the 18-test inventory]

### Pitfall 7: `version="0.1.0"` in plugin.cfg has quotes; sed regex must preserve them

**What goes wrong:** A naive `sed -i "s/0.1.0/0.2.0/" plugin.cfg` mangles other content; a `sed -i "s/version=.*/version=0.2.0/"` strips the quotes, producing `version=0.2.0` (no quotes) which Godot still parses but creates a noisy diff and a `version="..."`/`version=...` flip-flop on subsequent releases.

**How to avoid:** Use the regex in Pattern 2 above with explicit quote re-insertion: `sed -i -E "s/^version\s*=.*$/version=\"${NEW_VERSION}\"/"`.

[VERIFIED: read of `addons/penta_tile/plugin.cfg:5` — actual content is `version="0.1.0"` quoted]

### Pitfall 8: 18-test suite must run on Linux but `run_tests.ps1` is PowerShell-only

**What goes wrong:** No bash equivalent of `run_tests.ps1` exists. CI cannot reuse the local dev runner.

**How to avoid:** Plan-phase creates `addons/penta_tile/tests/run_tests.sh` with the same 18-test inventory. Pattern:

```bash
#!/usr/bin/env bash
# Mirror of run_tests.ps1 for Linux/CI.
set -e
GODOT="${GODOT:-godot}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

TESTS=(
  paint_test all_layouts_test visual_render_test strict_pixel_test
  penta_one_mode_test auto_strip_axis_test layout_swap_test
  all_layouts_swap_pixel_test bitmask_bounds_test comprehensive_bitmask_test
  penta_ground_hollow_test determinism_test blob_47_collapse_test
  blob_47_hollow_test single_grid_8_moore_propagation_test
  pixellab_first_cell_test pixellab_visual_regression_test fallback_routing_test
)

failures=0
for t in "${TESTS[@]}"; do
  echo "=== $t ==="
  "$GODOT" --headless --path "$PROJECT_ROOT" --script "addons/penta_tile/tests/${t}.gd" 2> "/tmp/${t}.stderr"
  rc=$?
  if [ $rc -ne 0 ] || grep -qE '^(ERROR|FAIL)\b|MAIN TEST FAILED' "/tmp/${t}.stderr"; then
    echo "FAIL: $t (rc=$rc)"
    cat "/tmp/${t}.stderr"
    failures=$((failures + 1))
  else
    echo "PASS: $t"
  fi
done

[ $failures -eq 0 ] && echo "ALL GREEN (${#TESTS[@]} tests)" || { echo "$failures FAILED"; exit $failures; }
```

The two test inventories MUST be kept in sync; that's a gardening task but acceptable for "single source of truth" — if drift is a concern, generate both from a `.txt` file. Not necessary at this phase scale.

[VERIFIED: read of `addons/penta_tile/tests/run_tests.ps1` lines 53-72 for 18-test inventory]

### Pitfall 9: TileMapDual identity audit — pinned tag is `v5.0.2` (2026-01-03)

**What goes wrong:** D-05-09 says "pinned tag" but earlier project notes mused that TileMapDual might have no releases. WebFetch confirmed 10 tags; the latest stable is **v5.0.2** dated 2026-01-03 (`fixed #61`).

**How to avoid:** Plan-phase clones at `git clone --depth=1 --branch v5.0.2 https://github.com/pablogila/TileMapDual /tmp/tmd`, runs the LOC recipe, records the commit hash that the tag points to in `05-LOC-AUDIT.md` (so even if the tag is moved, the audit references a specific commit).

[VERIFIED: github.com/pablogila/TileMapDual/tags WebFetch 2026-04-29]

### Pitfall 10: `plugin.cfg` change must propagate to Godot's metadata cache

**What goes wrong:** After bumping `version=0.2.0`, the local `.godot/` cache may still hold 0.1.0 references. CI doesn't have a cache so it's fine; local dev can have a stale `.godot/` causing odd warnings.

**How to avoid:** This is a developer-machine issue, not a workflow issue. CI starts cold every run. If a local re-import is needed, `rm -rf .godot/ && godot --import --quit-after 2`.

### Pitfall 11: `git archive` excludes `.godot/` (gitignored) — desirable but verify

**What goes wrong:** `git archive` includes ONLY tracked files. If `.uid` sidecars are tracked (they are, in this project), they're in the archive — good. If `.godot/` is not (it isn't, per gitignore) — the consumer must `--import` once, which is normal for fresh Godot projects.

**How to avoid:** Document in the GitHub Release notes (mechanically inserted by D-05-18 = CHANGELOG slice paste) the line "Run `godot --import` once after extracting." If the CHANGELOG slice already contains this, fine; if not, add it as a one-liner in the v0.2.0 CHANGELOG entry.

### Pitfall 12: 4 unused Penta layout `.tres` files in `demo/` — cleanup decision

**What goes wrong:** `addons/penta_tile/demo/` has `penta_tile_dual_grid_16.tres`, `penta_tile_minimal_3x3.tres`, `penta_tile_wang_2_corner.tres`, `penta_tile_wang_2_edge.tres` — none are referenced by the current demo scene (only `penta_layout_*.tres` Penta variants are referenced by `_capture_baseline.gd`). They're orphans from earlier scene iterations.

**How to avoid:** Plan-phase decides DELETE or KEEP. Recommend DELETE (they're orphans and the new demo binds via `[sub_resource]` directly to bundled bitmasks per D-05-02). The KEEP-list for `demo/`: `demo_runtime_painter.gd` + `.uid`, `penta_layout_*.tres` (Penta variants only), and the new `penta_tile_demo.tscn`. Everything else: DELETE.

[VERIFIED: glob of `addons/penta_tile/demo/*` 2026-04-29]

## Code Examples

### Complete `.github/workflows/release.yml` skeleton (verified syntax)

```yaml
# Source: synthesized from
#   Context7 /actions/checkout v6 (push pattern + permissions)
#   Context7 /softprops/action-gh-release v3 (release notes from file pattern)
#   Pattern 3 above (Godot CI exit code mitigation)
name: Release

on:
  workflow_dispatch:                          # D-05-15: no inputs, manual button only

jobs:
  release:
    runs-on: ubuntu-latest                    # has Node 24 for action-gh-release@v3
    permissions:
      contents: write                         # required to push commit + tag + create release
    env:
      GODOT_VERSION: 4.6.2-stable
    steps:
      - uses: actions/checkout@v6
        # persist-credentials: true (default) wires GITHUB_TOKEN into git remote

      - name: Configure git identity
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

      - name: Compute next version (D-05-16 auto-increment)
        run: |
          PLUGIN_CFG="addons/penta_tile/plugin.cfg"
          CURRENT=$(grep -E '^version\s*=' "$PLUGIN_CFG" | sed -E 's/^version\s*=\s*"?([^"]+)"?$/\1/')
          IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
          if [ "$MINOR" -ge 9 ]; then
            MAJOR=$((MAJOR + 1)); MINOR=0
          else
            MINOR=$((MINOR + 1))
          fi
          PATCH=0
          NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
          echo "Bumping ${CURRENT} → ${NEW_VERSION}"
          echo "NEW_VERSION=${NEW_VERSION}" >> "$GITHUB_ENV"
          echo "RELEASE_DATE=$(date -u +%Y-%m-%d)" >> "$GITHUB_ENV"

      - name: Download Godot 4.6.2-stable Linux
        run: |
          wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O godot.zip
          unzip -q godot.zip
          mv "Godot_v${GODOT_VERSION}_linux.x86_64" godot
          chmod +x godot

      - name: Headless project import (Pitfall #1 mitigated)
        run: |
          ./godot --headless --path . --import --quit-after 2 2> import_stderr.log || true
          if grep -qE '^(ERROR|SCRIPT ERROR):' import_stderr.log; then
            echo "::error::Godot import produced errors:"; cat import_stderr.log; exit 1
          fi

      - name: Run 18-test suite
        run: |
          chmod +x addons/penta_tile/tests/run_tests.sh
          GODOT=$(pwd)/godot bash addons/penta_tile/tests/run_tests.sh

      - name: Headless-open demo scene
        run: |
          ./godot --headless --quit-after 2 res://addons/penta_tile/demo/penta_tile_demo.tscn 2> open_stderr.log || true
          if grep -qE '^(ERROR|SCRIPT ERROR):' open_stderr.log; then
            echo "::error::Demo open produced errors:"; cat open_stderr.log; exit 1
          fi

      - name: Bump plugin.cfg
        run: |
          sed -i -E "s/^version\s*=.*$/version=\"${NEW_VERSION}\"/" addons/penta_tile/plugin.cfg

      - name: Rewrite CHANGELOG header
        run: |
          sed -i -E "s/^## \[Unreleased\][^\n]*$/## [${NEW_VERSION}] — ${RELEASE_DATE}/" CHANGELOG.md

      - name: Commit, tag, push
        run: |
          git add addons/penta_tile/plugin.cfg CHANGELOG.md
          git commit -m "chore(release): v${NEW_VERSION}"
          git tag -a "v${NEW_VERSION}" -m "PentaTile v${NEW_VERSION}"
          git push origin HEAD:main
          git push origin "v${NEW_VERSION}"

      - name: Build release zip via git archive
        run: |
          git archive --format=zip --prefix="penta_tile-v${NEW_VERSION}/" \
            -o "penta_tile-v${NEW_VERSION}.zip" "v${NEW_VERSION}" -- addons/penta_tile/

      - name: Extract CHANGELOG slice (D-05-18)
        run: |
          awk -v ver="${NEW_VERSION}" '
            /^## \[/ {
              if (in_section) { exit }
              if (index($0, "[" ver "]") > 0) { in_section = 1; print; next }
            }
            in_section { print }
          ' CHANGELOG.md > release-notes-body.md
          test -s release-notes-body.md || { echo "::error::release-notes-body.md is empty"; exit 1; }

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          tag_name: v${{ env.NEW_VERSION }}
          name: PentaTile v${{ env.NEW_VERSION }}
          body_path: release-notes-body.md
          files: penta_tile-v${{ env.NEW_VERSION }}.zip
```

[VERIFIED: each step pattern cross-checked against Context7 docs for /actions/checkout v6 and /softprops/action-gh-release v3, plus Godot pitfalls confirmed via WebFetch on GitHub issues]

### Hover-target detection in `demo_runtime_painter.gd` (Plan A)

```gdscript
# Source: original — extends existing _apply_at_event_position pattern
# Walks scene-tree children for PentaTileMapLayer instances and resolves
# the cursor to the instance whose Rect2 footprint contains the cursor.
func _apply_at_event_position(event_position: Vector2, button: MouseButton) -> void:
    var canvas_position := get_canvas_transform().affine_inverse() * event_position

    # Find the PentaTileMapLayer whose footprint contains the cursor.
    var hit_layer: PentaTileMapLayer = null
    for child in get_children():
        if child is PentaTileMapLayer:
            # Use the layer's used_rect in tile coords + tile_set.tile_size to compute
            # the world-space footprint, OR use a child Area2D if the plan-phase wants
            # explicit hit zones. Recommend the Rect2 approach — no extra nodes needed.
            var local := child.to_local(canvas_position)
            var cell := child.local_to_map(local)
            var rect := child.get_used_rect().grow(2)  # generous margin
            if rect.has_point(cell):
                hit_layer = child
                break

    if hit_layer == null:
        return

    var cell := hit_layer.local_to_map(hit_layer.to_local(canvas_position))
    if cell == _last_cell:
        return
    _last_cell = cell
    _apply_cell(hit_layer, cell, button)
```

(Implementation detail; planner can simplify or extend.)

### Identity audit recipe — pinned to v5.0.2 (Plan C)

```bash
# Source: methodology continuity from Phase 2/3/3.5/4 audits
# (see STATE.md "Roadmap Evolution" entries citing this recipe)

# 1. PentaTile runtime LOC (cumulative, current = 2884)
git ls-files 'addons/penta_tile/*.gd' 'addons/penta_tile/layouts/*.gd' \
  | grep -v 'tests/' \
  | grep -v 'demo/' \
  | xargs wc -l

# 2. PentaTile public surface
echo "@export count:"
grep -rE '^@export' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd | wc -l
echo "Public methods (no leading _):"
grep -rE '^func [a-z]' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd | wc -l
echo "class_name'd classes:"
grep -rE '^class_name ' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd | wc -l

# 3. TileMapDual comparison (pinned tag v5.0.2)
git clone --depth=1 --branch v5.0.2 https://github.com/pablogila/TileMapDual /tmp/tmd
TMD_HASH=$(cd /tmp/tmd && git rev-parse HEAD)
echo "TileMapDual v5.0.2 commit: ${TMD_HASH}"

cd /tmp/tmd
git ls-files '*.gd' \
  | grep -v 'test' \
  | grep -v 'demo' \
  | grep -v 'example' \
  | xargs wc -l

# 4. Hot-path comparison: manual call-graph trace, not scriptable
#    PentaTile: _update_cells → _paint_via_layout → layout.compute_mask → layout.mask_to_atlas → set_cell
#    TileMapDual: _update_cells → ??? (record from manual read of TileMapDual source)
#    Anti-pattern register check: PITFALLS.md AP-1..AP-10 + CLAUDE.md Identity Guardrails reject list
```

(Output goes into `05-LOC-AUDIT.md` working artifact; summary into README "Identity & Footprint" section per D-05-10.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual release: hand-edit plugin.cfg + tag + zip + upload | `workflow_dispatch` GitHub Actions one-click | This phase (Phase 5) | "If it cannot be automatic, remove it" — D-05-15 hard rule |
| `gh release create` CLI | `softprops/action-gh-release@v3` | Industry-shift (action-gh-release benchmark 93.25 / Context7) | Both work; action gets first-class glob support and body_path validation |
| Godot CI via `barichello/godot-ci:VERSION` Docker | Direct binary download from `github.com/godotengine/godot/releases` | Recommended for version-pin precision | Container's tag is pinned at 4.3 in upstream sample workflow; direct download = exact 4.6.2 |
| `--quit` for Godot CI | `--quit-after 2` | Issue #77508 outcome (recognized 2023, still relevant 2026) | Engine needs ≥ 2 frames to actually finish import work |
| LOC as identity gate | LOC as signal + hot-path + anti-pattern register | D-05-11 (this phase) | Reframes "PentaTile must be smaller than TileMapDual" → "PentaTile's hot path stays minimal AND no anti-patterns from the register" |

**Deprecated/outdated:**
- The CONSTRAINT in `PROJECT.md` line 88 ("PentaTile must remain visibly smaller and simpler than TileMapDual") — SC-C reframes this. Plan-phase rewrites the line.
- The ROADMAP Phase 5 SC-7 ("Final LOC audit confirms `addons/penta_tile/` total surface area stays under TileMapDual's equivalent") — SC-C reframes this. Plan-phase rewrites the line.
- `addons/penta_tile/ATTRIBUTION.md` mention in REL-03 — SC-B deletes this. Plan-phase removes the trailing clause from REQUIREMENTS.md:219.
- "10 built-in layouts" in DEMO-01 / DOC-01 / ROADMAP Phase 5 description — SC-A reframes to "8 actually-shipped layouts." Plan-phase rewrites four occurrences (REQUIREMENTS.md:202, REQUIREMENTS.md:208, ROADMAP.md:29, ROADMAP.md:201, ROADMAP.md:208, ROADMAP.md:211 — six total places).

## Spec Correction Surface (SC-A through SC-D — exact edits the planner must include)

This is the load-bearing finding for the planner: **the spec corrections are six discrete edits across three files**, not abstract reframings.

### SC-A: "10 layouts" → "8 actually-shipped layouts"

| File | Line | Current | New |
|------|------|---------|-----|
| `.planning/REQUIREMENTS.md` | 202 | "showcases all 10 built-in layouts" | "showcases all 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5; Tilesetter pair stays deferred to v0.3+ per D-86 b)" |
| `.planning/REQUIREMENTS.md` | 208 | "listing all 10 built-in layouts" | "listing all 8 actually-shipped layouts" |
| `.planning/ROADMAP.md` | 29 | "showcasing all 10 layouts" | "showcasing all 8 actually-shipped layouts" |
| `.planning/ROADMAP.md` | 201 | "showcasing all 10 built-in layouts" | "showcasing all 8 actually-shipped layouts" |
| `.planning/ROADMAP.md` | 208 | "showcases all 10 layouts" | "showcases all 8 actually-shipped layouts" |
| `.planning/ROADMAP.md` | 211 | "listing all 10 built-in layouts" | "listing all 8 actually-shipped layouts" |

[VERIFIED: grep for "10 (built-in\|layouts\|tile)" returned 6 matches above]

### SC-B: ATTRIBUTION.md mention deletion from REL-03

| File | Line | Current | New |
|------|------|---------|-----|
| `.planning/REQUIREMENTS.md` | 219 | "GitHub Release artifact `penta_tile-v0.2.0.zip` with `addons/penta_tile/` at the archive root, including templates and ATTRIBUTION.md." | "GitHub Release artifact `penta_tile-v0.2.0.zip` with `addons/penta_tile/` at the archive root, including bundled bitmask PNGs. Per D-72/D-73, NO ATTRIBUTION.md ships." |
| `.planning/ROADMAP.md` | 213 | (Phase 5 SC-6) "Downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run; ATTRIBUTION.md is present at the addon root." | "Downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run." (delete the ATTRIBUTION.md clause) |
| `.planning/PROJECT.md` | 44 | `- [ ] addons/penta_tile/ATTRIBUTION.md crediting TileBitTools (MIT)` | DELETE the line. (Or move to Out of Scope — but it's already in the Out of Scope table at line 310.) |

[VERIFIED: grep for "ATTRIBUTION.md" returned 9 matches; the 3 above are the ones requiring action; the rest are correct references in audit/closeout artifacts]

### SC-C: PROJECT.md Constraints + ROADMAP SC-7 reframing

| File | Line | Current | New |
|------|------|---------|-----|
| `.planning/PROJECT.md` | 88 | "**Identity**: PentaTile must remain visibly smaller and simpler than TileMapDual; expansions should not pull in terrain metadata, tile caches, or watcher infrastructure." | "**Identity**: PentaTile prioritizes hot-path minimalism and anti-pattern absence over raw LOC delta vs TileMapDual. The runtime path stays short (`_update_cells → compute_mask → mask_to_atlas → set_cell`), and the addon does not adopt terrain metadata, tile caches, watcher / signal-fanout systems, persistent coordinate caches, parallel paint APIs, or `EditorInspectorPlugin` polish. LOC is reported as data, not a verdict." |
| `.planning/ROADMAP.md` | 214 | (Phase 5 SC-7) "Final LOC audit confirms `addons/penta_tile/` total surface area stays under TileMapDual's equivalent — the result included in the release notes." | "Final identity audit reports three axes (LOC, public surface, hot-path depth) plus anti-pattern register check. LOC reported as signal, not a fail criterion (D-05-11). Audit summary lives in README § Identity & Footprint; full working artifact at `.planning/phases/05-*/05-LOC-AUDIT.md`." |
| `.planning/ROADMAP.md` | 261 | "The PROJECT.md identity constraint — \"PentaTile must remain visibly smaller and simpler than TileMapDual\" — is checked at four points across the roadmap:" | "The PROJECT.md identity constraint — hot-path minimalism + anti-pattern absence (per D-05-11 reframe) — is checked at four points across the roadmap:" |
| `CLAUDE.md` | 82 | "The PROJECT.md identity constraint is **\"PentaTile must remain visibly smaller and simpler than TileMapDual.\"**" | "The PROJECT.md identity constraint is **hot-path minimalism + anti-pattern absence.** PentaTile prioritizes a short runtime path and avoidance of TileMapDual-territory anti-patterns (terrain peering, watchers, persistent caches, parallel paint APIs); LOC is reported as signal, not a fail criterion (D-05-11)." |

[VERIFIED: grep for "smaller and simpler|smaller than TileMapDual|under TileMapDual|surface area stays under" returned the 4 matches above + one in CLAUDE.md mirror]

### SC-D: REL-01 ownership flip from manual commit to workflow side-effect

| File | Line | Current | New |
|------|------|---------|-----|
| `.planning/REQUIREMENTS.md` | 217 | (REL-01) "`plugin.cfg` `version` field bumped from `0.1.0` to `0.2.0`." | "`plugin.cfg` `version` field bumped by the release workflow per the auto-increment rule (D-05-16). REL-01 is verified by the workflow's commit SHA on the release tag, not by manual edit." |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Godot 4.6.2 Linux x86_64 zip URL `https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip` is correct (filename pattern inferred from prior Godot releases; WebFetch could not load asset list directly). | Standard Stack | CI fails at download step. Mitigation: plan-phase verifies by `curl -I` to that URL or falls back to mirror. [ASSUMED — verify in plan-phase] |
| A2 | The `softprops/action-gh-release@v3` `with.body_path` correctly reads UTF-8 markdown with em-dashes from `release-notes-body.md`. | Pattern, Code Examples | Release body renders as garbled text. Low risk — tested by other projects extensively. [ASSUMED — encoding] |
| A3 | The 8-cell `find_child("PentaTileMapLayer", true, false)` in `_capture_baseline.gd` is the only place in the test suite that depends on the demo scene's tree-shape. (Verified for the 18 tests in `run_tests.ps1`, but not the diagnostic `*_diag.gd` files.) | Pitfall #6 | A diagnostic script breaks; not a CI failure. [VERIFIED for run_tests.ps1; ASSUMED for diag files] |
| A4 | Removing the 4 unused single-variant Penta layout `.tres` files in `demo/` (e.g., `penta_tile_dual_grid_16.tres`) doesn't break any existing test or scene. | Pitfall #12 | A grep across the repo before deletion would confirm; if anything references them via path, deletion fails import. [ASSUMED — plan-phase greps before delete] |
| A5 | `git push origin HEAD:main` from the workflow doesn't trigger a recursive `workflow_dispatch` (it's manual-only by design). | Pitfall #4 | Recursive trigger; cosmetic concern only since the workflow exits non-zero on a re-trigger if version is already bumped. [VERIFIED by reading workflow_dispatch docs] |

**If this table is empty:** It's not — five assumptions to confirm in plan-phase, all low-risk and easily falsifiable.

## Open Questions

1. **Camera setup: fit-all-fixed vs. PanCamera2D?**
   - What we know: 8 instances arranged 2×4 occupy ~2256 × 928 px. A fixed Camera2D at center with `zoom = 0.4` shows everything but tiles look small.
   - What's unclear: whether the user wants to interact ergonomically with each layout (which favors a closer zoom + panning) or just SEE all 8 at once (favors fit-all).
   - Recommendation: Default to **fit-all-fixed** (matches D-05-01 "spatial grid" framing); hand-author the camera position+zoom in the `.tscn`. If the planner wants pan, that's discretion-area.

2. **Number of cells per instance demo paintable region?**
   - What we know: drag-paint must produce visible output. Each instance needs ≥ 4×4 cells visible at start.
   - What's unclear: whether to pre-paint a small starter pattern in each instance, or leave them all empty.
   - Recommendation: Empty + drag-paint-in (matches v0.1 demo philosophy). Optional pre-paint of a simple "starter" silhouette is discretion-area.

3. **`_capture_baseline.gd` adaptation: rename target instance vs. add `--node-path=` flag?**
   - Recommendation in Pitfall #6 above: option (a) name one instance literally `PentaTileMapLayer`. Plan-phase confirms.

4. **Does Phase 5 fold the Codex deferral from Phase 4 into the v0.2.0 release notes?**
   - What we know: Phase 4 deferred Codex due to quota wall; preserved prompt at `04-CODEX-PROMPT.md`. Single-pass Gemini coverage shipped.
   - What's unclear: whether the v0.2.0 release notes need a "Known limitations" line about the partial cross-AI coverage, OR whether the existing Phase 4 doc trail is enough.
   - Recommendation: NO mention in release notes (it's an internal QA process detail, not user-facing). If user wants transparency, plan-phase adds a one-liner. Discretion-area.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.6.2 (Linux) | CI workflow steps 4, 5, 6 | ✓ (downloaded each run) | 4.6.2-stable | None — pinned by D-05-16 |
| Godot 4.6.2 (Windows) | Local dev `run_tests.ps1` | ✓ | `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe` per `run_tests.ps1:20` | None |
| `gh` CLI | Optional (alternative to `softprops/action-gh-release`) | ✓ on `ubuntu-latest` | latest | Don't use; prefer the action |
| `git` | All git operations | ✓ on `ubuntu-latest` | bundled | None |
| `bash` | `run_tests.sh` + workflow steps | ✓ | bundled | Inline YAML if absolutely needed |
| `awk`, `sed`, `grep`, `wget`, `unzip` | Workflow body | ✓ | GNU coreutils | None |
| `secrets.GITHUB_TOKEN` | All git push + release publish | ✓ | auto-provided | PAT (only if pushing to a different repo) |
| Network access to github.com release downloads | Step 3 (Godot binary) | ✓ | — | Mirror via downloads.tuxfamily.org if github.com download is gone (was the source pre-2024) |
| `npm` / Node 24 | `softprops/action-gh-release@v3` runtime | ✓ on `ubuntu-latest` (24.04) | Node 24 | Pin `runs-on: ubuntu-22.04` would break v3 — KEEP `ubuntu-latest` |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

## Validation Architecture

> `workflow.nyquist_validation: true` per `.planning/config.json`. Section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bespoke headless Godot script harness — each test is a `.gd` file with `extends SceneTree` + `_initialize`; runs via `godot --headless --script <path>`; PASS = exit 0; FAIL = non-zero. No GUT, no other framework. |
| Config file | `addons/penta_tile/tests/run_tests.ps1` (PowerShell, Windows local dev) — registers the 18-test inventory |
| Quick run command (local Windows) | `.\addons\penta_tile\tests\run_tests.ps1 -NoPause -Test fallback_routing_test` (single test) or `... -Test all -NoPause` (all 18) |
| Full suite command (CI Linux) | `bash addons/penta_tile/tests/run_tests.sh` (NEW — Plan D Wave 1 creates this) |

### Phase Requirements → Test Map

This phase produces no NEW test code. The validation surface is the EXISTING 18-test suite plus three NEW CI-orchestrated checks (steps 4, 5, 6 of the release workflow).

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEMO-01 | New `.tscn` shows all 8 layouts | manual visual | `godot res://addons/penta_tile/demo/penta_tile_demo.tscn` | ❌ scene refresh in Plan A creates it |
| DEMO-02 | Each of 8 instances uses bundled fallback (`tile_set = null`) | composed-canvas test | `bash addons/penta_tile/tests/run_tests.sh` (covered by `fallback_routing_test`) | ✓ shipped Phase 4 |
| DEMO-03 | Drag-paint works across grid | manual visual | demo eyeball | ❌ manual UAT step in Plan A |
| DOC-01..04 | README + CHANGELOG sections | manual review | none — docs verified visually | ❌ produced in Plan B |
| REL-01 | plugin.cfg version bumped | workflow side-effect | release workflow step 7 commits the bump | — workflow run |
| REL-02 | git tag `v0.2.0` cut on release commit | workflow side-effect | release workflow step 8 creates tag | — workflow run |
| REL-03 | GitHub Release zip downloads + extracts cleanly | CI orchestrated | `godot --import` step on a fresh runner equivalent (D-05-14 frames steps 4 + 6 as the proxy) | ✓ steps 4 + 6 of workflow |
| (manual) Identity audit | `05-LOC-AUDIT.md` produced | developer judgment | bash recipe in "Code Examples" above | ❌ produced in Plan C |

### Sampling Rate

- **Per task commit:** Run `run_tests.ps1 -NoPause -Test all` locally (~2 minutes). 18 tests must stay green.
- **Per wave merge:** Same — 18-test suite green is the gate.
- **Phase gate:** Workflow run completes with green status (steps 4 + 5 + 6 green, commit + tag + release published, zip artifact attached). This IS the `/gsd-verify-work` evidence for REL-01..03.

### Wave 0 Gaps

- [x] `addons/penta_tile/tests/run_tests.sh` — Linux mirror of the PowerShell runner. NOT optional. Exists? **NO** — Plan D Wave 1 creates it.
- [ ] `addons/penta_tile/tests/run_tests.ps1` — Windows local-dev runner. **EXISTS.** Used as reference for `run_tests.sh`.
- [ ] Determinism baseline `BASELINE_HASH=2561003017` (the actual current value, NOT the 2986698704 quoted in the context — this changed in Phase 2 closeout). Self-contained per Pitfall #6; no Phase 5 work needed.
- [ ] Framework install: `wget` Godot 4.6.2-stable Linux binary — done in workflow step 3.

*(No new GDScript test files needed. Phase 5 reuses Phase 4's 18 tests; CI orchestrates them via the new `run_tests.sh`.)*

## Project Constraints (from CLAUDE.md)

The planner MUST honor the following directives extracted from `./CLAUDE.md`:

1. **Breaking Changes Policy (HARD RULE — both directions):**
   - NO backwards-compat shims. Don't preserve `demo_player.gd`/`penta_tile_ground.tres` "in case someone has scripts referencing them" — delete cleanly. CHANGELOG documents the breakage.
   - NO forward-compat speculation. Don't add `version: int` to plugin.cfg shape, don't add hooks, don't add inputs to `workflow_dispatch` "in case patches are needed later" — D-05-16 explicitly forbids that.

2. **Coined-Term Discipline:** "Penta" reserved exclusively for the 5-archetype format. Don't introduce `PentaCI`, `PentaRelease`, `PentaWorkflow`, etc. — workflow file is `release.yml`, scripts/jobs use generic names.

3. **Critical Pitfalls #1-10:** None directly apply to Phase 5 (these are runtime/synthesis concerns). Phase 5 ADDS Pitfalls #1-12 in this research file (Godot CI exit codes, permissions, version regex, etc. — those are Phase-5-specific).

4. **Identity Guardrails (subject to D-05-11/12 reframing):** SC-C captures the rewrite. The reject list (terrain peering, watchers, coord cache, signal fanout, parallel paint API, EditorInspectorPlugin polish) stays as a non-negotiable.

5. **Quality Bar:** "Works in my game." No new test infrastructure. Demo-scale only. The CI workflow is the formalization of "works in my game" for the release ship-gate.

6. **Test Methodology:** Already codified post-Phase 2 UAT. Phase 5 doesn't add new tests; it reuses the methodology by running the existing 18-test suite in CI.

## Sources

### Primary (HIGH confidence)
- **Context7 `/actions/checkout`** — v6 syntax + permissions + push-back patterns [VERIFIED via ctx7 CLI 2026-04-29; benchmark score in metadata]
- **Context7 `/softprops/action-gh-release`** — v3.0.0 `body_path` + `files` + `tag_name` syntax [VERIFIED via ctx7 CLI 2026-04-29; benchmark score 93.25]
- **GitHub Release Assets** — Godot 4.6.2-stable Linux x86_64 zip URL (filename inferred; verify in plan-phase) [github.com/godotengine/godot/releases/tag/4.6.2-stable]
- **GitHub Tags page** — TileMapDual v5.0.2 latest stable tag (2026-01-03) [github.com/pablogila/TileMapDual/tags]
- **Direct file reads** — `addons/penta_tile/plugin.cfg`, `demo/penta_tile_demo.tscn`, `demo/demo_runtime_painter.gd`, `demo/demo_player.gd`, `layouts/penta_tile_layout.gd:140-165` (`get_fallback_tile_set` codegen), `tests/_capture_baseline.gd`, `tests/determinism_test.gd`, `tests/run_tests.ps1`, `CHANGELOG.md`, `README.md`, all of `.planning/phases/05-demo-refresh-documentation-release/05-CONTEXT.md`

### Secondary (MEDIUM confidence)
- **Godot Issue #77508** — `--quit-after 2` workaround [WebFetch 2026-04-29]
- **Godot Issue #83042** — export exit code 0 on error [WebFetch 2026-04-29]
- **Godot Issue #85062** — CLI exit codes unreliable [WebFetch 2026-04-29]
- **GitHub Discussion #68252** — release-only permission scope (informational; not used) [WebSearch 2026-04-29]
- **AWK changelog extract gist** — `gist.github.com/Integralist/57accaf446cf3e7974cd01d57158532c` [WebSearch 2026-04-29]

### Tertiary (LOW confidence — flagged for plan-phase verification)
- **Godot 4.6.2 download URL exact filename** — inferred from pattern; A1 in Assumptions Log; plan-phase should `curl -I` to confirm [WebSearch noted godotengine.org archive page exists]

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — Context7 docs current; Godot binary download verified by web; GitHub Actions versions confirmed
- Architecture (workflow shape, demo grid pattern, audit recipe): **HIGH** — D-05 decisions are crisp; methodology continuity from prior phases
- Pitfalls (Godot CI exit codes, permissions, regex, find_child): **HIGH** — each pitfall verified via direct file read OR upstream issue
- Spec corrections (SC-A through SC-D): **HIGH** — exact line numbers and current text grep-verified
- Identity audit target (TileMapDual v5.0.2): **HIGH** — tag list confirmed via WebFetch
- Camera/grid layout details: **MEDIUM** — proposed dimensions are reasonable but not authoritative; plan-phase tunes
- Hover-target detection algorithm shape: **MEDIUM** — single approach proposed; plan-phase confirms or alternates

**Research date:** 2026-04-29
**Valid until:** 2026-05-29 (30 days for stable Godot 4.6.2 + GitHub Actions ecosystem; flag for re-research if any of `actions/checkout`, `softprops/action-gh-release`, or Godot ship a major release)
