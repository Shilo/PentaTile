# PixelLab.ai Tile Generation — Format Audit

**Researched:** 2026-04-25 (subagent on https://www.pixellab.ai/docs)
**Confidence:** HIGH on the three documented export targets; MEDIUM on the per-export pixel-grid conventions (PixelLab docs don't show full atlases for each); LOW on whether a "raw native" format exists prior to export selection (docs imply not, but unstated).

---

## What PixelLab is

AI tile/tileset/sprite generator. Two relevant tools:

- **Create Tileset** — generates a 2-terrain transition tileset from text (`inner` / `transition` / `outer` descriptions) or reference textures. Tier 1+.
- **Create Tiles (Pro)** — generates "tile variations for game maps from a text description." Supports Square top-down, Hex (flat + pointy), Isometric, Octagon. Tile sizes 16–128 px.

Map-painting tools (`create-map`, `extend-map`, `extend-map-v2`) are orthogonal — those are canvas authoring, not tileset generation.

## Native format — there isn't one

The PixelLab docs don't expose a "raw" native format that's separate from the user-selected export target. The user picks ONE of three export targets at generation/export time; whatever underlying representation PixelLab uses internally isn't visible to consumers.

Net effect: **PixelLab's effective "native" format = whatever the user exported.** No new mask topology lurking.

## Three documented export targets

| Target | Tile count | Grid | Mask topology | TetraTile equivalent |
|--------|-----------|------|----------------|----------------------|
| **Wang tileset** (Sprite-Fusion-compatible per PixelLab docs) | 16 | 4×4 | 4-bit corner (dual-grid) | ✓ `TetraTileLayoutDualGrid16` (already planned for Phase 2) |
| **Dual-grid 15-tileset** | 15 | 5×3 with stray fill | 4-bit corner (Tilesetter convention) | ✓ `TetraTileLayoutTilesetterWang15` (already planned for Phase 3) |
| **3×3 tileset** | 9 | 3×3 | 4-bit edge / "Match Sides" | ✗ **Not in v0.2 — would need `TetraTileLayoutMinimal3x3`** |

The 3×3 export = the classic "3×3 minimal" autotile layout — Godot 3.x called it `3x3 minimal`, Godot 4 calls it `MATCH_SIDES`. Same shape RPG Maker A2 ground tiles use, and what most "tiny terrain set" community art ships as.

## No Godot integration

- **No first-party Godot plugin or `.tres` exporter.** PixelLab outputs PNG atlases; the user manually imports them into a Godot `TileSet`.
- An **MCP server** (`github.com/pixellab-code/pixellab-mcp`) exposes generation to AI agents — produces images, not Godot resources.
- Engine name-checked in PixelLab docs: **Sprite Fusion only.** Not Godot, Unity, Tiled, or LDtk.

This means TetraTile would BE the Godot integration — there's no first-party tool to compete with or be displaced by.

## Implications for TetraTile v0.2

### Option A: skip Minimal3x3 — defer to v0.3

- Two of three PixelLab exports already covered by planned layouts. Doc the mapping in a "PixelLab interop" README section — "if your PixelLab export is Wang, use `DualGrid16`; if it's dual-grid-15, use `TilesetterWang15`."
- The 3×3 export is rarer in modern Godot art than blob47/wang16; users can defer until v0.3 if they need it.
- Net v0.2 scope: unchanged.

### Option B: add Minimal3x3 — close the loop

Ship `TetraTileLayoutMinimal3x3` as the 9th layout in v0.2:

- 9 tiles in a 3×3 atlas (could be authored or auto-decoded from a template)
- Single-grid edge mask (T/E/B/W bits, just like Wang2Edge)
- BUT: only 9 of 16 edge-mask states are encoded — the remaining 7 are derived via rotation reuse OR the layout doesn't support those states (depends on the atlas convention)
- Covers PixelLab's third export AND legacy Godot-3 atlases AND RPG Maker A2-ground (broader payoff than a PixelLab-only subclass)
- Marginal cost: ~60 LOC for the subclass + 1 template PNG + 1 fallback TileSet. Plus a decoder probe (could be a third spike to verify the 3×3 silhouettes encode unambiguously with the unified 8-anchor sampler).

### Recommendation

**Option B if "PixelLab interop" is a v0.2 marketing-line goal.** Otherwise **Option A** — keep v0.2 lean, document the mapping, defer the 9-tile layout to v0.3.

The 3×3 layout is the only piece of v0.2 milestone scope that depends on PixelLab specifically. If the user is fine with "PixelLab Wang and dual-grid-15 work out of the box; 3×3 export coming later," v0.2 doesn't grow.

## Notes on the example image (user-supplied)

The user provided one example image showing ~7 irregular-arrangement tiles, dark navy + light grey grid lines, ~120×96 px. The subagent could not match it to any of the three documented PixelLab export grids:

- 4×4 Wang: 16 tiles in a tidy grid, no irregular arrangement
- 5×3 dual-grid-15: 15 tiles (one stray-fill position), still rectangular
- 3×3: 9 tiles in a square, no irregularity

Most likely candidates for what the example actually is:
1. A **WIP / preview screenshot** from PixelLab's authoring UI before the user hits "export" — partial tile generation in progress.
2. A **subset preview** showing only the variations PixelLab generated, not a complete autotile atlas.
3. A different tool's output mistakenly labeled "PixelLab."

If the user can confirm the source — or share which of the three export targets generated this — that pins down whether we're missing a fourth format.

## Sources

- https://www.pixellab.ai/docs/tools/create-tileset
- https://www.pixellab.ai/docs/tools/create-tiles-pro
- https://www.pixellab.ai/docs/options/tileset
- https://www.pixellab.ai/docs/guides/map-tiles
- https://www.pixellab.ai/pixellab-api
- https://github.com/pixellab-code/pixellab-mcp
- YouTube tutorials: `q9z2Vhpz-Z8`, `p1l9S3ta_XA` (for visual confirmation of export UI; not yet watched)

---

*Audit: PixelLab does not warrant a dedicated TetraTile layout subclass. Add `TetraTileLayoutMinimal3x3` only if its broader value (legacy Godot-3 atlases, RPG Maker A2 interop) justifies the +60 LOC.*
