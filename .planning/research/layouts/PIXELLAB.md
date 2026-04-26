# PixelLab.ai Tile Generation — Format Audit

**Researched:** 2026-04-25 (subagent on docs + brainstorm session with user, who provided multiple native-output examples and confirmed the layout match)
**Confidence:** HIGH on native format = `template_corners` (user-confirmed); HIGH on the three documented export targets; HIGH on no first-party Godot integration.

---

## Headline finding

**PixelLab native output (top-down AND side-scroller) uses dandeliondino's `template_corners.png` layout** — i.e., the canonical 4×4, 16-tile, **Match Corners** (4-bit corner mask) layout. User confirmed this directly during the brainstorm session by mapping their generation outputs to the dandeliondino reference template.

**Implication:** PixelLab native is fully covered by `TetraTileLayoutDualGrid16` (already planned for v0.2 Phase 2). **No new layout subclass needed.** Spike 002 already validated the decoder against `template_corners.png` at 16/16 slot correctness — the native PixelLab path is pre-validated.

---

## What PixelLab is

AI tile/tileset/sprite generator. Two relevant tools:

- **Create Tileset** — generates a 2-terrain transition tileset from text (`inner` / `transition` / `outer` descriptions) or reference textures. Tier 1+.
- **Create Tiles (Pro)** — generates "tile variations for game maps from a text description." Supports Square top-down, Hex (flat + pointy), Isometric, Octagon. Tile sizes 16–128 px.

Map-painting tools (`create-map`, `extend-map`, `extend-map-v2`) are orthogonal — those are canvas authoring, not tileset generation.

## Native format

PixelLab generates a 4×4, 16-tile atlas matching the **Match Corners** (corner-mask) topology. Both top-down and side-scroller use the same layout — what differs between them is the **art content** (top-down: rotation-symmetric grass; side-scroller: gravity-oriented platform tops/bottoms), NOT the mask topology.

This is the same layout dandeliondino's `template_corners.png` documents (carried by https://github.com/dandeliondino/godot-4-tileset-terrains-docs/blob/master/templates/png/template_corners.png).

User-provided examples shown during brainstorm:
- 4 native PixelLab outputs at varying resolutions (~60–120 px wide), all consistent with the 4×4 / 16-tile Match Corners layout (with the visible variation being art content, not grid structure).
- User explicit confirmation: "PixelLab 'top down' and 'side scroller' native output image seems to be this layout: [template_corners.png]"

## Three documented export targets (additional formats PixelLab supports)

| Target | Tile count | Grid | Mask topology | TetraTile equivalent |
|--------|-----------|------|----------------|----------------------|
| **Wang tileset** (Sprite-Fusion-compatible per PixelLab docs) | 16 | 4×4 | 4-bit corner (dual-grid) | ✓ `TetraTileLayoutDualGrid16` (Phase 2) |
| **Dual-grid 15-tileset** | 15 | 5×3 with stray fill | 4-bit corner (Tilesetter convention) | ✓ `TetraTileLayoutTilesetterWang15` (Phase 3) |
| **3×3 tileset** | 9 | 3×3 | 4-bit edge / "Match Sides" | ✗ Not in v0.2 — `TetraTileLayoutMinimal3x3` would close this |

PixelLab's "Wang" export and its native format both produce the same 4×4 corner-mask layout — the export step appears to be a no-op for that target. The dual-grid-15 export reorganizes to Tilesetter's 5×3 convention; the 3×3 export shrinks to the "Match Sides" minimal set.

## No Godot integration

- **No first-party Godot plugin or `.tres` exporter.** PixelLab outputs PNG atlases; the user manually imports them into a Godot `TileSet`.
- An **MCP server** (`github.com/pixellab-code/pixellab-mcp`) exposes generation to AI agents — produces images, not Godot resources.
- Engine name-checked in PixelLab docs: **Sprite Fusion only.** Not Godot, Unity, Tiled, or LDtk.

TetraTile becomes the Godot integration — there's no first-party tool to compete with or be displaced by.

## Implications for TetraTile v0.2

### Native PixelLab — COVERED by existing scope

`TetraTileLayoutDualGrid16` (already planned for Phase 2) handles native PixelLab output unchanged. Document the workflow in the layout-library README:

> **PixelLab interop:** PixelLab's native generation produces a 4×4 corner-mask atlas matching the Match Corners convention. Use `TetraTileLayoutDualGrid16` for PixelLab-generated content (both top-down and side-scroller). PixelLab's "Wang" export is the same format; the "Dual-Grid 15" export uses `TetraTileLayoutTilesetterWang15`; the "3×3" export is not yet supported (post-v0.2).

### Open scope decision: ship `TetraTileLayoutMinimal3x3`?

The 3×3 export target is the only PixelLab format not covered by v0.2. Adding it would also cover legacy Godot 3.x atlases and RPG Maker A2 ground sets. Cost: ~60 LOC + template PNG + fallback TileSet + maybe a third spike.

- **Recommend defer to v0.3** unless the user calls out 3×3 interop as a v0.2 milestone goal.
- Current v0.2 scope (8 layouts) covers PixelLab native + Wang export + dual-grid-15 export, plus the rest of the autotile zoo.

### Top-down vs side-scroller is NOT a layout distinction

A common confusion (the user surfaced this during brainstorm): "side-scroller" and "top-down" tilesets look different and seem to need different addon support. The reality:

- The **layout** (mask topology, grid shape, slot count) is identical for both — `DualGrid16` works for either.
- The **art content** differs: side-scroller tiles have gravity orientation (grass-on-top, rock-on-bottom); top-down tiles are rotation-symmetric.
- TetraTile renders both equivalently; the art is the user's responsibility.

Document this distinction in the README so users don't try to find a "side-scroller layout" that doesn't exist.

## Sources

- https://www.pixellab.ai/docs/tools/create-tileset
- https://www.pixellab.ai/docs/tools/create-tiles-pro
- https://www.pixellab.ai/docs/options/tileset
- https://www.pixellab.ai/docs/guides/map-tiles
- https://www.pixellab.ai/pixellab-api
- https://github.com/pixellab-code/pixellab-mcp
- https://github.com/dandeliondino/godot-4-tileset-terrains-docs/blob/master/templates/png/template_corners.png — the matching reference layout
- User-provided native generation samples (top-down + side-scroller, multiple resolutions; brainstorm session 2026-04-25)
- Spike 002 — `template_corners.png` decoded at 16/16 slot correctness with TetraTile's unified 8-anchor sampler

---

*Audit conclusion: PixelLab native = `DualGrid16`. Already covered by v0.2 scope. No new layout subclass required for PixelLab support. Optional `TetraTileLayoutMinimal3x3` would close the 3×3 export gap if desired; defer to v0.3 by default.*
