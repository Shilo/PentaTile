# Phase 4: Fallback Routing + Doc Sweep + Cross-AI Review — Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 20 (7 NEW + 12 EXISTING addon source + 1 EXISTING test registry)
**Analogs found:** 20 / 20 (every file has at least a role-match analog; one — `04-DOC-SWEEP.md` — is `novel structure proposed` because no prior doc-sweep summary exists in this project)

This phase has three braided deliverables. Pattern assignments are grouped by deliverable so the planner can pull patterns per plan.

---

## File Classification

| New / Modified | File | Role | Data Flow | Closest Analog | Match Quality |
|----------------|------|------|-----------|----------------|---------------|
| NEW | `addons/penta_tile/tests/fallback_routing_test.gd` | test (composed-canvas SceneTree script) | event-driven (process_frame await) + transform (canvas blit + invariant assert) | `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (matrix template) + `addons/penta_tile/tests/penta_ground_hollow_test.gd` (canvas-blit + bbox + transform helper) | exact (composite of two analogs) |
| NEW | `.planning/phases/04-fallback-routing/04-FALLBACK-UAT.md` | planning artifact (UAT sign-off) | request-response (test → result → notes) | `.planning/phases/02-native-layouts/02-HUMAN-UAT.md` | exact |
| NEW | `.planning/phases/04-fallback-routing/04-DOC-SWEEP.md` | planning artifact (sweep summary) | batch (per-file before/after) | none (no prior doc-sweep artifact) — closest secondary structure: `02-07-SUMMARY.md` LOC-checkpoint section + `04-RESEARCH.md` § 1 sweep checklist | novel structure proposed |
| NEW | `.planning/phases/04-fallback-routing/04-GEMINI-REVIEW.md` | planning artifact (raw findings) | batch (per-finding records) | `.planning/phases/02-native-layouts/02-REVIEW.md` (severity-classified findings + frontmatter counts) | exact |
| NEW | `.planning/phases/04-fallback-routing/04-GEMINI-REVIEW-FIX.md` | planning artifact (disposition log) | batch (per-finding disposition + commit SHA) | `.planning/phases/02-native-layouts/02-REVIEW-FIX.md` (WR-{NN} fix log + commit SHAs) | role-match (extended schema) |
| NEW | `.planning/phases/04-fallback-routing/04-CODEX-REVIEW.md` | planning artifact (raw findings) | batch | same as GEMINI-REVIEW | exact |
| NEW | `.planning/phases/04-fallback-routing/04-CODEX-REVIEW-FIX.md` | planning artifact (disposition log) | batch | same as GEMINI-REVIEW-FIX | role-match (extended schema) |
| MODIFY | `addons/penta_tile/penta_tile_map_layer.gd` | addon source (core node) | request-response (TileMapLayer subclass) | `addons/penta_tile/penta_tile_synthesis.gd:1-19` (style template) — partial coverage already exists, sweep extends to `@export` properties + public methods | role-match (style template, not 1:1) |
| MODIFY | `addons/penta_tile/penta_tile_synthesis.gd` | addon source (synthesis util) | transform (image → image) | itself (1-19 already exemplary; sweep extends to public methods + properties) | exact (self-template) |
| MODIFY | `addons/penta_tile/penta_tile_atlas_slot.gd` | addon source (data record) | CRUD (Resource fields) | itself (1-9 already exemplary field-by-field doc) | exact (self-template) |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout.gd` | addon source (abstract base) | transform (mask → atlas slot) | itself (1-12 already exemplary class block; add `@experimental` per D-04-03; extend to virtual methods + `bitmask_template` setter) | exact (self-template) |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_penta.gd` | addon source (layout subclass) | transform | `addons/penta_tile/penta_tile_synthesis.gd:1-19` (rich class-level block style) + `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd:1-18` (existing layout-class template) | role-match |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd` | addon source (layout subclass) | transform | itself (1-18 has rich class-level block — sweep extends to `mask_to_atlas` + `compute_mask` overrides) | exact (self-template) |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd` | addon source (layout subclass) | transform | `penta_tile_layout_dual_grid_16.gd:1-18` (parallel layout class with rich block) | role-match |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` | addon source (layout subclass) | transform | `penta_tile_layout_dual_grid_16.gd:1-18` | role-match |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd` | addon source (layout subclass) | transform | `penta_tile_layout_dual_grid_16.gd:1-18` | role-match |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` | addon source (layout subclass) | transform | itself (1-22 has rich class-level block citing D-numbers + research provenance — sweep extends to public method coverage) | exact (self-template) |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd` | addon source (layout subclass) | transform | itself (1-25 has rich block citing D-89/D-93/D-94/D-104) | exact (self-template) |
| MODIFY | `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd` | addon source (layout subclass) | transform | `penta_tile_layout_pixel_lab_top_down.gd:1-25` (sister-class style) | role-match |
| MODIFY | `addons/penta_tile/tests/run_tests.ps1` | test registry (PowerShell) | config (declarative array) | itself, lines 53–71 (existing `$allTests` array — sweep adds 1 entry mirroring existing 17) | exact (self-template) |

---

## Pattern Assignments

### Deliverable 1: Fallback Routing Verification

#### File: `addons/penta_tile/tests/fallback_routing_test.gd` (NEW — test, composed-canvas)

**Primary analog:** `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (pattern × layout matrix template)
**Secondary analog:** `addons/penta_tile/tests/penta_ground_hollow_test.gd` (canvas-compose + bbox + `_apply_transform` helper)

**Header pattern** (copy verbatim shape from `comprehensive_bitmask_test.gd:1-32`):

```gdscript
## Fallback routing UAT: paints a 3x3 pattern with each of the 8 actually-shipped
## layouts under tile_set = null. Asserts (a) PREVIEW-03 — tile_set auto-fills
## from layout.get_fallback_tile_set(); (b) every painted display cell composes
## non-zero opaque pixels into a virtual canvas; (c) PREVIEW-04 — direct
## tile_set assignment overrides fallback; (d) clearing tile_set + re-assigning
## layout re-routes to fallback.
##
## Layouts covered (D-04-05): Penta, DualGrid16, Wang2Edge, Wang2Corner, Min3x3,
## Blob47Godot, PixelLabTopDown, PixelLabSideScroller. (Tilesetter pair stays
## deferred per D-86 (b).)
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/fallback_routing_test.gd
extends SceneTree
```

**Layout preload + matrix block** (copy directly from `comprehensive_bitmask_test.gd:34-91`):

```gdscript
const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")
const _Blob47GodotSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")
const _PixelLabTopDownSc      = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd")
const _PixelLabSideScrollerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd")

var _failures: Array = []
```

The `layouts` Array-of-Dictionary structure with `name` + `script` + `is_dual_grid` keys at lines 82-91 is the canonical matrix shape. Copy verbatim, drop the `is_dual_grid` key only if Phase 4's bbox assertion doesn't need it (recommend keeping it — fallback test still wants to assert non-empty bbox and dual-grid offset matters).

**Composed-canvas blit + transform pattern** (copy from `penta_ground_hollow_test.gd:158-203`):

```gdscript
# Compose actual rendered canvas from the dispatched tiles.
var c_min := Vector2i(99999, 99999)
var c_max := Vector2i(-99999, -99999)
for cell: Vector2i in painted_visual:
    c_min.x = min(c_min.x, cell.x); c_min.y = min(c_min.y, cell.y)
    c_max.x = max(c_max.x, cell.x); c_max.y = max(c_max.y, cell.y)
var w: int = (c_max.x - c_min.x + 1) * tile_size.x
var h: int = (c_max.y - c_min.y + 1) * tile_size.y
var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
canvas.fill(Color(0, 0, 0, 0))

for cell: Vector2i in painted_visual:
    var ac: Vector2i = primary.get_cell_atlas_coords(cell)
    if not eff_src.has_tile(ac):
        unrenderable_atlas += 1
        continue
    var alt: int = primary.get_cell_alternative_tile(cell)
    var transform: int = alt & ~0xfff
    var src_tile := atlas_img.get_region(Rect2i(ac * tile_size, tile_size))
    var rotated := _apply_transform(src_tile, transform)
    canvas.blit_rect(rotated, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min) * tile_size)
```

**`_apply_transform` helper** — copy verbatim from `penta_ground_hollow_test.gd:261-284`. The function is self-contained, handles `TRANSPOSE | FLIP_H | FLIP_V` correctly per Critical Pitfall #1, and is the canonical transform-replay implementation in the test suite.

**`_record` failure-collection pattern + exit-code semantics** (copy from `comprehensive_bitmask_test.gd:97-105, 282-285`):

```gdscript
print("\n=== summary ===")
if _failures.is_empty():
    print("ALL PASS")
    quit(0)
else:
    printerr("FAIL (%d):" % _failures.size())
    for f in _failures:
        printerr("  - " + f)
    quit(1)


func _record(label: String, msg: String) -> void:
    _failures.append("[" + label + "] " + msg)
    printerr("  FAIL " + label + ": " + msg)
```

**Layer-instantiation under fallback** (the test's defining shape — `tile_set` is NEVER assigned). Pull from `RESEARCH.md` § 2 (verbatim recipe) and `comprehensive_bitmask_test.gd:118-122` for the layer-add + double-await pattern:

```gdscript
var layer = _LayerScript.new()
layer.layout = layout_def.script.new()    # auto-fills tile_set from fallback per penta_tile_map_layer.gd:54-70
get_root().add_child(layer)
await process_frame
await process_frame
```

**PREVIEW-04 contract checks** (NEW — derive from `penta_tile_map_layer.gd:75-96` `_set` hook semantics; pattern shown in `RESEARCH.md` § Code Examples lines 921-945):

```gdscript
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
```

**Per-cell solidity / non-empty bbox assertion idiom** — copy from `comprehensive_bitmask_test.gd:170-201` (opaque-pixel scan + `_record` on threshold violations). For Phase 4 specifically:
- Single-grid layouts: assert each painted cell dispatches to a 100%-solid atlas tile.
- Dual-grid layouts: assert each painted display cell has non-zero opacity (sanity).
- All layouts: assert composed-canvas opaque-pixel count > 0.

**DIVERGENCE from analogs:**
- Pattern set is intentionally smaller (1× 3×3 rectangle vs comprehensive's 18 patterns) — Phase 4 verifies the fallback PATH engages, not mask-matrix correctness (already covered by `comprehensive_bitmask_test.gd`). Per `RESEARCH.md` § 2 "Recommended Pattern Set."
- Test does NOT load any user-supplied `tile_set` (`penta_ground_hollow_test.gd` loads `ground.tres` at line 103; this test must NOT — fallback-only).
- Adds two named PREVIEW-04 sub-tests (`_test_preview_04_override`, `_test_preview_04_reroute`) that the matrix template does not have.

**Regression-catch verification recipe** (CLAUDE.md Test Methodology #5; documented in `04-FALLBACK-UAT.md`, not in the test file): stash the line `if tile_set == null or _tile_set_is_fallback:` in `penta_tile_map_layer.gd:64` to `if false:`, rerun, expect failure. Documented in `RESEARCH.md` § 2 Regression-Catch.

---

#### File: `addons/penta_tile/tests/run_tests.ps1` (MODIFY — registry append)

**Self-template** — lines 53–71. Single-line append inside the existing `$allTests` array:

```powershell
    $allTests = @(
        "paint_test",
        "all_layouts_test",
        # ... 14 more existing entries ...
        "pixellab_visual_regression_test",
        "fallback_routing_test"            # ← ADD THIS LINE (D-04-06; brings count 17 → 18)
    )
```

The existing comment on line 52 (`# Test inventory. Diagnostics live in *_diag.gd...`) needs no change — append-only operation.

**DIVERGENCE:** none. Pattern is trivially identical to the existing 17 entries.

---

#### File: `.planning/phases/04-fallback-routing/04-FALLBACK-UAT.md` (NEW — manual UAT sign-off)

**Primary analog:** `.planning/phases/02-native-layouts/02-HUMAN-UAT.md`

**Frontmatter pattern** (lines 1-7):

```yaml
---
status: complete   # filled in once user signs off
phase: 04-fallback-routing
source: [04-VERIFICATION.md]   # update if a verification artifact lands; otherwise drop
started: 2026-04-29T...
updated: ...
---
```

**Heading structure pattern** (lines 9-31): `## Current Test` → `## Tests` → numbered `### N. Title (req-id)` blocks → `### N+1. ...`. Each `### N.` block has the shape:

```markdown
### 1. {layout name} fallback eyeball pass (PREVIEW-03 per D-04-05)
expected: With `layout = {LayoutClass}.new()` and no manual `tile_set` assigned,
demo scene paints visibly correct tiles for a small painted region. No editor errors,
no empty cells.
result: [pass | fail | partial — narrative + screenshot path under user://fallback_{layout}.png]
```

Repeat 8 times for the 8 actually-shipped layouts. Then a separate `### 9.` block for PREVIEW-04 contract:

```markdown
### 9. PREVIEW-04 user-override regression (per D-04-06 belt+suspenders)
expected: Assigning a custom `tile_set` directly flips `_tile_set_is_fallback`
to false; clearing back to null + re-assigning `layout` re-routes to fallback.
result: [pass | fail with reproduction steps]
```

**Summary block pattern** (lines 31-39):

```markdown
## Summary

total: 9
passed: ...
partial: ...
pending: ...
issues: ...
skipped: ...
blocked: ...
```

**Gaps + Closure Notes pattern** (lines 41-50): freeform list of any layouts that need follow-up + a closure-note paragraph confirming the user's actual eyeball confirmation timestamp (analogue to `02-HUMAN-UAT.md`'s "Final visual confirmation (2026-04-28T22:00)" sentence). Reference the composed-canvas `fallback_routing_test.gd` PASS as programmatic backing for the manual eyeball pass.

**DIVERGENCE:** Phase 2's UAT had 4 grouped tests; Phase 4's has 8 layout-eyeball + 1 contract = 9. The shape scales linearly.

---

### Deliverable 2: Doc-Comment Sweep (12 addon scripts)

#### Shared style template — `addons/penta_tile/penta_tile_synthesis.gd:1-19`

This block is the canonical Godot doc-comment pattern in PentaTile. Every sweep target uses it as the structural template:

```gdscript
@tool
## Synthesis machinery for PentaTileLayoutPenta. Builds runtime TileSets from
## a single source TileSet by extracting sub-regions of slot 0 (IsolatedCell)
## and assembling synthesized archetypes per the locked anchoring spec
## (see .planning/phases/02-native-layouts/02-02-PLAN.md Gate 1 / Gate 2).
##
## Determinism invariant: same (source_tile_set, axis, tile_count) → bit-identical
## output (PENTA-SYNTH-06). Re-runs only when these inputs change.
##
## Slot ordering (LOCKED — Phase 2 architectural sweep):
##   0 = IsolatedCell  (always authored; source of OuterCorner render-time rotation)
##   1 = Fill          (synthesized from slot 0 in ONE mode; authored in TWO..FIVE)
##   ...
##
## OuterCorner has NO synthesized output slot. mask_to_atlas returns slot 0 with
## rotation flags (ROTATE_90/180/270) at render time — Path B per Gate 1.
class_name PentaTileSynthesis
extends RefCounted
```

**Structural elements every class-level block must have** (per D-04-02 + D-04-03 + Godot's official format verified in `04-RESEARCH.md` § 1):

1. `@tool` line first (if applicable).
2. One-line brief description (sentence-cased, period-terminated).
3. Blank `##` line.
4. Longer detail paragraph(s). Use `[Class TileMapLayer]`, `[method foo]`, `[member bar]` BBCode for cross-references (`04-RESEARCH.md` § 1 BBCode tag table).
5. Invariants / contract section (when applicable — copy the bullet style from `penta_tile_synthesis.gd:9-15`).
6. `## See:` paragraph linking to research docs (copy from `layouts/penta_tile_layout.gd:8-11`).
7. Optional `## @tutorial(Label): URL` and/or `## @experimental` structural tags as the LAST lines before the `class_name`. Tag form is `@keyword: value` — NO space before colon (`04-RESEARCH.md` § 1 critical rule).
8. `class_name X` then `extends Y`.

**`@experimental` placement** (D-04-03): only on `addons/penta_tile/layouts/penta_tile_layout.gd` class-level block (the abstract-base / subclassing surface). Not proliferated to every member or every layout subclass per `04-RESEARCH.md` § 8 Pitfall #5.

#### Per-method doc-comment template — `04-RESEARCH.md` § Code Examples lines 808-819

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

#### Per-`@export`-property template — `addons/penta_tile/penta_tile_atlas_slot.gd:1-9` + `04-RESEARCH.md` lines 824-831

```gdscript
## Source TileSetAtlasSource ID for atlas reads. -1 means "use the first
## TileSetAtlasSource discovered in [member tile_set]." Set explicitly only
## when the user's TileSet has multiple sources and one of them isn't index 0.
@export var atlas_source_id: int = -1:
    set(value):
        atlas_source_id = value
        _queue_rebuild()
```

The annotation goes BETWEEN the `##` block and the property name — `04-RESEARCH.md` § 1 Annotation Interaction. Setter / getter blocks may follow on indented lines without breaking association.

#### File-by-file sweep targets

| File | Existing class-level state | Sweep work |
|------|----------------------------|------------|
| `penta_tile_map_layer.gd` | none (jumps from `@icon` to `class_name` at lines 1-4) | Add class-level `##` block before `class_name PentaTileMapLayer` covering the dual-layer architecture, the `tile_set == null` → fallback contract (PREVIEW-03/04), and pitfall references (#7 visible-false, #4 setter loops). Add `##` blocks on `@export var atlas_source_id`, `@export var layout`, `@export_storage var _tile_set_is_fallback`, `@export_range logic_layer_opacity`. Add `##` on public methods (`rebuild()`, `set_cell` overrides if any). Convert the rich `#`-prose at lines 27-34 (above the layout setter) — class-level facets promote to the new `##` class-block; per-line internals stay `#` per `04-RESEARCH.md` § 8 Pitfall #2. The `_init` override at 134-154 needs a `##` block per `04-RESEARCH.md` § 8 Pitfall #9 (race documentation). |
| `penta_tile_synthesis.gd` | exemplary (lines 1-19) | Class block already complete. Sweep extends to: `synthesize_strip`, `clip_polygon_to_subrect`, `validate_tile_size`, `resolve_active_mode`, `build_tile_set_from_synthesis`, and any other public method without `_` prefix. |
| `penta_tile_atlas_slot.gd` | exemplary (lines 1-9, including field-by-field doc) | Promote the inline `Fields:` block to per-`@export` `##` blocks (one above each of `atlas_coords`, `transform_flags`, `alternative_tile`). Class block keeps the role-and-consumer description but the field detail moves down to the properties (per Godot's preferred locality — field docs render in the inspector tooltip when `##` is on the property). |
| `layouts/penta_tile_layout.gd` | exemplary class block (lines 1-12) | Add `## @experimental` line at end of class block per D-04-03. Add `##` on `bitmask_template` setter, `description` property, virtual methods `compute_mask`, `mask_to_atlas`, `is_dual_grid`, `get_fallback_tile_set`. Use `[method ...]` cross-references between virtuals. |
| `layouts/penta_tile_layout_penta.gd` | rich `#`-prose (not promoted) | New class-level `##` block describing modes (ONE/TWO/THREE/FOUR/FIVE × HORIZONTAL/VERTICAL), `axis` semantics, source-vs-output convention, link to `02-02-PLAN.md` Gate 1/2. `##` on `axis` + `tile_count` + `bitmask_template` exports. `##` on `compute_mask`, `mask_to_atlas`, `get_fallback_tile_set` overrides + `_make_slot`-related public surface. |
| `layouts/penta_tile_layout_dual_grid_16.gd` | exemplary class block (lines 1-18) | Class block complete. Sweep extends to `compute_mask` + `mask_to_atlas` overrides. |
| `layouts/penta_tile_layout_wang_2_edge.gd` | likely partial — confirm at execution | Add/extend class-level block matching `dual_grid_16` style (mask convention, atlas grid). `##` on `compute_mask` + `mask_to_atlas`. |
| `layouts/penta_tile_layout_wang_2_corner.gd` | likely partial | Same as Wang2Edge. |
| `layouts/penta_tile_layout_minimal_3x3.gd` | likely partial | Class block describing 9-tile collapse semantics + mask=0 special case (Critical Pitfall #9). `##` on overrides. |
| `layouts/penta_tile_layout_blob_47_godot.gd` | exemplary class block (lines 1-22) | Class block complete; sweep extends to `compute_mask` + `mask_to_atlas` + the `_collapse_8bit_moore` helper (which IS public surface for the mask convention even though it's `_`-prefixed — judgment call per D-04-02 "WHY is non-obvious"). |
| `layouts/penta_tile_layout_pixel_lab_top_down.gd` | exemplary class block (lines 1-25) | Class block complete (cites D-89/D-93/D-94/D-104 per LOCKED-decision discipline). Sweep extends to `compute_mask` + `mask_to_atlas` + role-table accessor. |
| `layouts/penta_tile_layout_pixel_lab_side_scroller.gd` | likely partial | Class block matching top-down sister + side-scroller-specific mask convention. `##` on overrides. |

**DIVERGENCES from style template:**
- `penta_tile_map_layer.gd` is the ONLY sweep target with rich pre-existing `#`-prose comments that look like documentation but are NOT (per `04-RESEARCH.md` § 8 Pitfall #2). Sweep MUST NOT mass-promote `#` → `##`. Internal explanation stays `#`; public-facing contract paragraphs migrate up to the new class-level `##` block.
- Three Penta-family layouts bind to the LOCKED-decision discipline (`@D-04-XX` / `@D-XX` cited in PixelLab + Blob47 class blocks); Phase 4 must preserve those citations.

---

### Deliverable 3: Cross-AI Review (Gemini + Codex)

#### File: `04-GEMINI-REVIEW.md` (NEW — raw findings)

**Primary analog:** `.planning/phases/02-native-layouts/02-REVIEW.md`

**Frontmatter pattern** (copy shape from `02-REVIEW.md:1-31`, extend per `04-RESEARCH.md` § 4 schema):

```yaml
---
phase: 04-fallback-routing
reviewer: gemini   # or codex
reviewed_at: 2026-04-29T...
files_reviewed:
  - addons/penta_tile/penta_tile_map_layer.gd
  - addons/penta_tile/penta_tile_synthesis.gd
  # ... all 12 addon scripts ...
findings:
  critical: 0
  high: 0
  medium: 0
  low: 0
  info: 0
  total: 0
status: clean   # or "issues-found"
---
```

**Per-finding header pattern** (D-04-11 + `04-RESEARCH.md` § 4 ID format `{TOOL}-{SEVERITY-LETTER}-{NN}`):

```markdown
### GEMINI-H-01: {one-line title}

**File:** `addons/penta_tile/penta_tile_map_layer.gd:64-70`
**Severity:** Critical | High | Medium | Low | Info
**Theme:** Bug | Identity | Goal-misalignment | Doc | Design
**Finding:** {what's wrong, 1-3 sentences}
**Suggested fix:** {what to change, 1-3 sentences with code if useful}
**Rationale:** {why it matters — links to identity guardrail / pitfall / locked decision (D-XX) / requirement / Godot best practice}
```

The Phase 2 finding header used `### IN-10:` / `### IN-11:`; Phase 4 generalizes to two reviewers via `{TOOL}-` prefix per `04-RESEARCH.md` § 4. The body's six-field block (File / Severity / Theme / Finding / Suggested fix / Rationale) is mandated by D-04-11; reject findings missing fields per `04-RESEARCH.md` § 8 Pitfall #10 (reviewer hallucination mitigation).

**File/line citation idiom** (copy from `02-REVIEW.md:88` and `:130`): `**File:** \`addons/penta_tile/penta_tile_map_layer.gd:305-346\``. Range form preferred over single line. Always backticked.

**Suggested-fix block format** (copy from `02-REVIEW.md:139-148`): prose first, then optional fenced GDScript block when the change is concrete enough to show inline. Phase 2 IN-13 is the canonical example — text + ```gdscript fenced block + closing prose.

**Sort order** (per `04-RESEARCH.md` § 4): findings sorted by severity (Critical → High → Medium → Low → Info), then ID-ascending within each tier.

**Section structure** (copy from `02-REVIEW.md`):

```markdown
## Summary
{1-paragraph overall assessment}

## Critical
### GEMINI-C-01: ...

## High
### GEMINI-H-01: ...

## Medium
### GEMINI-M-01: ...

## Low
### GEMINI-L-01: ...

## Info
### GEMINI-I-01: ...
```

If a tier is empty, OMIT the header entirely (Phase 2's `02-REVIEW.md` has only `## Info` because critical+warning sections were empty).

**DIVERGENCE from analog:** Phase 2 used `WR-{NN}` (warning) and `IN-{NN}` (info); Phase 4 uses 5-tier severity letters per D-04-11. Phase 2 had no `Theme:` field; Phase 4 mandates it.

---

#### File: `04-CODEX-REVIEW.md` (NEW — raw findings)

Identical schema to `04-GEMINI-REVIEW.md`. The only differences:
- `reviewer: codex` in frontmatter.
- `CODEX-{H|M|L|I}-{NN}` finding IDs.
- Codex sees the post-Gemini-fix codebase per D-04-10 (so its finding pool is genuinely "second look," not a repeat of Gemini's).

No additional pattern guidance needed beyond the Gemini section.

---

#### File: `04-GEMINI-REVIEW-FIX.md` (NEW — disposition log)

**Primary analog:** `.planning/phases/02-native-layouts/02-REVIEW-FIX.md`

**Frontmatter pattern** (extend `02-REVIEW-FIX.md:1-10` with disposition counters per D-04-13/14 + `04-RESEARCH.md` § 4):

```yaml
---
phase: 04-fallback-routing
reviewer: gemini   # or codex
fixed_at: 2026-04-29T...
review_path: .planning/phases/04-fallback-routing/04-GEMINI-REVIEW.md
findings_total: 18
applied: 7
applied_partial: 1
rejected_disqualification: 5
rejected_other: 0
deferred: 5
status: all_dispositioned
---
```

**Disposition table pattern** (NEW relative to Phase 2; `02-REVIEW-FIX.md:43-47` had a 4-column commit-summary table — Phase 4 extends to 7 columns per `04-RESEARCH.md` § 4):

```markdown
## Disposition Table

| ID | Severity | Theme | File | Disposition | Commit | Rationale |
|----|----------|-------|------|-------------|--------|-----------|
| GEMINI-H-01 | High | Bug | penta_tile_map_layer.gd:64 | applied | abc1234 | Auto-applied per D-04-13. |
| GEMINI-M-01 | Medium | Design | penta_tile_synthesis.gd:45 | applied | 9abcdef | User-approved per D-04-13. |
| GEMINI-M-02 | Medium | Design | layouts/penta_tile_layout_penta.gd:120 | rejected-disqualification | — | Forward-compat versioning (D-04-14 trigger 2). |
| GEMINI-L-01 | Low | Doc | penta_tile_map_layer.gd:200 | deferred | — | Cosmetic; user defers to v0.3+. |
| GEMINI-I-03 | Info | Identity | — | rejected-disqualification | — | Phase 5 LOC trim (D-04-14 trigger 4). |
```

**Disposition vocabulary** (locked per `04-RESEARCH.md` § 4):

| Value | Meaning |
|-------|---------|
| `applied` | Fix shipped in a single commit (atomic per D-04-15). |
| `applied-partial` | Fix shipped but reviewer's full suggestion not adopted; rationale must note the deviation. |
| `rejected-disqualification` | Hits one of `04-RESEARCH.md` § 5 disqualification triggers (1-7); NO commit. |
| `rejected-other` | Rejected for a different reason (e.g., reviewer hallucination, finding incorrect); rationale required. |
| `deferred` | Valid but punted to v0.3+/v2; logged in CONTEXT.md `## Deferred Ideas`; NO commit in Phase 4. |

**Per-applied-fix detail block** (copy from `02-REVIEW-FIX.md:29-87`):

```markdown
### GEMINI-H-01 — Commit `abc1234`

**Files modified:** `addons/penta_tile/penta_tile_map_layer.gd`
**Applied fix:** {1-3 sentence description of the fix as actually committed}
**Requires human verification:** YES | NO — {if YES: what to verify}
```

The "Requires human verification" field is Phase 2's discipline (lines 35-36, 43-44, 53-54) — Phase 4 keeps it because the cross-AI surface is broader and reviewer hallucinations may sneak in.

**Rejected-disqualification + Deferred sections** (NEW relative to Phase 2):

```markdown
## Rejected Findings (Detail)

### GEMINI-M-02 — Disqualified (no-forward-compat per D-04-14 trigger 2)
{1-3 sentence description of why this is disqualified, citing the specific trigger
and the locked-decision / requirement / hard-rule it would violate}

## Deferred Findings (to v0.3+ or v2)

### GEMINI-L-01 — Deferred to CONTEXT.md `## Deferred Ideas`
{paste the deferral rationale — what the finding said, why it's not in scope for
Phase 4, where it will reopen}
```

**Atomic-commit-per-fix message format** (D-04-15 LOCKED + `04-RESEARCH.md` § 6):

```
fix(04): {FINDING-ID} — {one-line description}
```

Examples:
- `fix(04): GEMINI-H-01 — restore @experimental tag on PentaTileLayout class doc`
- `fix(04): CODEX-M-03 — clarify _make_slot axis-invariance contract in doc-comment`

The leading `fix(04):` matches the existing project commit-style convention (recent commits: `5a02d8d`, `cb740b9`, `9f74a87`). The em-dash `—` separator matches Phase 2's WR-fix style (commits `ea0ba23`, `ae5d787`, `9ca342e`, `d74df0e`, `2ca04e0`, `720f017`, `79af1e3`). One commit per finding; no bundling.

**DIVERGENCES from Phase 2 analog:**
- Phase 2 had no disposition table — its 7 fixes were all `applied` so a flat per-fix detail list sufficed. Phase 4 requires the table because findings will land in 5 dispositions.
- Phase 2's frontmatter had `iteration: 1` — Phase 4 drops this (D-04-10's strict-order Gemini→Codex isn't iterative; each reviewer runs once).
- The "Requires human verification" field stays — verification surface is broader, not narrower.

---

#### File: `04-CODEX-REVIEW-FIX.md` (NEW — disposition log)

Identical schema to `04-GEMINI-REVIEW-FIX.md` with `reviewer: codex` and `CODEX-` ID prefixes. Codex's disposition log lands AFTER Gemini's per D-04-10; the Codex pass commits land on top of Gemini's commits (sequential, not rebased — `04-RESEARCH.md` § 6 "Findings That Touch the Same Line").

---

### Deliverable 4: `04-DOC-SWEEP.md` (NEW — sweep summary, novel structure)

**No exact analog exists in the codebase.** The doc-sweep is a Phase 4-unique deliverable. Closest secondary structures:
- `02-07-SUMMARY.md` LOC-checkpoint section (per-file table + summary + audit decision) — for the per-file before/after table.
- `04-RESEARCH.md` § 1 itself is the format spec — pull the structural-tags + BBCode tag tables for the appendix if useful.

**Proposed structure** (planner finalizes, but the success-criteria item #5 in `04-CONTEXT.md` D-04-02 anchors it):

```markdown
---
phase: 04-fallback-routing
swept_at: 2026-04-29T...
scripts_swept: 12
status: complete
---

# Phase 4: Doc-Comment Sweep Summary

**Scope (D-04-01):** 12 addon scripts under `addons/penta_tile/` (excluding tests + demo).
**Format source-of-truth:** [Godot 4.x GDScript Documentation Comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html)
**Coverage depth (D-04-02):** class-level `##` + every public method + every `@export` property.
**Tags used (D-04-03):** structural `@tutorial(label)`, `@experimental` (on `PentaTileLayout` only); BBCode `[param]`, `[code]`, `[Class]`, `[method]`, `[member]`.

## Per-File Coverage Table

| File | Class block | Public methods (count) | @export properties (count) | `@experimental` | `@tutorial` count |
|------|-------------|------------------------|----------------------------|-----------------|--------------------|
| `penta_tile_map_layer.gd` | NEW | 0/X → X/X | 0/Y → Y/Y | no | 0 |
| `penta_tile_synthesis.gd` | EXISTING | partial → full | partial → full | no | 0 |
| `penta_tile_atlas_slot.gd` | EXISTING | n/a | partial → full | no | 0 |
| `layouts/penta_tile_layout.gd` | EXISTING + `@experimental` | partial → full | partial → full | YES (D-04-03) | 0 |
| `layouts/penta_tile_layout_penta.gd` | NEW | 0/X → X/X | 0/Y → Y/Y | no | 0 |
| ... 7 more layout files ... | ... | ... | ... | no | varies |

## Style Reference

Class-level template: `addons/penta_tile/penta_tile_synthesis.gd:1-19`
Field-doc template: `addons/penta_tile/penta_tile_atlas_slot.gd:1-9` (extended in sweep)
Member-doc template: `addons/penta_tile/layouts/penta_tile_layout.gd` virtual methods (added in sweep)

## Verification

- No `#` interruptions inside `##` blocks (`04-RESEARCH.md` § 8 Pitfall #1 guard).
- All `@keyword:` tags have NO space before colon (`04-RESEARCH.md` § 1 critical rule).
- All BBCode tags closed (`04-RESEARCH.md` § 8 Pitfall #6).
- No `@deprecated` tags added (Phase 4 uses zero — `04-RESEARCH.md` § 8 Pitfall #3).
- Cross-AI review pass (D-04-04) consumes this artifact as the doc-quality verification mechanism — no bespoke lint test.

## Stats

- Lines of `##` doc added: NN
- Public methods documented: NN / NN
- @export properties documented: NN / NN
- @experimental tags added: 1 (on `PentaTileLayout` only)
- @tutorial tags added: NN
```

**DIVERGENCE:** This is a novel artifact. The structure above is RECOMMENDED, not LOCKED — planner may adjust. The required content (per D-04-16 phase-close gate item 1) is "evidence that all 12 scripts × all 3 surface tiers (class + public methods + @export) got coverage." The table is the simplest way to show that evidence.

---

## Shared Patterns

### Atomic-Commit-Per-Fix (cross-cutting — D-04-15)

**Source:** `.planning/phases/02-native-layouts/02-REVIEW-FIX.md` + Phase 2 commits `ea0ba23` / `ae5d787` / `9ca342e` / `d74df0e` / `2ca04e0` / `720f017` / `79af1e3`.

**Apply to:** All review-driven fix commits in Phase 4 (Gemini fixes + Codex fixes).

**Format (LOCKED per D-04-15):**

```
fix(04): {FINDING-ID} — {one-line description}
```

**Rules** (`04-RESEARCH.md` § 6):
- One finding = one commit. One commit = one finding.
- Multi-file fixes implementing a SINGLE finding go in ONE commit.
- Em-dash separator (`—`, U+2014), not hyphen.
- `{FINDING-ID}` format `{TOOL}-{SEVERITY-LETTER}-{NN}` per `04-RESEARCH.md` § 4.

### Doc-Comment Style (cross-cutting — sweep deliverable)

**Source:** `addons/penta_tile/penta_tile_synthesis.gd:1-19` (class block) + `addons/penta_tile/penta_tile_atlas_slot.gd:1-9` (field block) + `04-RESEARCH.md` § Code Examples (method + property templates).

**Apply to:** All 12 sweep-target addon scripts.

**Critical rules** (`04-RESEARCH.md` § 1 + § 8):
1. `##` (double-hash), NEVER `#` for documentation.
2. Block must IMMEDIATELY precede the documented element — NO blank lines, NO `#` interruptions.
3. Annotation goes BETWEEN the `##` block and the member, NEVER between the `##` block and the annotation.
4. Structural tags use `@keyword:` form with NO space before colon.
5. BBCode tags must be closed (`[code]...[/code]`, NOT `[code]...`).
6. `@experimental` only on `PentaTileLayout` class block (D-04-03).
7. `@deprecated` NOT used in Phase 4 (`04-RESEARCH.md` § 8 Pitfall #3).
8. No `#` (single-hash) prose mass-promotion to `##` (`04-RESEARCH.md` § 8 Pitfall #2 — internal explanation stays `#`).

### Composed-Canvas Test Pipeline (cross-cutting — fallback UAT)

**Source:** `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (matrix) + `addons/penta_tile/tests/penta_ground_hollow_test.gd` (canvas-blit + transform helper).

**Apply to:** `addons/penta_tile/tests/fallback_routing_test.gd` (single file in Phase 4).

**5-step recipe** (`04-RESEARCH.md` § 2):
1. Construct layer; assign `layout`; do NOT assign `tile_set`. Auto-fill kicks in via `penta_tile_map_layer.gd:54-70`.
2. Add to scene + paint pattern; double `await process_frame`; call `rebuild()`.
3. Compose virtual canvas — for each `painted_visual` cell, read `(atlas_coords, transform_flags)`, apply via `_apply_transform` helper, blit into canvas `Image` at `(cell - c_min) * tile_size`.
4. Compute structural invariants — non-empty bbox, per-cell solidity (single-grid 100%, dual-grid > 0%).
5. `canvas.save_png("user://fallback_<layout>.png")` when in doubt; read via Read tool.

### Disqualification Filter (cross-cutting — review fix policy)

**Source:** `04-CONTEXT.md` D-04-14 + `04-RESEARCH.md` § 5 (7 hard triggers + 2 soft triggers) + `CLAUDE.md` Breaking Changes Policy + Coined-Term Discipline + `REQUIREMENTS.md` v2/v0.3+ deferred list.

**Apply to:** Every finding in `04-GEMINI-REVIEW.md` and `04-CODEX-REVIEW.md` — implementer scans triggers in ≤ 30 seconds before applying any fix.

**7 hard triggers** (auto-reject as `rejected-disqualification`):
1. Backwards-compat shim / deprecation alias / version-detection branch.
2. Forward-compat versioning field / schema marker / speculative extension point.
3. Feature deferred to v0.3+ or v2 (TBT-01/02-DEFERRED, VAR-01, VAR-PIXEL-01, TOP-01, NONROT-01, MULTITERR-01..05, TERRAIN-01, RPGM-01..03, IMPORT-01/02, TOOL-01..04, PERF-01/02, DIST-01/02).
4. Phase 5 territory (LOC trim, README sections, CHANGELOG, demo refresh, `plugin.cfg` bump, git tag, release zip, `ATTRIBUTION.md` per D-72/D-73).
5. `addons/penta_tile/ATTRIBUTION.md` proposal (banned per D-72/D-73).
6. Coined-Term Discipline violation (any "Penta" prefix on non-5-archetype subsystems).
7. Locked-decision contradiction (any D-XX in PROJECT.md, STATE.md, phase CONTEXT.md files).

### Severity-Tiered Auto-Fix Policy (cross-cutting — review fix policy)

**Source:** `04-CONTEXT.md` D-04-13 + `04-RESEARCH.md` § 7.

**Apply to:** Every finding from both reviewers.

| Severity | Workflow |
|----------|----------|
| Critical / High | Auto-apply (no user prompt). Implement → atomic commit → REVIEW-FIX.md row `applied` + SHA. |
| Medium | Propose to user (1 paragraph: what / why / commit message) → wait for approval → apply or `rejected-other`. |
| Low / Info | Surface in REVIEW-FIX.md "Low/Info Findings" section → user picks `applied` or `deferred` (logged to CONTEXT.md `## Deferred Ideas`). |

---

## No Analog Found

| File | Role | Reason | Recommendation |
|------|------|--------|----------------|
| `04-DOC-SWEEP.md` | planning artifact | No prior doc-sweep summary in this project | Use the proposed structure under Deliverable 4 above (per-file coverage table + style reference + verification checklist + stats). Anchored to D-04-02 success-criteria item #5 — ensures the planner can derive "scripts swept × surface tiers covered" evidence. |

---

## Metadata

**Analog search scope:**
- `addons/penta_tile/tests/` (16 existing test scripts examined — `comprehensive_bitmask_test.gd` and `penta_ground_hollow_test.gd` selected as primary).
- `addons/penta_tile/` (12 sweep-target scripts examined — three already-exemplary class blocks at `penta_tile_synthesis.gd:1-19`, `penta_tile_atlas_slot.gd:1-9`, `layouts/penta_tile_layout.gd:1-12` selected as style template).
- `addons/penta_tile/tests/run_tests.ps1:53-71` (registry self-template).
- `.planning/phases/02-native-layouts/02-HUMAN-UAT.md` (UAT artifact analog).
- `.planning/phases/02-native-layouts/02-REVIEW.md` + `02-REVIEW-FIX.md` (cross-AI review precedent).
- `.planning/phases/02-native-layouts/02-07-SUMMARY.md` (per-file table + audit-decision pattern for novel doc-sweep summary).
- `.planning/phases/03.5-pixellab-layouts-variation-seed-wiring/03.5-REVIEWS.md` (referenced via `04-RESEARCH.md` § Sources; checked for additional review-format precedent).

**Files scanned:** 24 (12 addon source + 5 test scripts + 4 planning artifacts + 3 REVIEW-FIX exemplars).

**Pattern extraction date:** 2026-04-29.

**LOCKED decisions cited in pattern assignments:**
- D-04-01 (12-script scope) — sweep deliverable.
- D-04-02 (class + public method + @export coverage) — sweep deliverable + DOC-SWEEP.md table.
- D-04-03 (full Godot tag set; `@experimental` only on `PentaTileLayout`) — sweep deliverable.
- D-04-04 (no doc-coverage lint test — cross-AI review is the verification) — DOC-SWEEP.md verification section.
- D-04-05 (8 actually-shipped layouts) — `fallback_routing_test.gd` matrix.
- D-04-06 (belt + suspenders programmatic + manual) — `fallback_routing_test.gd` + `04-FALLBACK-UAT.md`.
- D-04-09 (Gemini + Codex, both headless) — `04-GEMINI-REVIEW.md` + `04-CODEX-REVIEW.md`.
- D-04-10 (strict order Gemini → fix → Codex → fix) — affects sequencing, not patterns directly.
- D-04-11 (5-tier severity × 5-theme finding format) — REVIEW.md schema.
- D-04-12 (4 review artifacts) — REVIEW.md + REVIEW-FIX.md per reviewer.
- D-04-13 (severity-tiered auto-fix) — REVIEW-FIX.md disposition policy.
- D-04-14 (standard disqualification list) — REVIEW-FIX.md disposition vocabulary.
- D-04-15 (atomic commits, format `fix(04): {FINDING-ID} — {description}`) — Atomic-Commit-Per-Fix shared pattern.
- D-04-16 (phase-close gate, 4 artifacts) — affects sequencing, not patterns directly.

## PATTERN MAPPING COMPLETE
