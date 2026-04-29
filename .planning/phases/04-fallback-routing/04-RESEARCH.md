# Phase 4 Research

**Researched:** 2026-04-29
**Domain:** Godot 4.6 / GDScript doc-comments + cross-AI review tooling + composed-canvas UAT
**Confidence:** HIGH (Godot doc-comment format verified via Context7 `/godotengine/godot-docs`; CLI invocations verified via `--help` on installed binaries; Phase 2 review precedent verified verbatim from `02-REVIEW.md`)

## User Constraints (from CONTEXT.md)

### Locked Decisions

Sixteen decisions, D-04-01 through D-04-16, are locked in `04-CONTEXT.md`. Reproduced here verbatim with the implementation summary the planner needs:

**Doc sweep:**
- **D-04-01** Sweep is the **12 addon scripts** under `addons/penta_tile/` only. Tests + demo are out of scope. Files: `penta_tile_map_layer.gd`, `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, `layouts/penta_tile_layout.gd`, `layouts/penta_tile_layout_penta.gd`, `layouts/penta_tile_layout_dual_grid_16.gd`, `layouts/penta_tile_layout_wang_2_edge.gd`, `layouts/penta_tile_layout_wang_2_corner.gd`, `layouts/penta_tile_layout_minimal_3x3.gd`, `layouts/penta_tile_layout_blob_47_godot.gd`, `layouts/penta_tile_layout_pixel_lab_top_down.gd`, `layouts/penta_tile_layout_pixel_lab_side_scroller.gd`.
- **D-04-02** Class-level `##` block + `##` on every public method (no leading underscore) + `##` on every `@export` property. Private `_foo` methods get a one-liner only when the WHY is non-obvious.
- **D-04-03** Full Godot tag set: structural (`@tutorial`, `@experimental`, `@deprecated`); BBCode (`[param x]`, `[code]`, `[Class TileMapLayer]`, `[method foo]`, `[member bar]`). `@experimental` flag goes on the `PentaTileLayout` subclassing surface.
- **D-04-04** No doc-coverage lint test. Cross-AI review pass is the verification mechanism.

**Fallback close-out:**
- **D-04-05** UAT covers all **8 actually-shipped layouts**: 5 Phase 2 (Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3) + 1 Phase 3 (Blob47Godot) + 2 Phase 3.5 (PixelLabTopDown, PixelLabSideScroller). TBT-01-DEFERRED / TBT-02-DEFERRED stay out of scope per D-86 (b).
- **D-04-06** Belt + suspenders: programmatic composed-canvas test (`fallback_routing_test.gd`) AND manual demo eyeball (`04-FALLBACK-UAT.md`). Plus regression coverage: assigning `tile_set` directly overrides fallback; clearing re-routes.
- **D-04-07** PREVIEW-03 / PREVIEW-04 close in Phase 4 (not retroactively in Phase 2).
- **D-04-08** Phase 5 LOC + identity audit stays deferred to Phase 5; cross-AI review surfaces identity violations qualitatively.

**Cross-AI review:**
- **D-04-09** Two reviewers, both headless: Gemini + Codex. Cursor + Antigravity ruled out (subscription / IDE-only).
- **D-04-10** Strict order: Gemini → fix valid → Codex → fix valid. Codex sees the post-Gemini-fix codebase.
- **D-04-11** Each reviewer's prompt covers: codebase (12 scripts + tests as supporting evidence), project context (`PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `CLAUDE.md`), TileMapDual identity comparison. Findings categorized Severity (Critical | High | Medium | Low | Info) × Theme (Bug | Identity | Goal-misalignment | Doc | Design).
- **D-04-12** Outputs: `04-GEMINI-REVIEW.md` (raw) + `04-GEMINI-REVIEW-FIX.md` (disposition log) + `04-CODEX-REVIEW.md` + `04-CODEX-REVIEW-FIX.md`.

**Fix policy:**
- **D-04-13** Severity-tiered: Critical/High auto-apply; Medium gated on user approval; Low/Info logged, user picks apply or defer.
- **D-04-14** Standard disqualification list — see § 5 below.
- **D-04-15** Atomic commits per finding: `fix(04): GEMINI-W-03 — missing @return tag in PentaTileLayout.compute_mask docstring`.
- **D-04-16** Phase-close gate: all 4 artifacts must commit. ROADMAP row flips to `[x]` when (1) doc sweep covers all 12 scripts, (2) fallback UAT pass on 8 layouts visually + composed-canvas test green, (3) Gemini valid findings dispositioned + committed, (4) Codex valid findings dispositioned + committed.

### Claude's Discretion

- Plan sequencing (D-04 suggests doc sweep → UAT → Gemini → fix → Codex → fix; planner may reshape).
- The exact composed-canvas pattern matrix in `fallback_routing_test.gd` (the spec mandates "compose canvas + assert structural invariants" but the pattern set is at the planner's discretion — see § 2 for the recommendation).
- Cross-AI review prompt wording (the surface and severity/theme schema are locked; the prose is at the implementer's discretion — see § 4 for a reusable template).
- Whether to chunk reviews if context exceeds budget (§ 3 below recommends one prompt per logical surface as fallback).

### Deferred Ideas (OUT OF SCOPE)

- Doc-coverage lint test (deferred to v0.3+ if doc rot becomes a problem).
- Three-reviewer pass (Gemini + Antigravity + Codex) — Antigravity is IDE-only.
- Phase 5 LOC / identity audit pre-run (stays in Phase 5).
- Doc-sweep on `tests/` and `demo/` (internal surface).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **PREVIEW-03** | When `PentaTileMapLayer.tile_set == null` AND `layout != null`, layer routes through `layout.get_fallback_tile_set()` for prototyping. | § 2 — composed-canvas test asserts visible output for all 8 layouts under `tile_set = null`. § 9 lists the regression-net contract checks (override + re-route). Wiring already lives at `penta_tile_map_layer.gd:54-70` per CONTEXT.md anchors. |
| **PREVIEW-04** | When user assigns `tile_set` directly, it overrides the fallback (no warnings, no errors). | § 2 — same test asserts (1) assigning `tile_set` flips `_tile_set_is_fallback` to false via `_set` hook (`penta_tile_map_layer.gd:92-96`), (2) clearing back to `null` re-routes to fallback. |

## Summary

Phase 4 has three braided deliverables, all on locked rails. (1) **Doc sweep** is mechanical — the canonical Godot doc-comment format is `##` immediately preceding the documented element, with structural tags `@tutorial(label)`, `@experimental`, `@deprecated` at line beginnings and BBCode inline tags `[param x]`, `[code]`, `[Class FooBar]`, `[method foo]`, `[member bar]`. The 3 existing class-level blocks in the codebase (`penta_tile_synthesis.gd:1-19`, `penta_tile_atlas_slot.gd:1-9`, `layouts/penta_tile_layout.gd:1-12`) are exemplary style references. (2) **Fallback UAT** is a single composed-canvas test (`fallback_routing_test.gd`) that loops 8 layouts × 1 simple paint pattern with `tile_set = null`, blits each painted cell's `(atlas_coords, transform_flags)` into a virtual `Image`, and asserts non-empty bbox + per-cell solidity per CLAUDE.md Test Methodology #1. Full mask-coverage already lives in `comprehensive_bitmask_test.gd` (8 × 18 = 144 combos) — Phase 4 only verifies the **fallback path** works, not autotile correctness. (3) **Cross-AI review** uses two installed CLIs: `gemini -p "..."` (Gemini CLI 0.38.2) and `codex review "..."` (Codex CLI 0.124.0) — both confirmed installed and headless-capable.

**Primary recommendation:** Sequence the work as doc-sweep → fallback UAT → Gemini → fix → Codex → fix (D-04 suggests this; planner may re-shape but doing doc-sweep first means reviewers see the documented codebase). Use the severity/theme schema from § 4 verbatim in both reviewer prompts. Apply the disqualification checklist in § 5 within ≤ 30 seconds per finding.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fallback wiring (`tile_set == null` → `layout.get_fallback_tile_set()`) | `PentaTileMapLayer` (the `layout` setter, `_init`, `_set` hook) | `PentaTileLayout` (each subclass's `get_fallback_tile_set()` codegen) | Layer owns the routing; layout owns the codegen. Already shipped in Phase 2 — Phase 4 verifies, doesn't author. |
| Doc-comment authoring | Each of the 12 addon scripts | — | Per-file authoring; no cross-file machinery. |
| UAT composed-canvas verification | `addons/penta_tile/tests/fallback_routing_test.gd` | `addons/penta_tile/tests/run_tests.ps1` (registry) | New test file + registry append (17 → 18 tests). |
| Cross-AI review surface | External CLIs (gemini, codex) | `04-{TOOL}-REVIEW.md` (raw findings) + `04-{TOOL}-REVIEW-FIX.md` (disposition log) | Reviewers run outside Claude Code; outputs land as artifacts in the phase dir. |
| Fix-application dispatch | Implementer (Claude / user) | Atomic-per-finding commits + REVIEW-FIX.md disposition column | Severity tier drives auto / gated / logged paths (D-04-13). |

## 1. Godot Doc-Comment Format

[VERIFIED: Context7 `/godotengine/godot-docs` query "GDScript documentation comments syntax @tutorial @experimental @deprecated BBCode tags"]
[CITED: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html]

### Syntax Rules

**Marker:** Documentation comments use `##` (double hash). Single `#` is a regular comment and is NOT picked up by the doc system. The official docs explicitly state: "every line must start with the double hash symbol `##`."

**Placement (canonical rule):** "Documentation comments must immediately precede the element they document, whether it's a variable, function, or class." A blank line OR an interrupting `#` (single-hash) comment between the `##` block and the documented element breaks the association.

**Three legal forms:**

1. **Multi-line block above member:**
   ```gdscript
   ## Brief description on first line.
   ##
   ## Longer detail starts after one blank ## line.
   var my_var: int
   ```

2. **Single-line block above member** (no blank, no detail):
   ```gdscript
   ## My variable.
   var my_var
   ```

3. **Inline trailing form** (same line as declaration):
   ```gdscript
   var my_var ## My variable.
   signal my_signal ## My signal.
   const MY_CONST = 1 ## My constant.
   ```

**Class-level placement (load-bearing for Phase 4):** Per the official docs and the project's existing exemplary blocks, class-level docs go AFTER `extends` (and after `@tool` / `@icon` annotations) but BEFORE the first member. The canonical pattern from the Godot docs:

```gdscript
@abstract                       # optional annotations first
class_name MyNode
extends Node
## A brief description of the class's role and functionality.
##
## The description of the script, what it can do,
## and any further detail.
##
## @tutorial:             https://example.com/tutorial_1
## @tutorial(Tutorial 2): https://example.com/tutorial_2
## @experimental
```

The PentaTile codebase already uses this convention — `penta_tile_synthesis.gd` has `@tool` then `## ...` block then `class_name PentaTileSynthesis`. The block lands BEFORE `class_name` in those files because there is no `extends` clause; the rule "after `extends` if present, after annotations always, before `class_name` if no `extends`" is what the existing 3 exemplary blocks follow. Don't break this pattern in the sweep.

### Structural Tags

All structural tags use `@keyword: value` or `@keyword(label): value` form. **Critical:** "If there is any space in between the tag name and colon, for example `@tutorial :`, it won't be treated as a valid tag and will be ignored."

| Tag | Form | Where it goes | Notes |
|-----|------|---------------|-------|
| `@tutorial: URL` | Script-level only | Inside the class-level `##` block | Bare URL form. |
| `@tutorial(Label): URL` | Script-level only | Inside the class-level `##` block | Custom label appears in editor help. |
| `@deprecated` | Script-level OR member-level | Inside the doc block | Bare form. |
| `@deprecated: Use [member another] instead.` | Script-level OR member-level | Inside the doc block | Optional explanation. |
| `@experimental` | Script-level OR member-level | Inside the doc block | Bare form. |
| `@experimental: This class is unstable.` | Script-level OR member-level | Inside the doc block | Optional explanation. |

[ASSUMED] BBCode is permitted inside the explanation text after the colon (e.g., `@deprecated: Use [member another] instead.`) — the docs reference example uses `[member]` inside `@deprecated:` so this is confirmed.

### BBCode Inline Tag Set

[VERIFIED: official docs URL above]

**Cross-reference tags** (these resolve into clickable links in the editor's help viewer):

| Tag | Use |
|-----|-----|
| `[Class]` (e.g., `[TileMapLayer]`) | Reference a class. Just the class name in brackets. |
| `[method foo]` or `[method Class.foo]` | Reference a method. |
| `[member bar]` or `[member Class.bar]` | Reference a property. |
| `[constant Color.RED]` | Reference a constant. |
| `[signal Class.changed]` | Reference a signal. |
| `[enum Mesh.ArrayType]` | Reference an enum. |
| `[constructor Color.Color]` | Reference a constructor. |
| `[operator Color.operator *]` | Reference an operator. |
| `[theme_item Label.font]` | Reference a theme item. |
| `[annotation @GDScript.@rpc]` | Reference an annotation. |
| `[param x]` | Reference a parameter (the typical inline use within method docs). |

**Formatting tags:**

| Tag | Use |
|-----|-----|
| `[code]...[/code]` | Inline monospace code. |
| `[codeblock]` ... `[/codeblock]` | Block-level code. Supports `lang=gdscript|csharp|text`. **Indents with 4 spaces, NOT tabs.** |
| `[b][/b]`, `[i][/i]`, `[u][/u]`, `[s][/s]` | Bold / italic / underline / strikethrough. |
| `[color=red]...[/color]` | Colored text (HTML names or hex). |
| `[br]` | Line break. |
| `[url]URL[/url]` | Inline URL. |
| `[kbd]Ctrl+C[/kbd]` | Keyboard shortcut. |
| `[lb]` and `[rb]` | Literal `[` and `]` (when you need brackets that aren't BBCode). |

### Annotation Interaction (`@tool`, `@export_group`, `@export`)

Per the official docs: "If the member has any annotation, the annotation should immediately precede it" — meaning the annotation comes BETWEEN the doc comment and the member, NOT between the doc comment and the annotation. The pattern is always:

```gdscript
## Doc comment block here.
@export var foo: int
```

This is the pattern the existing PentaTile `@export_storage var _tile_set_is_fallback` (line 79 of `penta_tile_map_layer.gd`) uses with its preceding `#` (single-hash) comment — Phase 4 will convert that prose to `##` for any export the planner deems public-facing.

[ASSUMED] `@export_group` is a top-level grouping annotation, not a member annotation, so its doc-comment treatment is special: a `##` block before `@export_group("Foo")` is treated by some tooling as a "section header" but the official docs do not explicitly cover this. Recommendation: place `##` blocks on the member, not on the `@export_group` line; the inspector renders `@export_group` as a heading regardless.

### Single-Hash Interruption

[ASSUMED — not explicitly covered in the official docs but verified by the existing exemplary blocks in the codebase] A single `#` comment between a `##` block and the documented element breaks the association — the doc block must be UNINTERRUPTED. The current `penta_tile_synthesis.gd:1-19` block is one continuous `##` block with no `#` lines mixed in, confirming this is the working pattern. The planner should mandate "no `#` lines inside a `##` doc block" as a sweep rule.

### Private Members

[VERIFIED: official docs] "If any member variable or function name starts with an underscore, it will be treated as private...will not appear in the documentation" — UNLESS explicitly documented with `##`, in which case they appear in the help window. Per D-04-02, private `_foo` methods get a `##` doc-comment ONLY when the WHY is non-obvious; otherwise they stay un-doc-commented and Godot hides them automatically. This matches the existing CLAUDE.md "comments explain WHY, not WHAT" convention.

## 2. Fallback-Routing UAT Methodology

### Composed-Canvas Pipeline

[VERIFIED: `addons/penta_tile/tests/comprehensive_bitmask_test.gd:1-100`, `addons/penta_tile/tests/penta_ground_hollow_test.gd:1-130`, `addons/penta_tile/tests/pixellab_visual_regression_test.gd`]

The pipeline is a 5-step recipe established in Phase 2's UAT bug-fix sweep and refined in Phase 3.5:

1. **Construct layer:** `layer = PentaTileMapLayer.new()`. Set `layer.layout = <layout subclass instance>` (e.g., `PentaTileLayoutPenta.new()`). Do NOT assign `tile_set` — the layer's `layout` setter auto-fills it from `layout.get_fallback_tile_set()` and sets `_tile_set_is_fallback = true` (per `penta_tile_map_layer.gd:54-70`).
2. **Add to scene + paint:** `get_root().add_child(layer)`, await two process frames, then `layer.set_cell(coord, 0, Vector2i(0, 0))` for each cell in the test pattern, await two process frames, then `layer.rebuild()`.
3. **Compose virtual canvas:** for each painted display cell on `layer._primary_layer`, read `atlas_coords = primary.get_cell_atlas_coords(cell)` + `alt = primary.get_cell_alternative_tile(cell)` (which packs transform flags via the `_pack_alternative` recipe per PITFALLS §3). Extract the source image from the synthesized atlas, apply the transform (`TRANSPOSE`/`FLIP_H`/`FLIP_V` bits in `alt`), blit into the canvas `Image` at `cell * tile_size`.
4. **Compute structural invariants:**
   - **Non-empty bbox:** scan canvas for opaque pixels (`alpha > 0`); assert at least one opaque pixel exists.
   - **Per-cell opacity:** for each painted display cell, assert at least one opaque pixel within its `tile_size × tile_size` region.
   - **Bbox matches expected painted region:** for single-grid layouts, opaque bbox equals `painted_cells × tile_size`; for dual-grid, the bbox spans 1 cell larger to accommodate quadrant composition.
5. **Save PNG when in doubt:** `canvas.save_png("user://fallback_routing_<layout>.png")` and read via the `Read` tool. Lesson #4 from CLAUDE.md Test Methodology — UI bugs need eyeball verification.

### Recommended Pattern Set for Phase 4

Phase 4's UAT goal is "fallback produces SOMETHING visible," NOT "fallback is bug-free across all 16 mask states." Mask-correctness coverage already lives in `comprehensive_bitmask_test.gd` (8 layouts × 18 patterns = 144 combos) and `bitmask_bounds_test.gd`. The minimum sufficient pattern set per layout is:

- **Single 3×3 rectangle** — exercises masks 0..15 in single-grid layouts (interior fully-surrounded cell hits mask 15; edges/corners hit other states); for dual-grid, the 3×3 logic region produces a 4×4 display region with all 16 corner-mask states represented.

The 3×3 rectangle is sufficient because:
- It produces both interior + edge + corner cells in one pattern.
- It avoids the 1×1 / 1×N pitfall classes that already have dedicated coverage in `comprehensive_bitmask_test.gd` (mask=0 dispatch, isolated cells, lines).
- Per Codex's PIXLAB-04 review (`03.5-REVIEWS.md`), simple smoke patterns work fine when the test's PURPOSE is "fallback path engages" rather than "mask matrix correct."

**Optional second pattern (recommended):** 1×1 isolated cell — catches the single-grid `mask=0` dispatch regression (CLAUDE.md Pitfall #9) under the fallback path specifically. Adds ~30 LOC, ~1 second runtime.

**Total test cost estimate:** 8 layouts × 1 (or 2) patterns × ~5 ms paint + ~10 ms canvas compose + assertion = under 1 second wall-clock, well within the run_tests.ps1 budget.

### Regression-Catch Verification (CLAUDE.md Test Methodology #5)

Concrete recipe for the new test:

1. Run `fallback_routing_test.gd` against the working code → all 8 layouts pass.
2. Stash the fallback flip: in `penta_tile_map_layer.gd:64`, change `if tile_set == null or _tile_set_is_fallback:` to `if false:` (disables auto-fill).
3. Re-run the test → expect failure (canvas empty for all 8 layouts because no `tile_set` is bound and the layer renders nothing).
4. Document the test output in `04-FALLBACK-UAT.md` showing the stashed-fix failure.
5. Restore the line, confirm test goes green.

This satisfies CLAUDE.md Test Methodology #5: "Verify the test catches the regression. Stash the fix, rerun, confirm failure."

### `run_tests.ps1` Wiring

Append `"fallback_routing_test"` to the `$allTests` array at line 53-71 of `addons/penta_tile/tests/run_tests.ps1`. Test count goes 17 → 18. No other changes needed; the runner discovers `addons/penta_tile/tests/<name>.gd` automatically.

### Two-Tier Verification (D-04-06)

**Programmatic (auto-runs in `run_tests.ps1`):** the new `fallback_routing_test.gd` per the spec above.

**Manual (`04-FALLBACK-UAT.md`):** the human eyeball pass on the demo. Steps:

1. Open `addons/penta_tile/demo/penta_tile_demo.tscn` in the Godot editor.
2. For each of the 8 layouts, swap the `layout` property to that layout's `.tres` (or instantiate via the inspector picker), clear `tile_set` to `null`, drag-paint a small region in the running game.
3. Sign off in `04-FALLBACK-UAT.md` with one row per layout: layout name | result (PASS / FAIL with screenshot path) | notes.
4. PREVIEW-04 contract check: assign a custom `tile_set` (any TileSet `.tres`) directly, confirm it overrides; clear it again, confirm fallback re-engages. Sign off.

Both must pass for ROADMAP `[x]`.

## 3. Headless Cross-AI Review Mechanics

### Gemini CLI

[VERIFIED via `gemini --version` → 0.38.2; `gemini --help` confirms headless flags]

**Invocation shape:**
```bash
gemini -p "<prompt>" 2>/dev/null > 04-GEMINI-REVIEW.md
# OR for stdin:
cat 04-GEMINI-PROMPT.md | gemini -p - 2>/dev/null > 04-GEMINI-REVIEW.md
```

**Key flags:**
- `-p, --prompt <text>` — non-interactive mode. Per the help: "Run in non-interactive (headless) mode with the given prompt. Appended to input on stdin (if any)."
- `-m, --model <name>` — model selection. Defaults to current Gemini default; for code review the recommended model is `gemini-2.5-pro` (large context, strong reasoning) or `gemini-2.5-flash` (faster, cheaper). [ASSUMED: `gemini-2.5-pro` is the highest-quality model name as of April 2026; verify with `gemini --help` model list at execution time]
- `--include-directories <paths>` — comma-separated additional workspace directories (use to include `.planning/` alongside `addons/penta_tile/`).
- `--yolo` / `--approval-mode yolo` — auto-accept all actions. NOT NEEDED for review-only invocation since `-p` produces output and exits.
- `-o, --output-format <text|json|stream-json>` — text default; use text for the raw markdown.

**Recommended invocation for Phase 4:**
```bash
gemini --model gemini-2.5-pro \
  --include-directories ".planning,addons/penta_tile" \
  -p "$(cat .planning/phases/04-fallback-routing/04-GEMINI-PROMPT.md)" \
  > .planning/phases/04-fallback-routing/04-GEMINI-REVIEW.md 2>&1
```

The `--include-directories` flag is the cleanest way to attach the planning docs + addon source as workspace context. Stdin redirection works as an alternative if path-quoting is awkward on Windows PowerShell.

### Codex CLI

[VERIFIED via `codex --version` → 0.124.0; `codex review --help` confirms the dedicated `review` subcommand]

**Invocation shape — `codex review` (recommended for Phase 4):**
```bash
codex review "<prompt>" > 04-CODEX-REVIEW.md
# OR via stdin:
cat 04-CODEX-PROMPT.md | codex review - > 04-CODEX-REVIEW.md
```

**Key flags from `codex review --help`:**
- Positional `[PROMPT]` — custom review instructions; `-` reads from stdin.
- `-c, --config <key=value>` — TOML overrides; e.g., `-c model="o3"` selects the model.
- `--uncommitted` — review staged + unstaged + untracked changes (NOT useful here — Phase 4 reviews the WHOLE codebase, not a diff).
- `--base <BRANCH>` — review changes against a base branch (NOT useful here — same reason).
- `--commit <SHA>` — review a specific commit (NOT useful here).

**Alternative: `codex exec` (workflow precedent from `~/.claude/get-shit-done/workflows/review.md`):**
```bash
cat 04-CODEX-PROMPT.md | codex exec --skip-git-repo-check - > 04-CODEX-REVIEW.md
```

The existing GSD workflow uses `codex exec` (not `codex review`) for Plan-level reviews; `codex review` is newer. [ASSUMED] For Phase 4's whole-codebase review, `codex exec` is the more battle-tested path because the existing review prompts are designed for it. Recommendation: use `codex exec --skip-git-repo-check -` for Phase 4 to match Phase 3.5's precedent (`03.5-REVIEWS.md`).

**Recommended invocation for Phase 4:**
```bash
cat .planning/phases/04-fallback-routing/04-CODEX-PROMPT.md | \
  codex exec --skip-git-repo-check - \
  > .planning/phases/04-fallback-routing/04-CODEX-REVIEW.md
```

### Model Selection

[VERIFIED via Gemini `--help`; ASSUMED for model names current as of 2026-04-29]

| Reviewer | Model | Rationale |
|----------|-------|-----------|
| Gemini | `gemini-2.5-pro` | Large context (~1M tokens), strong reasoning, highest quality for code-review surface. Alternative: `gemini-2.5-flash` for faster turnaround at lower quality. |
| Codex | Default (per `~/.codex/config.toml`) | Existing Phase 3.5 review used codex defaults successfully; no need to override. If user wants override: `codex exec -c model="o3" --skip-git-repo-check -`. |

### Token-Budget Realism

[VERIFIED via file enumeration]

The full review surface for Phase 4 is approximately:

| Surface | Files | Size estimate |
|---------|-------|---------------|
| Addon code (12 scripts) | `addons/penta_tile/*.gd` + `addons/penta_tile/layouts/*.gd` | ~2660 LOC × ~50 chars/line ≈ 130 KB |
| Tests (supporting evidence per D-04-11) | 17 test scripts under `addons/penta_tile/tests/` | ~3-4 KB each ≈ 60 KB |
| `CLAUDE.md` | 1 file | ~20 KB |
| `.planning/PROJECT.md` | 1 file | ~10 KB |
| `.planning/ROADMAP.md` | 1 file | ~20 KB |
| `.planning/REQUIREMENTS.md` | 1 file | ~25 KB |
| **Total** | — | **~265 KB** |

[CITED: Gemini 2.5 Pro 1M-token context window per Google's published specs] Gemini 2.5 Pro's 1M-token context (~3 MB of text) accommodates the full surface in a single prompt with comfortable headroom. Codex's default model also handles ~265 KB easily.

**Conclusion:** No chunking required. Single-prompt review is feasible for both reviewers.

**Fallback chunking strategy (if a future reviewer hits a limit):** Split into three logical surfaces:
1. **Code:** `addons/penta_tile/*.gd` + `addons/penta_tile/layouts/*.gd` (12 scripts)
2. **Planning:** `CLAUDE.md` + `.planning/PROJECT.md` + `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md`
3. **Identity comparison:** TileMapDual public README excerpt + the canonical anti-pattern register from `.planning/research/PITFALLS.md`

Run three review passes, merge findings into a single `04-{TOOL}-REVIEW.md`. Not needed for Phase 4 — listed only as a documented escape hatch.

## 4. Cross-AI Review Output Schemas

### Severity Ladder (D-04-11)

Five tiers. Working definitions calibrated to PentaTile's "works in my game" quality bar (CLAUDE.md):

| Tier | Definition | Auto-apply? (D-04-13) |
|------|------------|----------------------|
| **Critical** | Security or data-loss class bug; demo crashes on load; saved scene corruption; runtime exception in the autotile hot path. None expected in Phase 4 review (codebase has 3 prior code-review passes clean). | YES (no prompt) |
| **High** | Correctness regression; broken contract (e.g. PREVIEW-03/04 wiring breaks); identity-guardrail violation (terrain peering, watcher pattern, cache); locked-decision contradiction (D-XX); coined-term violation. | YES (no prompt) |
| **Medium** | Quality issue with debatable fix; potentially missing edge case in a non-hot-path; doc-comment ambiguity that could mislead a custom-layout author; LOC overage in a non-budget-locked area. | NO — propose to user, await approval, then commit. |
| **Low** | Cosmetic / style polish; minor naming inconsistency; unused helper; debt-but-not-bug. | NO — surface in summary; user picks apply or defer. |
| **Info** | Observation without action; trivia about the codebase; future-phase hint that doesn't affect current scope. | NO — log only; user picks apply or defer. |

### Theme Rubric (D-04-11)

Five themes. Each finding gets exactly one primary theme (reviewer may note secondary):

| Theme | Rubric (1-2 sentences) |
|-------|------------------------|
| **Bug** | Code does the wrong thing — wrong output, wrong error path, wrong API call. The fix is a code change. |
| **Identity** | The change/code/doc/decision moves PentaTile toward TileMapDual's surface area or hot-path complexity (terrain peering, watcher fanout, persistent cache, parallel painting API, EditorInspectorPlugin polish). The fix is a removal or simplification. |
| **Goal-misalignment** | The code/doc contradicts a project goal — out-of-scope feature creep, breaks a "works in my game" pragma, claims completeness on something that's actually deferred. The fix is a scope correction. |
| **Doc** | Doc-comment is missing, wrong, misleading, contradicts code, uses wrong BBCode/structural tag, or doesn't follow Godot's official format. The fix is a doc change. |
| **Design** | Architecture or pattern choice is debatable — could be cleaner, could be more idiomatic, could match an existing project pattern better. The fix is a refactor. NOT a bug. |

### Finding ID Format

Per Phase 2's `WR-{NN}` precedent, generalized for two reviewers:

```
{TOOL}-{SEVERITY-LETTER}-{NN}
```

Where `{TOOL}` is `GEMINI` or `CODEX`; `{SEVERITY-LETTER}` is `C` (Critical), `H` (High), `M` (Medium), `L` (Low), `I` (Info); `{NN}` is a zero-padded sequence within tier per reviewer.

Examples: `GEMINI-H-01`, `GEMINI-H-02`, `GEMINI-M-01`, `CODEX-C-01`, `CODEX-I-07`.

### `04-{TOOL}-REVIEW.md` Schema (Raw Findings)

Required frontmatter + per-finding fields:

```markdown
---
phase: 04-fallback-routing
reviewer: gemini  # or codex
reviewed_at: 2026-04-29T...
files_reviewed:
  - addons/penta_tile/penta_tile_map_layer.gd
  - addons/penta_tile/...
findings:
  critical: 0
  high: 2
  medium: 5
  low: 8
  info: 3
  total: 18
---

# Phase 4: Cross-AI Review Report (Gemini)

## Summary
{1-paragraph overall assessment}

## High

### GEMINI-H-01: {one-line title}

**File:** `addons/penta_tile/penta_tile_map_layer.gd:{line range}`
**Theme:** Bug | Identity | Goal-misalignment | Doc | Design  (pick one)
**Finding:** {what's wrong, 1-3 sentences}
**Suggested fix:** {what to change, 1-3 sentences with code if useful}
**Rationale:** {why it matters — links to identity guardrail / pitfall / locked decision / requirement / Godot best practice as appropriate}

### GEMINI-H-02: ...

## Medium

### GEMINI-M-01: ...

## Low

### GEMINI-L-01: ...

## Info

### GEMINI-I-01: ...
```

**Reviewer prompt requirement:** the prompt must instruct each reviewer to populate every field above. Missing file/line numbers fall under § 9 (reviewer-hallucination risk) and trigger a verify-before-applying step.

### `04-{TOOL}-REVIEW-FIX.md` Schema (Disposition Log)

Per Phase 2's WR-fix table style, extended with disposition column per D-04-13/14:

```markdown
---
phase: 04-fallback-routing
reviewer: gemini  # or codex
fixed_at: 2026-04-29T...
findings_total: 18
applied: 7
applied_partial: 1
rejected_disqualification: 5
rejected_other: 0
deferred: 5
---

# Phase 4: Review-Fix Log (Gemini)

## Disposition Table

| ID | Severity | Theme | File | Disposition | Commit | Rationale |
|----|----------|-------|------|-------------|--------|-----------|
| GEMINI-H-01 | High | Bug | penta_tile_map_layer.gd:64 | applied | abc1234 | Auto-applied per D-04-13 (High = auto). |
| GEMINI-H-02 | High | Doc | layouts/penta_tile_layout.gd:1 | applied | def5678 | Auto-applied per D-04-13. |
| GEMINI-M-01 | Medium | Design | penta_tile_synthesis.gd:45 | applied | 9abcdef | User-approved per D-04-13 (Medium = gated). Approved 2026-04-29. |
| GEMINI-M-02 | Medium | Design | layouts/penta_tile_layout_penta.gd:120 | rejected-disqualification | — | Proposes forward-compat versioning field per D-04-14 (no-forward-compat). |
| GEMINI-L-01 | Low | Doc | penta_tile_map_layer.gd:200 | deferred | — | Cosmetic; user defers to v0.3+. Logged in CONTEXT.md `## Deferred Ideas`. |
| GEMINI-I-03 | Info | Identity | — | rejected-disqualification | — | Suggests Phase 5 LOC trim per D-04-14 (Phase 5 territory). |

## Applied Fixes (Detail)

### GEMINI-H-01 — Commit `abc1234`
{1-3 sentence description of the fix as actually committed}

### ...

## Rejected Findings (Detail)

### GEMINI-M-02 — Disqualified (no-forward-compat)
{1-3 sentence description of why this is disqualified}

### ...

## Deferred Findings (to v0.3+)

### GEMINI-L-01 — Deferred to CONTEXT.md `## Deferred Ideas`
{paste the deferral rationale}
```

**Disposition values:**
- `applied` — fix shipped in a single commit (atomic per D-04-15).
- `applied-partial` — fix shipped but reviewer's full suggestion not adopted; rationale notes the deviation.
- `rejected-disqualification` — finding hits one of the § 5 disqualification triggers; NO commit.
- `rejected-other` — finding rejected for a different reason (e.g., reviewer misread the code, finding is incorrect); rationale required.
- `deferred` — finding is valid but punted to v0.3+/v2; logged in CONTEXT.md `## Deferred Ideas` per the GSD pattern; NO commit in Phase 4.

## 5. Standard Disqualification Checklist

[VERIFIED: D-04-14 in CONTEXT.md, REQUIREMENTS.md "Out of Scope" + v2 Requirements + v0.3+ deferred items, STATE.md decisions D-72/D-73/D-86, CLAUDE.md Breaking Changes Policy + Coined-Term Discipline]

A finding is "not valid" (recorded but NOT applied) when ANY of the following triggers fire. Implementer scans the finding and applies this list in ≤ 30 seconds.

### Hard Triggers (Auto-Reject)

1. **Backwards-compat shim / deprecation alias / version-detection branch / migration fallback.**
   - Examples: "add `@export var legacy_template_image` that aliases `bitmask_template`"; "branch on engine version"; "preserve v0.1 behavior under flag X."
   - Rule: CLAUDE.md HARD RULE — Breaking Changes Policy. NEVER write compat shims. CHANGELOG entries are the only acceptable compat work.

2. **Forward-compat versioning field / schema marker / speculative extension point.**
   - Examples: "add `version: int = 1` to `PentaTileLayout`"; "introduce `PentaTileLayoutFormatVersion` enum for future migration"; "expose virtual `get_extended_metadata()` for future custom data."
   - Rule: CLAUDE.md HARD RULE — no-forward-compat policy. YAGNI applies hardest to versioning machinery.

3. **Feature deferred to v0.3+ or v2** (per REQUIREMENTS.md):
   - `TBT-01-DEFERRED` (PentaTileLayoutTilesetterWang15)
   - `TBT-02-DEFERRED` (PentaTileLayoutTilesetterBlob47)
   - `TEMPLATE-02-DEFERRED` (Tilesetter half of bundled PNG sweep)
   - `VAR-01` (Y-axis variation)
   - `VAR-PIXEL-01` (PixelLab variation-bank pick)
   - `TOP-01` (top-tile support)
   - `NONROT-01` (non-rotating spillover)
   - `MULTITERR-01..05` (multi-terrain in one tileset)
   - `TERRAIN-01` (terrain transition tiles)
   - `RPGM-01..03` (RPG Maker A2/A4/Sub-Blob)
   - `IMPORT-01/02` (Tiled / LDtk importers)
   - `TOOL-01..04` (PentaBake, converter, collision tools, MkDocs)
   - `PERF-01/02` (shader fallback, large-map benchmarks)
   - `DIST-01/02` (Asset Library, GUT)

4. **Phase 5 territory** (per ROADMAP):
   - LOC trim / formal TileMapDual surface comparison.
   - README sections: "Layouts" / "Upgrading from 0.1.x" / "Authoring a Custom Layout" (DOC-01..03).
   - CHANGELOG.md v0.2.0 entry (DOC-04).
   - Demo refresh showcasing all 8/10 layouts (DEMO-01..03).
   - `plugin.cfg` version bump 0.1.0 → 0.2.0 (REL-01).
   - Git tag `v0.2.0` (REL-02).
   - GitHub Release zip (REL-03).

5. **`addons/penta_tile/ATTRIBUTION.md` proposal** — banned per D-72 / D-73. The README footnote acknowledging TileBitTools is the ONLY acceptable attribution surface.

6. **Coined-Term Discipline violation** — proposing a "Penta" prefix for a non-5-archetype subsystem (e.g., "PentaCache," "PentaDecoder," "PentaToolkit," "PentaBank"). Rule: per CLAUDE.md, "Penta" is reserved for the 5-archetype tileset format only.

7. **Locked-decision contradiction** — finding contradicts any `D-XX` entry in:
   - `04-CONTEXT.md` (D-04-01 through D-04-16)
   - Prior phase CONTEXT.md files (D-01-XX, D-02-XX, D-03-XX, D-86, D-87, D-88..D-105)
   - `.planning/PROJECT.md` Key Decisions
   - `.planning/STATE.md` Decisions list

### Soft Triggers (Apply Judgment)

8. **"Could be more idiomatic"** without a concrete bug or guardrail — Design theme finding at Low/Info severity. Apply if cheap; defer otherwise.

9. **"Add more tests"** — Phase 4 has a defined test surface (the new `fallback_routing_test.gd`). Adding peripheral tests is Phase 5 / Phase 4-extension territory unless the reviewer identifies a specific regression risk.

### Disposition Workflow

Per finding (≤ 30 seconds):

1. Read finding ID + Severity + Theme + Suggested fix.
2. Scan triggers 1-7 above. If any fires → `rejected-disqualification`. Note which trigger in rationale.
3. If no trigger fires → finding is valid. Apply per § 7 severity-tiered policy.

## 6. Atomic-Commit-Per-Fix Pattern

[VERIFIED: Phase 2's 7 WR fixes (commits `ea0ba23`, `ae5d787`, `9ca342e`, `d74df0e`, `2ca04e0`, `720f017`, `79af1e3`) per `02-REVIEW.md` summary table]

### Commit Message Format

```
fix(04): {FINDING-ID} — {one-line description}
```

Examples:
- `fix(04): GEMINI-H-01 — restore @experimental tag on PentaTileLayout class doc`
- `fix(04): CODEX-M-03 — clarify _make_slot axis-invariance contract in doc-comment`
- `fix(04): GEMINI-H-04 — wire fallback re-route on tile_set clear`

The leading `fix(04):` matches the existing project commit-style convention (`docs($PHASE):`, `feat($PHASE):`, `test($PHASE):` in recent commits like `5a02d8d`, `cb740b9`, `9f74a87`). The em-dash (`—`) separator matches Phase 2's WR-fix style. The finding ID format matches § 4.

### Multi-File Fixes

Per Phase 2's WR-01 precedent (`ae5d787` touched `penta_tile_synthesis.gd` AND added test code AND updated a comment): **multi-file fixes go in ONE commit when they implement a SINGLE finding**. The commit message references one finding ID; the fix may span the layout file + the doc-comment + a test update if those are logically the same fix.

**One finding = one commit. One commit = one finding.** Never bundle two findings in one commit; never split one finding across two commits.

### Findings That Touch the Same Line

[ASSUMED — Phase 2 didn't hit this case explicitly] When a later finding's fix touches a line already modified by a prior finding's fix in the same review pass: apply **sequentially**, NOT via rebase. The second commit builds on the first. The disposition table in REVIEW-FIX.md captures both commits independently with their respective SHAs.

If two findings genuinely conflict (their suggested fixes are mutually exclusive): apply judgment, pick one, log the rejected one as `rejected-other` with rationale "conflicts with {OTHER-ID}; chose other fix because [reason]."

### Rejected-Disqualification Findings

NO commit. Only a row in `04-{TOOL}-REVIEW-FIX.md` with `disposition: rejected-disqualification` + the trigger that fired (per § 5). The codebase doesn't change; the audit trail is the disposition log.

### Deferred Findings

NO commit in Phase 4. Add a row in `04-{TOOL}-REVIEW-FIX.md` with `disposition: deferred`. Then append the finding to `04-CONTEXT.md` `## Deferred Ideas` section (or to a future phase's CONTEXT.md if pre-planned). The disposition log remains the source of truth.

## 7. Severity-Tiered Fix-Application Policy

Concretizing D-04-13:

### Critical / High → Auto-Apply

**Boundary:**
- **Critical:** security / data-loss class bug; runtime exception in autotile hot path; saved scene corruption; demo refuses to load.
- **High:** correctness regression; broken locked contract (PREVIEW-03/04 wiring breaks; AUTO_STRIP dispatch breaks); identity-guardrail violation (terrain peering, watcher fanout, persistent cache); locked-decision contradiction (D-XX); coined-term violation; broken Godot doc-comment format.

**Workflow:**
1. Implementer reads finding.
2. Scan disqualification list (§ 5). If trigger fires → `rejected-disqualification`. STOP.
3. Implement fix.
4. Atomic commit per § 6 format.
5. Update `04-{TOOL}-REVIEW-FIX.md` row: disposition=`applied`, commit SHA, rationale.

NO user prompt at any step. (User signs off in aggregate when the phase closes.)

### Medium → User-Gated

**Boundary:** quality issue with debatable fix. Examples: "this method's doc could be clearer about the failure mode"; "this `Image.save_png()` debug call should probably be removed."

**Workflow:**
1. Implementer reads finding.
2. Scan disqualification list. If trigger fires → `rejected-disqualification`. STOP.
3. Propose the fix to the user (1 paragraph: what / why / commit message). Wait for approval.
4. On approval: implement, atomic commit, update REVIEW-FIX.md `disposition=applied`.
5. On rejection: update REVIEW-FIX.md `disposition=rejected-other` with user's rationale.

### Low / Info → Logged + User Picks

**Boundary:** cosmetic / style polish / future-phase hint / observation.

**Workflow:**
1. Implementer reads finding.
2. Scan disqualification list. If trigger fires → `rejected-disqualification`. STOP.
3. Surface the finding in the phase summary (e.g., REVIEW-FIX.md "Low/Info Findings" section).
4. User picks: apply (treat as Medium workflow) | defer (log to `04-CONTEXT.md ## Deferred Ideas` or a future phase's CONTEXT.md, disposition=`deferred`).

### Reviewer Output Expectations

For automatic dispatch to work cleanly, each finding in `04-{TOOL}-REVIEW.md` MUST include:

- `Severity: Critical | High | Medium | Low | Info` — exactly one of these five values, capitalized.
- `Theme: Bug | Identity | Goal-misalignment | Doc | Design` — exactly one of these five.
- `File: path:line-range` — concrete path and line numbers (defends against reviewer hallucination per § 9).
- `Finding:` — what's wrong.
- `Suggested fix:` — proposed change.
- `Rationale:` — why it matters (with cross-reference to identity guardrail / pitfall / locked decision / requirement).

The reviewer prompt template in § 4 enforces this schema. Findings missing required fields trigger a clarifying re-query OR (more pragmatically) implementer-judgment fill-in noted in REVIEW-FIX.md rationale.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Custom GDScript test harness via `SceneTree`-based scripts under `addons/penta_tile/tests/` (no GUT — per CLAUDE.md "no third-party deps"). |
| Config file | `addons/penta_tile/tests/run_tests.ps1` (PowerShell registry / runner). |
| Quick run command | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -Test fallback_routing_test -NoPause` |
| Full suite command | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` (currently 17 tests; Phase 4 adds 1 → 18) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| **PREVIEW-03** | `tile_set == null` + `layout != null` → layer renders via `layout.get_fallback_tile_set()`. Visible output for all 8 layouts. | unit (composed-canvas) | `pwsh -File addons/penta_tile/tests/run_tests.ps1 -Test fallback_routing_test -NoPause` | ❌ Wave 0 — must be created. |
| **PREVIEW-04** | Assigning `tile_set` directly overrides fallback (no warnings, no errors). Clearing → re-routes to fallback. | unit (state-flag assertion) | Same command — assertions live in same test file. | ❌ Wave 0. |
| **(D-04-06 manual)** | Demo eyeball pass on all 8 layouts. | manual-only | `04-FALLBACK-UAT.md` artifact + screenshots. | ❌ Wave 0. |

### Sampling Rate

- **Per task commit:** `pwsh -File addons/penta_tile/tests/run_tests.ps1 -Test fallback_routing_test -NoPause` (the new test alone, ~1 second wall-clock).
- **Per wave merge:** `pwsh -File addons/penta_tile/tests/run_tests.ps1 -NoPause` (full 18-test suite, ~30 seconds wall-clock).
- **Phase gate:** Full suite green BEFORE the 4 close-out artifacts commit AND ROADMAP `[x]` flips. Per D-04-16, ALL FOUR artifacts (`04-FALLBACK-UAT.md`, `04-DOC-SWEEP.md`, `04-GEMINI-REVIEW-FIX.md`, `04-CODEX-REVIEW-FIX.md`) must exist + be committed.

### Wave 0 Gaps

- [ ] `addons/penta_tile/tests/fallback_routing_test.gd` — covers PREVIEW-03 + PREVIEW-04. New file; uses the composed-canvas pipeline from § 2; pattern matrix is 8 layouts × 1 (or 2) simple patterns.
- [ ] `addons/penta_tile/tests/run_tests.ps1` — registry append (line 53-71): add `"fallback_routing_test"` to `$allTests` array.
- [ ] `04-FALLBACK-UAT.md` — manual UAT sign-off artifact. New file in `.planning/phases/04-fallback-routing/`.

*(No framework install needed — `SceneTree`-based testing is native Godot 4.6.)*

### Validation Layers

1. **Test layer:** the new `fallback_routing_test.gd`. Asserts (a) all 8 layouts produce visible output under `tile_set = null` (composed-canvas non-empty bbox + per-cell solidity per § 2); (b) PREVIEW-04 contract — `_tile_set_is_fallback` flips to false on direct `tile_set` write, flips to true on fallback re-route. Failure modes caught: any layout's `get_fallback_tile_set()` returning null; any layout's bundled bitmask PNG missing/corrupt; the layer's auto-fill chain breaking; the `_set` user-override hook (`penta_tile_map_layer.gd:92-96`) breaking.

2. **Manual-UAT layer:** `04-FALLBACK-UAT.md` — human eyeball pass on `addons/penta_tile/demo/penta_tile_demo.tscn` with each of the 8 layouts swapped in. Catches: rendering bugs that only show up in the editor's preview (not headless), bundled bitmask PNGs that are technically valid but visually wrong, `tile_set = null` UX regressions (e.g., editor refusing to engage TileMap pane).

3. **Cross-AI review layer:** Gemini + Codex passes are validation surfaces in their own right. They review the PREVIEW-03/04 wiring, the doc-sweep output, the test file, and the codebase as a whole against TileMapDual identity guardrails + CLAUDE.md hard rules. Findings ladder per § 4-5-7.

4. **Phase-close gate:** all 4 artifacts must commit. ROADMAP Phase 4 row flips to `[x]` ONLY when:
   - `04-FALLBACK-UAT.md` ✓ (manual UAT sign-off)
   - `04-DOC-SWEEP.md` ✓ (doc-sweep before/after summary)
   - `04-GEMINI-REVIEW-FIX.md` ✓ (Gemini findings dispositioned + commits referenced)
   - `04-CODEX-REVIEW-FIX.md` ✓ (Codex findings dispositioned + commits referenced)
   - Full test suite green (all 18 tests).

## 8. Phase 4-Specific Pitfalls

### Doc-Comment Sweep Risks

1. **Single-`#` interruption inside a `##` block.** A stray `#` line breaks doc-comment association silently (Godot drops the doc, the help viewer shows nothing). Guard rule for the sweep: NO single-`#` lines inside a `##` block. Verify by grepping each post-sweep file for `^##` followed by `^#[^#]` followed by `^##`. The existing 3 exemplary blocks have no `#` interruptions — preserve that.

2. **Single-`##` accidental promotion of explanatory `#` comments.** The current `penta_tile_map_layer.gd` has rich `#` (single-hash) prose comments explaining the WHY of internal logic (e.g., the long comment block at lines 27-34 above the `layout` setter). DO NOT promote those to `##` wholesale — they're internal explanation, not public-facing doc. Per D-04-02 the rule is: class-level `##` block + `##` on every public method + `##` on every `@export` property + `##` on private `_foo` methods only when WHY is non-obvious. Internal `#` prose stays `#`.

3. **`@deprecated` on an in-use surface.** `@deprecated` is a STRONG signal — Godot's editor shows the deprecation icon in the help viewer. DO NOT add `@deprecated` to anything the codebase still calls or the user might reasonably use. Phase 4's only `@deprecated` candidates are surfaces that are documented in CHANGELOG as removed in v0.2 — but those are already DELETED, not deprecated. Recommendation: Phase 4 uses ZERO `@deprecated` tags. `@experimental` on the `PentaTileLayout` subclassing surface (per D-04-03) is the only structural status tag the sweep adds.

4. **Property-rename trap (CLAUDE.md Pitfall #3 / PITFALLS §6).** Phase 4 should NOT rename any properties. The doc-comment sweep is annotation-only. If the implementer or a reviewer proposes a rename mid-sweep: route to a separate phase / commit, with `@export_storage` shadow + CHANGELOG entry. Rationale: doc-sweeps that piggyback renames orphan saved scenes silently — the demo `.tscn` and the bundled `.tres` files in `addons/penta_tile/demo/` would lose configuration.

5. **`@experimental` placement scope.** Per D-04-03 and the official Godot docs, `@experimental` can go at script-level (whole class is experimental) OR at member-level (single method/property is experimental). For `PentaTileLayout`, the class-level `@experimental` flag in the existing `## ` block at `layouts/penta_tile_layout.gd:1-12` is the right placement — signals to subclassers that the API is unstable. Don't proliferate `@experimental` onto every member; one tag at the class level is sufficient.

6. **BBCode tag closing rules.** `[code]...[/code]`, `[codeblock]...[/codeblock]`, `[b]...[/b]` etc. require explicit closing tags. Self-closing tags like `[br]` don't. A missing close tag silently breaks the doc rendering. Guard: paste the doc into the Godot editor's help viewer (`F1 → search class name`) at least once during sweep verification.

### Fallback-UAT Risks

7. **Synthesis ordering bug under `tile_set = null`.** The fallback path is HOT in Phase 4 — every paint with `tile_set = null` runs the full `get_fallback_tile_set()` codegen. If the codegen has a synthesis-ordering bug (e.g., Penta's `synthesize_strip` getting called before the bitmask PNG fully loads in headless mode), it manifests as empty tiles only under fallback, not under user-supplied `tile_set`. The composed-canvas test in § 2 catches this at PASS/FAIL boundary; the manual UAT catches the visual artifact tier (e.g., one tile missing in an 8×8 grid).

8. **`TileMapLayer.visible = false` cleanup behavior (CLAUDE.md Pitfall #7).** Already mitigated in v0.1 via `self_modulate.a` on the logic layer (NOT `visible = false`). Don't regress in Phase 4 — the doc sweep on `penta_tile_map_layer.gd` should NOT touch the `_apply_logic_layer_opacity()` path. The composed-canvas test under fallback EXERCISES this surface (fallback engages → autofill happens → if anything went wrong with `visible = false` it would manifest as empty render); failure mode is covered.

9. **`_init` vs setter race for default layout.** `penta_tile_map_layer.gd:134-154` runs `_init` to mirror the auto-fill chain for the default-instantiated `PentaTileLayoutPenta` (the default value of the `@export var layout`). If the doc sweep on `penta_tile_map_layer.gd` accidentally wraps `_init` in a `##` block that breaks association with the `func _init()` declaration, the auto-fill silently breaks for fresh nodes. Guard: the sweep treats `_init` as private (`_` prefix), so per D-04-02 it gets a `##` doc-comment ONLY if the WHY is non-obvious — and it IS non-obvious here (Godot 4 doesn't fire `@export` setters for default values). Recommendation: include a `##` block on `_init` explaining this race.

### Cross-AI Review Risks

10. **Reviewer hallucination — invented file/line/code.** Both Gemini and Codex can hallucinate file paths, line numbers, or code snippets that don't match reality. Mitigation: the REVIEW.md schema in § 4 REQUIRES `File: path:line-range` per finding. The implementer MUST verify each finding's file/line/code against the actual codebase BEFORE applying. If verification fails → `rejected-other` with rationale "reviewer hallucination — line {N} contains different code than cited."

11. **Reviewer confusion about "Penta" coined term.** Both reviewers see "PentaTile" + "Penta" + "PentaTileLayoutPenta" + "PentaTileSynthesis" and may propose generic "Penta" prefixes for unrelated subsystems (e.g., "PentaCache" for a memoization layer, "PentaToolkit" for a utility class). This is a Coined-Term Discipline violation per CLAUDE.md and a § 5 disqualification trigger. Mitigation: each reviewer prompt MUST include the CLAUDE.md "Coined-Term Discipline" section verbatim. Suggested prompt fragment:

    > **CONSTRAINT (HARD):** "Penta" is reserved exclusively for the 5-archetype tileset format. Never coin "Penta" prefixes for unrelated subsystems. Findings that propose such prefixes will be rejected as Coined-Term Discipline violations per CLAUDE.md.

12. **Reviewer suggests TileMapDual-style features.** Reviewers comparing PentaTile against TileMapDual may suggest "while you're here, consider adding terrain peering / watcher pattern / persistent cache." These are Identity-theme HIGH findings if the reviewer presents them as bugs ("PentaTile is missing X"), but PROJECT.md identity constraint says PentaTile must remain "visibly smaller and simpler than TileMapDual" — these are disqualified per § 5 trigger 7 (locked-decision contradiction with PROJECT.md). Mitigation: prompt MUST include the PROJECT.md identity constraint + the CLAUDE.md Identity Guardrails list (no terrain peering / watchers / parallel APIs / persistent cache / EditorInspectorPlugin polish) verbatim.

13. **`gemini -p` PowerShell quoting on Windows.** Multi-line prompts with embedded backticks, dollar signs, or quotes are fragile on Windows PowerShell. Use STDIN redirection (`Get-Content prompt.md | gemini -p -`) instead of inline `-p "$(cat ...)"` to avoid shell-escape gotchas. The `cat | gemini -p -` pattern is stdlib-safe; the `gemini -p "$(cat)"` pattern breaks on `"`s in the prompt.

14. **`codex exec --skip-git-repo-check -` swallows shell errors.** If the codex command fails (e.g., model unavailable, network error), the output file may be empty or contain a stub error message. Always check `[ -s 04-CODEX-REVIEW.md ]` after invocation; on empty, retry with explicit model override OR fall back to `codex review` subcommand.

## 9. Out-of-Scope Triple-Check

Items reviewers may propose that should immediately route to Phase 5 / v0.3+ backlog and NOT be applied in Phase 4:

| Proposal | Routes To | Why |
|----------|-----------|-----|
| LOC trim / formal TileMapDual surface comparison | Phase 5 | D-04-08 — Phase 5 owns the formal audit. Phase 4 surfaces identity violations qualitatively only. |
| README "Layouts" / "Upgrading from 0.1.x" / "Authoring a Custom Layout" sections | Phase 5 (DOC-01..03) | ROADMAP Phase 5 entry. |
| CHANGELOG.md v0.2.0 entry naming all breaking changes | Phase 5 (DOC-04) | ROADMAP Phase 5 entry. |
| Demo refresh showcasing all 10 layouts (runtime layout switching OR side-by-side) | Phase 5 (DEMO-01..03) | ROADMAP Phase 5 entry. |
| `plugin.cfg` version bump 0.1.0 → 0.2.0 | Phase 5 (REL-01) | ROADMAP Phase 5 entry. |
| Git tag `v0.2.0` | Phase 5 (REL-02) | ROADMAP Phase 5 entry. |
| GitHub Release zip `penta_tile-v0.2.0.zip` | Phase 5 (REL-03) | ROADMAP Phase 5 entry. |
| `addons/penta_tile/ATTRIBUTION.md` (any form) | NEVER (banned) | D-72 / D-73 — README footnote is the only attribution surface. The audit deliverable `03-TBT-DEEP-AUDIT.md` reads TBT source for design analysis only; nothing is lifted. |
| `PentaTileLayoutTilesetterWang15` / `PentaTileLayoutTilesetterBlob47` | v0.3+ backlog | TBT-01-DEFERRED / TBT-02-DEFERRED per D-86 (b). |
| Tilesetter half of bundled bitmask PNG sweep | v0.3+ backlog | TEMPLATE-02-DEFERRED. |
| Variation-bank deterministic pick for PixelLab layouts | v2 backlog | VAR-PIXEL-01 per D-91 — design-coupled with VAR-01 + MULTITERR-01. |
| Y-axis variation via `TileData.probability` + deterministic hash | v2 backlog | VAR-01. |
| Top-tile support (designated top-edge visuals) | v2 backlog | TOP-01. |
| Multi-terrain in one tileset (Y-axis-as-terrain for strip layouts; multiple atlas sources for block layouts) | v2 backlog | MULTITERR-01..05. |
| Outer transition tiles (terrain-to-terrain blending) | v2 backlog | TERRAIN-01. |
| RPG Maker A2/A4 subtile compositor / Sub-Blob 20 / Micro-Blob 13 | v0.3+ backlog | RPGM-01..03. |
| Tiled `.tsx` Wang Set rule importer / LDtk `.ldtk` rule importer | v0.3+ backlog | IMPORT-01..02. |
| Shader fallback for diagonal compositing | v2 backlog | PERF-01. |
| Large-map perf benchmarks (>10k cells) | v2 backlog | PERF-02. |
| Godot Asset Library submission | v2 backlog | DIST-01. |
| Formal automated test suite (GUT or similar) | v2 backlog | DIST-02. |
| `EditorInspectorPlugin` polish for layout authoring | v2 backlog (likely never per Identity Guardrails) | PROJECT.md "Out of Scope" — TileMapDual territory. |
| Doc-coverage lint test | v0.3+ if doc rot becomes a problem | D-04-04 / CONTEXT.md `## Deferred Ideas`. |
| Three-reviewer pass (Gemini + Antigravity + Codex) | NEVER for Phase 4 | D-04-09 — Antigravity is IDE-only. |
| `version: int` field on `PentaTileLayout` or any Resource | NEVER (banned) | CLAUDE.md no-forward-compat hard rule. |
| Backwards-compat shim for `template_image` / `fallback_tile_set` / `decoder_image` / `PentaTileAtlasContract` | NEVER (banned) | CLAUDE.md no-backwards-compat hard rule; v0.1 → v0.2 is a clean break. |
| New `## ` block on `tests/` or `demo/` scripts | Out of scope | D-04-01 — sweep is the 12 addon scripts only. |
| Refactor away `_pack_alternative` helper (currently unused — only set to 0 by all 8 layouts) | v2 backlog (when variation work reopens) | IN-01 / IN-09 from `02-REVIEW.md` — Phase 3.5 / variation territory. |

When a reviewer finding lands on any of these items, the implementer scans, identifies the trigger, and dispositions as `rejected-disqualification` with the specific trigger cited (e.g., "D-04-14 trigger 4 — Phase 5 territory (LOC trim)").

## Code Examples

### Doc-Comment Style — Class-Level Block

[VERIFIED: pattern from `addons/penta_tile/penta_tile_synthesis.gd:1-19`]

```gdscript
@tool
## One-line brief description (sentence-cased, period-terminated).
##
## Longer detail paragraph. Mentions slot ordering / mask convention where
## relevant. Cross-references via [member], [method], [Class].
##
## Determinism / contract invariants stated as bullets:
##   - Invariant 1.
##   - Invariant 2.
##
## See:
##   - .planning/research/PITFALLS.md §N
##   - .planning/phases/0X-name/0X-NAME.md Gate Y
##
## @experimental
class_name PentaTileLayout
extends Resource
```

### Doc-Comment Style — Public Method

```gdscript
## Compute the layout-specific mask for [param coord] using [param sample_fn]
## as the neighbor-presence query.
##
## Returns the mask integer the layout's [method mask_to_atlas] consumes.
##
## [param coord] - the logic-grid coordinate being computed.
## [param sample_fn] - Callable taking Vector2i, returning bool (true=painted).
func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
    push_error("PentaTileLayout.compute_mask must be overridden by subclass")
    return 0
```

### Doc-Comment Style — `@export` Property

```gdscript
## Source TileSetAtlasSource ID for atlas reads. -1 means "use the first
## TileSetAtlasSource discovered in [member tile_set]." Set explicitly only
## when the user's TileSet has multiple sources and one of them isn't index 0.
@export var atlas_source_id: int = -1:
    set(value):
        atlas_source_id = value
        _queue_rebuild()
```

### Composed-Canvas Test Skeleton

[VERIFIED: distilled from `comprehensive_bitmask_test.gd` + `penta_ground_hollow_test.gd` + `pixellab_visual_regression_test.gd`]

```gdscript
## Fallback routing UAT: paints a small pattern with each of the 8 actually-
## shipped layouts under tile_set = null, asserts visible composed-canvas
## output for every painted cell. Verifies PREVIEW-03 + PREVIEW-04.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/fallback_routing_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
# ... 7 more layout preloads ...

var _failures: Array = []

func _initialize() -> void:
    print("=== fallback_routing_test ===")

    var pattern: Array = [
        Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
        Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
        Vector2i(0,2), Vector2i(1,2), Vector2i(2,2),
    ]   # 3x3 — exercises masks 0..15 across single + dual grid

    var layouts: Array = [
        {"name": "Penta",                "script": _PentaScript},
        {"name": "DualGrid16",           "script": _DualGrid16Sc},
        {"name": "Wang2Edge",            "script": _Wang2EdgeSc},
        {"name": "Wang2Corner",          "script": _Wang2CornerSc},
        {"name": "Min3x3",               "script": _Min3x3Sc},
        {"name": "Blob47Godot",          "script": _Blob47GodotSc},
        {"name": "PixelLabTopDown",      "script": _PixelLabTopDownSc},
        {"name": "PixelLabSideScroller", "script": _PixelLabSideScrollerSc},
    ]

    for layout_def: Dictionary in layouts:
        await _test_fallback(layout_def, pattern)

    # PREVIEW-04 contract: assigning + clearing tile_set
    await _test_preview_04_override()
    await _test_preview_04_reroute()

    print("\n=== summary ===")
    if _failures.is_empty():
        print("ALL PASS")
        quit(0)
    else:
        printerr("FAIL (%d):" % _failures.size())
        for f in _failures:
            printerr("  - " + f)
        quit(1)


func _test_fallback(layout_def: Dictionary, pattern: Array) -> void:
    var layer = _LayerScript.new()
    layer.layout = layout_def.script.new()    # auto-fills tile_set from fallback
    get_root().add_child(layer)
    await process_frame
    await process_frame

    # PREVIEW-03 sanity: tile_set MUST be auto-filled.
    if layer.tile_set == null:
        _record(layout_def.name, "PREVIEW-03 — tile_set still null after layout assignment")
        layer.queue_free()
        return
    if not layer.get("_tile_set_is_fallback"):
        _record(layout_def.name, "_tile_set_is_fallback flag should be true after auto-fill")

    for c: Vector2i in pattern:
        layer.set_cell(c, 0, Vector2i(0, 0))
    await process_frame
    layer.rebuild()
    await process_frame

    # Compose canvas + assert non-empty bbox + per-cell solidity.
    var canvas: Image = _compose_rendered_canvas(layer, pattern)
    if not _has_opaque_pixels(canvas):
        _record(layout_def.name, "composed canvas is empty under tile_set = null")
        # Save PNG for eyeball debug per CLAUDE.md Test Methodology #4
        canvas.save_png("user://fallback_%s.png" % layout_def.name)

    layer.queue_free()


func _test_preview_04_override() -> void:
    # Assigning tile_set directly flips _tile_set_is_fallback to false.
    var layer = _LayerScript.new()
    layer.layout = _PentaScript.new()
    get_root().add_child(layer)
    await process_frame

    var custom = TileSet.new()
    layer.tile_set = custom
    if layer.get("_tile_set_is_fallback"):
        _record("PREVIEW-04", "_tile_set_is_fallback should flip to false after direct assignment")
    layer.queue_free()


func _test_preview_04_reroute() -> void:
    # Clearing tile_set re-routes to fallback.
    var layer = _LayerScript.new()
    layer.layout = _PentaScript.new()
    get_root().add_child(layer)
    await process_frame
    layer.tile_set = null
    layer.layout = _PentaScript.new()    # trigger setter to re-fill
    if layer.tile_set == null:
        _record("PREVIEW-04", "tile_set should re-fill from fallback after clear + layout reassign")
    layer.queue_free()
```

### Reviewer Prompt Template (Reusable for Both Gemini and Codex)

```markdown
# PentaTile v0.2.0 — Phase 4 Code Review Request

You are reviewing the PentaTile addon (Godot 4.6 / GDScript dual-grid autotiler) at
the close of Phase 4 (Fallback Routing + Doc Sweep + Cross-AI Review).

## Scope

Review the following surfaces against the project's locked goals:

**Codebase:** `addons/penta_tile/` (12 GDScript files + supporting tests under `tests/`).

**Project context (HARD CONSTRAINTS):**
- `.planning/PROJECT.md` — vision, identity guardrail ("PentaTile must remain visibly
  smaller and simpler than TileMapDual"), out-of-scope list.
- `.planning/REQUIREMENTS.md` — v1 requirement IDs Phase 4 closes (PREVIEW-03/04) +
  v2/v0.3+ deferred list (which a finding MUST NOT re-propose).
- `.planning/ROADMAP.md` — Phase 4 entry + Phase 5 entry (the latter defines what
  Phase 4 explicitly does NOT own).
- `CLAUDE.md` — including the **HARD RULES** sections:
  - Identity Guardrails: never recommend terrain peering, watcher patterns,
    persistent caches, parallel painting APIs, EditorInspectorPlugin polish.
  - Breaking Changes Policy (HARD RULE): never propose backwards-compat shims,
    deprecation aliases, version-detection branches, OR forward-compat versioning
    fields, schema markers, speculative extension points.
  - Coined-Term Discipline: "Penta" is reserved for the 5-archetype tileset format
    only. Never coin "Penta" prefixes for unrelated subsystems.
  - Critical Pitfalls #1-10 (esp. #1 alternative_tile bit packing, #2 variation
    determinism, #3 property-rename trap, #5 setter loops, #8/#9/#10 single-grid
    + Penta synthesis traps).

**Comparison target:** TileMapDual public README + repo (https://github.com/pablogila/TileMapDual)
— for surface-area, hot-path simplicity, watcher avoidance, terrain-peering avoidance,
and doc-quality comparison.

## Required Finding Format

For EVERY finding, populate ALL of these fields. Findings missing required fields
will be flagged for re-review.

```
### {TOOL}-{SEVERITY-LETTER}-{NN}: {one-line title}

**File:** `path/to/file.gd:{line_start}-{line_end}`
**Severity:** Critical | High | Medium | Low | Info
**Theme:** Bug | Identity | Goal-misalignment | Doc | Design  (pick exactly one primary)
**Finding:** {what's wrong, 1-3 sentences}
**Suggested fix:** {what to change, 1-3 sentences with code snippet if useful}
**Rationale:** {why it matters — cross-reference to identity guardrail / pitfall /
locked decision (D-XX) / requirement ID / Godot best practice}
```

`{TOOL}` is `GEMINI` or `CODEX` (per the reviewer running this prompt).
`{SEVERITY-LETTER}` is C/H/M/L/I.
`{NN}` is zero-padded sequence within tier.

## Severity Definitions

- **Critical:** Security or data-loss class bug; demo crashes; saved scene corruption.
- **High:** Correctness regression; broken contract; identity-guardrail violation;
  locked-decision contradiction; coined-term violation; broken Godot doc-comment format.
- **Medium:** Quality issue with debatable fix.
- **Low:** Cosmetic / style polish.
- **Info:** Observation without action.

## Theme Definitions

- **Bug:** Code does the wrong thing.
- **Identity:** Code/doc moves PentaTile toward TileMapDual's surface or hot-path
  complexity.
- **Goal-misalignment:** Contradicts a project goal — out-of-scope creep, broken
  pragma, false completeness claim.
- **Doc:** Doc-comment is missing/wrong/misleading or violates Godot's official
  doc-comment format (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html).
- **Design:** Architecture or pattern choice is debatable; could be cleaner. NOT a bug.

## Disqualification Filter (DO NOT PROPOSE THESE)

The implementer will reject findings that propose:

1. Backwards-compat shims, deprecation aliases, version-detection branches.
2. Forward-compat versioning fields, schema markers, speculative extension points.
3. Features deferred to v2 / v0.3+ (TBT-01/02-DEFERRED, VAR-01, VAR-PIXEL-01, TOP-01,
   NONROT-01, MULTITERR-01..05, TERRAIN-01, RPGM-01..03, IMPORT-01/02, TOOL-01..04,
   PERF-01/02, DIST-01/02). Full list in REQUIREMENTS.md "v2 Requirements" section.
4. Phase 5 work (LOC trim, README rewrites, CHANGELOG, demo refresh, plugin.cfg
   bump, GitHub release, ATTRIBUTION.md per D-72/D-73).
5. Coined-Term Discipline violations (any "Penta" prefix on non-5-archetype
   subsystems).
6. Locked-decision contradictions (any D-XX entry in PROJECT.md / STATE.md / phase
   CONTEXT.md files).

If your finding hits any of these, please pre-flag it in the rationale: "May be
disqualified per category {N} — included for completeness."

## Output

Single markdown document. Sort findings by severity (Critical → Info), then by ID.
Include the frontmatter block from the schema.

Begin review.
```

## Sources

### Primary (HIGH confidence)

- **Context7 `/godotengine/godot-docs`** — queries for "GDScript documentation comments syntax @tutorial @experimental @deprecated BBCode tags" and "## comment placement before extends class_name member variable function." Returned canonical examples + tag set + placement rules. (Library ID resolved via `npx ctx7 library godot` returning highest-match score.)
- **Official Godot docs:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html — verified comment placement, structural tag set, BBCode tag set, private-member rules, annotation interaction.
- **`addons/penta_tile/penta_tile_synthesis.gd:1-19`** — exemplary class-level `##` block pattern (slot ordering + invariants + research-doc references).
- **`addons/penta_tile/penta_tile_atlas_slot.gd:1-9`** — exemplary field-by-field `##` block.
- **`addons/penta_tile/layouts/penta_tile_layout.gd:1-12`** — exemplary class-level block with `See:` paragraph linking to research docs.
- **`addons/penta_tile/penta_tile_map_layer.gd:35-96, 134-160`** — PREVIEW-03/04 wiring already in place (the `layout` setter, `_set` user-override hook, `_init` mirror).
- **`addons/penta_tile/tests/comprehensive_bitmask_test.gd:1-100`** — pattern × layout matrix template.
- **`addons/penta_tile/tests/penta_ground_hollow_test.gd:1-130`** — user-fixture composed-canvas template.
- **`addons/penta_tile/tests/run_tests.ps1:53-71`** — current test registry inventory.
- **`.planning/phases/02-native-layouts/02-REVIEW.md`** — severity-tiered + atomic-commit-per-fix precedent (7 WR commits referenced verbatim).
- **`.planning/phases/03.5-pixellab-layouts-variation-seed-wiring/03.5-REVIEWS.md`** — Codex retrospective review precedent + PIXLAB-04 finding pattern.
- **`.planning/research/PITFALLS.md`** — canonical anti-pattern register cited in § 8.
- **`CLAUDE.md`** Identity Guardrails + Breaking Changes Policy + Coined-Term Discipline + Critical Pitfalls + Test Methodology — verbatim hard-rule text used in § 5 / § 8 / § 4 reviewer prompt.
- **`gemini --version` → 0.38.2; `gemini --help` output** — verified `-p` flag, `-m` model flag, `--include-directories` flag, `-o` output-format flag.
- **`codex --version` → codex-cli 0.124.0; `codex review --help`, `codex --help`** — verified `codex review` subcommand exists; verified `codex exec --skip-git-repo-check` precedent from `~/.claude/get-shit-done/workflows/review.md`.

### Secondary (MEDIUM confidence)

- **`~/.claude/get-shit-done/workflows/review.md`** — existing GSD `/gsd-review codex` skill workflow. Documents the `codex exec --skip-git-repo-check -` pattern Phase 3.5 used successfully.
- **`.planning/STATE.md`** — Decisions list including D-72 / D-73 (ATTRIBUTION.md ban), D-86 (Tilesetter defer), D-04-01..16 lineage.
- **`.planning/REQUIREMENTS.md`** — v1 / v2 / Out-of-Scope tables driving § 5 disqualification list.
- **`.planning/ROADMAP.md`** — Phase 4 + Phase 5 entries that scope the out-of-scope triple-check (§ 9).

### Tertiary (LOW confidence — flagged inline as `[ASSUMED]`)

- Gemini model name `gemini-2.5-pro` (current as of April 2026) — verify with `gemini --help` model list at execution time.
- Single-`#` interruption inside a `##` block breaks doc-comment association — not explicitly stated in the official docs, but consistent with Phase 4's exemplary blocks AND with how Godot's parser is documented to extract docs ("must immediately precede the element").
- BBCode tag list is complete — Godot may have added new tags between training cutoff and 2026-04-29; the doc URL is the authoritative source.

## Metadata

**Confidence breakdown:**
- Doc-comment format: **HIGH** — Context7 + official URL + 3 working exemplary blocks in codebase.
- Fallback UAT methodology: **HIGH** — three canonical test files in codebase establish the composed-canvas pattern; CLAUDE.md Test Methodology codifies the rules.
- Cross-AI review tooling: **HIGH** — both CLIs verified installed and headless-capable via `--help` + `--version`. GSD `/gsd-review` workflow precedent confirms the invocation shapes.
- Cross-AI review schema (severity / theme / IDs): **HIGH** — Phase 2 `WR-{NN}` precedent + Phase 3.5 `03.5-REVIEWS.md` precedent + D-04-11 lock.
- Disqualification list: **HIGH** — D-04-14 + REQUIREMENTS.md v2 + STATE.md decisions + CLAUDE.md hard rules cross-verified.
- Severity-tier policy: **HIGH** — D-04-13 lock + WR-fix Phase 2 atomic-commit precedent.
- Phase 4 pitfalls: **MEDIUM** — derived from Critical Pitfalls #1-10 (HIGH) + Phase 4-specific reasoning (lower confidence on the doc-sweep traps which are project-specific predictions).
- Out-of-scope triple-check: **HIGH** — direct mapping from REQUIREMENTS.md / ROADMAP.md / STATE.md.

**Research date:** 2026-04-29
**Valid until:** 2026-05-29 (30 days — Godot 4.6 stable; CLIs in steady state; project hard rules unchanged for the milestone)

## RESEARCH COMPLETE
