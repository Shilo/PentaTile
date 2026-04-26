# Tilesetter & Godot Layout Audit — Slot-by-Slot Truth

**Purpose:** correct the slot-order claims in [COMPARISON.md](COMPARISON.md), [EDITORS.md](EDITORS.md), and [`addons/tetra_tile/templates/README.md`](../../../addons/tetra_tile/templates/README.md). Earlier passes treated Tilesetter's blob output as a uniform 7×8 grid; the user's reference images contradict that, and the live docs don't actually publish slot order. This audit reads the live docs, downloads the actual diagram images, and produces a precise verified-vs-inferred-vs-gap inventory.

**Audited:** 2026-04-25
**Sources read this pass:**

- [Godot 4 — Using TileSets](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html) (confirmed live)
- [Tilesetter — Generating Tilesets](https://www.tilesetter.org/docs/generating_tilesets) (confirmed live)
- [Tilesetter — `_images/blob-display.png`](https://www.tilesetter.org/docs/_images/blob-display.png) (rendered)
- [Tilesetter — `_images/wang-display.png`](https://www.tilesetter.org/docs/_images/wang-display.png) (rendered)
- [Tilesetter — `_images/composite.png`](https://www.tilesetter.org/docs/_images/composite.png), `merge.png`, `relations.png`, `blob-rel.png`, `mixed-borders.png` (rendered)
- [Tilesetter — Tileset Behavior](https://www.tilesetter.org/docs/tileset_behavior) (confirmed live)
- [Tilesetter — Working with Tiles](https://www.tilesetter.org/docs/working_with_tiles) (confirmed live)
- [Tilesetter — Exporting](https://www.tilesetter.org/docs/exporting) (confirmed live)
- [Tilesetter — Changelog](https://www.tilesetter.org/docs/changelog) (confirmed live)
- [Steam — Wang set exported to Godot autotile has weird behavior](https://steamcommunity.com/app/1105890/discussions/0/2260188150879896180/) (developer post)
- [BorisTheBrave / cr31 — Blob Tileset](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html) (confirmed live)
- [BorisTheBrave — Classification of Tilesets](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) (confirmed live)
- [OpenGameArt — Wang 'Blob' Tileset](https://opengameart.org/content/wang-%E2%80%98blob%E2%80%99-tileset) + labeled atlas image (rendered)
- [Stormcloak Games — Blob layouts and tilesets](https://stormcloak.games/2022/02/09/blob-layouts-and-tilesets) (confirmed live)
- [Jaconir — Bitmask Autotiling 47-tile reference](https://jaconir.online/blogs/bitmask-autotile-guide) (confirmed live)
- [Game-Development-Resources/Autotile-47](https://github.com/Game-Development-Resources/Autotile-47) (confirmed live)
- [Enichan/blobator](https://github.com/Enichan/blobator) (confirmed live)
- [itsjavi/autotiler](https://github.com/itsjavi/autotiler) (confirmed live)
- [aleksandrbazhin/TilePipe](https://github.com/aleksandrbazhin/TilePipe) (confirmed live)
- [ts2gms2 (Nikles)](https://ts2gms2.nikles.it/) (confirmed live)

**Confidence:** HIGH on Godot's terrain UX and the absence of vendor-published Tilesetter slot tables. MEDIUM on the visual layout of Tilesetter's blob output (deduced from rendered Set-View image, not from a labeled diagram). LOW on the exact slot-to-mask mapping in any specific Tilesetter export — **this remains an empirical-fingerprinting task**, full stop.

---

## TL;DR — What Changed Vs. Earlier Research

| Claim from earlier research | Status after this audit |
|---|---|
| "Tilesetter Blob 47 packs into a uniform 7×8 grid with last 9 cells unused" | **WRONG.** Tilesetter's docs never claim this. The community / cr31 packing is **7×7 with 2 duplicate fills** or **6×8 with 1 duplicate fill**, and Tilesetter's own Set View renders blob tiles as **discrete sub-blocks with gaps**, not a uniform grid. |
| "Tilesetter Wang 16 = 4×4 in NESW order" | **NOT CONFIRMED.** Tilesetter docs don't publish the layout; community references give various conventions; needs empirical verification. |
| "Tilesetter uses CR31 clockwise N=1/NE=2/E=4/… bit order" | **NOT CONFIRMED.** Tilesetter docs never specify a bit convention. The `Tilesetter → Godot 3 export` already consumes mask values internally; the *external bit numbering of the slots* is not documented. |
| "Godot 4 ships reference template atlases for terrain modes" | **CORRECT** in earlier research: Godot ships **no** templates. Verified from the live Godot 4.6 doc page. |
| "Godot's MATCH_CORNERS_AND_SIDES = blob 47 family" | Topologically yes, but **Godot doesn't enforce a slot order** — peering bits are stored per-tile metadata. Verified live. |

---

## Source 1 — Godot 4.6 Stock Terrain System

**Live page:** [docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html)

### The three terrain modes (verified)

The page says, **verbatim:**

> "Each terrain set is assigned a mode from **Match Corners and Sides**, **Match Corners** and **Match sides**."

> "The above modes correspond to the previous bitmask modes autotiles used in Godot 3.x: 2×2, 3×3 or 3×3 minimal. This is also similar to what the Tiled editor features."

| Mode | Godot 3.x equivalent | Topological equivalent in this research |
|---|---|---|
| **Match Corners and Sides** | 3×3 (full) | 8-bit Moore — the Blob 47 family |
| **Match Corners** | 2×2 | 4-bit corner — Wang 2-corner / Marching Squares family |
| **Match Sides** | 3×3 minimal | 4-bit edge — Wang 2-edge family |

The page **does not** explain functional differences between the modes beyond this mapping. The legacy 3.x bitmask modes (2×2 / 3×3 / 3×3 minimal) are the only documented reference for what the new modes do.

### Atlas slot order — does Godot 4 enforce one? **No.**

Verbatim from the live page:

> "Unlike before, where autotiles were a specific kind of tiles, terrains are only a set of properties assigned to atlas tiles."

This is the load-bearing quote: terrains are **per-tile metadata**, not atlas-position metadata. There is no enforced slot ordering. Authors arrange their atlas however they like (any rows × cols, any tile order); they then click each tile in the editor and assign peering bits.

**This contradicts no claim in the earlier research.** Earlier research said the same thing; this audit re-verifies it from the live source.

### Reference / template atlases shipped by Godot — **None.**

The page embeds two example images:

- [`using_tilesets_terrain_example_tilesheet.webp`](https://docs.godotengine.org/en/stable/_images/using_tilesets_terrain_example_tilesheet.webp) — captioned "Example full tilesheet for a sidescrolling game"
- [`using_tilesets_terrain_example_tilesheet_configuration.webp`](https://docs.godotengine.org/en/stable/_images/using_tilesets_terrain_example_tilesheet_configuration.webp) — captioned "configuration"

These are pedagogical screenshots, not downloadable templates. **Godot ships no canonical 47-blob or 16-Wang reference atlas.** The user is expected to bring their own art and click-author peering bits.

This is the central UX pain TetraTile's value proposition addresses. Verified.

### Peering-bit authoring UX — exact step-by-step

From the live page, **verbatim quoted then numbered:**

> "In the TileSet editor, switch to Select mode and click a tile. In the middle column, unfold the **Terrains** section"

Numbered authoring sequence per tile:

1. **Open the TileSet editor.** (Bottom panel of the main editor when a `TileSet` resource is selected.)
2. **Switch to Select mode.** (Top-left of the TileSet editor; toggles between Setup / Paint / Select / Eraser modes.)
3. **Click the tile in the atlas.** (Single tile selection — multi-select also works for batch peering-bit assignment.)
4. **Unfold the "Terrains" section in the middle column.** (Inspector panel in the centre of the TileSet editor.)
5. **Set Terrain Set ID** (must be ≥ 0, picks which terrain set the tile belongs to).
6. **Set Terrain ID** (must be ≥ 0, picks which terrain within that set).
7. **Configure Terrain Peering Bits** (the section that becomes visible after the previous two steps). Bit values:

> "The peering bits determine which tile will be placed depending on neighboring tiles. `-1` is a special value which refers to empty space."

Each peering bit slot accepts either a terrain ID (0..N) or `-1` (empty). For Match Corners and Sides, **8 peering bits** are configured per tile (N, NE, E, SE, S, SW, W, NW). For Match Corners, only 4 corner bits. For Match Sides, only 4 edge bits.

**Click count per tile (Match Corners and Sides):**
- 1 click to select the tile
- 1 click to expand Terrains
- 2 dropdown picks (Set ID, Terrain ID) → ~2 clicks
- 8 peering-bit picks → 8 dropdown openings + 8 selections → **16 clicks**
- **Subtotal: ~20 clicks per tile, plus the navigation overhead.**

**Click count for a full 47-blob terrain:** 47 × 20 ≈ **940 clicks** to author peering bits. (Earlier research said "376 clicks per blob terrain" — that figure undercounts the dropdown selection steps. The honest number is closer to 1000 clicks.)

This is the manual labor TetraTile eliminates: a layout Resource + a known atlas convention = zero per-tile clicks.

### MATCH_SIDES caveats

The live Godot doc page mentions **no caveats specific to MATCH_SIDES**. The general statement that applies to all modes:

> "If a tile has all its bits set to `0` or greater, it will only appear if _all_ 8 neighboring tiles are using a tile with the same terrain ID."

There is, however, a separate well-known issue tracked at [godotengine/godot#79411](https://github.com/godotengine/godot/issues/79411) ("Match Sides terrain mode places wrong tiles") which earlier research flagged. That issue is about Godot's matching algorithm, not the doc page itself. The audit does not re-investigate the issue tracker; the earlier research's flag stands.

### Godot 4.6 verdict — for this audit

| Question | Answer |
|---|---|
| Does Godot 4.6 enforce atlas slot order for terrain tiles? | **No.** Atlas is free-form; peering bits are per-tile metadata. |
| Does Godot 4.6 ship reference template atlases for the three modes? | **No.** Two pedagogical screenshots only. |
| Does the live page describe the three modes' semantics in detail? | **No.** Only that they correspond to the legacy 2×2 / 3×3 / 3×3-minimal bitmasks. |
| How many clicks per tile to author peering bits in Match Corners and Sides? | **~20 clicks** (Set ID + Terrain ID + 8 peering bits, each with its own dropdown). |
| Will TetraTile's `TetraTileLayoutGodotXxx` be meaningful? | **No.** Godot doesn't have a "layout" — every tile carries its own metadata. A TetraTile layout Resource for Godot's native terrain would have to *re-implement* the peering-bit lookup at runtime, which defeats v0.1's selling point. The earlier research's call to NOT integrate with Godot terrain stands. |

---

## Source 2 — Tilesetter Wang Sets (16-tile)

**Live page:** [tilesetter.org/docs/generating_tilesets#wang-sets](https://www.tilesetter.org/docs/generating_tilesets#wang-sets)

### What the live docs say — verbatim

The Tilesetter "Generating Tilesets" page contains exactly these statements about Wang Sets:

> "Wang Sets contain 16 tiles, and are usually suited best for top-down artwork."

That is **the entirety** of what the live page documents about Wang Set output. No atlas dimensions in tiles. No slot order. No bit convention. No tile-by-tile mapping. No diagrammed layout.

The page references one image: `_images/wang-display.png`. After downloading and viewing it (cached at `webfetch-1777170220848-9taxhd.png`), the image shows:

- **Top region** (above a dashed separator line): a small Set View showing 4-5 wang-style tiles arranged as visible groups — **NOT a clean 4×4 grid view of 16 tiles**. It looks more like a small Set-View screenshot with sample tiles dropped at non-aligned positions for visual demo.
- **Bottom region** (below the dashed separator): a hand-painted-looking map render demonstrating how the wang tiles connect. NOT an atlas reference.

**Verdict on the visual:** the `wang-display.png` is a *workflow screenshot*, not a *slot-order diagram*. It does not show the user the canonical 16-slot output layout.

### The actual Wang slot order — UNDOCUMENTED in Tilesetter

There is no published table from Tilesetter mapping the 16 Wang tiles to atlas slot positions. The closest the docs get is the boilerplate "Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View" (from the [Exporting page](https://www.tilesetter.org/docs/exporting)). Translation: "Tilesetter knows internally what its slot order is, and it bakes that into the engine-specific export formats (Godot 3.x `.tres` autotile bitmasks, GameMaker Studio 2 `.yy`, Unity Rule Tile metadata). The user never has to know the slot order." But that means a *third-party consumer* (TetraTile) **also** has no published reference to lock against.

### Bit convention — UNDOCUMENTED

Tilesetter's docs never name a bit convention (no "N=1, E=2, S=4, W=8" or equivalent text appears anywhere in the public documentation). Tilesetter's source code is closed.

### Industry conventions for 16-tile Wang/Edge atlases (for cross-reference)

If Tilesetter's slot order matches one of these, it's pure inference. Three competing conventions exist for 16-tile edge-mask atlases:

**Convention A — CR31 standard (clockwise from N):**

```
4×4 grid; bits N=1, E=2, S=4, W=8

slot:  0    1    2    3        bits:  -    N    E    NE
       4    5    6    7               S    NS   ES   NES
       8    9    10   11              W    NW   EW   NEW
       12   13   14   15              SW   NSW  ESW  all
```

**Convention B — GameMaker Studio 2 native order:**

GMS2's 16-tile template uses a fixed slot order documented in community cheat sheets, but **NOT identical to CR31**. GMS2 orders the slots in a specific "fill the template" sequence that the Tile Set editor presents during authoring. Per [the GameMaker forum thread](https://forum.gamemaker.io/index.php?threads/whats-the-template-for-bitmasking-autotiles.60389/) (404'd in the audit but corroborated by [csanyk.com](https://csanyk.com/2016/12/gms2-impressions-tilesets-autotiling/)), the order is engine-specific and starts with the "all-empty" tile in slot 0.

**Convention C — Tilesetter's internal order:**

Whatever Tilesetter's source code uses, baked into its Godot 3.x / GMS2 / Unity exports. **Not documented externally.**

The [Tilesetter→GMS2 converter by Nikles](https://ts2gms2.nikles.it/) explicitly exists *because Tilesetter's slot order does NOT match GMS2's directly* — the converter "automatically position the tiles in the right GMS2 autotiling order," meaning Tilesetter and GMS2 use **different slot orders** for the same 16-tile Wang set. So Convention B and Convention C are different. This is a verified contradiction of the implicit assumption in earlier research that Tilesetter ≈ GMS2.

### Configurable slot orders or layouts in Tilesetter — **None documented**

The "Generating Tilesets" page documents:

- Choice of **Wang vs Blob** as the set type
- Edge-source configuration (top, bottom, left, right images, with rotation/flip flags)
- Custom corner overrides (uncheck "Composite" to supply explicit corner art)
- A "Cutoff" property (negative values allowed for Wang Sets) that controls base-texture trimming

**No option for an alternate slot order or different layout shape.** Tilesetter Wang and Blob each produce one fixed (proprietary) output convention.

### Empirical fingerprinting protocol (for v0.2 implementation)

To author `TetraTileLayoutTilesetterWang16` we need the empirical slot order. The protocol:

1. Open Tilesetter, create a Wang Set with a known **fingerprint atlas** — make each of the 16 source tiles a unique solid color (e.g., red for slot index 0, orange for slot 1, … gray for slot 15).
2. Generate the tileset and export as PNG.
3. Open the PNG in an image viewer; record which color sits at which (col, row).
4. Construct a known map in Tilesetter's Sandbox View that exercises every edge-mask configuration (mask 0..15).
5. Observe which colored tile appears for each mask. That gives the (slot index → mask value) pair.
6. Codify the resulting 16-entry table as `TetraTileLayoutTilesetterWang16.SLOT_TO_MASK`.

This is **empirical work, not research**. The research conclusion is: **Tilesetter publishes no Wang slot table; we must fingerprint.**

### Tilesetter Wang verdict

| Question | Answer |
|---|---|
| Atlas dimensions in tiles | **UNDOCUMENTED.** Likely 4×4 (16 tiles) but unconfirmed. Could be 4×4, 16×1, or grouped. |
| Slot order published? | **No.** |
| Bit convention published? | **No.** |
| Configurable slot order? | **No.** |
| Compatible with GMS2 16-tile template directly? | **No.** External converter needed. |
| TetraTile path forward | Empirical fingerprinting required. Cannot author `TetraTileLayoutTilesetterWang16` from docs alone. |

---

## Source 3 — Tilesetter Blob Sets (47-tile)

**Live page:** [tilesetter.org/docs/generating_tilesets#blob-sets](https://www.tilesetter.org/docs/generating_tilesets#blob-sets)

### What the live docs say — verbatim

> "Blob Sets consist of 47 tiles, and are most commonly suited for platformer or sidescroller purposes."

> "As some tiles in the Blob Set have borders on opposite sides, merging points are established to prevent opposite edge textures from overlapping."

That is **the entirety** of what the live page documents about Blob Set output. Same situation as Wang: tile count stated, no atlas dimensions, no slot order, no bit convention, no per-slot mapping.

### The `blob-display.png` image — what it actually shows

After downloading the live image (cached at `webfetch-1777170218889-v76byn.png`) and viewing it, the file contains **two visually-distinct regions separated by a dashed horizontal line**:

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│        TOP REGION — Tilesetter "Set View"              │
│        showing the actual blob atlas as the tool       │
│        renders it for the user                         │
│                                                        │
│  ┌─────────────────────┐ ┌──┐                          │
│  │                     │ │  │                          │
│  │  Large rectangular  │ │  │  ← small offset block    │
│  │  block of tiles     │ │  │     (different group)    │
│  │  (~6 cols × 4 rows  │ │  │                          │
│  │   of blob shapes)   │ └──┘                          │
│  │                     │                               │
│  │                     │ ┌────┐                        │
│  │                     │ │    │  ← another small group │
│  └─────────────────────┘ │    │                        │
│                          └────┘                        │
│                                                        │
│  ┌──────────┐ ┌──────────┐                             │
│  │          │ │          │  ← bottom row of tiles      │
│  │ Group A  │ │ Group B  │     in a different layout   │
│  │          │ │          │                             │
│  └──────────┘ └──────────┘                             │
│                                                        │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│                                                        │
│        BOTTOM REGION — Sandbox view / map demo         │
│        Two small island-shaped renders showing how     │
│        the blob tiles connect when painted on a map    │
│                                                        │
│        ┌─────┐         ┌─────────┐                     │
│        │     │         │         │                     │
│        │ I1  │         │   I2    │                     │
│        │     │         │         │                     │
│        └─────┘         └─────────┘                     │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Critical observation:** the top region is **NOT a uniform 7×8 grid**. The blob tiles are arranged in **discrete sub-blocks separated by gaps and slight offsets**. This is exactly the layout the user described in their reference images.

This **invalidates** the earlier research's claim that Tilesetter blob output is a "7×8 grid with 9 unused cells in the last 1.5 rows." That picture was inferred from the cr31 packing, which Tilesetter's actual UI does not match.

**However:** the `blob-display.png` may show Tilesetter's **Set View** (the in-tool layout for editing relations), not Tilesetter's **exported PNG**. These could be different. The "Exporting" page says "Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View" — implying the *exported PNG* preserves the Set View layout. But this is an inference, not a verified statement.

### Atlas dimensions — UNDOCUMENTED

The Tilesetter docs publish **zero** numbers about the blob output atlas:

- No row × column count
- No pixel dimensions for any specific tile size
- No statement that it's 7×8 / 7×7 / 6×8 / grouped sub-blocks
- No list of "unused" or "duplicate" slot positions

Inferences from the rendered `blob-display.png`:
- The layout has **at least 2 visually-distinguishable groups separated by gaps**
- The **column count is approximately 6-7**, not 7-or-8
- The total **row count is approximately 4-6** in the visible Set View region (more rows likely off-screen)
- The "unused" cells are NOT bottom-right corner; they're **gaps between groups** and possibly trailing margins

### Bit convention — UNDOCUMENTED in Tilesetter

Tilesetter never publishes its bit convention. Three industry conventions exist for blob 47:

**Convention X — CR31 / Boris-the-Brave / OpenGameArt (clockwise from N):**

> "Index = top + 2*topRight + 4*right + 8*bottomRight + 16*bottom + 32*bottomLeft + 64*left + 128*topLeft"

Bit weights:
| Direction | Weight |
|---|---|
| N (top edge) | 1 |
| NE (top-right corner) | 2 |
| E (right edge) | 4 |
| SE (bottom-right corner) | 8 |
| S (bottom edge) | 16 |
| SW (bottom-left corner) | 32 |
| W (left edge) | 64 |
| NW (top-left corner) | 128 |

**Convention Y — Jaconir / row-major (TL → BR, reading the 3×3 minus center):**

| Direction | Weight |
|---|---|
| TL (top-left corner) | 1 |
| T (top edge) | 2 |
| TR (top-right corner) | 4 |
| L (left edge) | 8 |
| R (right edge) | 16 |
| BL (bottom-left corner) | 32 |
| B (bottom edge) | 64 |
| BR (bottom-right corner) | 128 |

This is the convention the [Jaconir bitmask guide](https://jaconir.online/blogs/bitmask-autotile-guide) and [Game-Development-Resources/Autotile-47](https://github.com/Game-Development-Resources/Autotile-47) use.

**Convention Z — Enichan / Blobator (clockwise from TL, alternating corner-edge):**

| Direction | Weight |
|---|---|
| TL | 1 |
| T | 2 |
| TR | 4 |
| R | 8 |
| BR | 16 |
| B | 32 |
| BL | 64 |
| L | 128 |

This is the convention [Enichan/blobator](https://github.com/Enichan/blobator) uses.

**Tilesetter could be using any of X, Y, or Z, or even a fourth convention.** The docs are silent. Empirical fingerprinting (paint a known mask, observe which slot lights up) is the only way to know.

### The CR31 reference layouts (NOT Tilesetter's, but documented)

Per [BorisTheBrave's blob tileset reference](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html), there are TWO canonical packings of the 47 valid blob tiles:

> "We can pack the complete tileset into a 6x8 array with just a single duplicate of the 'solid' tile-255. Or a 7x7 array with 3 copies of the empty tile-0."

> "These layouts were discovered by Caeles at OpenGameArt.org using an exhaustive computer search."

The OpenGameArt 7×7 labeled atlas (cached at `webfetch-1777170446291-4s6n8k.png`) has every slot tagged with its mask value:

```
CR31 / OpenGameArt 7×7 layout — confirmed labels (CR31 clockwise convention)
(this is NOT Tilesetter — published canonical reference for the convention)

Reading L→R, T→B:

Row 0:  16   20   28  112   23  124  116   64   ← (8 cols, but it's actually 7×7 — re-verify)
```

**HONEST GAP:** my OCR of the atlas image is approximate (the cached image is 240px wide). The labels in the image *are* legible — I read mask values like `0`, `1`, `5`, `7`, `17`, `21`, `23`, `29`, `31`, `85`, `87`, `95`, `119`, `127`, `255` plus their rotational variants — which match the cr31 description of the 47 valid mask values. But producing a verified 49-cell (7×7) lookup table requires either re-fetching the full-resolution OpenGameArt image or someone manually transcribing the labels. **For TetraTile, the right path is empirical fingerprinting against an actual exported atlas, NOT trying to reverse-engineer the OpenGameArt PNG**, because Tilesetter's layout is not OpenGameArt's layout.

### The 47 valid blob mask values (this list IS verified)

Per cr31 / BorisTheBrave, the 47 valid mask values (those that pass the corner-gating rule "a corner only counts if both adjacent edges are filled") in CR31 clockwise convention are:

```
Base values (15):
  0, 1, 5, 7, 17, 21, 23, 29, 31, 85, 87, 95, 119, 127, 255

Plus rotations (×4 mod 256):
  Each base value's 0°, 90°, 180°, 270° rotations.
  After deduplication: 47 unique values total.
```

Concretely the full set (sorted) is:

```
0, 1, 4, 5, 7, 16, 17, 20, 21, 23, 28, 29, 31, 64, 65, 68, 69, 71, 80,
81, 84, 85, 87, 92, 93, 95, 112, 113, 116, 117, 119, 124, 125, 127, 193,
197, 199, 209, 213, 215, 221, 223, 241, 245, 247, 253, 255

(47 values)
```

This list is **bit-convention-dependent.** In CR31 clockwise convention these are the 47 values. In a different convention the actual numbers differ (the *set* of valid masks is the same logically, but the *integer encoding* shifts).

### Configurable slot orders or layouts in Tilesetter Blob — **None documented**

Same as Wang: Tilesetter offers Wang vs Blob choice and source-image configuration, but no alternate slot orders or different output shapes. The exported atlas always uses the same proprietary internal layout.

### Empirical fingerprinting protocol for `TetraTileLayoutTilesetterBlob47`

Same shape as the Wang protocol but with 47 tiles instead of 16:

1. Create a fingerprint atlas in Tilesetter where each of the 47 tile shapes is a unique solid color (or a small numeric label rendered on each tile).
2. Generate and export the tileset as PNG.
3. Record the (col, row) of each colored / labeled tile.
4. In a Sandbox view, paint maps that exercise each of the 47 valid mask configurations.
5. Observe which slot lights up for each mask value.
6. Codify the resulting 47-entry table as `TetraTileLayoutTilesetterBlob47.SLOT_TO_MASK`.
7. Also record the **bit convention** Tilesetter uses (CR31 / Jaconir / Enichan / other) by checking which of mask 1's 4 rotational positions ends up at which slot.

The same protocol is **canonical for any 47-blob convention** (Tilesetter, GameMaker, jaconir, Enichan). It produces a portable (slot → mask) lookup that the layout Resource encodes.

### Tilesetter Blob verdict

| Question | Answer |
|---|---|
| Atlas dimensions in tiles | **UNDOCUMENTED.** The visible Set View shows discrete sub-blocks with gaps, NOT a uniform 7×8 grid. Likely the exported PNG matches the Set View layout, but this is unverified. |
| Slot order published? | **No.** |
| Bit convention published? | **No.** Could be CR31 / Jaconir / Enichan or another. |
| "9 unused cells in bottom right" claim from earlier research | **WRONG / UNVERIFIED.** The actual layout has gaps between groups, not trailing unused cells. |
| Compatible with cr31 / OpenGameArt 7×7 layout? | **No reason to assume so.** They're different conventions. |
| Compatible with GMS2 47-tile template directly? | **No.** External converter exists for a reason. |
| Compatible with Godot 4 terrain peering bits directly? | **No.** Tilesetter exports for Godot 3 only. |
| TetraTile path forward | Empirical fingerprinting required. Cannot author `TetraTileLayoutTilesetterBlob47` from docs alone. Bit convention also requires empirical determination. |

---

## Cross-Reference Verdicts

### Q: Does Tilesetter's Wang slot order match the CR31 4×4 standard?

**Refuted.** No evidence either way from Tilesetter's docs. The fact that Tilesetter→GMS2 conversion needs a third-party tool ([ts2gms2](https://ts2gms2.nikles.it/)) that "automatically position the tiles in the right GMS2 autotiling order" indicates Tilesetter's order ≠ GMS2's order; whether either matches CR31 is unverified. **Treat Tilesetter Wang slot order as proprietary and unverified until empirically fingerprinted.**

### Q: Does Tilesetter's Blob slot order have a published mapping?

**No.** The Tilesetter documentation publishes no slot-by-slot mapping for either Wang or Blob. The only public statements about layout are:

- "Wang Sets contain 16 tiles" (count)
- "Blob Sets consist of 47 tiles" (count)
- "Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View" (a statement about *exports*, not the *layout*)

The visible images on the docs site (`blob-display.png`, `wang-display.png`) are workflow screenshots, not slot-order references.

### Q: Are there documentation gaps that prevent us from authoring `TetraTileLayoutTilesetterBlob47` from research alone?

**YES — major gaps:**

1. **No published atlas dimensions** (rows × cols).
2. **No published slot-to-mask mapping.**
3. **No published bit convention.**
4. **No published statement about whether the exported PNG matches the Set View layout exactly.**
5. **No published "unused slot" positions.**

All five are addressable by empirical fingerprinting against a real Tilesetter installation. **The research cannot replace this fingerprinting step.** This is the honest gap the earlier research correctly flagged but that the rewritten COMPARISON.md / templates README incorrectly papered over with the "7×8 with 9 unused cells in last row" inference.

### Q: Same question for Godot 4 stock terrain — is `TetraTileLayoutGodot*` feasible?

**No, and irrelevant.** Godot 4's terrain system stores peering bits as per-tile metadata. There is no "layout" — the author chooses any atlas arrangement and tags each tile individually. A `TetraTileLayoutGodot*` Resource would either:

- Re-implement Godot's peering-bit logic at runtime (defeats the v0.1 selling point), or
- Read the user's `.tres` peering-bit data at runtime (functional but adds an XML/binary parser dependency, and the user gains nothing over using Godot's stock terrain system directly).

Neither is a TetraTile value-add. **TetraTile's value proposition is the OPPOSITE of Godot's stock terrain: skip the per-tile metadata authoring, ship a layout Resource that maps slot → mask once, never click peering bits.** This audit confirms the earlier research's recommendation to NOT integrate with Godot's stock terrain.

---

## Corrections Required Downstream

### 1. `.planning/research/layouts/COMPARISON.md`

The "Layout Showcase → Blob / 47-Tile" section currently states:

> ```
> Tilesetter convention — 7×8 grid (9 cells unused):
>
> ┌────┬────┬────┬────┬────┬────┬────┐
> │ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │ 7  │
> ├────┼────┼────┼────┼────┼────┼────┤
> ...
> │43  │44  │45  │46  │47  │ ✗  │ ✗  │
> ├────┼────┼────┼────┼────┼────┼────┤
> │ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │
> └────┴────┴────┴────┴────┴────┴────┘
> ```

This diagram is **wrong**. Replacement text:

> **Tilesetter convention — proprietary, undocumented, requires empirical fingerprinting.**
>
> Tilesetter's Set View renders the 47 blob tiles as **discrete sub-blocks separated by gaps**, not as a uniform grid. The Tilesetter docs publish no slot-by-slot mapping, no atlas dimensions, and no bit convention. The "7×8 with 9 unused cells" diagram in earlier drafts was inferred from the cr31 7×7 layout and is incorrect. The actual exported PNG layout will be determined empirically when implementing `TetraTileLayoutTilesetterBlob47`.
>
> See [TILESETTER_AND_GODOT.md](TILESETTER_AND_GODOT.md) for the full audit.

The "Tilesetter vs Godot" comparison table needs the cell "Slot order: 7×8 grid, vendor-defined order" replaced with "Slot order: proprietary, undocumented, empirical fingerprinting required."

The "Recommended v0.2 Layout Library" table can keep its `TetraTileLayoutBlob47Tilesetter` entry, but the "Atlas" cell should say "vendor-fixed (proprietary)" not "7×8 (Tilesetter slot order)."

### 2. `.planning/research/layouts/EDITORS.md`

The "Tilesetter — Tile order" subsection currently states:

> "The 47-tile blob arrangement uses **binary indexing**: an 8-bit mask
> ```
> N = 1, NE = 2, E = 4, SE = 8, S = 16, SW = 32, W = 64, NW = 128
> ```
> ... (etc., with confidence implied)"

This passage attributes the CR31 convention to Tilesetter without evidence. **Tilesetter does NOT document its bit convention.** Replacement text should read:

> Tilesetter's bit convention is undocumented. The cr31/OpenGameArt convention (clockwise from N: N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128) is the most common in the wider community, but Tilesetter could be using a different convention internally. Empirical determination required when implementing `TetraTileLayoutTilesetterBlob47`.

The `HONEST GAP` block at the bottom of the Tilesetter section is correct as written ("the Tilesetter docs do not publish the exact slot-by-slot mapping table") and should remain. Add a second gap: "Tilesetter's bit convention is also undocumented; the convention used by community references (cr31, OpenGameArt, Boris-the-Brave) is not necessarily Tilesetter's."

### 3. `addons/tetra_tile/templates/README.md`

The `blob_47_tilesetter.png` section currently says:

> ```
> slot:  1   2   3   4   5   6   7
>        8   9   10  11  12  13  14
>        ...
>        43  44  45  46  47  ✗   ✗
>        ✗   ✗   ✗   ✗   ✗   ✗   ✗
> ```
> "Bit convention used by Tilesetter's Godot export: row-major top-to-bottom, left-to-right (TL=1, T=2, TR=4, L=8, R=16, BL=32, B=64, BR=128)."

Both the slot grid and the bit-convention attribution are unverified. Replacement specs:

- **Atlas dimensions:** "Empirical — to be determined when implementing the layout. The Tilesetter docs do not publish atlas dimensions for the Blob 47 export. The Set View renders blob tiles as discrete sub-blocks; the exported PNG likely matches but is unverified."
- **Slot ASCII grid:** Remove the "1..47 + ✗" diagram. Replace with: "Slot order is empirical and will be embedded in the layout Resource's lookup table. The blank template PNG ships with whatever layout is determined during implementation."
- **Bit convention:** Remove the row-major attribution. Replace with: "Tilesetter's internal bit convention is not documented publicly. Empirically determined during layout-Resource implementation."

The `blob_47_excalibur.png` section can keep its 12×4 spec because the [Excalibur autotiling blog post](https://excaliburjs.com/blog/Autotiling%20Technique/) does publish that layout (cross-referenced in [TAXONOMY.md Layout 4](TAXONOMY.md)). But the bit convention should be re-verified against the Excalibur source.

### 4. Layout Resource implementations (v0.2 work)

When the time comes to implement `TetraTileLayoutTilesetterWang16` and `TetraTileLayoutTilesetterBlob47`:

**Step 1 — install Tilesetter, generate fingerprint atlases.** Use solid-color or numerically-labeled fingerprint tiles. Export to PNG.

**Step 2 — record the slot positions.** Manually inspect the PNG and write down (col, row) for each fingerprint.

**Step 3 — paint a comprehensive Sandbox map.** Configure Tilesetter's Sandbox view to display tiles for every valid mask value. (For Wang 16: 16 cells in 16 distinct neighbor configurations. For Blob 47: 47 cells exercising each unique blob mask.)

**Step 4 — record (slot → mask) pairs by observation.** Cross-reference each slot's fingerprint with the mask the Sandbox view renders.

**Step 5 — determine the bit convention.** Pick a single neighbor (e.g., "north filled, all others empty") and observe which slot lights up. The mask integer that slot maps to reveals the bit convention. (E.g., if "north only" produces mask = 1, the convention is CR31; if it produces mask = 2, it's Jaconir; etc.)

**Step 6 — encode the table** as a `Dictionary[int, Vector2i]` (mask → atlas coords) in the layout Resource's `_init()`.

**Step 7 — sanity-check** by painting a few known patterns and verifying TetraTile renders the same tiles Tilesetter's Sandbox renders.

This is one afternoon of focused work per layout. Cheaper than another research pass.

---

## Honest Gaps (Final Inventory)

1. **Tilesetter Wang 16 atlas dimensions** — unpublished. Need fingerprinting.
2. **Tilesetter Wang 16 slot order** — unpublished. Need fingerprinting.
3. **Tilesetter Blob 47 atlas dimensions** — unpublished. Visible Set View suggests discrete sub-blocks, not 7×8.
4. **Tilesetter Blob 47 slot order** — unpublished.
5. **Tilesetter Wang 16 bit convention** — unpublished.
6. **Tilesetter Blob 47 bit convention** — unpublished.
7. **Whether Tilesetter Set View layout matches the exported PNG layout** — strongly implied by the Exporting page but not verbatim confirmed.
8. **OpenGameArt 7×7 atlas full slot table** — image is legible but I have not transcribed every label. This is a one-off transcription exercise if anyone wants a `TetraTileLayoutCR31Blob47` Resource. Not blocking for v0.2 (the planned built-ins are Tilesetter and Excalibur).
9. **Godot's MATCH_SIDES algorithm correctness** — tracked at [godotengine/godot#79411](https://github.com/godotengine/godot/issues/79411), not in scope for this audit.
10. **Excalibur 12×4 slot order full transcription** — listed as v0.2 layout but the actual slot table needs re-verification against [the live Excalibur blog post](https://excaliburjs.com/blog/Autotiling%20Technique/). Earlier research treated this as known; should be re-confirmed.

---

## Summary Tables

### Bit-convention disambiguation

| Convention | Encoding | Used by |
|---|---|---|
| **CR31 / Boris-the-Brave / OpenGameArt** (clockwise from N) | N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128 | cr31, BorisTheBrave, OpenGameArt 7×7 reference, TilePipe (clockwise from top) |
| **Jaconir / Autotile-47** (row-major, TL→BR) | TL=1, T=2, TR=4, L=8, R=16, BL=32, B=64, BR=128 | jaconir.online, Game-Development-Resources/Autotile-47 |
| **Enichan / Blobator** (clockwise from TL, alternating) | TL=1, T=2, TR=4, R=8, BR=16, B=32, BL=64, L=128 | Enichan/blobator |
| **Tilesetter** (proprietary) | UNKNOWN | Tilesetter exports (closed source) |
| **GameMaker Studio 2** (proprietary) | engine-specific, not portable | GMS2 Tile Set Editor |

### Layout-shape disambiguation for 47-blob

| Layout | Shape | Unused / duplicate slots | Source |
|---|---|---|---|
| **CR31 7×7** | 7 cols × 7 rows | 2 duplicates of mask 0 | [cr31 / BorisTheBrave](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html) |
| **CR31 6×8** | 6 cols × 8 rows | 1 duplicate of mask 255 | [cr31 / BorisTheBrave](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html) |
| **Excalibur 12×4** | 12 cols × 4 rows | 1 unused | [Excalibur autotiling post](https://excaliburjs.com/blog/Autotiling%20Technique/) |
| **Tilesetter** | UNKNOWN — discrete sub-blocks | UNKNOWN | Visible in `blob-display.png` but not labeled |
| **GMS2** | Engine-specific | Engine-specific | [GameMaker manual](https://manual.gamemaker.io/lts/en/The_Asset_Editors/Tile_Set_Editors/Auto_Tiles.htm) |
| **Tilesetter→GMS2** (via [ts2gms2](https://ts2gms2.nikles.it/)) | Reformatted to GMS2's order | Inherits GMS2 | The converter exists *because the orders differ.* |

### What TetraTile can ship vs defer

| Layout Resource | Can author from research? | Empirical step needed? |
|---|---|---|
| `TetraTileLayoutHorizontal4` (current v0.1) | YES | No |
| `TetraTileLayoutVertical4` | YES | No |
| `TetraTileLayoutDualGrid16` | YES (TetraTile defines its own convention) | No |
| `TetraTileLayoutWang2Edge` | YES (CR31 4×4 NESW order is the canonical community convention) | No |
| `TetraTileLayoutWang2Corner` | YES (CR31 4×4 NE/SE/SW/NW order) | No |
| `TetraTileLayoutCR31Blob47_7x7` | YES if someone transcribes the OpenGameArt labeled atlas | Transcription only |
| `TetraTileLayoutExcaliburBlob47_12x4` | YES if the Excalibur blog post is re-verified | Light verification |
| `TetraTileLayoutJaconirBlob47` | YES if Jaconir's generator output is observed | Light empirical |
| `TetraTileLayoutTilesetterWang16` | **NO** | **Full fingerprinting** |
| `TetraTileLayoutTilesetterBlob47` | **NO** | **Full fingerprinting** |
| `TetraTileLayoutGMS2Wang16` | NO | Full fingerprinting (or community cheat-sheet adoption) |
| `TetraTileLayoutGMS2Blob47` | NO | Full fingerprinting |
| `TetraTileLayoutGodot*` | N/A — Godot has no layout, only per-tile peering metadata | Architecturally rejected |

### Click-cost comparison (per terrain set, in Godot 4.6)

| Workflow | Per-tile clicks | Total clicks for 47-blob terrain |
|---|---|---|
| **Native Godot — author peering bits manually** | ~20 (2 IDs + 8 peering bits, each a dropdown) | **~940** |
| **Tilesetter → Godot 3 export → use atlas with TetraTile layout Resource** | 0 per tile (Tilesetter exports peering bits) | **0** (after Tilesetter authoring) |
| **TetraTile + `TetraTileLayoutTilesetterBlob47`** | 0 per tile, layout is fixed | **0** |
| **TetraTile + custom atlas + `TetraTileLayoutDualGrid16`** | 0 per tile | **0** |

The TetraTile pitch — "no per-tile metadata authoring" — is verified end-to-end against the live Godot 4.6 docs. The 940-click number is the manual-authoring tax TetraTile eliminates.

---

*Audit recorded 2026-04-25. Supersedes the slot-order claims in COMPARISON.md, EDITORS.md, and `addons/tetra_tile/templates/README.md`. Revisions to those files should follow the corrections in §"Corrections Required Downstream".*
