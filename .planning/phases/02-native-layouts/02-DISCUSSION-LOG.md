# Phase 2: Native Layouts — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 02 — Native Layouts
**Areas discussed:** Layout name (Tetra5 root), 5th-tile rotation semantics, Dispatcher overlay-skip mechanism, Phase scope routing

---

## Trigger — user-driven scope expansion

The user asked to extend Phase 2's original scope (DualGrid16 / Wang2Edge / Wang2Corner / Min3x3) by appending a **5-tile** Tetra layout pair. The 5th tile is an explicit "edge connector" / diagonal art slot that obviates the runtime `_overlay_layer` for masks 6 (NE+SW) and 9 (NW+SE). Architectural lift: the dispatcher learns to skip the overlay layer when the active layout doesn't need it, which incidentally also benefits all other Phase-2/3/3.5 non-Tetra4 layouts.

User's framing of the architectural change:
- 4 tile = 2 child tilemap layers (primary visual + diagonal overlay)
- 5 tile, dual grid = 1 child tilemap layer (primary visual only)
- All other layouts = 1 child tilemap layer (primary visual only)

Note: the user's "no need for additional tilemap layers" framing for non-Tetra4 layouts conflates the user's own painted layer (the **logic** layer, hidden via `self_modulate.a`) with the visual layers. All layouts always need *one* visual TileMapLayer; what disappears for non-Tetra4 layouts is specifically the **overlay** / diagonal-composition layer (the 3rd one).

---

## Layout name

**Question:** What should the new 5-tile Tetra layouts be called?

### Round 1 (initial options)

| Option | Description | Selected |
|---|---|---|
| TetraEdge (Recommended) | Names the 5th tile's role — diagonal/edge connector. | |
| TetraPlus | Generic 'Tetra + one more tile'. | |
| Tetra5 | Numeric tile count. | |
| TetraConnected | Emphasizes diagonal connection. | |

**User's response:** "Either Tetra5 or TetraDiagonal, as 'edge' maybe be ambigious with the border tile. is there a standard name for those edge connector tiles? if so, i might want to use the standard and most popular name. research more and ask me again."

**Notes:** User flagged the `Edge` / `Border` archetype collision (TetraTile's existing `Border` archetype = Excalibur.js's `Edge` archetype). User asked Claude to research the community-standard name before re-asking.

### Research finding

Searched the autotile/Wang/dual-grid community vocabulary. Excalibur.js's dual-grid article ([Dual Tilemap Autotiling Technique](https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/)) codifies the 5-archetype dual-grid set:

> "Graphics Tilemap (overlay) Only 5 tiles: `Edge`, `InnerCorner`, `OuterCorner`, `Filled`, or `Opposite Corners`"

So the standard community name for the **5th archetype tile** is `Opposite Corners` (or `OppositeCorners`). BorisTheBrave's "Classification of Tilesets" ([link](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/)) doesn't override this. BorisTheBrave's "Quarter-Tile Autotiling" ([link](https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/)) confirms 5-tile rotation sets are sufficient for the entire tileset when tiles rotate.

The `Opposite Corners` term is for the **5th tile**, not the **layout itself** — leaving room for picking a layout class name.

### Round 2 (research-informed options)

| Option | Description | Selected |
|---|---|---|
| Tetra5 (Recommended) | TetraTile's own number-suffix convention (Wang2Edge, DualGrid16, Blob47, Min3x3). Terse, scannable. Templates: `tetra_5_horizontal.png` / `tetra_5_vertical.png`. | ✓ |
| TetraOpposite | Aligns with Excalibur.js community term. Reads slightly oddly out loud. | |
| TetraOppositeCorners | Spelled-out community term — unambiguous but long; class names get repetitive in Godot's typed-picker. | |
| TetraDiagonal | User's earlier instinct. 'Diagonal' is overloaded (diagonal stride vs the 6/9 disconnected-diagonal mask). | |

**User's choice:** `Tetra5 (Recommended)`

**Notes:**
- The community term `Opposite Corners` is preserved as the *archetype* name (used for the constant `_OPPOSITE_CORNERS`, in code comments, in the layout's `description` field, and in the templates/README cross-reference) — the choice is to use it where it adds clarity (the tile name) rather than where it adds friction (the class name).
- `Tetra5` matches `Wang2Edge` / `Wang2Corner` / `Blob47Godot` / `TilesetterWang15` / `TilesetterBlob47` / `Minimal3x3` / `DualGrid16` — every other layout in the project that is named by tile count uses a number suffix.

---

## 5th-tile rotation semantics

**Question:** How does the 5th tile cover the two diagonal masks (6 = NE+SW, 9 = NW+SE)?

| Option | Description | Selected |
|---|---|---|
| One sprite, runtime rotates (Recommended) | True 5-tile. Author paints ONE diagonal asset; runtime applies _ROTATE_0 / mirror for the second case. Smallest atlas, biggest art saving. | ✓ |
| Two sprites (becomes 6-tile) | Each diagonal gets its own asymmetric art. Maximum artistic freedom; layout no longer "5-tile". | |
| Author-mirrored sentinel | Author paints mask 6 only; runtime auto-FLIPS for mask 9. More fragile. | |

**User's choice:** `One sprite, runtime rotates (Recommended)`

**Notes:** Locks in `Tetra5` as a true 5-slot atlas. The exact transform_flags constant for mask 6 vs mask 9 (e.g. `_ROTATE_90` vs `TRANSFORM_FLIP_H`) is left to the planner — the choice is between "match the OUTER_CORNER rotation table for visual continuity" and "match the simplest pixel-flip semantics." Either yields visually correct output if the 5th-tile sprite is painted to match v0.1's overlay-composed reference.

---

## Dispatcher / overlay-skip optimization

**Question:** How does TetraTileMapLayer know to skip the diagonal overlay child layer for layouts that don't need it?

| Option | Description | Selected |
|---|---|---|
| Add `needs_diagonal_overlay()` virtual + extend skip to ALL non-Tetra4 layouts (Recommended) | Base declares the virtual (default `false`); Tetra4 overrides `true`. `_ensure_visual_layers` lazy-creates `_overlay_layer` only when `true`. Cleanest, broadest perf win. | ✓ |
| Sentinel-only (current behavior) | Keep the existing `diagonal_complement_atlas_coords == (-1,-1)` runtime guard. Overlay layer still always created; just never painted to. | |
| Both — virtual + sentinel | Defense-in-depth. | |

**User's choice:** `Add 'needs_diagonal_overlay()' virtual + extend skip to ALL non-Tetra4 layouts (Recommended)`

**Notes:**
- The user's choice extends the perf optimization to layouts that already don't need the overlay (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) — they currently pay for an empty overlay TileMapLayer at runtime that this refactor reclaims.
- D-35 in CONTEXT.md adds a defense-in-depth layer: `_paint_via_layout` reads `_overlay_layer != null` before attempting overlay paint, so a misconfigured layout that returns `false` from `needs_diagonal_overlay()` while still setting `diagonal_complement_atlas_coords` no-ops the overlay paint instead of crashing. `update_configuration_warnings()` flags the inconsistency.

---

## Phase scope routing

**Question:** Where do the new 5-tile layouts + overlay-skip refactor land in the roadmap?

### Round 1

| Option | Description | Selected |
|---|---|---|
| Inside Phase 2 (Recommended) | Phase 2 expands from 4 to 6 native layouts + dispatcher refactor. Adds ~80–120 LOC, 2 templates, 2 fallback TileSets. | |
| Phase 2.1 decimal insert | Phase 2 ships the 4 originally planned; Phase 2.1 adds the 5-tile pair + dispatcher refactor. | |
| Phase 1.1 dispatcher-first | Architectural change lands as a tiny standalone phase before Phase 2; Phase 2 picks up the 5-tile layouts using the new hook. | |

**User's response:** "im already working on phase 2, add it as phase 3 and push the other phases back one"

**Notes:** Picked a 4th option (insert as new Phase 3, renumber 3 → 4, 3.5 → 4.5, 4 → 5, 5 → 6).

### Round 2 (correction)

**User's correction:** "sorry i was wrong, please append is to phase 2, not add a new phase"

**Final choice:** `Inside Phase 2`

**Notes:** Reverts to the original recommendation. Phases 3 / 3.5 / 4 / 5 unchanged. Phase 2's plan count grows from `TBD` to `~6` (one plan per layout family, plus the dispatcher refactor as its own wave). New TETRA5-01..05 requirements added to REQUIREMENTS.md by the planner (per D-40); ROADMAP.md Phase 2 success criteria expanded (per D-41).

---

## Claude's Discretion (handed to planner)

Per D-29, D-31, D-37, D-39 in CONTEXT.md:

- Exact `transform_flags` value for mask 6 vs mask 9 in Tetra5 (`_ROTATE_90` vs `TRANSFORM_FLIP_H` vs `TRANSFORM_FLIP_V`)
- File naming convention for the new layout files (`tetra_tile_layout_tetra5_horizontal.gd` vs `tetra_tile_layout_tetra_5_horizontal.gd` — likely the latter per the `tetra_tile_layout_tetra_horizontal.gd` precedent)
- Whether `_OPPOSITE_CORNERS` constant lives on `Tetra5Horizontal` or on a shared base
- Exact `update_configuration_warnings()` text for the malformed-overlay-contract case
- Plan wave breakdown (suggested: dispatcher refactor → 4 originally-planned native layouts in parallel → Tetra5H+V → visual regression + LOC checkpoint)

## Deferred Ideas

Per `<deferred>` section in CONTEXT.md:

- TetraBake (procedural OppositeCorners generator from Tetra4 atlas) — newly motivated by Tetra5's existence but still parked in v2 backlog (TOOL-01)
- Asymmetric 6-tile variant — rejected per D-31 (breaks "5-tile" name, doubles authoring burden)
- Author-mirrored sentinel — rejected per D-31 (fragile)
- Class-name alternatives `TetraEdge` / `TetraOpposite` / `TetraOppositeCorners` / `TetraDiagonal` — rejected per D-29 in favor of `Tetra5`

---

## SUPERSESSION NOTICE — 2026-04-26

The Phase 2.1 brainstorm session reframed the Tetra5 plan. **The decisions in CONTEXT.md (D-28..D-46) and the rounds above are partially superseded.** The user's policy on breaking changes ("always allowed, always; never write compat shims") and the realization that the previously-deferred TetraBake idea (procedural OppositeCorners synthesis) is the *better* path — not a future "tool" — drove the pivot.

### What changed

| Before (CONTEXT D-28..D-46) | After (this supersession) |
|---|---|
| `TetraTileLayoutTetra5Horizontal` + `TetraTileLayoutTetra5Vertical` ship as NEW separate classes | The existing `TetraTileLayoutTetraHorizontal`/`TetraTileLayoutTetraVertical` (Phase 1) **gain load-time synthesis** of the 5th OppositeCorners archetype. Auto-detect 4-vs-5-tile sources. **No separate Tetra5 classes ship.** |
| `needs_diagonal_overlay() -> bool` virtual on base; `_overlay_layer` lazily skipped for layouts that return `false` | `_overlay_layer` is **deleted entirely**. `needs_diagonal_overlay()` virtual is removed. Every v0.2 layout renders via single-layer 5-archetype dispatch. `AtlasSlot.diagonal_complement_atlas_coords` is removed. |
| Tetra4 (Phase 1) keeps its v0.1 overlay rendering; only Tetra5/other layouts skip overlay | Tetra4 **changes rendering path** to load-time synthesis. Output is bit-identical to v0.1 overlay composition for masks 6/9 (verified via pixel-hash test). Breaking change for any code reading `_overlay_layer` directly; CHANGELOG entry covers it. |
| TETRA5-01..05 requirements added in Phase 2 | TETRA-SYNTH-01..06 requirements replace them in REQUIREMENTS.md |

### Decisions superseded

- **D-28** (append Tetra5H+V as 6th layout in Phase 2) → REPLACED. No separate Tetra5 classes. Tetra*Horizontal/Vertical gain synthesis.
- **D-29** (class root name `Tetra5`) → MOOT. No separate class.
- **D-30, D-32, D-46** (canonical paint anchoring for Tetra5's mask 6 vs mask 9) → STILL APPLY but to the synthesized OppositeCorners, not a separate class. Synthesis is parameterized by these conventions.
- **D-33** (`needs_diagonal_overlay() -> bool` virtual + lazy overlay skip) → REPLACED by full overlay-layer deletion (TETRA-SYNTH-04). The virtual is removed; not needed.
- **D-36** (Tetra5 atlas slot order = `[Fill, Inner, Border, Outer, OppositeCorners]`) → STILL APPLIES. Artists who hand-author 5 tiles use this order. Synthesis writes the OppositeCorners to slot 4 in the runtime atlas. Auto-detect: 4-tile source → synthesize; 5-tile source → use slot 4 directly.
- **D-39** (Tetra5Horizontal extends Tetra4Horizontal; Tetra5Vertical extends Tetra5Horizontal) → MOOT. No subclass needed. Single class auto-detects.
- **D-40** (TETRA5-* requirement IDs) → REPLACED by TETRA-SYNTH-01..06.
- **D-41** (Phase 2 success criterion expanded for Tetra5) → REPLACED by Phase 2 success criteria 6, 7, 8, 9 (synthesis pixel-identity, overlay removal, auto-detect, collision support).
- **D-43** (`update_configuration_warnings()` for malformed Tetra5 atlases) → STILL APPLIES with adjusted scope. Now warns on auto-detect ambiguity (e.g., `5 × 1` atlas where slot 4 is empty/identical-to-fill — the artist intended Tetra4 but accidentally added a 5th column). Warning text adjusts to the auto-detect framing.

### Decisions still in force unchanged

- D-31 (5-tile is the canonical convention; reject asymmetric 6-tile)
- D-34..D-35 (single-grid pipeline unchanged)
- D-37..D-38 (compute_mask + atlas dispatch via Vector2i unchanged)
- D-42 (mask 0 short-circuit unchanged)
- D-44..D-45 (marching-squares cross-references; regression-suite protections — both still apply to all v0.2 layouts)
- All four originally-planned native layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship as planned.

### New decisions (Phase 2 plan should pick these up)

- **D-47: Tetra layouts auto-detect source atlas tile count.** `TetraTileLayoutTetraHorizontal` reads `TileSetAtlasSource.get_atlas_grid_size()` at contract-load. If width=4 (or height=4 for vertical): synthesize. If width=5 (or height=5): use slot 4 directly. Anything else: `update_configuration_warnings()` flags it.
- **D-48: Synthesis target lives in an internal runtime TileSet on `_primary_layer`.** User's source `tile_set` is never mutated. The synthesized atlas is allocated at `atlas_contract` setter time, freed when the contract changes. Deterministic — same source atlas + same layout → bit-identical synthesis output.
- **D-49: Synthesis copies collision/occlusion/navigation polygons from source archetypes to the synthesized OppositeCorners tile.** Two source-tile collision polygon sets are translated to the diagonal positions on the synthesized tile. Animation frames, custom data layers, probability weights, and Y-sort origin are NOT copied (explicitly out of scope for v0.2 synthesized tiles per TETRA-SYNTH-03; documented in DOC-03 as a layout-choice tradeoff).
- **D-50: Pixel-identity verification gate for Phase 2 plan.** A test renders v0.1's overlay-composed Tetra4 vs synthesis-produced Tetra4 for masks 6 and 9 and asserts pixel-hash equality. Failure blocks merge.
- **D-51: Overlay-layer code deletion is a breaking change documented in CHANGELOG.** `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` are removed. Any external code reading these breaks. Per the user's breaking-changes policy (CLAUDE.md, PROJECT.md), this proceeds without compat shims.
- **D-52: Tetra5 (artist-authored 5th tile) is preserved as a USE CASE, not a separate class.** Artists who want a hand-drawn distinct OppositeCorners author 5 tiles in their atlas; auto-detect picks them up. Bundled `tetra_5_horizontal.png` and `tetra_5_vertical.png` greybox templates ship for this case (TETRA-SYNTH-06).

### What this means for the Phase 2 planner

- Drop "ship Tetra5Horizontal/Tetra5Vertical as new classes" from the plan
- Add "rewrite TetraTileLayoutTetraHorizontal/Vertical to synthesize 5th tile + auto-detect 4-vs-5"
- Add "delete overlay layer code path from TetraTileMapLayer + AtlasSlot"
- Add "pixel-identity test for synthesis output"
- The 4 originally-planned native layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship unchanged
- Wave breakdown suggestion (planner free to recompose):
  - Wave 1: synthesis machinery (Image.blit_rect helper, runtime TileSet construction, collision polygon copy) + delete overlay layer path
  - Wave 2: rewrite Tetra Horizontal/Vertical to use synthesis (auto-detect, bit-identical output verification)
  - Wave 3: 4 originally-planned native layouts in parallel
  - Wave 4: 5-tile templates + bundled fallback TileSets + visual regression + LOC checkpoint

---

## SECOND SUPERSESSION — 2026-04-26 (later same day)

**Phase 2.1 (Single-Tile separate class) collapsed back into Phase 2.** The earlier supersession above introduced the synthesis approach for Tetra4 → 5-archetype rendering. A follow-up brainstorm session reframed this further: the same auto-detect machinery handles a third case — **TETRA1 mode** — where the artist provides 1 tile per strip and the layout synthesizes all 5 archetypes via sub-region slicing. This obviates the need for a separate `TetraTileLayoutSingleTile` class. Single Tetra layout per axis covers all three artist conventions.

### What changed (since the first supersession above)

| First supersession (TETRA-SYNTH-01..06) | This supersession (TETRA-SYNTH-01..09) |
|---|---|
| Auto-detect 4-vs-5 source tiles | Auto-detect 1-vs-4-vs-5 source tiles (per strip-axis dimension) |
| Synthesize 5th archetype from OuterCorner pair (TETRA4 mode) | Synthesize all 5 archetypes from 1 source tile (TETRA1) OR 5th from OuterCorner pair (TETRA4) |
| `TetraTileLayoutSingleTile` separate class for the 1-tile prototyping use case (Phase 2.1) | NO separate class — TETRA1 mode handled inside the unified Tetra layout via auto-detect |
| 6 TETRA-SYNTH-* requirements | 9 TETRA-SYNTH-* requirements (covers all 3 modes + enum override + per-strip refinement + warnings) |

### New decisions (Phase 2 plan should pick these up — supersedes/extends D-47..D-52)

- **D-53: Tetra layout absorbs TETRA1 mode via auto-detect.** No separate `TetraTileLayoutSingleTile` class. The unified `TetraTileLayoutTetraHorizontal`/`Vertical` classes auto-detect the source atlas strip-axis tile count and dispatch to one of three modes:
  - `axis_size == 1` → TETRA1 (synthesize 5 archetypes from 1 source tile per strip via sub-region slicing)
  - `axis_size == 4` → TETRA4 (synthesize 5th OppositeCorners from OuterCorner pair per strip)
  - `axis_size == 5` → TETRA5 with per-strip refinement (TETRA4 for strips with col 4 empty, TETRA5 for fully-populated strips)
  - Other axis sizes (0, 2, 3, 6+) → render disabled + `update_configuration_warnings()` fires
- **D-54: `TileCountMode` enum on the Tetra layout class for explicit override.** Members: `AUTO` (default), `TETRA1`, `TETRA4`, `TETRA5`. UPPER_SNAKE_CASE per GDScript style guide. AUTO triggers detection; explicit values skip detection and validate atlas content with explicit warnings on mismatch. Use cases for non-AUTO: (a) prototyping with a 4/5-wide atlas where artist wants TETRA1 semantics; (b) team conventions locking everyone to a specific mode; (c) self-documenting `.tres` files.
- **D-55: Detection is dimension-based ONLY — no pixel-content inspection.** Reasons: (1) false positives unacceptable (artist's monochrome tiles could trigger SingleTile false-positive under similarity heuristics); (2) atlas dimensions are a hard fact, not heuristic; (3) the rare collision case (TETRA1 intent + 4/5-wide atlas) is solved by the enum override. Detection cost is O(1) for atlas-axis-size + O(N strips) for per-strip `has_tile()` refinement in 5-wide atlases. Microseconds at contract-load. Manual override skips detection entirely (saves microseconds, real value is explicit error messaging).

### Decisions superseded (since first supersession)

- **TETRA-SYNTH-01..06** (the previous 6 requirements) → REPLACED by **TETRA-SYNTH-01..09** (9 requirements covering all three modes + enum + per-strip refinement + warnings). The previous reqs covered TETRA4 only; the new set is mode-agnostic.
- **SINGLE-01..05** (Phase 2.1 requirements) → RETIRED. TETRA1 mode in TETRA-SYNTH-* covers their intent. Phase 2.1 directory removed.
- **First-supersession Wave 2 ("rewrite Tetra Horizontal/Vertical to use synthesis (auto-detect, bit-identical output verification)")** → EXPANDED to "rewrite Tetra Horizontal/Vertical to use synthesis with auto-detect of 1/4/5 modes + TileCountMode enum + per-strip refinement + bit-identical output verification for TETRA4 mode."

### Decisions still in force from first supersession

- D-47 (`get_atlas_grid_size()` based detection) — extended to handle 1, 4, 5 (not just 4, 5)
- D-48 (synthesized atlas internal to `_primary_layer`, source `tile_set` never mutated) — unchanged
- D-49 (collision/occlusion/navigation polygons copied; animation/custom-data NOT) — unchanged
- D-50 (pixel-identity test gate for TETRA4 mode) — unchanged
- D-51 (overlay-layer deletion is a breaking change, no compat shim) — unchanged
- D-52 (Tetra5 hand-authored 5th tile preserved as USE CASE, not separate class) — extended: TETRA1 (1 tile) ALSO preserved as use case, also no separate class

### Naming convention (per user direction)

- Enum members use `TETRA1`, `TETRA4`, `TETRA5` (UPPER_SNAKE_CASE per GDScript style guide)
- Requirement IDs remain `TETRA-SYNTH-*` (documentation convention)
- File / class naming unchanged: `tetra_tile_layout_tetra_horizontal.gd` → `TetraTileLayoutTetraHorizontal` (per Phase 1 D-16 precedent)

### Wave breakdown (revised — supersedes first-supersession waves)

- Wave 1: synthesis machinery (`_synthesize_strip()` helper covering all 3 modes via `Image.blit_rect`, runtime TileSet construction, collision polygon copy) + delete overlay layer path from `TetraTileMapLayer` + `AtlasSlot`
- Wave 2: rewrite `TetraTileLayoutTetraHorizontal`/`Vertical` with `TileCountMode` enum + auto-detect (1/4/5 + per-strip refinement) + `update_configuration_warnings()` + bit-identical pixel-hash test for TETRA4 mode
- Wave 3: 4 native layouts in parallel (DualGrid16, Wang2Edge, Wang2Corner, Min3x3)
- Wave 4: 6 templates total (TETRA1 H+V new, TETRA4 H+V existing, TETRA5 H+V new) + bundled fallback TileSets + visual regression for all 3 Tetra modes + LOC checkpoint

### What this means for the Phase 2 planner

If you already started planning Phase 2 against the first supersession (D-47..D-52), you can re-run `/gsd-discuss-phase 2` safely — the discussion log is now coherent with the second supersession. The 4 native layouts (DualGrid16/Wang2Edge/Wang2Corner/Min3x3) are unchanged; the architectural lift is broader (TETRA1 + TETRA4 + TETRA5 modes + enum + per-strip refinement) but uses the same synthesis machinery.

---

## THIRD SUPERSESSION — 2026-04-26 (later, after spotting AI-overengineering on the contract)

User reviewed `TetraTileAtlasContract` and called out three things: (1) the `version: int = 1` field had no consumer (speculative forward-compat the AI added), (2) the `decoder_image` had no consumer (similarly speculative), (3) the contract wrapper was overengineered for what should be a single resource attached to the layer. Result: a sweeping simplification + a no-forward-compat policy added to CLAUDE.md.

### What changed

| Before this supersession | After |
|---|---|
| `TetraTileMapLayer.atlas_contract: TetraTileAtlasContract` | `TetraTileMapLayer.layout: TetraTileLayout` (no contract wrapper) |
| `TetraTileAtlasContract` class with `version`, `layout`, `variation_seed` | Class deleted; `version` deleted (speculative); `variation_seed` deferred to v2 with VAR-PIXEL-01 |
| Two Tetra classes (`TetraTileLayoutTetraHorizontal`, `TetraTileLayoutTetraVertical`) | One merged `TetraTileLayoutTetra` with `axis: Axis` enum |
| `tile_count_mode: TileCountMode { AUTO, TETRA1, TETRA4, TETRA5 }` | `tile_count: TileCountMode { AUTO=0, ONE=1, FOUR=4, FIVE=5 }` (renamed property; non-AUTO ints match the actual count) |
| `template_image: Texture2D` exposed @export on layout base | `bitmask_template: Texture2D` (renamed); on `TetraTileLayoutTetra` hidden via `_validate_property` (axis-resolved) |
| `fallback_tile_set: TileSet` exposed @export | Hidden; codegen via `get_fallback_tile_set() -> TileSet` virtual on the base class |
| `decoder_image: Texture2D` (speculative) | Deleted |
| Flat `templates/*.png` files | Per-layout folders: `templates/[layout_name]/{atlas.png, bitmask.png}` |
| `addons/tetra_tile/contracts/*.tres` (4 files) + `tetra_tile_atlas_contract.gd` + `tetra_tile_template.png` (root) | All deleted |

### New decisions (D-56..D-60)

- **D-56: `TetraTileAtlasContract` deleted entirely.** `version`, `variation_seed`, `_set_contract` back-ref, `_contract: WeakRef` on layout — all gone. `layout` is on `TetraTileMapLayer` directly. Setter has idempotence guard + disconnect-before-reconnect on `layout.changed`. Per the no-forward-compat policy, no migration shim.
- **D-57: Tetra layout classes merged.** `TetraTileLayoutTetra` with `axis: Axis = HORIZONTAL` enum (members `HORIZONTAL`/`VERTICAL`). `_make_slot` branches on axis. Phase 1's `TetraTileLayoutTetraHorizontal` / `TetraTileLayoutTetraVertical` files deleted; new `tetra_tile_layout_tetra.gd` created.
- **D-58: `tile_count: TileCountMode` enum** (renamed from `tile_count_mode` — `_mode` was redundant). Members `AUTO = 0`, `ONE = 1`, `FOUR = 4`, `FIVE = 5`. Explicit int values match the tile count for non-AUTO; `int(mode)` returns the count when not AUTO. Same auto-detect algorithm as the second supersession (D-47), now also handles ONE.
- **D-59: One user-facing image property — `bitmask_template`** (renamed from `template_image`). Doubles as visual reference + bitmask rules definition. `fallback_tile_set` no longer @export'd; replaced by `get_fallback_tile_set()` virtual that builds from bundled `atlas.png`. `decoder_image` deleted (was speculative). Per-layout folders: `templates/[layout_name]/{atlas.png, bitmask.png}`.
- **D-60: `TetraTileLayoutTetra` hides `bitmask_template` via `_validate_property`.** Class-level constant lookup table maps `(axis, tile_count)` → bundled `bitmask.png` and `atlas.png` paths. Inspector shows ONLY `axis`, `tile_count`, `description` for Tetra. Other layouts (DualGrid16, Wang*, etc.) still show their `bitmask_template` for user customization (they don't hide it).

### Decisions superseded by this round

- **D-47** (auto-detect 1/4/5 from `get_atlas_grid_size()`) — STILL APPLIES, just with the new ONE/FOUR/FIVE enum naming
- **D-48** (synthesized atlas internal to `_primary_layer`) — STILL APPLIES
- **D-49** (collision/occlusion/navigation polygons copied to synthesized tiles) — STILL APPLIES
- **D-50** (pixel-identity test gate for FOUR mode) — STILL APPLIES (just renamed from TETRA4)
- **D-51** (overlay-layer deletion) — STILL APPLIES
- **D-52** (FIVE / hand-authored 5-tile preserved as use case, not separate class) — STILL APPLIES (now within the merged class)
- **D-53** (Tetra absorbs ONE mode) — STILL APPLIES (within the merged class)
- **D-54** (`TileCountMode` enum) — REPLACED by D-58 (renamed property + new member names)
- **D-55** (dimension-based detection, no pixel inspection) — STILL APPLIES

### Wave breakdown (third revision)

- Wave 1: synthesis machinery (`_synthesize_strip()` covering ONE/FOUR/FIVE, runtime TileSet construction via `get_fallback_tile_set()`, collision polygon copy) + delete `_overlay_layer` from `TetraTileMapLayer` + delete `diagonal_complement_atlas_coords` from `AtlasSlot`
- Wave 2: delete `TetraTileAtlasContract` + delete `addons/tetra_tile/contracts/` folder + delete `addons/tetra_tile/tetra_tile_template.png`. Replace `atlas_contract` property with `layout: TetraTileLayout` on `TetraTileMapLayer`. Update setter for direct `layout.changed` connection.
- Wave 3: merge `TetraTileLayoutTetraHorizontal` + `TetraTileLayoutTetraVertical` into `TetraTileLayoutTetra` with `axis: Axis` + `tile_count: TileCountMode` enums. Hide `bitmask_template` via `_validate_property`. Class-level constant lookup table for axis × mode → bundled paths.
- Wave 4: `TetraTileLayout` base — rename `template_image` → `bitmask_template`. Remove `fallback_tile_set` @export. Add `get_fallback_tile_set()` virtual. Delete `decoder_image`.
- Wave 5: 4 native layouts in parallel (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) using the new conventions
- Wave 6: restructure templates folder — migrate existing flat PNGs to `[layout_name]/atlas.png`; generate new `[layout_name]/bitmask.png` per layout (all 6 Tetra mode×axis combos + 4 native non-Tetra layouts). Update `_generate_greybox_templates.py`.
- Wave 7: visual regression (FOUR-mode pixel-identity vs v0.1 + ONE/FOUR/FIVE rendering tests) + LOC checkpoint + CHANGELOG entries

---

## FOURTH SUPERSESSION — 2026-04-26 (later, after extended Tetra design refinement)

User pushed deeper on the slot ordering and synthesis quality questions, leading to: **expanded mode set (ONE/TWO/THREE/FOUR/FIVE), new slot order with IsolatedCell at slot 0, and asset consolidation (single PNG per layout, no atlas/bitmask split, templates folder deleted).** This is the locked-in design for Phase 2.

### What changed (since the third supersession)

| Third supersession | Fourth supersession |
|---|---|
| Three modes: `ONE`, `FOUR`, `FIVE` | **Five modes**: `ONE`, `TWO`, `THREE`, `FOUR`, `FIVE` (each step adds one explicit archetype slot) |
| `tile_count: TileCountMode { AUTO, ONE, FOUR, FIVE }` | `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE, TWO, THREE, FOUR, FIVE }` (AUTO_STRIP added for per-strip detection) |
| Canonical Tetra slot order (Fill at 0, Inner at 1, Border at 2, Outer at 3) | **New slot order**: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. OuterCorner is implicit. |
| Two PNGs per layout (`atlas.png` + `bitmask.png`) under `templates/[layout_name]/` | **Single PNG per layout**, doubles as inspector preview AND fallback TileSet source. **Templates folder DELETED.** PNGs co-locate next to layout `.gd` files. |
| Template paths: `addons/tetra_tile/templates/tetra_horizontal/{atlas.png,bitmask.png}` | Flat siblings for single-variant layouts: `addons/tetra_tile/layouts/tetra_tile_layout_dual_grid_16.png`. Subfolder for Tetra (10 variants): `addons/tetra_tile/layouts/tetra_tile_layout_tetra/{one,two,three,four,five}_{horizontal,vertical}.png`. |

### New decisions (D-61..D-67)

- **D-61: Five progressive modes** instead of three. Each subsequent mode adds explicit artist control over one more archetype:
  - ONE: 1 tile (IsolatedCell only); synth all from sub-regions of slot 0
  - TWO: + Fill (slot 1); synth Border/Inner/Outer/Opposite from slot 0
  - THREE: + Border (slot 2); synth Inner/Outer/Opposite from slot 0
  - FOUR: + InnerCorner (slot 3); synth Outer/Opposite from slot 0
  - FIVE: + OppositeCorners (slot 4); synth only Outer from slot 0
  - User intent: "sacrificing quality for less quantity / time saving" — mid-tier modes are intentional for fast prototyping.
- **D-62: New slot order** `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — never has a dedicated slot, always synthesized from slot 0's corners. Rationale: an isolated cell visually IS four outer corners + edges + fill, so OuterCorner art is naturally expressed via slot 0's corners. Acceptable per user: "i dont see this a problem, because in all cases, IsolatedCell is just a 4 sided OuterCorner."
- **D-63: Border at slot 2 (before InnerCorner at slot 3) — visual frequency over fill-percentage ordering.** Border appears at every edge cell in typical maps (most visually impactful archetype after Fill); InnerCorner appears at concave junctions (less common). User considered strict fill-percentage ordering (`100 → 75 → 50 → 50`) and rejected: "i guess there is technically no pro to this idea other then visually more appealing." Functional ordering wins.
- **D-64: `AUTO_STRIP` enum value** added alongside `AUTO`. AUTO is dimension-only (cheapest, all strips share the same mode). AUTO_STRIP does per-strip detection via `has_tile()` (each strip independently 1-5; strips can differ within a single atlas). Cost difference is negligible (~50 bool lookups for typical sizes); the practical reason for two modes is intent — *"all my terrain rows have the same complexity"* vs *"different terrains might use different mode counts."* Naming locked at `AUTO_STRIP` per user preference (matches existing TetraTile "strip" terminology; no industry-standard term exists for axis-agnostic 1D atlas line).
- **D-65: Single PNG per layout serves both inspector preview AND fallback TileSet source.** No `atlas.png` / `bitmask.png` split. The PNG IS the bitmask reference AND its pixels back the prototyping fallback. Saves bundled file count by 50% and simplifies maintenance. The current `tetra_horizontal.png` style (clean greybox with visible slot positions) already functions as both — the artificial split was overengineering.
- **D-66: Templates folder deleted entirely.** Bundled PNGs co-locate next to layout `.gd` files for self-contained per-layout asset bundles:
  - **Tetra (10 variants)**: `addons/tetra_tile/layouts/tetra_tile_layout_tetra/{one,two,three,four,five}_{horizontal,vertical}.png` (subfolder)
  - **Single-variant layouts**: `addons/tetra_tile/layouts/tetra_tile_layout_<slug>.png` (flat sibling)
  - Bitmask generator script (`_generate_greybox_templates.py`) renamed and updated to produce the new structure.
- **D-67: Updated test gate.** TETRA-SYNTH-12 specifies FOUR-mode visual regression against a CAPTURED baseline (not bit-identical to literal v0.1 overlay rendering, since slot ordering changed — slot 3 is now InnerCorner, was OuterCorner in v0.1). The baseline is a fresh capture under the new convention. Used to detect synthesis regressions across future refactors.

### Decisions superseded since the third supersession

- **D-58** (`TileCountMode { AUTO, ONE, FOUR, FIVE }`) → REPLACED by D-61+D-64 (added TWO/THREE modes + AUTO_STRIP)
- **D-60** (axis × mode lookup table for `bitmask_template`) — STILL APPLIES, just with 5 modes × 2 axes = 10 entries instead of 3 × 2 = 6
- **First-supersession D-50** (FOUR mode bit-identical to v0.1 overlay) — REPLACED by D-67. Since slot ordering changed, true bit-identity vs v0.1 is no longer meaningful; baseline is a fresh capture under the new convention.

### Decisions still in force unchanged

- D-47..D-49 (synthesized atlas internal to `_primary_layer`; collision polygons copied; no animation/custom-data)
- D-51 (overlay-layer deletion is a breaking change; no compat shim)
- D-52 (FIVE / hand-authored 5-tile preserved as use case, not separate class)
- D-53 (Tetra absorbs ONE mode via auto-detect)
- D-55 (dimension-based detection only, no pixel inspection)
- D-56 (TetraTileAtlasContract deleted; layout: TetraTileLayout directly on layer)
- D-57 (Tetra Horizontal/Vertical merged into TetraTileLayoutTetra)
- D-59 (single user-facing image — `bitmask_template`; `decoder_image` deleted; `fallback_tile_set` hidden)

### Wave breakdown (fifth revision — addresses audit findings 2026-04-26)

**Dependency note**: waves are NOT strictly sequential as numbered. Wave 1 (synthesis machinery) calls `get_fallback_tile_set()` which Wave 4 adds; Wave 3 (merge Tetra classes) references the renamed `bitmask_template` property which Wave 4 also adds. Reordered below so each wave's dependencies are satisfied by the time it runs:

- **Wave 1: Pre-work — Phase 1 verification migration + base-class renames.**
  - Migrate `.planning/phases/01-contract-skeleton-tetra-layouts/01-VERIFICATION.md` 26 tests to the new API surface (LAYER-05). Tests written against the deleted `atlas_contract` + `TetraTileLayoutTetraHorizontal`/`Vertical` need rewrites against `layout: TetraTileLayout` + `TetraTileLayoutTetra(axis=...)`. New tests added for TWO/THREE/FIVE modes + AUTO_STRIP. Phase 1's `01-VERIFICATION.md` is marked as historical; new tests live alongside Phase 2 verification.
  - Rename `template_image` → `bitmask_template` on `TetraTileLayout` base. Remove `fallback_tile_set` @export. Add `get_fallback_tile_set()` virtual stub (returns null until Wave 2 fills it). Delete `decoder_image`. (Was Wave 4 in fourth revision; promoted to Wave 1 because Waves 2-3 depend on the rename.)

- **Wave 2: Synthesis machinery + overlay deletion + contract deletion + demo rebind.**
  - Build `_synthesize_strip(strip_index, mode)` helper covering all 5 modes (ONE/TWO/THREE/FOUR/FIVE). Includes runtime TileSet construction (fills in the `get_fallback_tile_set()` stub from Wave 1) + collision/occlusion/navigation polygon copy.
  - Delete `_overlay_layer` from `TetraTileMapLayer` + `_OVERLAY_LAYER_NAME` constant + `_paint_overlay_for_slot()` + `diagonal_complement_atlas_coords` field on `AtlasSlot`.
  - Delete `TetraTileAtlasContract` class + `addons/tetra_tile/contracts/` folder + the `tetra_tile_atlas_contract.gd` file + the `addons/tetra_tile/tetra_tile_template.png` original v0.1 reference. Replace `atlas_contract` property with `layout: TetraTileLayout` on `TetraTileMapLayer`. Update setter for direct `layout.changed` connection. **Delete the static `_DEFAULT_LAYOUT` singleton in `tetra_tile_map_layer.gd:193-198`** (it allocated `TetraTileLayoutTetraHorizontal.new()` — class doesn't exist after Wave 3).
  - **Atomically rebind `addons/tetra_tile/demo/tetra_tile_demo.tscn`** — remove the `[ext_resource ... contracts/default_horizontal.tres]` reference and replace `atlas_contract = ExtResource(...)` with `layout = ExtResource(...)` pointing at a Tetra layout instance (LAYER-04). Demo MUST load cleanly in the Godot editor at the end of Wave 2 — this is a non-skippable acceptance criterion.

- **Wave 3: Tetra layout merge.**
  - Merge `TetraTileLayoutTetraHorizontal` + `Vertical` into `TetraTileLayoutTetra` with `axis: Axis = HORIZONTAL` enum + `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5 }`. Hide `bitmask_template` via `_validate_property`. Class-level constant lookup table maps `(axis, mode)` → bundled PNG path.
  - Wire `TetraTileLayoutTetra` to call `_synthesize_strip()` from Wave 2 for the relevant mode.

- **Wave 4: 4 native layouts in parallel.**
  - DualGrid16, Wang2Edge, Wang2Corner, Min3x3 ship using the new conventions + flat-sibling PNG bundles.

- **Wave 5: Asset relocation.**
  - Delete `addons/tetra_tile/templates/` folder.
  - Create per-layout PNGs at new co-located paths: 10 in `addons/tetra_tile/layouts/tetra_tile_layout_tetra/` subfolder (`{one,two,three,four,five}_{horizontal,vertical}.png`) + 4 flat siblings (`tetra_tile_layout_dual_grid_16.png`, etc.).
  - Update bitmask generator script (renamed from `_generate_greybox_templates.py`) to produce the new structure.

- **Wave 6: AUTO/AUTO_STRIP detection + warnings + baseline capture + demo refresh.**
  - Implement AUTO and AUTO_STRIP detection algorithms (TETRA-SYNTH-02/03). Wire `update_configuration_warnings()` per TETRA-SYNTH-08.
  - Capture FOUR-mode regression baseline per TETRA-SYNTH-12 spec (test scene, hash, baseline file location).
  - Demo refresh — exercise ONE/FOUR/FIVE modes (TWO/THREE optional in demo).

- **Wave 7: Closeout.**
  - LOC checkpoint (estimated +1300-1500 LOC vs. ~911 prior) — flag identity guardrail if exceeded materially.
  - CHANGELOG entries per DOC-04.

### Pre-plan-phase recommendations (audit-sourced)

1. **Spike 004 — ONE-mode sub-region anchoring** (recommended before plan execution). Spikes 001-003 covered decoder feasibility, NOT synthesis-from-a-single-source-tile. Open question: "where in slot 0 do the corners / edges / fill live, and how are sub-rects extracted?" Either run a spike to lock the math or have plan-phase pin it down with explicit justification.

2. **Collision-polygon transform spec** — the polygon-copy step in TETRA-SYNTH-06 needs a sketch in the plan: each polygon is a `Vector2[]`; rotations and flips applied via `Transform2D` or per-vertex math; sub-region clipping for ONE/TWO/THREE modes where the synthesized tile uses only part of slot 0's polygon area. Don't let the executor discover this mid-implementation.

3. **Phase 2 sub-wave structure or 2.0/2.5 split** — Phase 2 is now ~2× original scope (33 of 58 reqs, 17 success criteria, 7 waves). Plan-phase should decide upfront whether the wave breakdown above is sufficient or whether further splitting is warranted (e.g., a Phase 2.0 "architectural simplification" + Phase 2.5 "4 native layouts + asset relocation" split).

### What this means for the Phase 2 planner

If you've started planning Phase 2 against any prior supersession, **this fourth supersession is the LOCKED final design.** Re-run `/gsd-discuss-phase 2` if helpful — the discussion log is now coherent across four iterations. Key constraints for the plan:
- Five `tile_count` modes (not three) plus AUTO/AUTO_STRIP
- Slot 0 = IsolatedCell across all modes; OuterCorner never has its own slot
- Single PNG per layout (no atlas/bitmask split)
- No `templates/` folder — bundled PNGs co-locate in `layouts/`
- `TetraTileAtlasContract` deleted; `layout: TetraTileLayout` directly on layer
- One merged `TetraTileLayoutTetra` class with `axis` + `tile_count` enums
