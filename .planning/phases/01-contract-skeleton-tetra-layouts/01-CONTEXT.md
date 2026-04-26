# Phase 1: Contract Skeleton + Tetra Layouts — Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers the **architecture skeleton** for v0.2's layout library:

- `TetraTileAtlasContract` Resource owning a typed `layout: TetraTileLayout` reference
- `TetraTileLayout` base Resource with virtual `compute_mask` / `mask_to_atlas` / `is_dual_grid` interfaces, plus `template_image` / `fallback_tile_set` / `description` field declarations
- `AtlasSlot` Resource (atlas_coords + transform_flags + alternative_tile + diagonal_complement_atlas_coords)
- The **template-image-to-mask decoder** that auto-populates slot tables at Resource load (eliminates per-slot AtlasSlot authoring)
- BOTH paint pipelines wired in `TetraTileMapLayer`: dual-grid (preserved from v0.1) and single-grid (new — feeds Phase 2's Wang2Edge / Wang2Corner)
- `TetraTileLayoutTetraHorizontal` and `TetraTileLayoutTetraVertical` subclasses — first concrete layouts using the new architecture; output bit-identical to v0.1

The phase boundary is "the load-bearing architectural slice." Every Phase 2-5 layout slots in as a pure subclass add with no further changes to `tetra_tile_map_layer.gd`. Visual regression on v0.1-style scenes proves the migration is non-breaking.

</domain>

<decisions>
## Implementation Decisions

### Architecture (the polymorphic Resource skeleton)

- **D-01: Approach B (polymorphic `TetraTileLayout` Resource).** Locked in `MASK_UNIFICATION.md`. Strategy pattern: each layout subclass owns its mask topology and slot resolution. The dispatcher in `_update_cells` is generic. New layouts = new files; layer file does not grow.
- **D-02: Method shape — `compute_mask(coord: Vector2i, sample_fn: Callable) -> int` + `mask_to_atlas(mask: int) -> AtlasSlot`.** Per `REQUIREMENTS.md` LAYOUT-01/02. Simpler than open `paint()` (which was rejected for v0.2 since RPG Maker subtile composition is deferred to v0.3+). The diagonal-overlay case (masks 6 and 9) is handled by `AtlasSlot.diagonal_complement_atlas_coords`, not by multi-write paint().
- **D-03: `AtlasSlot` fields — atlas_coords (Vector2i), transform_flags (int = 0), alternative_tile (int = 0), diagonal_complement_atlas_coords (Vector2i, optional).** Per LAYOUT-04. The `alternative_tile` field is declared in Phase 1 but only consumed by Phase 3.5 PixelLab layouts that ship variation_seed wiring; intermediate layouts leave it 0.
- **D-04: `_pack_alternative(alt_id, transform_flags)` helper guards `assert(alt_id < 4096)`.** Prevents bit-collision pitfall (alternative_tile and TRANSFORM_FLIP_* share one int).
- **D-05: Layout subclass declares `is_dual_grid() -> bool` virtual.** Cannot be auto-detected from template visuals (DualGrid16 and Wang2Corner share silhouettes, different grid models). Tetra Horizontal/Vertical/DualGrid16 return `true`; Wang2Corner/Wang2Edge/all blob layouts return `false`. Spike finding confirmed in `TEMPLATE_CONVENTIONS.md` §5.
- **D-06: `TetraTileMapLayer` carries BOTH paint pipelines (dual-grid + single-grid) in Phase 1.** Even though Phase 1's only layouts (Tetra H/V) are dual-grid, shipping both pipelines now means Phase 2's first single-grid layout (Wang2Corner) requires zero changes to the layer file. Phase 1 = load-bearing architecture; Phases 2/3/3.5 = pure subclass adds.
- **D-07: `_resolve_layout()` returns a lazy singleton `TetraTileLayoutTetraHorizontal` when `atlas_contract == null`.** One unified dispatch path. The v0.1 inline match goes away — its behavior moves into the singleton's `mask_to_atlas` table. Per CONTRACT-04: null-contract scenes render bit-identically.
- **D-08: Idempotence guard + disconnect-before-reconnect on `Resource.changed`.** Per CONTRACT-05. Setter pattern: `if value == _atlas_contract: return` then `disconnect → assign → connect`.

### Decoder (Phase 1 owns this — defines framework for all v0.2 layouts)

The decoder is the user's stated priority: *"allow users to intuitively create a template AND its bitmask without authoring each primitive data value (no manual AtlasSlot records per slot)."* All decoder rules locked across spikes 001 / 002 / 003.

- **D-09: Background-detection rule (verbatim user articulation).** *"Any pixel that isn't transparent or white is a bit mask peer connection."* Concretely: alpha < 64 → empty; rgb >= 240 each channel → empty; otherwise bit set. Handles both alpha-encoded greyboxes (TetraTile's existing) and color-encoded silhouettes (dandeliondino-style). Validated across 9 templates in spike 002 + 16 PixelLab samples in spike 003.
- **D-10: 8-anchor sampler — 4 corner-quadrant centers + 4 edge midpoints.** No center bit (TetraTile's mask-0-implies-empty semantics). Layout subclass declares which subset of `{TL, TR, BL, BR, T, E, B, W}` are mask bits.
- **D-11: 3×3 majority vote at each anchor (≥5 of 9 alpha-opaque).** Resilient to AA, single-pixel anomalies, AI generation noise. Validated in spike 001 (anti-aliased painted-template probe) and spike 003 (PixelLab generation noise).
- **D-12: Tile-size-invariant anchor formulas.** `quarter = tile // 4`, `half = tile // 2`, `inset = max(2, tile // 16)`. Verified at 16 px (TetraTile greyboxes) and 64 px (dandeliondino + PixelLab). Geometric outline rejection — anchors are placed ≥4 px inside the slot, never sampling outline / grid-line pixels.
- **D-13: Decode at Resource load + cache.** Sub-millisecond cost across all v0.2 templates (≤1.7 ms for 48-slot blob47, ≤300 µs for 8×8 PixelLab). The decoded `Array[AtlasSlot]` (or per-mask cell-position list for variation-bank layouts) is cached on the layout Resource until `Resource.changed` invalidates it.
- **D-14: Mask 0 disambiguation per grid model.** Dual-grid layouts erase the display cell on mask 0 (preserves v0.1 behavior). Single-grid layouts may optionally point `mask_slots[0]` at an "isolated/lonely tile" slot; otherwise erase. The dandeliondino blob47 template has TWO mask-0 slots (truly blank vs center-only) — single-grid layouts can pick which represents "isolated."
- **D-15: Surface ambiguous / missing / unrecognized slots via `update_configuration_warnings()`.** Spike 001's failure-mode probes already validated: ambiguous slots (two slots same mask), missing masks (gaps in the mask coverage table), and slots that fail the topology constraint (e.g., blob47's corner-implies-adjacent-edges) all detectable. Edit-time warnings catch broken templates before runtime.

### Phase 1 deliverables — specifically

- **D-16: `TetraTileLayoutTetraHorizontal` + `TetraTileLayoutTetraVertical` subclasses.** Both override `is_dual_grid()` to return `true`. Both produce visually bit-identical output to v0.1's HORIZONTAL / VERTICAL atlas_layout enum modes. Per TETRA-01/02/03.
- **D-17: Bundled default `TetraTileAtlasContract` Resource.** Shipped at `addons/tetra_tile/contracts/default_horizontal.tres` (or similar) referencing `TetraTileLayoutTetraHorizontal`. Plus a `default_vertical.tres` for the vertical variant. Drop a fresh `TetraTileMapLayer` into a scene + assign one of the bundled contracts → instant working autotile.
- **D-18: Bundled `TetraTileLayoutTetraHorizontal.tres` + `TetraTileLayoutTetraVertical.tres`.** Pre-populated with `template_image` references to the existing `addons/tetra_tile/templates/tetra_horizontal.png` and `tetra_vertical.png` (already shipped in commit e86036f). Inspector typed-picker shows them under the contract's `layout` slot per success criterion 5.
- **D-19: v0.1's `atlas_layout: AtlasLayout` enum is hard-removed.** Pre-1.0 breaking change; CHANGELOG entry in Phase 5. Migration path: v0.1 scenes that haven't been updated render unchanged via the null-contract fallback (D-07). Scenes that explicitly set `atlas_layout` will need to swap to assigning `atlas_contract` instead — documented in DOC-02 (Upgrading from 0.1.x).
- **D-20: PREVIEW-01 — `template_image: Texture2D` declared on TetraTileLayout base.** Renders inline in inspector via Godot's stock Texture2D preview (no `EditorInspectorPlugin` needed). The other PREVIEW-* requirements (fallback_tile_set bundling, fallback runtime routing) live in Phases 2/4 — Phase 1 only declares the FIELD.

### Inspector + tooling

- **D-21: No `EditorInspectorPlugin` polish in Phase 1.** Per `PROJECT.md` identity guardrail. Typed `@export var layout: TetraTileLayout` gives Godot's stock typed-picker; no custom UI.
- **D-22: `description: String` (multiline) declared on TetraTileLayout base.** Per LAYOUT-03. Plus a class-level `##` doc-comment for inspector hover hints.
- **D-23: Editor-side layout visualizer (parked).** User mentioned wanting a visualizer. Lighter alternatives surveyed (`@tool`-mode Control rendering decoded mask grid; Node-based visualizer in demo scene). Defer to Phase 5 demo work or v0.3.

### v0.2 scope expansion (informs Phase 2-5)

The brainstorm expanded v0.2 from 8 to 11 layouts. Phase 1 doesn't deliver these, but the architecture must accommodate them. Listed here so the planner can verify Phase 1's interface is sufficient.

- **D-24: New layout — `TetraTileLayoutMinimal3x3`** (Match Sides 3×3 minimal, 9 tiles, single-grid, 4-bit edge mask). Covers PixelLab "Tileset 3×3" export + RPG Maker A2 + legacy Godot 3.x atlases. Lands in Phase 2 alongside Wang2Edge.
- **D-25: New layouts — `TetraTileLayoutPixelLabTopDown` + `TetraTileLayoutPixelLabSideScroller`** (Aseprite plugin native, 8×8 atlas with variation banks, single-grid, 4-bit corner mask). Cell-to-role tables hardcoded verbatim from `tileset_transform.lua`. Role-to-mask bijection locked in spike 003: `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]`. Identical mapping for both modes; only cell-to-role layout differs. Land in new Phase 3.5 (after standard blob47 layouts; before Phase 4 fallback routing).
- **D-26: `variation_seed` wiring (Phase 3.5 prerequisite).** REQUIREMENTS.md `CONTRACT-02` declares `variation_seed: int = 0` as a placeholder. PixelLab layouts wire it up to a deterministic hash + bucket-pick: `cells = mask_to_atlas_cells[mask]; pick = cells[hash(coord, variation_seed) % cells.size()]`. Doesn't need full `TileData.probability` infrastructure (deferred to v2). Lands in Phase 3.5 alongside the PixelLab layouts that need it.
- **D-27: ROADMAP.md and REQUIREMENTS.md updates.** ROADMAP.md needs Phase 3.5 inserted + new layouts added to Coverage table. REQUIREMENTS.md needs new requirement IDs (e.g., `MIN3x3-01`, `PIXLAB-01..04`, `VAR-PIXEL-01`). These updates are surfaced as a Phase 1 prerequisite — but actually executing them is part of planning rather than Phase 1's implementation work. Flagged for the planner.

### Claude's discretion (planner has flexibility here)

- **File layout / folder structure.** Where to put new `.gd` files (`addons/tetra_tile/` flat vs `addons/tetra_tile/layouts/` subdir). The planner should pick whichever keeps imports clean and matches `CONVENTIONS.md`.
- **Default `.tres` file naming** (`default_horizontal.tres` vs `tetra_horizontal_default.tres` etc.). Cosmetic.
- **`Resource.changed` signal-storm coalescing details.** v0.1's `_queue_rebuild` deferred coalescer is the precedent (`PITFALLS.md` §4); preserve the pattern, exact wiring is implementation detail.
- **`update_configuration_warnings()` exact warning copy.** As long as ambiguous / missing / unrecognized slots are flagged with actionable text.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project + roadmap

- `.planning/PROJECT.md` — milestone scope, identity guardrails, Out-of-Scope list, Key Decisions table
- `.planning/REQUIREMENTS.md` — all 39 v1 requirements; Phase 1 owns CONTRACT-01..05, LAYOUT-01..05, TETRA-01..03, PREVIEW-01
- `.planning/ROADMAP.md` — phase breakdown; success criteria per phase. **NOTE:** v0.2 scope expanded during this discuss session — ROADMAP.md needs an update reflecting Phase 3.5 + 3 new layouts (deferred to planning)
- `.planning/STATE.md` — current position; will be updated after CONTEXT.md commits

### Research — architecture + design

- `.planning/research/SUMMARY.md` — synthesis of upstream research; Phase 1 plan reference
- `.planning/research/ARCHITECTURE.md` — current `_resolve_slot` design, lazy layer pattern, anti-patterns
- `.planning/research/PITFALLS.md` — alternative_tile bit packing (§1), variation determinism (§2), Resource property renames (§3), setter loops (§4), top-tile assignment (§6), `TileMapLayer.visible` cleanup (§7)
- `.planning/research/STACK.md` — Godot 4.6 stack details
- `.planning/research/FEATURES.md` — feature catalog

### Research — layouts (the v0.2-specific body)

- `.planning/research/layouts/MASK_UNIFICATION.md` — **load-bearing**: Approach B (polymorphic Resource) selection, code shape, performance reality check, LOC budget
- `.planning/research/layouts/TAXONOMY.md` — 24-layout catalogue
- `.planning/research/layouts/COMPARISON.md` — artist-facing layout comparison reference
- `.planning/research/layouts/EDITORS.md` — Tilesetter / Tiled / LDtk / Unity / RPG Maker conventions
- `.planning/research/layouts/GODOT_TERRAIN.md` — Godot's stock terrain peering bits, MATCH_SIDES disputed semantics (#79411), pain points
- `.planning/research/layouts/TILEBITTOOLS.md` — TBT addon audit + slot tables for Phase 3
- `.planning/research/layouts/TILESETTER_AND_GODOT.md` — live-doc audit
- `.planning/research/layouts/TEMPLATE_CONVENTIONS.md` — **NEW**: prior-art synthesis (dandeliondino + Better Terrain + Godot stock); decoder design rationale; dual-grid declaration analysis
- `.planning/research/layouts/PIXELLAB.md` — **NEW**: PixelLab format audit; Aseprite plugin native + 3 export targets; locked role-to-mask mapping; v0.2 scope expansion plan

### Codebase maps

- `.planning/codebase/ARCHITECTURE.md` — overall system architecture
- `.planning/codebase/CONCERNS.md` — known concerns
- `.planning/codebase/CONVENTIONS.md` — naming, file layout, GDScript style
- `.planning/codebase/INTEGRATIONS.md` — Godot integration points
- `.planning/codebase/STACK.md` — language/version specifics
- `.planning/codebase/STRUCTURE.md` — file/directory structure
- `.planning/codebase/TESTING.md` — testing approach (visual regression on demo)

### Spike findings (the load-bearing decoder validations)

- `.planning/spikes/001-template-decoder-feasibility/README.md` — VALIDATED. 3×3 majority vote + alpha-only sampling + geometric outline rejection. Initial brightness floor was anti-helpful and got dropped.
- `.planning/spikes/002-blob47-decoder-generalization/README.md` — VALIDATED. Unified background rule (transparent OR white = empty) handles both TetraTile alpha-encoded greyboxes AND dandeliondino color-encoded silhouettes. Generalizes across tile sizes (16, 64 px) and topologies (corner / edge / blob47).
- `.planning/spikes/003-pixellab-bit-mapping/README.md` — VALIDATED. PixelLab native role-to-mask bijection locked across both top-down and side-scroller layouts. Variation-bank semantics confirmed.
- `.planning/spikes/MANIFEST.md` — spike index + locked design decisions
- `.planning/spikes/CONVENTIONS.md` — Python+Pillow stack, output conventions

### Brainstorm continuity

- `.planning/phases/01-contract-skeleton-tetra-layouts/01-PRE-SPIKE-NOTES.md` — initial brainstorm capture before spikes ran. Reference for "why we ended up here."
- `.planning/phases/01-contract-skeleton-tetra-layouts/01-DISCUSSION-LOG.md` — full discuss-phase Q&A audit trail (companion to this CONTEXT.md)

### v0.1 source + assets

- `addons/tetra_tile/tetra_tile_map_layer.gd` — 261 LOC v0.1; lines 67-152 are the current `_paint_display_cell` 16-state match that moves into `TetraTileLayoutTetraHorizontal`
- `addons/tetra_tile/templates/_generate_greybox_templates.py` — Pillow generator for the 5 shipped greyboxes; reference for tile dimensions + mask conventions
- `addons/tetra_tile/templates/{tetra_horizontal,tetra_vertical,dual_grid_16,wang_2corner,wang_2edge}.png` — 5 shipped greyboxes; Phase 1 layouts reference `tetra_horizontal.png` and `tetra_vertical.png`
- `addons/tetra_tile/templates/README.md` — artist-facing template spec; mask conventions (LOCKED)

### External (read-only)

- `C:\Users\shilo\AppData\Roaming\Aseprite\extensions\pixellab\tileset_transform.lua` — source of truth for PixelLab cell-to-role layouts (Phase 3.5 hardcodes these)
- `C:\Users\shilo\AppData\Roaming\Aseprite\extensions\pixellab\generate-tileset.lua` + `generate-tileset-sidescroller.lua` — endpoint + canvas-size logic for PixelLab (informational; not directly used in implementation)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`tetra_tile_map_layer.gd`** (261 LOC) — v0.1 core; the 16-state match in `_paint_display_cell` (lines 116-152) becomes `TetraTileLayoutTetraHorizontal.mask_to_atlas`'s table. The corner-mask computation in `_mask_at` (lines 155-165) becomes the layout's `compute_mask` body. Roughly half of the file's LOC moves into the layout subclass; the rest stays in the layer for both pipelines (dual-grid + single-grid).
- **`_generate_greybox_templates.py`** — Pillow generator for `tetra_horizontal.png` / `tetra_vertical.png`. Phase 1's `.tres` files reference the existing PNGs; no new template assets needed.
- **5 shipped greybox templates** — already covered: corner-mask conventions verified in spike 002. The 3 missing (blob_47_godot, tilesetter_wang_15, tilesetter_blob_47) ship in Phase 3.

### Established patterns (from `CONVENTIONS.md` + v0.1 source)

- **Setter discipline.** v0.1's `atlas_source_id` setter does direct assignment + `_queue_rebuild()`. The new `atlas_contract` setter must do idempotence guard + disconnect-before-reconnect on `Resource.changed` + `_queue_rebuild()` (D-08).
- **Lazy layer creation.** v0.1's `_ensure_visual_layers()` (lines 198-214) is a clean pattern for the dual-grid pipeline. Single-grid pipeline can use a simpler "visible layer = self_modulate alpha 1; logic layer = self_modulate alpha 0" approach without the half-tile offset.
- **Deferred rebuild coalescing.** `_queue_rebuild` calls `rebuild.call_deferred()`. Re-use the pattern verbatim to avoid signal storms when contract / layout properties change.
- **Internal child layers.** v0.1 uses `Node.INTERNAL_MODE_FRONT` for the visual + overlay layers. Phase 1 preserves that pattern.

### Integration points

- **`@export var atlas_contract: TetraTileAtlasContract`** on `TetraTileMapLayer` (replaces `atlas_layout` enum). Typed export gives Godot's stock typed-picker.
- **Null fallback.** When `atlas_contract == null`, `_resolve_layout()` returns a singleton `TetraTileLayoutTetraHorizontal` with v0.1 defaults. v0.1-style scenes (no contract assigned) keep working.
- **Layout's `template_image`** is consumed by the auto-decoder at Resource load. The decoded slot table is cached on the layout instance.

### LOC budget

Per `MASK_UNIFICATION.md` §6.3 estimate (Phase 1 scope only):

- `tetra_tile_map_layer.gd`: ~290 LOC (v0.1 260 + ~30 for both pipelines + setter discipline; the 16-state match relocates out)
- `tetra_tile_atlas_contract.gd`: ~50 LOC
- `tetra_tile_atlas_slot.gd`: ~30 LOC
- `tetra_tile_layout.gd` (NEW base): ~50 LOC (interface + decoder helper functions)
- `tetra_tile_layout_tetra_horizontal.gd` (NEW): ~80 LOC (16-state mask_to_atlas table)
- `tetra_tile_layout_tetra_vertical.gd` (NEW): ~30 LOC (overrides atlas_coords axis vs horizontal)
- **Phase 1 total: ~530 LOC** across 6 files. Comfortably under TileMapDual's ~700-900 LOC.

End-of-Phase-1 LOC checkpoint logs the actual number per `ROADMAP.md` Identity Guardrails.

</code_context>

<specifics>
## Specific Ideas

### Two-image decoder system (visual + decoder)

Per the brainstorm: layout supports both `template_image: Texture2D` (the artist's canvas, can be anything) AND optional `decoder_image: Texture2D` (the silhouette/peering encoding the addon decodes). When `decoder_image` is null, the addon decodes from `template_image` (Option A's "silhouette IS the decoder"). When `decoder_image` is set, the user's explicit decoder overrides — the visual can diverge freely from quadrant conventions.

For Phase 1, the `decoder_image` field is **declared** on TetraTileLayout but Phase 1 layouts (Tetra H/V) hardcode their slot tables (preserving v0.1 visual bit-identity). The `decoder_image` decode path activates for user-defined layouts in Phase 4+ work.

### PixelLab variation-bank pitch (for README)

> **PixelLab interop:** TetraTile reads PixelLab's full 8×8 native generation including the variation tiles the official exporter discards. Drop a PixelLab Aseprite output into your scene with a `TetraTileLayoutPixelLabTopDown` or `…SideScroller` contract — get up to 28 variants of the bulk fill for free.

This is a meaningful differentiator (PixelLab's own exporter does first-occurrence-only and discards duplicates). Document in Phase 5's README work.

### Mask convention summary (locked, applies to all v0.2 layouts)

```
Corner mask (Tetra / DualGrid16 / Wang2Corner / PixelLab):
  TL=1, TR=2, BL=4, BR=8     →  mask 0..15

Edge mask (Wang2Edge / Minimal3x3):
  T=1, E=2, B=4, W=8         →  mask 0..15
  (CR31 N/E/S/W naming; T = north / "up", B = south / "down")

Blob mask (Blob47Godot / TilesetterBlob47):
  TL=1, TR=2, BL=4, BR=8, T=16, E=32, B=64, W=128
  → 256 raw, 47 reachable + 1 blank = 48 valid
  Constraint: corner bit set requires both adjacent edge bits set
```

### Out-of-band progress acknowledgment

5 of 8 greybox templates + the generator script shipped in commit e86036f. Phase 1's TetraHorizontal/Vertical layouts reference the existing `tetra_horizontal.png` and `tetra_vertical.png` directly — no new template authoring needed in Phase 1.

</specifics>

<deferred>
## Deferred Ideas

### Pushed to Phase 2/3/3.5/4/5 (within v0.2 scope)

- `TetraTileLayoutDualGrid16` — Phase 2
- `TetraTileLayoutWang2Corner` / `TetraTileLayoutWang2Edge` — Phase 2
- `TetraTileLayoutMinimal3x3` (NEW per scope expansion) — Phase 2 alongside Wang2Edge
- `TetraTileLayoutTilesetterWang15` — Phase 3
- `TetraTileLayoutBlob47Godot` / `TetraTileLayoutTilesetterBlob47` — Phase 3
- `TetraTileLayoutPixelLabTopDown` / `TetraTileLayoutPixelLabSideScroller` (NEW) — Phase 3.5
- `variation_seed` deterministic hash + bucket-pick (NEW) — Phase 3.5 prerequisite
- Bundled `fallback_tile_set` per layout — Phase 2 (NATIVE-04, PREVIEW-02)
- Runtime fallback routing (`tile_set == null` → use layout's fallback) — Phase 4
- Demo scene refresh + README — Phase 5

### Pushed to v0.3 / future milestones (out of v0.2 scope)

- **Y-axis variation** (full `TileData.probability` machinery) — original v0.2 pillar, deferred. The minimal `variation_seed` wiring in Phase 3.5 is the prerequisite for full variation later but doesn't deliver it.
- **Top-tile support** — original v0.2 pillar, deferred. Needs design discussion against the layout-library shape.
- **RPG Maker A2/A4 subtile composition** — architecturally reserved (`TetraTileLayout` slot exists), but the quarter-tile compositor is a v0.3+ refactor.
- **Tiled `.tsx` / LDtk `.ldtk` rule importers** — both editors store rules in project files, not atlases; rule-importer infra is out of scope.
- **TetraBake** (procedural 5th-tile composition) — parking lot.
- **Tileset converter** (Wang/blob → TetraTile) — authoring tooling deferred.
- **Multi-terrain transitions** (grass→dirt etc.) — distinct R&D track.
- **Shader fallback** for diagonal compositing — performance optimization not needed at demo scale.
- **Editor visualizer** (`@tool` Control rendering decoded mask grid alongside template) — discussed during brainstorm; defer to Phase 5 demo or v0.3.
- **TileMapDual deep audit** — proposed during brainstorm; user picked "PixelLab only, then conclude" instead. Defer; not blocking Phase 1.

### Reviewed during brainstorm but explicitly deferred

- **Auto-detection of dual-grid vs single-grid from template visuals** — concluded impossible (same template visuals serve both grid models). Locked as explicit subclass declaration (D-05).
- **Auto-detection of mask topology from a single template image** — fragile across slot-0 conventions. Layout subclass declares topology (D-05); auto-detect stays as a courtesy fallback for tooling.
- **Free-form atlas decoder** for PixelLab native — superseded by spike 003's finding that PixelLab native uses a fixed 8×8 layout with hardcoded role-IDs. Not free-form.

</deferred>

---

*Phase: 01-contract-skeleton-tetra-layouts*
*Context gathered: 2026-04-25*
