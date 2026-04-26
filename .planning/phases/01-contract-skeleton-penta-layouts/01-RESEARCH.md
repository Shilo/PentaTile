# Phase 1 Research — Validation Pass

**Date:** 2026-04-25
**Mode:** Re-iteration / accuracy audit (per user request: *"only do a re-iteration on research to verify all documentation is valid and accurate"*)
**Status:** RESEARCH COMPLETE
**Confidence:** HIGH on architecture / decoder / PixelLab; MEDIUM on absolute LOC predictions; HIGH on every load-bearing claim cross-checked against live code.

---

## Audit Summary

This was a re-iteration pass over an exceptionally well-pre-researched phase. Reviewed: 27 locked CONTEXT.md decisions (D-01..D-27), 14 phase requirements (CONTRACT-01..05, LAYOUT-01..05, TETRA-01..03, PREVIEW-01), 3 validated spikes (001 / 002 / 003), 9 layout research files, 7 codebase maps, the 261-LOC v0.1 source, the 165-LOC `_generate_greybox_templates.py`, and the live PixelLab `tileset_transform.lua`. Cross-checked the load-bearing claims (line numbers, decoder rules, role-to-mask bijection, mask-bit assignments, atlas_layout enum, plugin.cfg version) and made **3 in-place corrections** to research artifacts where the live code disagreed with the docs. The user-locked CONTEXT.md was NOT edited; nuances are reported in the corrections log.

The Phase 1 architecture is locked, decoder rules are validated across 9 templates + 16 PixelLab samples (via spikes 001 / 002 / 003), and PixelLab role-to-mask bijection was confirmed today against the actual `tileset_transform.lua` source. All 14 phase requirements have implementation guidance traceable to either CONTEXT.md (locked decisions), MASK_UNIFICATION.md (architecture), or the spike outputs (decoder).

**One genuine planner risk surfaced** — see *Open Questions / Planner Discretion* §3 below: the question of whether single-grid pipeline ships in Phase 1 (per D-06 / TEMPLATE_CONVENTIONS.md §6 recommendation) or in Phase 2 (when the first single-grid layout, Wang2Corner, lands). CONTEXT.md D-06 locks "ship both pipelines in Phase 1" — but executes via the planner since "what 'shipping the pipeline' means concretely with no consumer in Phase 1" is implementation discretion.

---

## Corrections Log

### Correction 1 — `.planning/codebase/ARCHITECTURE.md` (line 35)
**Was:** `Location: Internal TileMapLayer created at runtime (line 201 in tetra_tile_map_layer.gd)` (Overlay Visual Layer)
**Now:** `Location: Internal TileMapLayer created at runtime (line 202 in tetra_tile_map_layer.gd)`
**Reason:** The live source (read 2026-04-25) places the `_overlay_layer` assignment at line 202 (`_overlay_layer = _get_or_create_visual_layer(_OVERLAY_LAYER_NAME)`). Line 201 is the `if _overlay_layer == null or not is_instance_valid(_overlay_layer):` guard. Drift was minor but a downstream researcher tracing "where is the overlay created?" would be misled by 1 line.

### Correction 2 — `.planning/codebase/STRUCTURE.md` (lines 89-90)
**Was:**
```
- Public methods: camelCase without underscore (`rebuild()`, inherited `set_cell()`, `erase_cell()`)
- Export properties: camelCase (`atlas_source_id`, `atlas_layout`, `logic_layer_opacity`)
```
**Now:**
```
- Public methods: snake_case without underscore (`rebuild()`, inherited `set_cell()`, `erase_cell()`)
- Export properties: snake_case (`atlas_source_id`, `atlas_layout`, `logic_layer_opacity`)
```
**Reason:** The cited examples are all `snake_case` (no inner capitals). `atlas_source_id` is unambiguously snake_case. The "camelCase" label in STRUCTURE.md contradicted the very examples it provided AND CONVENTIONS.md, which correctly identifies them as `snake_case`. Internally inconsistent within the codebase research; corrected to match CONVENTIONS.md and the live code.

### Correction 3 — `.planning/codebase/STRUCTURE.md` (lines 20, 63, 111)
**Was:** Three claims that the demo's `tetra_tile_ground.png` is `16x4px` and tiles are `8x8px each` / `4 tiles × 8px`.
**Now:** Corrected to `64x16 px tileset atlas (4 tiles × 16 px)` / `64x16 pixel atlas (4 tiles × 16 px, horizontally arranged)` / `4 tiles, 16x16px each, horizontally or vertically arranged`.
**Reason:** Verified by reading the actual file dimensions via Pillow: `Image.open(...).size == (64, 16)`. The greybox generator in `_generate_greybox_templates.py` declares `TILE = 16` (line 21). The templates README per-template specs say `64 × 16 px (4 tiles × 16 px wide)` for `tetra_horizontal.png` (line 99). STRUCTURE.md was stale — likely from before the v0.2 templates landed in commit e86036f, when the demo asset was at a different size, or a research-time misobservation.

### Nuances flagged (NOT corrected — locked artifacts)

These appear in `01-CONTEXT.md` (the user-locked decision artifact); the planner should be aware:

- **CONTEXT.md `<code_context>` says `_paint_display_cell` is "lines 116-152".** The function actually spans **lines 108-152**; line 116 is where the inner `match` statement begins. This is the 16-state match block, not the function body. Defensible if read as "the 16-state match (which is what relocates into TetraTileLayoutTetraHorizontal.mask_to_atlas)" — but a planner reading literally will be confused. Treat 116-152 as "the match block" and 108-115 as "the early-return + erase + source-resolve preamble that stays in the layer."
- **CONTEXT.md `<code_context>` says `_ensure_visual_layers` is "lines 198-214".** The function `_ensure_visual_layers()` actually ends at line 203. Lines 206-214 are the helper `_get_or_create_visual_layer()`. The cited range covers BOTH functions (the lazy-layer pattern as a whole). Planner should treat 198-203 as `_ensure_visual_layers` and 206-214 as `_get_or_create_visual_layer`.

These do not change any architectural decision; they affect only "which lines to point a developer at when porting to Phase 1's new layer file."

### Items checked and confirmed correct (no correction needed)

- **`_mask_at` lines 155-165** (CONTEXT.md `<code_context>`) — exact match ✓
- **`_paint_display_cell` body uses TL=1, TR=2, BL=4, BR=8** at lines 21-24, 157-164 — exact match with corner-mask convention locked in `templates/README.md` and `_generate_greybox_templates.py` ✓
- **261 LOC count** (CONTEXT.md, STRUCTURE.md, init JSON) — file ends at content line 261 (`wc -l` reports 260 newlines; the last line of GDScript content is line 261 per the editor's count) ✓
- **`atlas_layout: AtlasLayout` enum with `HORIZONTAL` / `VERTICAL` members** (line 6 declaration, line 31 export, lines 183-185 dispatch) — confirmed ✓
- **Decoder rules (D-09..D-15)** validated by spikes 001/002/003 — re-cross-checked against spike outputs; rules are bit-identical between research/MASK_UNIFICATION + spike findings + TEMPLATE_CONVENTIONS ✓
- **PixelLab role-to-mask mapping `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]`** — confirmed against `C:\Users\shilo\AppData\Roaming\Aseprite\extensions\pixellab\tileset_transform.lua` (read directly today). The `tileset_output` and `tileset_output_side` 8×8 tables in the lua file match spike 003's hardcoded `_CELL_TO_ROLE` arrays cell-for-cell ✓
- **`plugin.cfg` version is `0.1.0`** — confirmed ✓ (Phase 5 bumps to `0.2.0` per REL-01)
- **5 shipped greybox templates** (`tetra_horizontal.png`, `tetra_vertical.png`, `dual_grid_16.png`, `wang_2corner.png`, `wang_2edge.png`) all present + `.import` sidecars are well-formed ✓
- **No bundled `.tres` files exist yet** in `addons/tetra_tile/contracts/` or similar paths — Phase 1 owns the bundled-default-contract creation, no path collisions ✓
- **PITFALLS.md §1 (alt-tile bit packing)** — D-04 / LAYOUT-05 specify `_pack_alternative(alt_id, transform_flags)` with `assert(alt_id < 4096)`, matching PITFALLS.md §3's recipe ✓
- **PITFALLS.md §5 (setter loops + Resource.changed storms)** — D-08 specifies idempotence guard + disconnect-before-reconnect, matching PITFALLS.md §5's recipe verbatim ✓
- **PITFALLS.md §7 (TileMapLayer.visible cleanup)** — already mitigated in v0.1 via `self_modulate.a` (lines 248-251); CONCERNS.md confirms this as ongoing constraint; no Phase 1 path sets `visible = false` on the logic layer ✓
- **`MASK_UNIFICATION.md` Approach B selection** — section 3.1 ("Approach B wins on five of six dimensions") is internally consistent with D-01 ✓
- **Mask conventions** (corner: TL=1/TR=2/BL=4/BR=8 ; edge: N=1/E=2/S=4/W=8 — same bits as CONTEXT.md's T=1/E=2/B=4/W=8 since T=N and B=S) — verified across `templates/README.md`, `_generate_greybox_templates.py`, MASK_UNIFICATION.md, all spike outputs ✓

---

## Validation Architecture

> Required for Step 5.5 of the orchestrator. Phase 1 is architecture work, not feature work — the bar is "v0.2 visual output is bit-identical to v0.1 in every supported configuration." The default config (`workflow.nyquist_validation` not present) is enabled; this section ships the validation map.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (no GUT, no GdUnit4) — per `PROJECT.md` "Quality Bar: works in my game" |
| Config file | none |
| Quick run command | `Godot --headless --quit-after 1 --path . --scene addons/tetra_tile/demo/tetra_tile_demo.tscn` (smoke: scene loads + first frame paints) |
| Full suite command | manual demo regression: open `tetra_tile_demo.tscn` in editor, drag-paint for 30s, compare visuals with v0.1 reference screenshot |
| Visual regression baseline | "v0.1 baseline" — pre-Phase-1 screenshot of the demo scene at 5 known mask states (a known L-shape, a 2×3 rectangle, an isolated tile, a single-row strip, a checkerboard test pattern) |

### Phase Requirements → Test Map

| Req ID | Behavior to verify | Test Type | How to verify | Wave 0 setup needed? |
|--------|--------------------|-----------|---------------|----------------------|
| CONTRACT-01 | `@export var atlas_contract: TetraTileAtlasContract` exposes a typed Resource picker in inspector | manual-editor | Open scene; click `atlas_contract` slot; confirm only `TetraTileAtlasContract`-derived resources appear | none |
| CONTRACT-02 | `TetraTileAtlasContract` declares `version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0` | manual-editor | Open contract `.tres` in inspector; confirm three properties present at correct types | none |
| CONTRACT-03 | `_resolve_slot(mask)` reads from `contract.layout` via `compute_mask` + `mask_to_atlas`, NOT the v0.1 inline match | code-grep + visual | grep for `match _mask_at` — must NOT appear in `tetra_tile_map_layer.gd`. Visual: paint demo, confirm output matches v0.1 reference | none |
| CONTRACT-04 | Null contract → v0.1 hardcoded behavior (singleton fallback) renders bit-identical | visual-regression | Set `atlas_contract = null` on demo; paint identical pattern; pixel-diff against v0.1 baseline must be 0 | "v0.1 baseline" screenshot saved before Phase 1 starts |
| CONTRACT-05 | Idempotence guard prevents redundant rebuilds | debug-instrumented | Add temporary `print("rebuild #%d" % _rebuild_count)` in `_queue_rebuild`; reassign `atlas_contract` to the same Resource; confirm count does NOT increase. Edit a contract sub-property; confirm count increases by exactly 1 (not 2 or more) | debug-build instrumentation |
| LAYOUT-01 | `compute_mask(coord, sample_fn)` virtual exists on base; subclasses override | code-grep + manual | grep `func compute_mask` in `tetra_tile_layout.gd` — exists; grep in TetraHorizontal/Vertical — both override; calling on raw base raises `push_error` | none |
| LAYOUT-02 | `mask_to_atlas(mask)` virtual exists | code-grep + manual | Same as LAYOUT-01 for `mask_to_atlas` | none |
| LAYOUT-03 | Base declares `template_image`, `fallback_tile_set`, `description`, plus class-level `##` doc-comment | manual-editor | Open `tetra_tile_layout.gd`; confirm 3 `@export` lines + `##` doc-comment at file head; inspector shows the 3 fields | none |
| LAYOUT-04 | `AtlasSlot` Resource has `atlas_coords`, `transform_flags`, `alternative_tile`, `diagonal_complement_atlas_coords` | manual-editor | Open `tetra_tile_atlas_slot.gd`; confirm 4 properties at correct types | none |
| LAYOUT-05 | `_pack_alternative(alt, flags)` ORs and asserts `alt_id < 4096` | unit-style + code-grep | Add an `assert _pack_alternative(0, TRANSFORM_FLIP_H) == TRANSFORM_FLIP_H` and `_pack_alternative(4096, 0)` triggers assertion | none |
| TETRA-01 | TetraHorizontal output bit-identical to v0.1 horizontal | visual-regression | Use bundled `default_horizontal.tres`; pixel-diff against v0.1 baseline must be 0 across 5 known mask configurations | "v0.1 baseline" screenshots |
| TETRA-02 | TetraVertical output bit-identical to v0.1 vertical | visual-regression | Set `atlas_layout = VERTICAL` in v0.1 baseline capture; switch contract to `default_vertical.tres` in v0.2; pixel-diff = 0 | "v0.1 baseline" vertical screenshots |
| TETRA-03 | Demo scene with bundled default contract = bit-identical to v0.1 | visual-regression | Same as TETRA-01 but on the actual demo scene with a hand-painted pattern | "v0.1 baseline" demo screenshot |
| PREVIEW-01 | `template_image: Texture2D` renders inline in inspector via Godot's stock preview | manual-editor | Open `default_horizontal.tres` in inspector; confirm thumbnail of `tetra_horizontal.png` appears next to the `template_image` field (no custom plugin) | none |

### Sampling Rate

- **Per task commit:** code-grep checks (no behavior change) + GDScript parse check (`Godot --headless --check-only path`)
- **Per wave merge:** open demo scene in editor; verify it loads without errors; spot-check 1 of 5 mask configurations against v0.1 baseline
- **Phase gate:** ALL 5 mask-state visual regressions vs v0.1 baseline pixel-diff = 0; idempotence guard counter test passes; LOC checkpoint logged

### Wave 0 Gaps

- [ ] **Capture v0.1 baseline screenshots** — open demo scene **before** any Phase 1 code lands; paint 5 reference patterns (single tile, 2×3 rectangle, L-shape, single-row strip, checkerboard); save PNGs to `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-{pattern}.png`. This MUST happen before Phase 1 task 1 to provide the regression target.
- [ ] **Add debug-build instrumentation skeleton** — a `var _rebuild_count: int = 0` field on `TetraTileMapLayer` (gated by `OS.is_debug_build()` if it must not ship), incremented in `_queue_rebuild`. Reset and read by the verification script for CONTRACT-05.
- [ ] **No framework install needed** — visual regression is manual-editor + pixel-diff in any image-diff tool. No GUT, no Pillow tests required for Phase 1 verification (Pillow is used only for spike scripts and the greybox generator).

### Manual-only items (justified)

- **Visual regression** is *the* verification mechanism per `PROJECT.md` "works in my game" quality bar and `ROADMAP.md` Identity Guardrails. Pixel-diff is reproducible (Godot's renderer is deterministic for static scenes); the manual step is opening the scene and triggering rebuild. No automation gain at v0.2 scope.
- **Inspector typed-picker test (PREVIEW-01, CONTRACT-01)** must be done in the live editor — no headless way to verify the inspector UI. One-line check per phase merge.

---

## Planning-Ready Brief

### Architecture (per D-01 to D-08, locked)

**The polymorphic Resource skeleton (Approach B from MASK_UNIFICATION.md):**

```
TetraTileMapLayer (extends TileMapLayer, @tool)
├── @export atlas_contract: TetraTileAtlasContract  (replaces atlas_layout enum — D-19)
└── @export atlas_source_id, logic_layer_opacity, ... (preserved from v0.1)

TetraTileAtlasContract (extends Resource)  ── CONTRACT-02
├── @export version: int = 1
├── @export layout: TetraTileLayout
└── @export variation_seed: int = 0   (declared, consumed in Phase 3.5)

TetraTileLayout (extends Resource, abstract)  ── LAYOUT-01..03
├── @export template_image: Texture2D
├── @export fallback_tile_set: TileSet
├── @export description: String  (multiline)
├── @export decoder_image: Texture2D  (optional, declared per D-specifics; consumed by Phase 4+)
├── func compute_mask(coord: Vector2i, sample_fn: Callable) -> int  (virtual; push_error on base)
├── func mask_to_atlas(mask: int) -> AtlasSlot                       (virtual; push_error on base)
└── func is_dual_grid() -> bool                                      (virtual; push_error on base)
   └── ##  doc-comment header for inspector hints

AtlasSlot (extends Resource)  ── LAYOUT-04
├── atlas_coords: Vector2i
├── transform_flags: int = 0
├── alternative_tile: int = 0
└── diagonal_complement_atlas_coords: Vector2i  (optional; for tetra masks 6/9 overlay)

TetraTileLayoutTetraHorizontal (extends TetraTileLayout)  ── TETRA-01
├── is_dual_grid() => true
├── compute_mask: TL=1/TR=2/BL=4/BR=8 OR
└── mask_to_atlas: 16-state table (relocated from v0.1 lines 116-152), uses
    transform_flags for rotation reuse, diagonal_complement_atlas_coords for masks 6 & 9

TetraTileLayoutTetraVertical (extends TetraTileLayout)  ── TETRA-02
├── is_dual_grid() => true
└── (same mask topology as Horizontal; differs only in atlas_coords axis — declares
    Vector2i(0, tile_index) vs Vector2i(tile_index, 0))
```

**Dispatcher in `tetra_tile_map_layer.gd::_update_cells()` (revised, ~25 LOC):**

1. `_ensure_visual_layers()` (preserved from v0.1)
2. `forced_cleanup OR tile_set == null` → clear + return (preserved)
3. `_sync_visual_layers()` (preserved)
4. `coords.is_empty()` → `rebuild()` (preserved)
5. `var layout := _resolve_layout()` — returns `atlas_contract.layout` if non-null, else lazy singleton `TetraTileLayoutTetraHorizontal` (D-07 null fallback)
6. For each affected display cell:
   - `var mask := layout.compute_mask(display_cell, has_logic_fn_callable)`
   - `if mask == 0: erase + continue` (universal short-circuit per PITFALLS.md §4)
   - `var slot := layout.mask_to_atlas(mask)` (or per layout's choice; the reference shape)
   - `_paint_with_slot(layer, slot, display_cell)` — handles `transform_flags | alternative_tile`, plus `diagonal_complement_atlas_coords` for masks 6/9 onto the overlay layer

**Dual-grid pipeline (preserved from v0.1):** for each changed logic cell, mark 4 surrounding display cells affected (the existing `_mark_affected_display_cells` method); paint each at the +(-tile_size/2) offset position.

**Single-grid pipeline (new, Phase 1 ships per D-06):** for each changed logic cell, mark itself + neighbors (depending on layout topology — 4 for edge, 4 for corner, 8 for blob); paint at the cell's own position (no half-tile offset). Picker: `if layout.is_dual_grid(): ... else: ...` at the top of the affected-cells loop.

**Setter discipline (D-08, per PITFALLS.md §5):**
```gdscript
@export var atlas_contract: TetraTileAtlasContract:
    set(value):
        if atlas_contract == value: return                              # idempotence
        if atlas_contract != null and atlas_contract.changed.is_connected(_on_contract_changed):
            atlas_contract.changed.disconnect(_on_contract_changed)
        atlas_contract = value
        if atlas_contract != null:
            atlas_contract.changed.connect(_on_contract_changed)
        _queue_rebuild()

func _on_contract_changed() -> void:
    _queue_rebuild()  # already deferred; coalesces multiple emissions per frame
```

### Decoder (per D-09 to D-15, locked across spikes 001 / 002 / 003)

**Phase 1 declares the decoder framework** so Phase 2+ layouts auto-populate slot tables from `template_image` at Resource load. Phase 1's own layouts (Tetra H/V) hardcode their slot tables (preserves v0.1 visual bit-identity); the decoder activates for layouts that don't provide a hardcoded table.

**Background-detection rule (D-09, the user's articulated rule, validated in spike 002):**
```gdscript
func is_bit_set(pixel: Color) -> bool:
    if pixel.a8 < 64:
        return false              # transparent → background (TetraTile alpha-encoded)
    if pixel.r8 >= 240 and pixel.g8 >= 240 and pixel.b8 >= 240:
        return false              # opaque white → background (dandeliondino color-encoded)
    return true                   # opaque non-white → bit set
```

**8-anchor sampler (D-10, no center bit):**
```gdscript
const _quarter := tile_size / 4
const _half    := tile_size / 2
const _inset   := max(2, tile_size / 16)

# Corner anchors (TL, TR, BL, BR):
TL: (_quarter, _quarter)
TR: (tile_size - _quarter - 1, _quarter)
BL: (_quarter, tile_size - _quarter - 1)
BR: (tile_size - _quarter - 1, tile_size - _quarter - 1)

# Edge anchors (T/N, E, B/S, W):
T:  (_half - 1, _inset)
E:  (tile_size - _inset - 1, _half - 1)
B:  (_half - 1, tile_size - _inset - 1)
W:  (_inset, _half - 1)
```

**3×3 majority vote (D-11):** at each anchor, sample 9 pixels (radius 1); ≥5 of 9 with `is_bit_set` true → that bit is set. Resilient to AA, glow seams, AI generation noise.

**Layout subclass declares** which subset of `{TL, TR, BL, BR, T, E, B, W}` are mask bits in its topology. Tetra/DualGrid16/Wang2Corner/PixelLab → 4 corners. Wang2Edge/Minimal3x3 → 4 edges. Blob47Godot/TilesetterBlob47 → 8.

**Decode at Resource load + cache (D-13):** sub-millisecond cost across all v0.2 templates per spike 002 (≤1.7 ms for 48-slot blob47 at 64-px tiles; ≤300 µs for 8×8 PixelLab at 16-px tiles). Cache the decoded `Array[AtlasSlot]` (or `mask → cells[]` for variation-bank layouts) on the Layout Resource until `Resource.changed` invalidates it.

**Mask 0 disambiguation (D-14):**
- Dual-grid layouts (Tetra H/V, DualGrid16): erase the display cell on mask 0 (preserves v0.1 behavior).
- Single-grid layouts (Wang2Corner/Edge, Blob47, PixelLab*): mask 0 is "no neighbors"; layout MAY paint `mask_slots[0]` if non-null (the "isolated/lonely tile"); else erase. Layout subclass owns this decision.

**Surface ambiguous / missing / unrecognized slots (D-15):** via `update_configuration_warnings()` so the inspector flags broken templates at edit time. Three classes of warnings: (a) two slots same mask, (b) gaps in the mask coverage table, (c) slots failing topology constraint (e.g., blob47's corner-implies-adjacent-edges).

**For Phase 1 specifically:** the decoder code MAY ship as a base-class helper on `TetraTileLayout` (e.g., `_decode_template_to_mask_table()`) — but Phase 1's two layouts override `mask_to_atlas` directly with hardcoded tables, so the decoder is "declared and ready, not exercised" in Phase 1. Phase 2 layouts (Wang2Edge/Wang2Corner) will be the first consumers.

### Phase 1 Deliverables (per D-16 to D-23)

| Deliverable | File | LOC est. (per CONTEXT.md `<code_context>`) | Source |
|-------------|------|--------------------------------------------|--------|
| Layer dispatcher (revised) | `addons/tetra_tile/tetra_tile_map_layer.gd` | ~290 | v0.1 261 - inline match (~40) + contract setter (~20) + dispatcher (~15) + single-grid pipeline (~30) |
| Atlas contract Resource | `addons/tetra_tile/tetra_tile_atlas_contract.gd` | ~50 | new |
| Atlas slot Resource | `addons/tetra_tile/tetra_tile_atlas_slot.gd` | ~30 | new |
| Layout base Resource | `addons/tetra_tile/tetra_tile_layout.gd` (or `layouts/tetra_tile_layout.gd`) | ~50 | new (interface + decoder helpers) |
| Tetra Horizontal layout | `…tetra_tile_layout_tetra_horizontal.gd` | ~80 | new (16-state table relocated from v0.1) |
| Tetra Vertical layout | `…tetra_tile_layout_tetra_vertical.gd` | ~30 | new (overrides axis vs Horizontal) |
| Bundled default contract — horizontal | `addons/tetra_tile/contracts/default_horizontal.tres` (path is planner discretion) | n/a (.tres) | new |
| Bundled default contract — vertical | `addons/tetra_tile/contracts/default_vertical.tres` | n/a | new |
| Bundled layout instance — horizontal | `addons/tetra_tile/contracts/tetra_horizontal_default.tres` (or similar) | n/a | new (references existing `templates/tetra_horizontal.png`) |
| Bundled layout instance — vertical | `addons/tetra_tile/contracts/tetra_vertical_default.tres` | n/a | new (references existing `templates/tetra_vertical.png`) |
| **Phase 1 total** | **6 .gd files + 4 .tres** | **~530 LOC** | (CONTEXT.md `<code_context>`) |

**Key file-creation rules:**
- All file names follow `snake_case`, matching the class name (CONVENTIONS.md ✓).
- Class names use `PascalCase` with `class_name` registration (CONVENTIONS.md ✓).
- Existing template PNGs `tetra_horizontal.png` / `tetra_vertical.png` (commit e86036f) are referenced by the bundled `.tres` files — no new PNGs in Phase 1.
- v0.1's `atlas_layout: AtlasLayout` enum is hard-removed (D-19, breaking change; CHANGELOG entry in Phase 5).

### Pitfalls That Apply to Phase 1

Cross-referenced from `.planning/research/PITFALLS.md`:

| Pitfall # | Title | Phase 1 applicability | Mitigation locked? |
|-----------|-------|------------------------|---------------------|
| §1 | `_update_cells()` re-entrancy | LOW — only relevant when variation lands (Phase 3.5). Phase 1 reaffirms "variation never writes to logic layer." | Documented; no Phase 1 code touches this. |
| §2 | Variation shimmers (global RNG) | NONE — variation lands in Phase 3.5. | n/a |
| §3 | `alternative_tile` bit collision | YES — Phase 1 declares `_pack_alternative(alt, flags)` helper (D-04, LAYOUT-05). | D-04 + LAYOUT-05 — `assert(alt_id < 4096)` |
| §4 | 64-entry non-rotating mask table | NONE — non-rotating tilesets are deferred to a future milestone. (DualGrid16/Wang2Corner cover the asymmetric-art case in Phase 2.) | n/a |
| §5 | Setter loops in Resource-backed contract | YES — Phase 1's primary setter discipline concern. | D-08 (CONTRACT-05) — idempotence + disconnect-before-reconnect, verbatim PITFALLS.md §5 recipe |
| §6 | Renaming Resource properties | LOW — Phase 1 introduces NEW property `atlas_contract`; v0.1 `atlas_layout` is hard-removed (D-19), not renamed. No `__migrate__()` shadow needed since the OLD property is going away entirely (existing scenes with `atlas_layout` set lose that line silently — but their `atlas_contract = null` falls through to the v0.1 hardcoded singleton fallback per D-07/CONTRACT-04, so behavior is preserved). | Documented in CHANGELOG (Phase 5). Migration path = "swap to `atlas_contract` reference" or "leave null and rely on default behavior." |
| §7 | Top-tile authoring | NONE — top tiles are deferred to a future milestone. | n/a |
| §8 | Contract scope creep into TileMapDual territory | YES — Phase 1 is exactly the scope-creep risk surface. | LOC budget locked at ~530 LOC for Phase 1 (CONTEXT.md `<code_context>`); identity guardrail enforced via end-of-Phase-1 LOC checkpoint per ROADMAP.md |

**v0.1 logic-layer-visible cleanup mitigation (PITFALLS.md §7 / TetraTile-specific recap §3):** preserved unchanged. The v0.1 `_apply_logic_layer_opacity()` (lines 248-251) uses `self_modulate.a` to hide the logic layer; Phase 1 does NOT introduce any path that sets `visible = false` on the logic layer. Verified in current source — no changes proposed.

### Open Questions / Planner Discretion (RESOLVED)

All items below were resolved during Phase 1 plan creation. See per-item RESOLVED markers for which plan adopted each resolution.

Per CONTEXT.md `### Claude's discretion`:

1. **File layout / folder structure** — flat `addons/tetra_tile/` vs `addons/tetra_tile/layouts/` subdir. Recommendation: subdir for layouts (`layouts/tetra_tile_layout.gd`, `layouts/tetra_tile_layout_tetra_horizontal.gd`, etc.) to keep the addon root tidy as Phases 2-3.5 add 9 more layout files. Alternative: flat is fine for v0.2 scope (only 11 layouts total). Planner decides. **RESOLVED:** Plan 02 ships layouts in `addons/tetra_tile/layouts/`; AtlasContract + AtlasSlot stay at addon root (they are not layouts).
2. **Default `.tres` naming** — `default_horizontal.tres` vs `tetra_horizontal_default.tres` vs `default_tetra_horizontal.tres`. Cosmetic; recommend the convention "purpose first, layout second" → `default_horizontal.tres` is shorter. Planner decides. **RESOLVED:** Plan 05 ships bundled contracts as `default_horizontal.tres` / `default_vertical.tres` (purpose-first), and bundled layout instances as `tetra_horizontal_default.tres` / `tetra_vertical_default.tres`.
3. **Single-grid pipeline shape in Phase 1** — D-06 locks "ship both pipelines in Phase 1" but Phase 1 has NO single-grid layout consumer (Tetra H/V are dual-grid). Two options:
   - **(a) Ship the pipeline fully wired** — even though Phase 1 has no consumer, the routing branch (`if layout.is_dual_grid(): ... else: ...`), the `_mark_affected_logic_cells_for_single_grid()` helper, and the no-half-tile-offset paint path all land in Phase 1. Phase 2 consumes immediately. Pro: Phase 2 becomes pure subclass adds. Con: dead code in Phase 1.
   - **(b) Ship the pipeline as a stub** — the dispatcher reads `is_dual_grid()` but only the `true` branch is implemented; `false` raises `push_error("single-grid pipeline lands in Phase 2")`. Phase 2 implements the false branch in `tetra_tile_map_layer.gd` AND adds Wang2Corner. Pro: no dead code. Con: Phase 2 ALSO modifies the layer file, violating the "Phase 1 = load-bearing architecture; Phase 2+ = pure subclass adds" principle stated in CONTEXT.md `<domain>`.
   - **Recommendation:** option (a). The "pure subclass adds" principle in CONTEXT.md `<domain>` and TEMPLATE_CONVENTIONS.md §6 is more important than avoiding ~30 LOC of unexercised-by-Phase-1-but-tested-by-Phase-2 code. Planner verify.
   - **RESOLVED:** Option (a) adopted. Plan 04 ships the single-grid pipeline fully wired (`_mark_affected_single_grid_cells` helper + `if layout.is_dual_grid(): ... else: ...` routing in `_update_cells` and `rebuild`, plus zero-offset branch in `_visual_layer_offset`). Phase 1 has no consumer; Phase 2's Wang2Corner is the first. Plan 05 Task 4.4 (or Task 4.6) adds a stub-layout smoke test to verify the else branch doesn't crash.
4. **`Resource.changed` signal-storm coalescing details** — D-08 locks the pattern; specific implementation (e.g., do we use `_queue_rebuild` directly, or a separate `_on_contract_changed` handler that calls `_queue_rebuild`) is implementation detail. **RESOLVED:** Plan 04 introduces a dedicated `_on_contract_changed()` handler that calls `_queue_rebuild()` (which already coalesces via `call_deferred`). Plan 02 ships the back-reference path: `TetraTileLayout._contract: WeakRef` set by `TetraTileAtlasContract.layout` setter via `_set_contract(self)`. Phase 3.5 PixelLab variation pick will read `_contract.get_ref().variation_seed` through this path.
5. **`update_configuration_warnings()` warning copy** — D-15 locks the categories (ambiguous / missing / unrecognized); exact wording is planner discretion as long as warnings are actionable. **RESOLVED:** Planner discretion; not blocking for Phase 1 plan creation. Specific wording is owned by the executor when implementing the warnings.
6. **D-27 ROADMAP.md / REQUIREMENTS.md updates** — CONTEXT.md says "executing them is part of planning rather than Phase 1's implementation work." Planner should add as a Wave 0 planning task, not a Phase 1 implementation task. **RESOLVED:** Plan 01 Task 0.4 owns the ROADMAP.md (Phase 3.5 + bullet list + status table + Coverage table updates) and REQUIREMENTS.md (MIN3x3-01 + PIXLAB-01..04 + VAR-PIXEL-01 sections + Traceability rows + Phase 1 ID `TBD`->`1` bookkeeping).
7. **Graph context note:** No `.planning/graphs/graph.json` exists at this read-time; no semantic-graph context is included in this brief. If the user wants graph-aware suggestions in the next phase, run `gsd-tools.cjs graphify init` first. **RESOLVED:** Informational only; no graph context required for Phase 1 planning.

### Cross-Phase Architectural Constraints

The Phase 1 contract+layout interface MUST accommodate:

- **Phase 2** ships `TetraTileLayoutDualGrid16`, `TetraTileLayoutWang2Corner`, `TetraTileLayoutWang2Edge`, **and** new `TetraTileLayoutMinimal3x3` (D-24). Plus `PREVIEW-02` (bundled `fallback_tile_set` per layout). Interface obligation: the base `TetraTileLayout` MUST already declare `fallback_tile_set: TileSet` (LAYOUT-03). **NOT NEGOTIABLE.**
- **Phase 3** ships `TetraTileLayoutBlob47Godot`, `TetraTileLayoutTilesetterBlob47`, `TetraTileLayoutTilesetterWang15`. Interface obligation: the base + decoder must support 8-bit blob masks (D-10's 8-anchor sampler is sufficient; subclass declares topology). The single-grid pipeline (D-06 / planner question 3 above) MUST be in place by end of Phase 2 at latest.
- **Phase 3.5** ships `TetraTileLayoutPixelLabTopDown` and `TetraTileLayoutPixelLabSideScroller` (D-25), plus wires `variation_seed` deterministic-hash bucket-pick (D-26). Interface obligations:
  - `AtlasContract.variation_seed: int = 0` MUST be declared in Phase 1 (it is — CONTRACT-02). **NOT NEGOTIABLE.**
  - `AtlasSlot.alternative_tile: int = 0` MUST be declared in Phase 1 (it is — LAYOUT-04). **NOT NEGOTIABLE.**
  - `_pack_alternative(alt, flags)` helper with `assert(alt_id < 4096)` MUST ship in Phase 1 (it does — D-04 / LAYOUT-05). **NOT NEGOTIABLE.**
  - `mask_to_atlas` returning a chosen variation cell (per `(coord, variation_seed)` hash) is Phase 3.5 work; Phase 1's `mask_to_atlas` signature MUST accept the variation context. The cleanest interface is `mask_to_atlas(mask: int) -> AtlasSlot` with an optional second parameter; CONTEXT.md leaves this as `mask_to_atlas(mask: int) -> AtlasSlot` (LAYOUT-02). The variation context must therefore be threaded via a separate path — recommendation: layout has access to `variation_seed` via a back-reference set on Resource load, OR the dispatcher passes `(coord, variation_seed)` to a separate `pick_alternative(slot, coord, variation_seed)` Callable. PIXELLAB.md uses the latter shape; planner decides which to lock in Phase 1.
- **Phase 4** ships fallback-routing (`tile_set == null` → `layout.fallback_tile_set`). Interface obligation: `TetraTileLayout.fallback_tile_set: TileSet` declared in Phase 1 (it is — LAYOUT-03). **NOT NEGOTIABLE.**
- **Phase 5** ships demo refresh + README + release. No Phase-1 interface obligation; Phase 5 is the consumer.

**The single-most-load-bearing Phase 1 interface decision:** how `mask_to_atlas` exposes (or doesn't) the variation-pick context. CONTEXT.md / LAYOUT-02 declare `mask_to_atlas(mask: int) -> AtlasSlot` — no coord/variation_seed parameter. Phase 3.5 will need either (a) a back-reference on the layout to its owning contract (so `mask_to_atlas` can read `_contract.variation_seed`), (b) a separate `pick_variation(slot, coord)` Callable on the layout, or (c) a signature widening. Recommendation: **(a), with the back-reference set during contract.layout assignment.** Planner locks the choice during Phase 1 plan creation; Phase 3.5 just consumes.

---

## Requirements Coverage

For each phase requirement, where the planner finds implementation guidance:

| Req ID | Description (REQUIREMENTS.md) | Implementation guidance |
|--------|-------------------------------|--------------------------|
| **CONTRACT-01** | `@export var atlas_contract: TetraTileAtlasContract` on TetraTileMapLayer | CONTEXT.md `<code_context>` "Integration points" §1; this RESEARCH.md *Architecture* §1 (the layer's @export); MASK_UNIFICATION.md §5.1 |
| **CONTRACT-02** | `version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0` on contract | CONTEXT.md D-26 (variation_seed placeholder); this RESEARCH.md *Architecture* §1 (Resource hierarchy); MASK_UNIFICATION.md §7 (migration path) |
| **CONTRACT-03** | `_resolve_slot(mask)` reads from `contract.layout` | CONTEXT.md D-01/D-02; MASK_UNIFICATION.md §5.1 (dispatcher pseudocode); this RESEARCH.md *Architecture* §1 |
| **CONTRACT-04** | Null contract → v0.1 hardcoded behavior (bit-identical) | CONTEXT.md D-07 (lazy singleton fallback); ROADMAP.md Phase 1 success criterion 2 |
| **CONTRACT-05** | Idempotence guard + disconnect-before-reconnect on Resource.changed | CONTEXT.md D-08; PITFALLS.md §5 (verbatim recipe); this RESEARCH.md *Architecture* (setter discipline snippet) |
| **LAYOUT-01** | `compute_mask(coord, sample_fn)` virtual on base | CONTEXT.md D-02; TEMPLATE_CONVENTIONS.md §5; this RESEARCH.md *Architecture* §1 |
| **LAYOUT-02** | `mask_to_atlas(mask)` virtual on base | CONTEXT.md D-02; TEMPLATE_CONVENTIONS.md §5; this RESEARCH.md *Cross-Phase Constraints* (variation context note) |
| **LAYOUT-03** | `template_image`, `fallback_tile_set`, `description`, ## doc-comment | CONTEXT.md D-22 (description); TEMPLATE_CONVENTIONS.md §6; this RESEARCH.md *Architecture* §1 |
| **LAYOUT-04** | `AtlasSlot` fields | CONTEXT.md D-03; this RESEARCH.md *Architecture* §1 |
| **LAYOUT-05** | `_pack_alternative` helper with `assert(alt_id < 4096)` | CONTEXT.md D-04; PITFALLS.md §3 (verbatim recipe) |
| **TETRA-01** | TetraHorizontal subclass, bit-identical to v0.1 horizontal | CONTEXT.md D-16; v0.1 source `tetra_tile_map_layer.gd` lines 116-152 (the match block to relocate); MASK_UNIFICATION.md §5.2 (Tetra layout shape) |
| **TETRA-02** | TetraVertical subclass, bit-identical to v0.1 vertical | CONTEXT.md D-16; v0.1 source line 183-185 (the axis dispatch); same as TETRA-01 |
| **TETRA-03** | Demo with bundled default contract = bit-identical to v0.1 | CONTEXT.md D-17 / D-18 (bundled .tres); ROADMAP.md Phase 1 success criterion 1; this RESEARCH.md *Validation Architecture* (test plan) |
| **PREVIEW-01** | `template_image: Texture2D` renders inline in inspector | CONTEXT.md D-20; PIXELLAB.md (no custom plugin needed); this RESEARCH.md *Architecture* §1 |

All 14 phase requirements have implementation guidance. None are blocked. None require additional research before planning can begin.

---

## RESEARCH COMPLETE

**Phase 1 of 5 — Contract Skeleton + Tetra Layouts**

Validation pass complete. 3 in-place corrections to research artifacts (1 line-number drift in `codebase/ARCHITECTURE.md`; 1 `camelCase`→`snake_case` style drift + 3 stale tile-size claims in `codebase/STRUCTURE.md`). Zero corrections needed in `01-CONTEXT.md`, `MASK_UNIFICATION.md`, `PITFALLS.md`, `TEMPLATE_CONVENTIONS.md`, `PIXELLAB.md`, or any spike output. PixelLab role-to-mask bijection re-verified today against the live `tileset_transform.lua`. All 14 phase requirements have traceable implementation guidance. Planner can proceed.

**Flags for the planner:**
1. CONTEXT.md `<code_context>` cites `_paint_display_cell` lines 116-152 (the match block) and `_ensure_visual_layers` lines 198-214 (the lazy-layer pattern as a whole, including the helper). Both are defensible-but-imprecise; planner should treat them as "the relocated match block" and "the lazy-layer pattern" respectively, not as exact function bodies.
2. Single-grid pipeline shape in Phase 1 (planner discretion item §3 above) is the one architectural decision left undecided. Recommendation: ship the pipeline fully wired with no consumer in Phase 1, even though that puts ~30 LOC of "untested in Phase 1, exercised in Phase 2" code in the layer file.
3. Variation-pick context threading through `mask_to_atlas` (Cross-Phase Constraints note) — Phase 1 should lock the back-reference approach (layout has a `_contract` back-ref set when assigned to a contract) so Phase 3.5's PixelLab work has a clean path. Planner decides during plan creation.
4. v0.1 baseline screenshots MUST be captured BEFORE any Phase 1 code lands (Wave 0 task) — the visual regression target is destroyed otherwise.
