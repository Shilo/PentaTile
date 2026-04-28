# Changelog

All notable changes to **PentaTile** (formerly TetraTile) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased] — v0.2 in progress

### BREAKING — Project rename: TetraTile → PentaTile

The entire project has been renamed from **TetraTile** to **PentaTile**.
This is a breaking change with no backwards-compatibility shims, per the project's no-backwards-compat policy.

Renamed surface:

- Addon folder: `addons/tetra_tile/` → `addons/penta_tile/`
- Plugin id: `tetra_tile` → `penta_tile`
- Core class: `TetraTileMapLayer` → `PentaTileMapLayer`
- Contract class: `TetraTileAtlasContract` → `PentaTileAtlasContract`
- Layout base: `TetraTileLayout` → `PentaTileLayout`
- Layout subclasses: `PentaTileLayoutPentaHorizontal`, `PentaTileLayoutPentaVertical`
- All GDScript files: `tetra_tile_*.gd` → `penta_tile_*.gd`
- All `.tres` / `.tscn` assets: `tetra_*` → `penta_*`
- Custom data layer keys: `tetra_role` → `penta_role`, `tetra_lock_rotation` → `penta_lock_rotation`
- Requirement IDs: `TETRA-01..03` → `PENTA-01..03`, `TETRA-SYNTH-01..12` → `PENTA-SYNTH-01..12`
- `project.godot` config name: `"TetraTile"` → `"PentaTile"`

### Added — Penta codename anchors

- `README.md` § **What is a Penta tileset?** — canonical labeled-diagram section defining the 5 archetypes (IsolatedCell, Fill, Border, InnerCorner, OppositeCorners) and "Penta" as a coined term alongside Wang and Blob.
- `CLAUDE.md` § **Coined-Term Discipline** — project invariant reserving "Penta" exclusively for the 5-archetype format; prohibits `PentaCache`, `PentaDecoder`, or any unrelated "Penta" prefix.

### BREAKING — Phase 2: Architectural Simplification + Native Layout Library

**`PentaTileAtlasContract` deleted.** `layout: PentaTileLayout` lives directly on `PentaTileMapLayer` — no contract wrapper, no `version: int` speculative field. Per the no-forward-compat policy.

**Phase 1's `PentaTileLayoutPentaHorizontal` + `PentaTileLayoutPentaVertical` merged into a single `PentaTileLayoutPenta` class** with two enums:
- `axis: Axis { HORIZONTAL, VERTICAL }`
- `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE, TWO, THREE, FOUR, FIVE }` — five progressive synthesis modes per strip plus AUTO (dimension-only detection) and AUTO_STRIP (per-strip detection).

**New slot ordering** for the 5 Penta archetypes: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — synthesized from slot 0 with rotation across all modes; never has a dedicated slot (Path B).

**Runtime overlay layer DELETED entirely.** All v0.2 layouts render via single-layer 5-archetype dispatch. Removed: `PentaTileMapLayer._overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, `AtlasSlot.diagonal_complement_atlas_coords`. `PentaTileMapLayer` now has exactly ONE child visual layer.

**`template_image` renamed to `bitmask_template`** on `PentaTileLayout` base class. Single image serves as inspector preview AND fallback `TileSet` source — no atlas/bitmask split. **`fallback_tile_set` `@export` removed**; replaced by `get_fallback_tile_set()` virtual method that builds a `TileSet` from `bitmask_template` at runtime. **`decoder_image` deleted** (was speculative).

**Bundled bitmask PNGs co-located** next to layout `.gd` files. The old `templates/` folder is deleted entirely. Penta has 10 PNGs in `addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png`. Single-variant layouts use flat siblings: `penta_tile_layout_dual_grid_16.png`, `penta_tile_layout_wang_2_edge.png`, `penta_tile_layout_wang_2_corner.png`, `penta_tile_layout_minimal_3x3.png`. Original v0.1 `penta_tile_template.png` deleted.

### Added — Phase 2: Native Layout Subclasses

Four hand-authored layouts ship in this milestone:

- **`PentaTileLayoutDualGrid16`** — 4×4 atlas with 16 explicit tiles for every dual-grid corner mask (TL=1/TR=2/BL=4/BR=8). No rotation reuse; every state maps to a unique authored tile. Uses `mask % 4 = col, mask / 4 = row`.
- **`PentaTileLayoutWang2Edge`** — single-grid 4×4 atlas, edge mask N=1/E=2/S=4/W=8 (also known as Marching Squares / Cellular Automata 2-Edge). Edges form lines and paths.
- **`PentaTileLayoutWang2Corner`** — single-grid 4×4 atlas, corner mask sampling diagonal neighbors NE=1/SE=2/SW=4/NW=8. Same `mask%4 / mask/4` formula as DualGrid16 but semantically different bit-to-neighbor mapping.
- **`PentaTileLayoutMinimal3x3`** — single-grid 3×3 9-tile atlas with open-side collapse rule (col/row = 0 if that side is exclusively open, 2 if exclusively closed on opposite, 1 (center) otherwise). Masks 5 (T+B) and 10 (E+W) and all isolated-diagonal states collapse to the center tile (accepted visual loss for the 9-tile minimum).

### Added — Phase 2: Synthesis Engine

- **`PentaTileSynthesis`** (`addons/penta_tile/penta_tile_synthesis.gd`) — load-time synthesis engine that generates missing archetypes for ONE/TWO/THREE/FOUR modes from the explicit slots present in the source atlas. Includes:
  - **`synthesize_strip()`** — main entry point; dispatches per `TileCountMode`.
  - **`clip_polygon_to_subrect()`** — Sutherland-Hodgman polygon clipper for collision/occlusion/navigation polygon transfer to synthesized sub-region tiles.
  - **`transform_vertex()`** — locked Gate 2 transform order: `TRANSPOSE → FLIP_H → FLIP_V`.
  - **`build_tile_set_from_synthesis()`** — wires synthesized slots to a `TileSetAtlasSource` for the layer to consume.
  - **Signature-based idempotence** — synthesis re-runs only when `(instance_id, axis, tile_count, source_id, resolved_mode)` changes; `rebuild()` is safe to call repeatedly.
  - **Polygon transfer** — collision/occlusion/navigation polygons are copied with appropriate transforms. Animation/custom-data/probability/y-sort are NOT copied (documented as a layout-choice tradeoff).

### Added — Phase 2: Auto-Detection + Configuration Warnings

- **AUTO mode** — `PentaTileLayoutPenta.resolve_active_mode()` reads atlas axis dimension (1/2/3/4/5 → ONE/TWO/THREE/FOUR/FIVE). Atlas axis size 0 or 6+ disables rendering and emits a configuration warning.
- **AUTO_STRIP mode** — `PentaTileLayoutPenta.resolve_strip_modes()` independently detects each strip's tile count via `TileSetAtlasSource.has_tile()` checks. Different strips can use different modes within a single atlas. **Per-strip dispatch wired in commit 29cba37** (post-Wave 6, retroactive): the layer's `_ensure_synthesized_tile_set` branches on `AUTO_STRIP`, calls `resolve_strip_modes`, threads `strip_origin` per strip, builds a 5×N synthesized atlas (one row per strip; gap strips render empty + emit warning C). `mask_to_atlas` and `_make_slot` accept `strip_index: int = 0`; new virtual `PentaTileLayout.resolve_display_strip(coord, sample_atlas_fn)` returns the strip index for a painted display cell — Penta override picks the first non-empty TL→TR→BL→BR neighbor's source-atlas-coord (HORIZONTAL → `coords.y`, VERTICAL → `coords.x`); non-Penta layouts inherit base default = 0. Spec correction landed alongside: Wave 2's `synthesize_strip` docstring described Interpretation B (cumulative offset along slot axis) but Wave 6's `resolve_strip_modes` implemented Interpretation A (perpendicular strips); **Interpretation A locked**, default `strip_origin` sentinel formula corrected to `Vector2i(0, strip_index)` HORIZONTAL / `Vector2i(strip_index, 0)` VERTICAL. Mixed-strip painting documented as v0.2 best-effort (first-non-empty-neighbor wins); proper terrain transitions remain MULTITERR-* in v2 backlog.
- **`get_configuration_warnings_for(layer)`** virtual on `PentaTileLayoutPenta` — duck-typed delegation from `PentaTileMapLayer._get_configuration_warnings()` surfaces atlas-size / mode-mismatch warnings in the Godot inspector.

### Added — Phase 2: Determinism Test Harness

- **`addons/penta_tile/tests/determinism_test.gd`** — headless Godot regression script with 4 sub-tests:
  - Sub-test (a): `transform_vertex` worked example (all 8 flag combinations against locked Gate 2 truth table).
  - Sub-test (b): `clip_polygon_to_subrect` hash determinism (10 invocations).
  - Main test: 11 `rebuild()` runs; asserts all hashes identical AND match `BASELINE_HASH=2986698704`.
  - Sub-test (c): VERTICAL-axis structural coverage (WR-07 regression net) — asserts cell count matches `BASELINE_CELLS=46` from HORIZONTAL AND every painted atlas coord resolves in the synthesized atlas via `source.has_tile()`.
- **`addons/penta_tile/tests/_capture_baseline.gd`** — baseline capture utility with optional `--layout-path=<res_path>` CLI flag for capturing baselines against alternative layouts (e.g., `penta_layout_four_vertical.tres`).

Run via:
```
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script addons/penta_tile/tests/determinism_test.gd
```

### Phase 2 UAT bug-fix sweep (2026-04-28)

Closed 7 bug classes surfaced by user UAT against the demo scene with custom artist tile_set artwork. Commits `6553380` through `205fb67`.

**Bugs fixed:**

- **Bundled bitmask greyboxes** (`addons/penta_tile/_generate_bitmasks.py`) iterated through 4 silhouette designs before settling on the right shape per layout. **Single-grid edge-mask layouts (Wang2Edge, Min3x3) now ship solid 32×32 atlases** — partial-quadrant fills don't compose without dual-grid's half-tile offset, so single-grid uses solid silhouettes (artist's per-tile artwork carries the visual variation). **Wang2Corner gained its own solid 32×32 atlas** instead of reusing DualGrid16's partial-quadrant atlas (Wang2Corner is single-grid; DualGrid16's atlas is for dual-grid composition). **Penta dual-grid layouts keep per-archetype shapes** for slots 0–4 (slot 0 = BL quadrant only, slot 1 = full, slot 2 = bottom half, slot 3 = L-shape, slot 4 = TL+BR diagonal).

- **`PentaTileMapLayer._paint_via_layout` — single-grid logic-painted gate.** Previously, marking cardinal neighbors as affected caused them to also paint their own visual tile, extending the painted region by a full cell. Single-grid layouts now skip painting non-logic-painted cells (cardinal neighbors still trigger re-renders of their painted neighbors when the mask changes, but they don't render their own tile). Dual-grid layouts unchanged — they still paint all affected display cells (perimeter cells fill INNER quadrants that fall inside the painted logic pixel bounds).

- **`mask=0` short-circuit gated on `is_dual_grid()`.** Previously, the universal `mask == 0 → return` short-circuit dropped logic-painted single-grid cells whenever their mask sampler found no neighbors — isolated 1×1 paints, 1×N lines in Wang2Corner where straight lines have no diagonals. Now only dual-grid uses this short-circuit. All 3 single-grid layouts (Wang2Edge, Wang2Corner, Min3x3) drop their `mask == 0 → null` returns from `mask_to_atlas`; isolated cells dispatch to atlas (0, 0) for the Wangs and atlas (1, 1) for Min3x3 (per the open-side rule).

- **`PentaTileSynthesis._apply_canonical_silhouette()` (NEW)** enforces per-archetype expected opaque region during authored-slot extraction (FOUR/FIVE modes). Penta dispatches with rotation flags (TRANSPOSE | FLIP_H | FLIP_V) at render time. Stray opaque pixels in an artist's "cut" quadrant (e.g., orange inner-corner outline drawn at col 8 of slot 3's TR cut) get rotation-mapped INTO adjacent painted cells, producing visible bleed. The new method zeros the alpha of any pixel outside each archetype's canonical opaque region during synthesis, so artist art straying outside the expected silhouette can't bleed via rotation.

**Test coverage:**

The test suite grew from 9 → 12 tests, with 4 new/fortified tests catching this entire class of bug:

- `addons/penta_tile/tests/bitmask_bounds_test.gd` (NEW) — pixel-by-pixel verification of every bundled bitmask greybox PNG against expected per-slot silhouette. Catches generator drift.
- `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (NEW) — paints 16 patterns (1×1, 1×2_h, 1×2_v, 2×1, 2×2, 3×3, 4×4, 5×5, line_h_5, line_v_5, L_shape, T_shape, plus_shape, diag_pair, diag_anti, 3_isolated) across all 5 layouts and asserts: (a) every painted cell renders, (b) single-grid cells dispatch to 100%-opaque tiles, (c) dual-grid cells dispatch to non-zero-opacity tiles, (d) no out-of-bounds visual cells, (e) opaque pixel bbox matches user_cells × tile_size.
- `addons/penta_tile/tests/penta_ground_hollow_test.gd` (NEW) — uses the demo's actual `penta_tile_ground.tres` source atlas (real artist artwork), paints a hollow ring (8×8 outer, 4×4 hole), asserts opaque-pixel bbox stays within painted bounds AND zero opaque pixels render inside the hole. Catches rotation-bleed bugs that don't appear with bundled greyboxes.
- `addons/penta_tile/tests/all_layouts_swap_pixel_test.gd` (FORTIFIED) — added per-edge continuity (≥80% opacity at painted-neighbor edges), interior coverage (mask=15 ≥ 80%), bbox bounds, per-cell solidity (single-grid 100% opaque) assertions.

Each fix was verified by stashing the patch, rerunning, confirming failure, applying the fix, confirming pass — the gold-standard regression-net protocol.

**Methodology:**

The 6-commit cycle exposed gaps in the original test methodology. Lessons codified in `CLAUDE.md` § Test Methodology, three new Critical Pitfalls (#8 single-grid logic-painted gate, #9 single-grid mask=0 dispatch, #10 Penta canonical-silhouette enforcement), and a full retrospective in `.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md`. Cross-session memories `feedback_visual_testing.md` + `feedback_root_cause_discipline.md` capture the rules ("compose canvas pixel-by-pixel, not just dispatch tables", "trace full pipeline before patching symptoms").

### Migration notes for v0.1.x consumers

1. Replace all references to `TetraTileMapLayer` with `PentaTileMapLayer` in your scenes and scripts.
2. Move your `addons/tetra_tile/` folder to `addons/penta_tile/` and re-enable the plugin in Project Settings → Plugins.
3. If you stored the addon path in any tool scripts or CI configs (`res://addons/tetra_tile/`), update those to `res://addons/penta_tile/`.
4. Replace `atlas_contract = ...` on your `PentaTileMapLayer` instances with `layout = PentaTileLayoutPenta(axis=..., tile_count=...)` (or any other layout subclass). The `PentaTileAtlasContract` class is deleted.
5. If you authored against `PentaTileLayoutPentaHorizontal` / `PentaTileLayoutPentaVertical`, swap to `PentaTileLayoutPenta` with the appropriate `axis: Axis` enum value. Your atlas tile counts (1/2/3/4/5 along the strip axis) auto-detect under `tile_count = AUTO`.
6. If you reference `template_image` anywhere, rename to `bitmask_template`.
7. If you bind `fallback_tile_set` directly on a layout, remove it — `get_fallback_tile_set()` builds one from `bitmask_template` automatically.

---

## [0.1.0] — 2025-04-26

Initial release as **TetraTile**.

- Dual-grid autotiling via `TileMapLayer` subclass.
- 4-tile binary atlas: Fill, Inner Corner, Border, Outer Corner.
- 16-state marching-squares mask with transform-based rotations.
- Overlay layer composition for disconnected-diagonal masks (6 and 9).
- Horizontal and Vertical atlas layout support.
- Demo scene with platformer player and runtime painter.
