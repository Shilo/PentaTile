# Phase 2: Native Layouts — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 ships **six** TetraTile-native layout subclasses with hand-authored slot tables and bundled fallback TileSets:

| Layout | Atlas | Mask | Grid model | Overlay layer? |
|---|---|---|---|---|
| `TetraTileLayoutDualGrid16` | 4×4 (16 tiles) | 4-bit corner | dual | no |
| `TetraTileLayoutWang2Edge` | 4×4 (16 tiles) | 4-bit edge (CR31 N/E/S/W) | single | no |
| `TetraTileLayoutWang2Corner` | 4×4 (16 tiles) | 4-bit corner (CR31 NE/SE/SW/NW) | single | no |
| `TetraTileLayoutMinimal3x3` | 3×3 (9 tiles) | 4-bit edge | single | no |
| `TetraTileLayoutTetra5Horizontal` (NEW) | 5×1 strip | 4-bit corner | dual | **no** (5th tile replaces overlay) |
| `TetraTileLayoutTetra5Vertical` (NEW) | 1×5 strip | 4-bit corner | dual | **no** (5th tile replaces overlay) |

Each ships a bundled fallback TileSet (`PREVIEW-02`) so a fresh `TetraTileMapLayer` can paint with the layout attached and `tile_set == null` (consumer-side fallback routing lands in Phase 4).

**The architectural lift in this phase, beyond the layout subclass adds:** add `needs_diagonal_overlay() -> bool` virtual on `TetraTileLayout` base, and rewrite `_ensure_visual_layers` to lazy-skip `_overlay_layer` creation for any layout that returns `false` (i.e. every layout in v0.2 except the 4-tile Tetra Horizontal/Vertical from Phase 1). This is the perf optimization the 5-tile work surfaces; it propagates to every other Phase-2/3/3.5 layout for free.

Phase 2 originally scoped 4 native layouts + Min3x3 (5 layouts). Per this discussion, the 5-tile Tetra pair appended to Phase 2's scope (now **6 layouts**) — phases 3 / 3.5 / 4 / 5 unchanged.

</domain>

<decisions>
## Implementation Decisions

Decision IDs continue from Phase 1 (Phase 1 ended at D-27).

### Phase 2 scope expansion (Tetra5 layouts appended)

- **D-28: Append `TetraTileLayoutTetra5Horizontal` + `TetraTileLayoutTetra5Vertical` to Phase 2's scope.** Original Phase 2 scope (4 native + Min3x3) stays intact; the 5-tile Tetra pair is *added*, not substituted. Net: 6 layouts in Phase 2. Phase numbering and downstream phase scope unchanged.
- **D-29: Class root name = `Tetra5`.** `TetraTileLayoutTetra5Horizontal` / `TetraTileLayoutTetra5Vertical`. Matches TetraTile's own number-suffix convention (`Wang2Edge`, `Wang2Corner`, `DualGrid16`, `Blob47Godot`, `TilesetterWang15`, `TilesetterBlob47`, `Minimal3x3`). Rejected: `TetraEdge` (overloads with the existing "Edge" archetype = `Border`); `TetraOpposite` / `TetraOppositeCorners` (community standard term but reads awkwardly as a class name); `TetraDiagonal` ("diagonal" overloaded with diagonal-stride and the disconnected-diagonal mask cases). Tetra5 is unambiguous, terse, and pairs naturally with the unsuffixed 4-tile `Tetra*` parent classes.
- **D-30: 5th archetype's *tile* name (in code comments + docs + `description` field) = `Opposite Corners`.** Excalibur.js dual-grid article codifies the 5-archetype set as `Filled / Edge / InnerCorner / OuterCorner / OppositeCorners` (https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/). Aligns with broader dual-grid community vocabulary. Suggested constant name in `Tetra5Horizontal`: `const _OPPOSITE_CORNERS := 4` (atlas slot index 4, the 5th column).

### 5th-tile rotation semantics

- **D-31: One painted sprite, runtime applies a transform for the mirror diagonal.** Author paints ONE OppositeCorners sprite. The runtime applies `transform_flags = _ROTATE_0` for the canonical mask, and `_ROTATE_90` (or `TRANSFORM_FLIP_H` — planner picks the convention that matches the existing OUTER_CORNER rotation table for visual continuity) for the mirror. Rejected: 2-sprite asymmetric variant ("becomes 6-tile, breaks the name") and author-mirrored sentinel ("fragile if author wants asymmetric").
- **D-32: Canonical paint convention — paint the 5th tile to match mask 9 (TL+BR, the "\\" diagonal).** Mask 9 is the smaller TR-empty + BL-empty geometry; mask 6 (TR+BL = "/" diagonal) is the mirror. Convention rationale: matches the TL-anchored bit ordering (TL=1 is the lowest bit; the canonical pattern starts from TL and moves through the corners). `mask_to_atlas` for Tetra5: case 9 → `_make_slot(_OPPOSITE_CORNERS, _ROTATE_0)`; case 6 → `_make_slot(_OPPOSITE_CORNERS, <mirror transform>)`. Planner finalizes the exact transform_flags constant by visually verifying against the v0.1 overlay-composed output (must remain bit-identical when the 5th-tile art is the v0.1 overlay-composed pixels).

### Dispatcher — `needs_diagonal_overlay` virtual + lazy overlay skip

- **D-33: Add `func needs_diagonal_overlay() -> bool` virtual on `TetraTileLayout` base, default `false`.** Documents the dispatcher contract: a layout that returns `true` requires the `_overlay_layer` child node. A layout that returns `false` MUST NOT set `diagonal_complement_atlas_coords` on any slot (paired contract — the overlay sentinel and this virtual are co-locked). Phase 1's `TetraTileLayoutTetraHorizontal` (the 4-tile) overrides to return `true`; `TetraTileLayoutTetraVertical` inherits `true` from its parent unchanged. All Phase-2/3/3.5 layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3, Tetra5H, Tetra5V, plus all Phase-3 TBT-decoded layouts and Phase-3.5 PixelLab layouts) inherit `false` from the base.
- **D-34: `_ensure_visual_layers` lazy-creates `_overlay_layer` only when the active layout returns `needs_diagonal_overlay() == true`.** When `false`, `_overlay_layer` stays `null`; one less child Node + TileMapLayer per scene using a non-Tetra4 layout. Layout swap mid-runtime: re-evaluate on each `_resolve_layout()` call → if a previously-non-overlay layout swaps to a Tetra4 layout, `_ensure_visual_layers` is the egress that creates the overlay. The reverse swap (overlay → no overlay) is allowed to leak the existing layer node (`free_overlay_layer()` is not in scope; layer swap is a low-frequency edit-time operation, not hot-path).
- **D-35: `_paint_via_layout` reads `_overlay_layer != null` before attempting overlay paint.** Defense-in-depth: even if a layout incorrectly returns `false` from `needs_diagonal_overlay()` while still setting `diagonal_complement_atlas_coords`, the dispatcher silently no-ops the overlay paint instead of crashing. Such a layout is malformed and `update_configuration_warnings()` should flag it (planner's call on the warning text).

### Atlas shape, templates, fallback TileSets

- **D-36: Tetra5Horizontal atlas = 5×1 strip; Tetra5Vertical atlas = 1×5 strip.** Slot order: `[Fill, InnerCorner, Border, OuterCorner, OppositeCorners]`. The first 4 slots reuse the existing `Tetra*` archetype indices (Fill=0 / InnerCorner=1 / Border=2 / OuterCorner=3 — verbatim from Phase 1's `TetraTileLayoutTetraHorizontal` constants); OppositeCorners = 4. This means a v0.1-style Tetra atlas can be extended in-place by adding one more slot — no slot-index renumbering, drop-in compatible.
- **D-37: Generate templates `tetra_5_horizontal.png` (80×16 px) and `tetra_5_vertical.png` (16×80 px) via `_generate_greybox_templates.py`.** Add `gen_tetra_5_horizontal()` and `gen_tetra_5_vertical()` functions reusing the existing `draw_corner_mask` helper. 5th-slot greybox = mask 9 silhouette (TL+BR — "\\" diagonal). Updates the script's `outputs` dict and the templates/README.md "Shipped Templates" section.
- **D-38: Bundle `tetra_5_horizontal_fallback.tres` + `tetra_5_vertical_fallback.tres` TileSets.** Each is a `TileSet` `.tres` referencing the matching template PNG with 5 slots configured. Used by Phase 4's PREVIEW-03 fallback routing once `tile_set == null`. Naming follows the bundled pattern from Phase 1's `default_horizontal.tres` / `default_vertical.tres`.
- **D-39: Tetra5Horizontal class extends Tetra4Horizontal; Tetra5Vertical extends Tetra5Horizontal (axis-swap pattern).** Mirrors the Phase 1 D-16 inheritance: `TetraTileLayoutTetraVertical` extends `TetraTileLayoutTetraHorizontal` and overrides ONLY `_make_slot` (the atlas-axis-swap helper). For Tetra5: `TetraTileLayoutTetra5Horizontal` extends `TetraTileLayoutTetraHorizontal`, adds the OppositeCorners constant, overrides `mask_to_atlas` for ONLY cases 6 and 9 (delegates to `super.mask_to_atlas(mask)` for the other 14), and overrides `needs_diagonal_overlay()` to return `false`. `TetraTileLayoutTetra5Vertical` extends Tetra5Horizontal (NOT TetraVertical) and overrides ONLY `_make_slot` for the y-axis. LOC budget: ~30 LOC for Tetra5H + ~10 LOC for Tetra5V.

### Inspector validation

- **D-43: Add `update_configuration_warnings()` check for malformed Tetra5 atlases (surfaced by the Excalibur.js comparison; jyoung4242/dual-grid-auto-tiling demonstrates the same authoring pitfall in their published 6-tile spritesheet, which TetraTile can warn about at edit-time instead).** Re-uses Phase 1's existing warning infrastructure (D-15). The check fires on `TetraTileLayoutTetra5Horizontal` (inherited unchanged by `Tetra5Vertical`) and flags two failure modes:
  1. **Empty OppositeCorners slot** — slot index 4 in the active atlas (the 5×1 horizontal x=4, or 1×5 vertical y=4) is fully transparent or identical to slot 0 (Fill). Warning text suggestion: *"Tetra5 atlas: slot 4 (OppositeCorners) appears empty or identical to slot 0 (Fill). Paint a distinct OppositeCorners tile to handle the disconnected-diagonal mask cases (mask 6 = TR+BL, mask 9 = TL+BR). Without it, painted scenes will render mask 6 / 9 cells as plain fill."*
  2. **OppositeCorners identical to a transformed OuterCorner** (broader heuristic, optional) — the OppositeCorners slot's pixels match slot 3 (OuterCorner) under any of the 4 rotations or 4 flips. Likely a regression from copying v0.1's overlay-composed reference unchanged; warning text suggestion: *"Tetra5 atlas: slot 4 (OppositeCorners) appears identical to a transformed slot 3 (OuterCorner). Tetra5 expects a hand-authored 'opposite corners' diagonal — if you intended v0.1-equivalent visuals, this is correct; otherwise verify the OppositeCorners pixels are distinct."*
  Scope: Tetra5 only. Other layouts in v0.2 can grow their own validations in their respective phases (Phase 3 TBT layouts and Phase 3.5 PixelLab layouts each have their own characteristic mistakes — out of Phase 2 scope). Pixel-comparison strategy is Claude's discretion (image-hash equality is sufficient; per-quadrant centroid sampling is a richer alternative; planner picks the cheapest correct option).

### Documentation + roadmap updates (planner prerequisites)

- **D-40: REQUIREMENTS.md — add new TETRA5-* requirement IDs as part of Phase 2 planning.** Suggested:
  - `TETRA5-01`: `TetraTileLayoutTetra5Horizontal` + `TetraTileLayoutTetra5Vertical` subclasses; OppositeCorners archetype = atlas slot 4 in horizontal, slot (0,4) in vertical.
  - `TETRA5-02`: 5-tile dual-grid output bit-identical to v0.1 (and Phase 1) Tetra4 output for all 16 mask states when the 5th tile is painted to match the v0.1 overlay-composed pixels.
  - `TETRA5-03`: `needs_diagonal_overlay() -> bool` virtual on base; `_ensure_visual_layers` lazy-skips overlay layer creation when `false`. Verified by counting child TileMapLayer nodes after assigning each layout (Tetra4 = 2 children, all others = 1 child).
  - `TETRA5-04`: `tetra_5_horizontal.png` and `tetra_5_vertical.png` templates produced by `_generate_greybox_templates.py` (extends `TEMPLATE-03`'s scope).
  - `TETRA5-05`: Bundled `tetra_5_horizontal_fallback.tres` + `tetra_5_vertical_fallback.tres` fallback TileSets (extends `PREVIEW-02`'s scope).
- **D-41: ROADMAP.md Phase 2 success criteria expanded.** Add new criterion: "Painting a Tetra5Horizontal atlas with the 5th OppositeCorners tile authored produces visually correct mask-6 and mask-9 cells using a single TileMapLayer (no `_overlay_layer` child node created)." Existing criteria stay as-is. Phase 2 plan count goes from `TBD` to `~6` (one plan per layout family, plus the dispatcher refactor as its own wave).
- **D-42: Update `addons/tetra_tile/templates/README.md` "Shipped Templates" section** to list `tetra_5_horizontal.png` (5×1, 80×16 px) and `tetra_5_vertical.png` (1×5, 16×80 px). Mention the OppositeCorners archetype + Excalibur.js attribution. Land this update in the same plan as the template generation. Root README + CHANGELOG updates wait for Phase 5 (per existing roadmap split).
- **D-44: Marching Squares ↔ Wang2Edge cross-reference in user-facing docs.** "Marching Squares" is the algorithm name; "Wang 2-Edge" is the tile-classification name. Same 16-tile 4-bit N/E/S/W edge atlas. Land the cross-reference in two places:
  1. **`addons/tetra_tile/templates/README.md` "Mask Conventions" → Edge masks subsection**: append a single line beneath the existing edge-mask diagram: *"This is the same algorithm as 'Marching Squares' (4-bit N/E/S/W cardinal mask, 16 tiles) — same atlas, different vocabulary. Use `TetraTileLayoutWang2Edge` for both."*
  2. **`TetraTileLayoutWang2Edge`'s class-level `##` doc-comment AND `description` field**: cross-reference the algorithm name verbatim — *"16-tile 4-bit edge mask (CR31 N=1/E=2/S=4/W=8). Also known as 'Marching Squares' in algorithm-centric writeups (e.g., the Excalibur.js dual-grid article); same atlas, different vocabulary."*
  Lands in the same Wave as the Wang2Edge subclass implementation (no separate plan). Helps users arriving via marching-squares search terms find the right layout. Root README's "Supported Layouts" section gets the same cross-reference but as a Phase 5 docs deliverable (per the existing Phase 2/Phase 5 docs split — D-42).

### Claude's Discretion

- **Exact `transform_flags` value for mask 6 vs mask 9 in Tetra5.** Convention is mask 9 = `_ROTATE_0` (canonical paint); mask 6 = mirror. Planner picks between `_ROTATE_90`, `TRANSFORM_FLIP_H`, or `TRANSFORM_FLIP_V` based on visual symmetry of the OppositeCorners sprite (a slash-diagonal vs anti-slash-diagonal pixel pattern).
- **File naming convention for the new layout files.** `tetra_tile_layout_tetra5_horizontal.gd` vs `tetra_tile_layout_tetra_5_horizontal.gd`. Planner picks consistent with existing snake_case-class-name match (`tetra_tile_layout_tetra_horizontal.gd` precedent suggests `tetra_tile_layout_tetra_5_horizontal.gd`).
- **Whether `_OPPOSITE_CORNERS` constant lives on Tetra5Horizontal or on a shared base.** Defaults to Tetra5Horizontal (matches Phase 1's pattern of putting layout-specific constants on the layout). Tetra5Vertical inherits via `super`.
- **`update_configuration_warnings()` text for the `needs_diagonal_overlay() == false` + non-sentinel `diagonal_complement_atlas_coords` malformed case.** Free-form, as long as it names the contract violation.
- **Plan wave breakdown.** Suggested: Wave 1 = dispatcher refactor (`needs_diagonal_overlay` virtual + `_ensure_visual_layers` lazy skip). Wave 2 = the 4 originally-planned native layouts (DualGrid16 / Wang2Edge / Wang2Corner / Min3x3) in parallel. Wave 3 = Tetra5H + Tetra5V + new templates + fallback TileSets. Wave 4 = visual regression + LOC checkpoint. Planner free to recompose.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project + roadmap

- `.planning/PROJECT.md` — milestone scope, identity guardrails, Out-of-Scope list, Key Decisions table
- `.planning/REQUIREMENTS.md` — v1 requirements; Phase 2 owns NATIVE-01..03, MIN3x3-01, PREVIEW-02 (partial), TEMPLATE-04 (partial). New TETRA5-01..05 to be added by planner per D-40
- `.planning/ROADMAP.md` — phase breakdown; Phase 2 success criteria to be expanded per D-41
- `.planning/STATE.md` — current position; Phase 1 complete, Phase 2 ready to plan

### Phase 1 carry-forward

- `.planning/phases/01-contract-skeleton-tetra-layouts/01-CONTEXT.md` — Phase 1 decisions (D-01..D-27) that anchor Phase 2's architecture
- `.planning/phases/01-contract-skeleton-tetra-layouts/01-PATTERNS.md` — naming/inheritance patterns; the axis-swap inheritance pattern (D-39 reuses it)
- `.planning/phases/01-contract-skeleton-tetra-layouts/01-VERIFICATION.md` — Phase 1 verification artifact; the 26/26 test results that establish the baseline Tetra4 visuals are bit-identical to v0.1

### Research — architecture + design

- `.planning/research/ARCHITECTURE.md` — `_resolve_slot` design, lazy layer pattern, overlay-layer purpose (D-33/34 lazy-skip extends this)
- `.planning/research/PITFALLS.md` — alternative_tile bit packing (§1), Resource property renames (§3), setter loops (§4), overlay-layer cleanup behavior (§7)
- `.planning/research/STACK.md` — Godot 4.6 stack details; `TRANSFORM_FLIP_*` flag values that drive D-31's transform choice

### Research — layouts (the v0.2-specific body)

- `.planning/research/layouts/MASK_UNIFICATION.md` — load-bearing: polymorphic Resource selection, code shape; D-33's virtual fits within this architecture
- `.planning/research/layouts/TAXONOMY.md` — 24-layout catalogue
- `.planning/research/layouts/COMPARISON.md` — artist-facing layout comparison reference
- `.planning/research/layouts/EDITORS.md` — Tilesetter / Tiled / LDtk / Unity / RPG Maker conventions
- `.planning/research/layouts/TEMPLATE_CONVENTIONS.md` — prior-art synthesis (dandeliondino + Better Terrain + Godot stock); decoder design rationale
- `.planning/research/layouts/TILEBITTOOLS.md` — TBT addon audit + slot tables (Phase 3, but referenced for slot-table authoring discipline)
- `.planning/research/layouts/TILESETTER_AND_GODOT.md` — Tilesetter live-doc audit; "merging points" terminology contrast with Excalibur.js's "Opposite Corners"

### External references (community vocabulary)

- Excalibur.js dual-grid article — https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/ — codifies the 5-archetype dual-grid set: `Filled / Edge / InnerCorner / OuterCorner / OppositeCorners`. Source for D-30's archetype name.
- BorisTheBrave "Classification of Tilesets" — https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/ — tileset taxonomy reference (cross-checked but doesn't name individual archetypes)
- BorisTheBrave "Quarter-Tile Autotiling" — https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/ — confirms the 5-tile rotation set ("only 5 quarter-tiles needed for the entire tileset" if tiles rotate)

### Codebase maps

- `.planning/codebase/ARCHITECTURE.md` — overall system architecture; v0.1's overlay-layer rationale (D-33/34 lazy-skip preserves the original semantics for Tetra4 layouts)
- `.planning/codebase/CONCERNS.md` — known concerns; flags "Dual-layer composition for diagonals doubles tile ops for those masks" — D-31 directly addresses this for Tetra5
- `.planning/codebase/CONVENTIONS.md` — naming, file layout, GDScript style (snake_case file names match class names per existing `tetra_tile_layout_*.gd` convention)
- `.planning/codebase/INTEGRATIONS.md` — Godot integration points
- `.planning/codebase/STACK.md` — language/version specifics
- `.planning/codebase/STRUCTURE.md` — file/directory structure
- `.planning/codebase/TESTING.md` — testing approach (visual regression on demo)

### v0.1+Phase 1 source + assets (the canonical Tetra4 reference)

- `addons/tetra_tile/tetra_tile_map_layer.gd` (~298 LOC) — `_ensure_visual_layers` (lines 212-229), `_paint_via_layout` (lines 146-158), `_paint_overlay_for_slot` (lines 177-181) — these three functions get the lazy-skip refactor
- `addons/tetra_tile/layouts/tetra_tile_layout.gd` — base; D-33 adds `needs_diagonal_overlay()` virtual here
- `addons/tetra_tile/layouts/tetra_tile_layout_tetra_horizontal.gd` — Phase 1 4-tile reference; Tetra5Horizontal extends this
- `addons/tetra_tile/layouts/tetra_tile_layout_tetra_vertical.gd` — Phase 1 axis-swap reference; Tetra5Vertical follows the same axis-swap pattern but parents on Tetra5Horizontal
- `addons/tetra_tile/templates/_generate_greybox_templates.py` — extend with `gen_tetra_5_horizontal()` + `gen_tetra_5_vertical()`
- `addons/tetra_tile/templates/{tetra_horizontal,tetra_vertical,dual_grid_16,wang_2corner,wang_2edge}.png` — 5 shipped greyboxes; Tetra5 templates added alongside
- `addons/tetra_tile/templates/README.md` — artist-facing template spec; D-42 updates the "Shipped Templates" section

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets (Phase 1 already shipped)

- **`TetraTileLayoutTetraHorizontal.mask_to_atlas`** (16-state match table at lines 50-94) — `Tetra5Horizontal` overrides ONLY cases 6 and 9; the other 14 cases delegate via `super.mask_to_atlas(mask)`. Roughly ~25 LOC for the override class.
- **`TetraTileLayoutTetraHorizontal._make_slot`** + the axis-swap pattern in `TetraTileLayoutTetraVertical._make_slot` — `Tetra5Vertical` reuses the same pattern (override ONLY `_make_slot`). ~10 LOC.
- **`TetraTileMapLayer._ensure_visual_layers`** — current always-creates-both pattern. The lazy-skip refactor reads `layout.needs_diagonal_overlay()` and conditionally creates `_overlay_layer`. Net diff: ~6 LOC.
- **`_generate_greybox_templates.py`'s `draw_corner_mask`** helper — fills a slot's quadrants per a 4-bit corner mask. Reused for the 5th slot (silhouette = mask 9 = TL+BR).
- **`_pack_alternative(alt_id, transform_flags)`** helper on TetraTileLayout base (Phase 1 D-04) — Tetra5's `_make_slot` for masks 6 and 9 uses pure transform_flags; alt_id stays 0 (no variation in Phase 2).

### Established patterns (from `01-PATTERNS.md` + Phase 1 source)

- **Inheritance pattern (D-16 / Phase 1):** `Vertical` extends `Horizontal` and overrides ONLY the axis helper. Tetra5 follows: Tetra5H extends TetraH (overrides `mask_to_atlas` cases 6/9 + `needs_diagonal_overlay`); Tetra5V extends Tetra5H (overrides ONLY `_make_slot`).
- **Idempotence guard + `Resource.changed` hygiene** (D-08 / Phase 1) — preserved verbatim; Tetra5 layouts plug into the same path.
- **Lazy `_DEFAULT_LAYOUT` singleton** (D-07 / Phase 1) — no change in Phase 2; null-contract still resolves to TetraHorizontal4.
- **Snake_case file matches class name** (CONVENTIONS.md) — new files: `tetra_tile_layout_tetra_5_horizontal.gd`, `tetra_tile_layout_tetra_5_vertical.gd`.

### Integration points

- **`TetraTileLayout.needs_diagonal_overlay() -> bool`** (NEW virtual on base, default `false`) — read by `TetraTileMapLayer._ensure_visual_layers` to gate `_overlay_layer` creation.
- **`TetraTileMapLayer._overlay_layer`** (existing field) — now nullable depending on the active layout.
- **Inspector typed-picker** — new layouts auto-register via `class_name`; the contract's `layout` slot picker shows them alongside Phase 1's TetraH/V.

### LOC budget

Phase 2's expected additions, layered on Phase 1's 530-LOC baseline:

| File | Estimate |
|---|---|
| `tetra_tile_layout.gd` (existing — add `needs_diagonal_overlay` virtual) | +5 LOC |
| `tetra_tile_map_layer.gd` (existing — lazy overlay layer creation) | +6 LOC |
| `tetra_tile_layout_dual_grid_16.gd` (NEW) | ~80 LOC |
| `tetra_tile_layout_wang_2_edge.gd` (NEW) | ~80 LOC |
| `tetra_tile_layout_wang_2_corner.gd` (NEW) | ~80 LOC |
| `tetra_tile_layout_minimal_3x3.gd` (NEW) | ~60 LOC |
| `tetra_tile_layout_tetra_5_horizontal.gd` (NEW) | ~30 LOC |
| `tetra_tile_layout_tetra_5_vertical.gd` (NEW) | ~10 LOC |
| `_generate_greybox_templates.py` (existing — add 2 functions) | +30 LOC |
| **Phase 2 net add** | **~381 LOC** |

Cumulative end-of-Phase-2: ~530 + ~381 = **~911 LOC** of GDScript across `addons/tetra_tile/`. Comfortably under TileMapDual's ~700–900 LOC equivalent, but trending close — flagged for the end-of-Phase-3 LOC checkpoint per ROADMAP Identity Guardrails.

### Migration / breaking changes

None for Tetra5 specifically — this is pure addition. The `needs_diagonal_overlay()` virtual default of `false` is a breaking change for any **third-party** custom layout subclasses authored against the Phase 1 base (they'd silently lose overlay support if their `mask_to_atlas` returns slots with `diagonal_complement_atlas_coords`). Per `PROJECT.md` ("breaking changes accepted with migration notes; pre-1.0"), this is documented in the CHANGELOG (Phase 5) but not gated. No external custom layouts exist as of 2026-04-26 (audience = author's own games, no Asset Library distribution).

</code_context>

<specifics>
## Specific Ideas

### "Border" vs "Edge" terminology — settled

User flagged that `TetraEdge` would clash with the existing `Border` archetype (TetraTile's `Border` = the fully-flat side tile, atlas slot 2 in Tetra4Horizontal — what Excalibur.js calls `Edge`). Picking `Tetra5` sidesteps the collision entirely. Internal docs continue to use `Border` for the existing archetype; community-facing docs (templates/README, the new layout's `description` field) cross-reference Excalibur.js's `Edge` term so artists arriving from the dual-grid community can map between the two.

### v0.1 visual continuity with Tetra5

If an artist paints the 5th OppositeCorners tile to match the visual output of v0.1's two-layer composition (i.e. the OUTER_CORNER tile rotated 180° overlaid with the OUTER_CORNER tile rotated 0° on the other layer), Tetra5 produces output **bit-identical** to v0.1 / Phase 1's Tetra4. This is the key visual-regression target per D-31 and TETRA5-02. The greybox template's 5th slot should be painted to make this obvious — see `_generate_greybox_templates.py` D-37 (the 5th slot greybox = mask 9 silhouette).

### Future surface — TetraBake (parking lot)

`TOOL-01: TetraBake — edit-time utility to procedurally compose a fifth edge/diagonal connector tile` (in v2 backlog) is now newly motivated. Phase 2 ships the *consumer* (the 5-tile layout); Phase 2 does **not** ship the *generator* (a tool that takes a Tetra4 atlas and produces the OppositeCorners tile from the OUTER_CORNER source). TetraBake stays parked. Mention this in the Tetra5 layouts' `description` field so artists know they have to author the 5th tile manually.

### Mask convention for Tetra5 (inherited from Tetra4)

```
Corner mask (Tetra5 inherits from Tetra4):
  TL=1, TR=2, BL=4, BR=8     →  mask 0..15

Slot order in the atlas:
  Tetra5Horizontal = [Fill(0), InnerCorner(1), Border(2), OuterCorner(3), OppositeCorners(4)]
  Tetra5Vertical   = same order, transposed onto the y-axis (atlas_coords = (0, slot_index))

Mask → slot table (only cases 6 and 9 differ from Tetra4):
  case 6 (TR+BL = "/" diagonal) → OppositeCorners with <mirror transform>
  case 9 (TL+BR = "\" diagonal) → OppositeCorners with _ROTATE_0 (canonical paint)
  all other cases → super.mask_to_atlas(mask) [unchanged from Tetra4]
```

</specifics>

<deferred>
## Deferred Ideas

### Pushed to Phase 3 / 3.5 / 4 / 5 (within v0.2 scope, no renumber)

- TileBitTools-decoded layouts (Blob47Godot, TilesetterWang15, TilesetterBlob47) — Phase 3
- PixelLab layouts (TopDown, SideScroller) + variation_seed wiring — Phase 3.5
- Runtime fallback routing (`tile_set == null` → `layout.fallback_tile_set`) — Phase 4. The Phase 2 `fallback_tile_set` `.tres` files for the 6 native layouts are *bundled* in Phase 2 but only *consumed* in Phase 4.
- README `Layouts` section listing all 8 built-in layouts (now 8 with Tetra5H/V, plus DualGrid16, Wang2*, Min3x3, plus the 3 TBT layouts from Phase 3 and 2 PixelLab from Phase 3.5 — actually 10) — Phase 5. Phase 2 only updates `addons/tetra_tile/templates/README.md` (D-42).
- CHANGELOG entry — Phase 5.
- Demo refresh — Phase 5.

### Pushed to v0.3+ / future milestones (out of v0.2 scope)

- **TetraBake** (procedural OppositeCorners generator from a Tetra4 atlas) — TOOL-01 in v2 backlog. Now newly motivated by Tetra5's existence, but still gated on author bandwidth + v1.0 stability. Parking lot.
- **Y-axis variation** — original v0.2 pillar, deferred. Phase 3.5 wires `variation_seed` for PixelLab layouts only.
- **Top-tile support** — original v0.2 pillar, deferred.
- **RPG Maker A2/A4 subtile composition** — architecturally reserved, v0.3+ refactor.
- **External editor importers (Tiled / LDtk)** — v0.3+.
- **Multi-terrain transitions** — distinct R&D track.
- **Shader fallback for diagonal compositing** — PERF-01. Tetra5's overlay-skip + 5-tile architecture *partially* delivers this (no shader, but the overlay paint is eliminated for Tetra5 specifically; Tetra4 still needs it). Original PERF-01 stays in v2 backlog.
- **Editor visualizer / `EditorInspectorPlugin` polish** — Phase 5 demo or v0.3.
- **Wang/blob → TetraTile converter** (TOOL-02) — authoring tooling deferred.
- **Asset Library submission, MkDocs site, formal GUT test suite** — DIST-01, DIST-02 in v2 backlog.

### Reviewed during this discussion but explicitly deferred

- **Asymmetric 6-tile variant of Tetra5** (separate sprites for mask 6 vs mask 9). Would offer maximum artistic freedom for asymmetric diagonal art. Rejected per D-31: breaks the "5-tile" name, doubles the new authoring burden, and the rotation pattern is sufficient for the platformer / top-down art the user actually ships.
- **Author-mirrored sentinel** (paint mask 6 only, runtime auto-flips for mask 9). Rejected per D-31: fragile vs the explicit 1-sprite + transform model.
- **Naming `TetraEdge` / `TetraOpposite` / `TetraDiagonal` / `TetraOppositeCorners`** — rejected per D-29 in favor of `Tetra5` (community alignment via D-30's `OppositeCorners` *archetype* term, but TetraTile's own number-suffix pattern wins for the layout class name).

</deferred>

---

*Phase: 02-native-layouts*
*Context gathered: 2026-04-26*
