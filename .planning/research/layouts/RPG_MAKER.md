## RPG Maker Autotile Family — Format Audit + Possible Implementation Paths

**Researched:** 2026-04-26 (subagent web research + two reader-supplied URLs)
**Confidence:** HIGH on the per-version atlas dimensions and composition model. MEDIUM on "what TetraTile should ship" — three viable paths exist, each with different identity-guardrail tradeoffs.
**Status:** REFERENCE ONLY for v0.2.0. The new Phase 3 (Single-Tile Layout) does NOT ship RPG Maker support. This document captures the findings so a future milestone can pick up cleanly without re-doing the research.

---

## Headline finding

**Every RPG Maker autotile from RM2K onward composes per-cell quadrants at draw time.** The atlas stores a small palette of corner/edge fragments (typically `tile_size / 2` quarters); the engine computes a per-cell mask from neighbours, then looks up four quadrant coordinates — TL, TR, BL, BR — from a fixed table and blits them into one final cell. The 47-state "blob" is **not** baked into the atlas; it is generated from a much smaller source (~6 unique quad arrangements).

The official RPG Maker MZ blog confirms this in plain English: *"Stop thinking of the auto-tile as sets of 48×48 tiles. Instead, each tile is made up of 4 mini-tiles of 24×24 pixels… This is how the editor thinks about autotiles."* ([rpgmakerweb.com](https://www.rpgmakerweb.com/blog/classic-tutorial-how-autotiles-work))

**This is architecturally incompatible with TetraTile's current dispatch.** The v0.2 layout system assumes whole-tile slots — `mask_to_atlas(mask) -> AtlasSlot{atlas_coords, transform_flags, alternative_tile}`. RPG Maker rendering needs **four sub-tile lookups per cell** plus per-quadrant blitting. Adding it natively means a parallel render path next to `_paint_with_slot()`.

**Industry pattern (this matters):** no major engine does runtime quad-composition for RPG Maker formats natively. Tiled, Unity, GameMaker, Defold, and standalone tools (Tilesetter, autotiler.js, eishiya/tiled-expand-autotile) all settled on the same pattern: **expand once at import time, render flat thereafter.** This is the path that fits TetraTile's identity guardrail.

---

## Per-version breakdown

| Version | Tile | Quarter | Sheet name(s) | Per-autotile block | Source quads | Output mask states | Animation |
|---|---|---|---|---|---|---|---|
| **RM2K** (2000) | 16×16 | 8×8 | `ChipSet` (single sheet, 480×256, autotiles inline) | 3 cols × 4 rows = 12 source cells per autotile region (48×64 px) | ~6 unique quads | 47-state blob | 4-frame water (down a column) |
| **RM2K3** (2003) | 16×16 | 8×8 | `ChipSet` (same layout as 2K) | 3×4 = 12 cells (48×64 px) | ~6 quads | 47-state blob | 4-frame |
| **RM XP** | 32×32 | 16×16 | Separate `Autotile` files (≤7 per tileset) | 96×128 px = 3×4 cells per autotile | ~6 quads | 47-state blob | 3-frame (laid horizontally) |
| **RM VX** | 32×32 | 16×16 | A1, A2, A3, A4, A5 | A1/A2: 512×384, A3: 512×256, A4: 512×480, A5: 256×512 | A2 block = 2×3 cells = 6 source quads → 47 outputs | A1: water; A2: ground; A3: building exteriors; A4: walls/ceiling; A5: plain | A1 3-frame |
| **RM VX Ace** | 32×32 | 16×16 | A1–A5 (identical pixel dims to VX) | Same as VX | Same | Same | Same |
| **RM MV** | 48×48 | **24×24** | A1–A5 | A1/A2: 768×576, A3: 768×384, A4: 768×720, A5: 384×768 | A2: 32 "kinds" (8 cols × 4 rows), each kind = 2×3 cell block = 6 quads → 47 mask states (`FLOOR_AUTOTILE_TABLE`, 48 entries incl. solid). A4: 48 kinds in 3 vertical bands (wall-tops use floor table; wall-sides use 16-entry `WALL_AUTOTILE_TABLE`) | A1 3-frame water |
| **RM MZ** | 48×48 | 24×24 | A1–A5 | Identical to MV; binary-compatible | Identical | Identical | Identical |

**Key gotcha that burns Godot users:** the displayed tile size and the autotile sub-grid size are different. MV/MZ users importing into Godot 4 typically need to set TileMap cell size to **24×24** (the quarter), not 48×48 (the displayed tile). The reader-supplied [Reddit thread](https://www.reddit.com/r/godot/comments/e1509r/comment/f8n4d9h/) is exactly this confusion playing out — the linked target comment is just two words: *"24x24 pixels."*

### A4 special case (walls)

A single A4 sheet contains both **wall-tops** (use the 47/48-state floor table) and **wall-sides** (use a *separate* 16-state table because walls only need a 4-bit horizontal/vertical neighbour signature, no corners). The Reddit thread surfaces this in practice: *"wall sections from RPG Maker need a separate 2×2 autotile in Godot rather than the 3×3 used for ground."*

### A5 is NOT an autotile

A5 is a flat atlas of single tiles. Users routinely confuse this — calling it "the fifth autotile sheet" when it's actually plain.

---

## Format-name cheat sheet (what users will Google)

- **"RPG Maker 2000 / 2K3 ChipSet"** or **"RTP autotile"** — 16×16 tile, 3×4 inline grid, 4-frame water
- **"RPG Maker XP autotile"** — 32×32 tile, 96×128 per file, ≤7 autotiles per tileset, 3-frame animation
- **"A1 / A2 / A3 / A4 / A5"** — VX, VX Ace, MV, MZ
- **"MV format" / "MZ format"** — 48×48 tile, 24×24 quarter; MZ inherited MV's spec wholesale

---

## Quadrant composition rules (uniform across all versions)

From the official MV blog and `yxbh/tileset-format-specs`:

1. The **top-left tile** of every autotile block is *"ONLY used as what is shown in the tile selection part of the editor. None of it will ever be used in your actual maps."* It is a UI thumbnail, not source for stitching.
2. Each displayed tile is built from **4 mini-tiles of `tile_size / 2` pixels.**
3. Quadrants have **fixed corner roles**: red marker = upper-left, green = upper-right, yellow = lower-left, blue = lower-right. A red-marked source quad is *always* placed as the TL of the output regardless of where it lives in the source sheet.
4. **Edge matching is the artist contract:** every red right-edge must seamlessly match the corresponding green left-edge, etc. This is what makes hand-authoring a custom autotile fiddly but predictable.

Authoritative open spec: [yxbh/tileset-format-specs — RPG Maker MV/MZ autotile spec](https://github.com/yxbh/tileset-format-specs/blob/main/formats/rpg-maker-mv-mz/specs/autotiles.md). Documents the 48-entry `FLOOR_AUTOTILE_TABLE` and 16-entry `WALL_AUTOTILE_TABLE` lookup tables explicitly.

---

## How other engines handle RPG Maker formats

| Engine | Native support? | Pattern |
|---|---|---|
| **Tiled** | No (open since 2015: [issue #1022](https://github.com/bjorn/tiled/issues/1022)) | Community workaround: [`eishiya/tiled-expand-autotile`](https://github.com/eishiya/tiled-expand-autotile) — offline expander |
| **GameMaker Studio 2** | No (independent autotile system) | Marketplace asset: [`Zanto/RPG Maker XP to GMS2 Autotile`](https://marketplace.gamemaker.io/assets/6206/rpg-maker-xp-to-gms2-autotile) — converter |
| **Unity** | No | Asset Store: [Autotile Importer for RPG Maker-Compatible Tilesets](https://assetstore.unity.com/packages/tools/sprite-management/autotile-importer-for-rpg-maker-compatible-tilesets-image-103504) — paid importer (XP/VX/MV, A1–A4) |
| **Defold** | No | Pre-bake via [Tilesetter](https://www.tilesetter.org/) (which also exports to GMS2/Godot/Unity) |
| **Godot 4** | No | TBD — TetraTile would be the first |

The clear pattern: **no major engine adopts RPG Maker's exact 6-quad source format natively.** Everyone either bakes the blob ahead-of-time or ships a converter. Excalibur.js ([Autotiling Technique](https://excaliburjs.com/blog/Autotiling%20Technique/)) and standalone tools like [`itsjavi/autotiler`](https://github.com/itsjavi/autotiler) implement the 47-tile blob conceptually rather than the RPG Maker source format.

---

## Possible implementation paths for TetraTile

Three architecturally distinct options, sorted by identity-guardrail risk:

### Option 1 — Offline RPG Maker importer (LOW risk, RECOMMENDED for v0.3+)

**What it is:** an edit-time tool (GDScript editor plugin or standalone script) that reads an A2/A4/XP autotile sheet, runs the `FLOOR_AUTOTILE_TABLE` / `WALL_AUTOTILE_TABLE` lookups, blits 47 (or 16) output tiles to a new flat atlas PNG, and emits a `TetraTileAtlasContract` pointing at one of TetraTile's existing flat-blob layouts (`Blob47Godot`, or a new `RPGMaker47` if the slot table differs).

**Why this fits:**
- Zero changes to runtime (`_update_cells` stays untouched).
- Reuses the v0.2 layout library directly. The user gets a regular flat 47-tile atlas at the end.
- Matches what every other engine in the ecosystem did. Proven pattern.
- Naturally handles A2, A4 wall-tops, A4 wall-sides, XP, VX, VX Ace via different source-format readers all writing to the same flat-atlas output.
- Animation (A1 water 3-frame, RM2K water 4-frame) maps cleanly to TetraTile's `alternative_tile` variation banks once `variation_seed` lands (Phase 3.5).

**Why it's still non-trivial:**
- Image processing in GDScript — `Image.blit_rect` per quadrant. Not hard, but ~150–250 LOC in the importer alone.
- The `FLOOR_AUTOTILE_TABLE` and `WALL_AUTOTILE_TABLE` need transcribing from the spec (or copying from an MIT/Apache reference implementation with attribution).
- Need to handle each version's slight sheet-layout differences (XP vs MV vs RM2K).

**Recommended scope split:**
- v0.3 phase: A2 (ground) + MV/MZ + VX/VX Ace static frames only. Single new format.
- v0.3+ later: A4 walls (different table), XP, RM2K (different sheet packing), animation.

### Option 2 — Runtime quarter-tile compositor (HIGH risk, DEFERRED)

**What it is:** a parallel render path inside `TetraTileMapLayer` that, for `RotationMode.QUARTER_TILE` (or a `TetraTileLayoutRPGMakerA2` subclass), paints **four sub-tile cells per logic cell** by sampling four source quadrants and placing each at quarter-tile offsets on a dedicated quadrant overlay layer.

**Why this is risky:**
- Forks the dispatcher. `_paint_via_layout` would need a "four sub-cells per display cell" branch alongside the existing whole-tile branch. The current layer already has a primary + diagonal-overlay layer pair; quad rendering may need a third layer or a completely different display-coordinate scheme.
- Quarter-tile cell size means TileSet `tile_size` would need to be the quarter (e.g., 24×24 for MV) while the user's mental model is the displayed tile (48×48). Mismatch with every other layout.
- v0.1's hidden-logic-layer trick (`self_modulate.a` on the parent) doesn't compose obviously with a quarter-tile display grid.
- LOC and conceptual complexity push toward TileMapDual territory — directly contradicts the PROJECT.md identity guardrail.

**Already documented as out-of-scope:** [REQUIREMENTS.md:166](../../REQUIREMENTS.md#L166) explicitly says *"Quarter-tile compositor is a v0.3+ refactor; doesn't fit unified `_update_cells` dispatch."*

### Option 3 — Hybrid: shader-based quad composition (MEDIUM risk, EXPERIMENTAL)

**What it is:** keep the whole-tile dispatch, but render an RPG Maker A2 cell via a shader that samples four sub-rectangles from a single source texture and composites them in-fragment.

**Why it's interesting:** zero new layers, zero `_update_cells` changes. The mask → quadrant-coords mapping happens in CPU per cell (lightweight); the actual quadrant blit happens in a `ShaderMaterial` set on the visual layer.

**Why it's still risky:**
- Requires a `canvas_item` shader on the visual TileMapLayer with per-cell `INSTANCE_CUSTOM` data. Godot 4 supports this via `set_cell_alternative_tile` + custom data layers, but the integration with `TileSetAtlasSource` is awkward — alt-IDs + transform flags already use the same int.
- Not portable to non-shader contexts (mobile fallbacks, headless rendering).
- "TetraTile must remain visibly smaller and simpler than TileMapDual" — adding a shader path crosses that line.

Listed for completeness; not recommended.

---

## Recommendation

**For TetraTile's v0.3+ (when RPG Maker support is reopened): pursue Option 1 (offline importer).**

Concrete next-milestone scope sketch:
1. New layout subclass `TetraTileLayoutRPGMaker47` — slot table identical to `Blob47Godot` or transcribed fresh from the `FLOOR_AUTOTILE_TABLE`. The runtime layout *is* a flat-blob layout; "RPG Maker" is a property of the importer, not of the runtime.
2. New editor tool `addons/tetra_tile/tools/rpg_maker_importer.gd` (`@tool` script). Inputs: source PNG + version/format dropdown. Outputs: flat blob PNG + matching `TetraTileAtlasContract` `.tres`.
3. A4 walls handled by a separate tool pass writing to a 16-tile flat layout (likely `Wang2Edge` reused) — not to the same 47-blob.
4. Animation deferred until `variation_seed` lands and the variation-bank pattern is proven on PixelLab (Phase 3.5).

Total scope estimate: ~400–600 LOC for the importer, ~80 LOC for the layout subclass, plus visual regression on at least one A2 sample sheet. Larger than a v0.2 phase but well within a v0.3 milestone.

---

## Reader-supplied URLs — what they actually say

**[rpgmakerweb.com — *Classic Tutorial: How Autotiles Work*](https://www.rpgmakerweb.com/blog/classic-tutorial-how-autotiles-work)** — originally written for MV, applies unchanged to MZ. Key claims captured above (mini-tile composition, fixed quadrant corner roles, edge-matching contract). The blog is **the canonical "how do autotiles work" reference** for anyone authoring custom RPG Maker tilesheets, and pins the MV/MZ subtile size at 24×24 unambiguously.

**[Reddit r/godot — "Using RPG Maker tileset" (parent post `e1509r`, comment `f8n4d9h`)](https://www.reddit.com/r/godot/comments/e1509r/comment/f8n4d9h/)** — the literal target comment is just *"24x24 pixels"* answering "what cell size do you use?" Thread context:
- OP `Magarcan` was trying to use a free RPG Maker tileset with Godot 3.x's 3×3 autotile bitmask
- `golddotasksquestions` posted two corrected bitmask images ([imgur 1](https://i.imgur.com/Yg1uZxl.png), [imgur 2](https://i.imgur.com/PgRw5vk.png)) that worked once cell size was clarified to 24×24
- Follow-up comment confirmed wall sections need a separate 2×2 autotile (the A4 wall-side / `WALL_AUTOTILE_TABLE` distinction surfacing in practice)

**Practical lesson for TetraTile:** users naturally try to import RPG Maker sheets directly and get burned by the cell-size question. Any future RPG Maker support should make sub-tile size visible in the inspector, ideally via the layout's `description` field.

---

## Sources

- [Classic Tutorial: How Autotiles Work — RPG Maker Web](https://www.rpgmakerweb.com/blog/classic-tutorial-how-autotiles-work)
- [Reddit r/godot — Using RPG Maker Tileset (target comment)](https://www.reddit.com/r/godot/comments/e1509r/comment/f8n4d9h/)
- [yxbh/tileset-format-specs — RPG Maker MV/MZ autotile spec](https://github.com/yxbh/tileset-format-specs/blob/main/formats/rpg-maker-mv-mz/specs/autotiles.md)
- [RPG Maker Wiki — Tileset](https://rpgmaker.fandom.com/wiki/Tileset)
- [RPG Maker Wiki — Auto-tile](https://rpgmaker.fandom.com/wiki/Auto-tile)
- [Wikibooks — RPG Maker 2003/ChipSets](https://en.wikibooks.org/wiki/RPG_Maker_2003/ChipSets)
- [RPG Maker MZ Asset Standards (official)](https://rpgmakerofficial.com/product/MZ_help-en/01_11_01.html)
- [Bot's Guide to RPGM MV Tilesets — Medium](https://robotsweater.medium.com/bots-guide-to-custom-art-in-rpgmaker-mv-understanding-tilesets-9178fe09e475)
- [Tileset Roundup — BorisTheBrave](https://www.boristhebrave.com/2013/07/14/tileset-roundup/)
- [mapeditor/tiled issue #1022 — RPG Maker autotile import](https://github.com/bjorn/tiled/issues/1022)
- [eishiya/tiled-expand-autotile — Tiled script for RPG Maker tilesets](https://github.com/eishiya/tiled-expand-autotile)
- [GameMaker manual — Auto Tiles](https://manual.gamemaker.io/monthly/en/The_Asset_Editors/Tile_Set_Editors/Auto_Tiles.htm)
- [Unity Asset Store — Autotile Importer for RPG Maker-Compatible Tilesets](https://assetstore.unity.com/packages/tools/sprite-management/autotile-importer-for-rpg-maker-compatible-tilesets-image-103504)
- [Excalibur.js — Autotiling Technique](https://excaliburjs.com/blog/Autotiling%20Technique/)
- [itsjavi/autotiler — 47-tile blob generator](https://github.com/itsjavi/autotiler)

---

*Pre-implementation reference; no code committed. Reopen this document at v0.3+ milestone planning.*
