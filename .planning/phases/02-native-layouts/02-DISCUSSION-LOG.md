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
