# Layout Comparison — Practical Side-by-Side

**Audience:** game devs and artists deciding which atlas convention to use, and how each one looks as an image. This file is the user-facing distillation of [TAXONOMY.md](TAXONOMY.md) and [EDITORS.md](EDITORS.md). Those have the academic detail; this file answers "what should my PNG look like?"

> All atlas grids below show **slot positions** (where each tile sits in the source image), NOT the artwork itself. Each cell is one tile. Slot ordering is the load-bearing fact.

---

## TL;DR — Decision Table

| Use case | Pick this layout | Tiles to author | Atlas grid |
|---|---|---|---|
| "I just want autotiling on a 4-tile budget" | **Tetra** (this addon's v0.1 default) | 4 | 4×1 or 1×4 |
| "I have art that doesn't rotate cleanly (top tiles, isometric)" | **Dual-Grid 16** | 16 | 4×4 |
| "I'm using Tilesetter's Wang export" | **Tilesetter Wang 16** | 16 (Tilesetter generates) | Tilesetter-fixed |
| "I'm using Tilesetter's Blob export" | **Tilesetter Blob 47** | 47 (Tilesetter generates) | 7×8 (9 unused) |
| "I want roads / fences / linear connectors" | **Wang 2-Edge** | 16 | 4×4 |
| "I want the maximum-quality blob look" | **Blob 47** | 47 | 7×8 or 12×4 |
| "I have an RPG Maker A2/A4 sheet" | RPG Maker (deferred to v0.3+) | sub-tile composition | 768×576 quarter-tile blocks |
| "My atlas was authored in Tiled with Wang Sets" | Not directly supported — needs `.tsx` import | — | author-defined |
| "My atlas was authored in LDtk" | Not directly supported — needs `.ldtk` import | — | author-defined |

---

## The Vocabulary Mess (Read This First)

The terms **Wang**, **Blob**, **Dual-Grid**, and **Marching Squares** are constantly conflated. Boris-the-Brave's [Classification of Tilesets](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) is the definitive disambiguation. Plain-English version:

- **Marching squares** = a 4-bit *corner* mask. 16 possible states. Each tile sits at the intersection of 4 logic cells.
- **Wang 2-corner** = mathematically *identical* to marching squares. Just different naming (cardinal corners NE/SE/SW/NW vs. quadrants TL/TR/BL/BR). When indie devs say "Wang tiles" they almost always mean this.
- **Wang 2-edge** = a 4-bit *edge* mask. Also 16 states, but matches on edges (N/S/E/W) instead of corners. Used for roads, fences, paths.
- **Dual-grid** = a *rendering trick* on top of marching squares: the visual layer is offset by half a tile so corners line up perfectly. The math is the same as marching squares.
- **Blob 47** = an 8-bit *Moore* mask (4 edges + 4 corners) with the corner-gating rule "a corner only counts if both adjacent edges are filled." This collapses the naive 256 states to 47 visually meaningful ones.
- **Tetra** (this addon) = marching squares with a rotation-symmetry trick that compresses 16 tiles down to 4 unique tiles + an overlay-layer composition for the two ambiguous diagonals (masks 6 and 9).

**Rule of thumb:** if someone says "Wang tiles" without qualifying *2-edge* or *2-corner*, ask. Most modern indie use of "Wang" means 2-corner, which is identical to marching squares.

---

## Layout Showcase

### Tetra (v0.1 default — 4 tiles)

**Mask:** 4-bit corner. **Tile count:** 4 unique. **Atlas:** 4×1 (horizontal) or 1×4 (vertical).

```
HORIZONTAL (4×1):

┌────┬────┬────┬────┐
│ 0  │ 1  │ 2  │ 3  │
│Fill│Inn.│Bord│Out.│
│    │Corn│ er │Corn│
└────┴────┴────┴────┘
  ↑     ↑     ↑     ↑
 mask  mask  mask  mask
  15    14    12    8
 (all)(missing(missing(only
        BR)     B)    TL)

VERTICAL (1×4): same tiles, stacked instead.
```

The other 12 mask states (1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 13) are produced by *rotating* these 4 tiles using Godot's `TRANSFORM_FLIP_*` flags. Masks 6 and 9 (the two "disconnected diagonals") use the addon's overlay-layer trick: two outer corners painted on different layers.

**Rotation symmetry is baked in.** This is why tetra can't do top tiles or directional art without breaking the contract.

### Dual-Grid 16

**Mask:** 4-bit corner (same as tetra). **Tile count:** 16 unique. **Atlas:** 4×4 grid OR 16×1 strip.

```
4×4 grid (mask = row*4 + col, reading L→R, T→B):

┌────┬────┬────┬────┐
│ 0  │ 1  │ 2  │ 3  │   masks 0..3
├────┼────┼────┼────┤
│ 4  │ 5  │ 6  │ 7  │   masks 4..7
├────┼────┼────┼────┤
│ 8  │ 9  │10  │11  │   masks 8..11
├────┼────┼────┼────┤
│12  │13  │14  │15  │   masks 12..15
└────┴────┴────┴────┘
                  ↑
                 fully connected

WARNING: The exact bit numbering (which corner is bit 0 vs bit 3)
is NOT standardized. TileMapDual, jess-hammer, Excalibur, and CR31
all pick different orderings. TetraTile will commit to one and
document it in the layout Resource.
```

**vs. Tetra:** same mask system, but you author all 16 unique tiles instead of relying on rotation. This unlocks asymmetric art (top tiles, isometric, hand-drawn pixel work where rotation would look wrong).

### Marching Squares (single-grid, 16 tiles)

**Mask:** 4-bit corner. **Tile count:** 16. **Atlas:** identical to Dual-Grid 16.

The ONLY difference between Marching Squares and Dual-Grid 16: Dual-Grid renders the visual layer offset by half a tile so corners meet at logic-cell centers. Marching Squares renders on the same grid as the logic. Same atlas image, different paint position.

For TetraTile this is essentially "Dual-Grid 16 with `visual_layer_offset = (0, 0)`."

### Wang 2-Edge (16 tiles)

**Mask:** 4-bit edge (N/S/E/W). **Tile count:** 16. **Atlas:** 4×4 grid in NESW-bit order.

```
4×4 grid (mask bits: N=1, E=2, S=4, W=8 — CR31 standard):

┌────┬────┬────┬────┐
│ 0  │ 1  │ 2  │ 3  │   N off,  N on,  E on, NE on
│none│  N │  E │ NE │
├────┼────┼────┼────┤
│ 4  │ 5  │ 6  │ 7  │   S on, NS on, ES on, NES on
│  S │ NS │ ES │NES │
├────┼────┼────┼────┤
│ 8  │ 9  │10  │11  │   W on, NW on, EW on, NEW on
│  W │ NW │ EW │NEW │
├────┼────┼────┼────┤
│12  │13  │14  │15  │   SW, NSW, ESW, all
│ SW │NSW │ESW │all │
└────┴────┴────┴────┘

Use case: roads, fences, paths, platforms — anything where
the SHAPE of the connection matters more than the corners.
```

### Wang 2-Corner (= Marching Squares, different label)

**Mask:** 4-bit corner (NE/SE/SW/NW). **Tile count:** 16. **Atlas:** 4×4 in NE/SE/SW/NW-bit order.

Same math as marching squares. Just laid out cardinally:

```
4×4 grid (mask bits: NE=1, SE=2, SW=4, NW=8 — CR31 standard):

┌────┬────┬────┬────┐
│ 0  │ 1  │ 2  │ 3  │
├────┼────┼────┼────┤
│ 4  │ 5  │ 6  │ 7  │
├────┼────┼────┼────┤
│ 8  │ 9  │10  │11  │
├────┼────┼────┼────┤
│12  │13  │14  │15  │
└────┴────┴────┴────┘

Note the bits are rotated 45° from marching-squares-style
(TL/TR/BL/BR) but the count and meaning are equivalent.
```

**Tilesetter calls this "Wang Set" in its export.** The 16-tile output is a 4×4 in this order.

### Blob / 47-Tile

**Mask:** 8-bit Moore (edges + corners) with corner-gating reduction → 47 valid states. **Tile count:** 47.

There are **two atlas conventions in active use**, and they're NOT interchangeable:

```
Tilesetter convention — 7×8 grid (9 cells unused):

┌────┬────┬────┬────┬────┬────┬────┐
│ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │ 7  │
├────┼────┼────┼────┼────┼────┼────┤
│ 8  │ 9  │10  │11  │12  │13  │14  │
├────┼────┼────┼────┼────┼────┼────┤
│15  │16  │17  │18  │19  │20  │21  │
├────┼────┼────┼────┼────┼────┼────┤
│22  │23  │24  │25  │26  │27  │28  │
├────┼────┼────┼────┼────┼────┼────┤
│29  │30  │31  │32  │33  │34  │35  │
├────┼────┼────┼────┼────┼────┼────┤
│36  │37  │38  │39  │40  │41  │42  │
├────┼────┼────┼────┼────┼────┼────┤
│43  │44  │45  │46  │47  │ ✗  │ ✗  │   ← last 3 unused
├────┼────┼────┼────┼────┼────┼────┤
│ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │ ✗  │   ← all unused
└────┴────┴────┴────┴────┴────┴────┘

Excalibur.js / jaconir convention — 12×4 grid (one cell unused):

┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
│ 0  │ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │ 7  │ 8  │ 9  │ 10 │ 11 │
├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
│ 12 │ 13 │ 14 │ 15 │ 16 │ 17 │ 18 │ 19 │ 20 │ 21 │ 22 │ 23 │
├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
│ 24 │ 25 │ 26 │ 27 │ 28 │ 29 │ 30 │ 31 │ 32 │ 33 │ 34 │ 35 │
├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
│ 36 │ 37 │ 38 │ 39 │ 40 │ 41 │ 42 │ 43 │ 44 │ 45 │ 46 │ ✗  │
└────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
```

**The 47 tiles are the same set of visual shapes in both conventions.** What differs is *which mask value lives in which atlas slot.* That mapping is what each `TetraTileLayoutBlob47*` Resource will encode.

> **Honest gap:** the research did not enumerate the slot-by-slot mapping for either convention. That comes when implementing each layout Resource — paint a known fingerprint atlas in Tilesetter / Excalibur, observe which mask lands in which slot, codify.

### Sub-Blob 20 (quarter-tile)

**Mask:** subtile composition. **Tile count:** 20 quarter-tile pieces (composed at runtime into all 47 blob shapes). **Atlas:** tool-specific.

Different paradigm. Each *visual* tile is built from 4 quarter-tile pieces drawn from the source. RPG Maker A2 and Blobator both consume this. Out of scope until v0.3+; flagged as architecturally supported in [MASK_UNIFICATION.md](MASK_UNIFICATION.md).

### RPG Maker A1 / A2 / A3 / A4 / A5

Fundamentally different paradigm — *not* a mask-driven tile selector. Listed for completeness only.

| Sheet | Purpose | Atlas size | Mechanic |
|---|---|---|---|
| A1 | Animated water/lava | 768×576 | Sub-blob with 3 animation frames |
| A2 | Ground autotile | 768×576 | Sub-blob (quarter-tile composition) |
| A3 | Building roof+wall pairs | 768×384 | Whole-tile pairs; not really autotiling |
| A4 | Wall autotile (top + side) | 768×720 | Two compositors stacked |
| A5 | Normal tiles | 384×768 | No autotiling at all |

**RPG Maker is deferred to v0.3+** because supporting A2/A4 means writing a quarter-sample compositor, not a mask-to-tile selector. The architecture in [MASK_UNIFICATION.md](MASK_UNIFICATION.md) leaves a slot for it but doesn't implement it.

---

## Wang vs Dual-Grid 16 — The Question You Asked

Both layouts have **16 tiles** and **4-bit masks**. The differences are in mask system, what each bit means, and atlas ordering.

| Axis | Dual-Grid 16 | Wang 2-Edge | Wang 2-Corner |
|---|---|---|---|
| Mask system | 4-bit **corner** | 4-bit **edge** | 4-bit **corner** |
| What each bit reads | Logic cells at the 4 corners of the visual cell | Neighbor cells at N/S/E/W | Neighbor cell corners at NE/SE/SW/NW |
| Sample direction | "Look at the four logic cells around me" | "Look at the four neighbors next to me" | "Look at the four corners of my neighbors' overlap zone" |
| Use case | Pixel-art autotiling, terrain | Roads, fences, paths | Same as Dual-Grid (mathematically identical) |
| Render position | Visual layer offset by **half a tile** | Same grid as logic | Same grid as logic |
| Atlas grid | 4×4 (or 16×1 strip) | 4×4 in NESW-bit order | 4×4 in NE/SE/SW/NW-bit order |
| Bit numbering canonical? | **No** — every implementation picks one | Yes (CR31 N=1, E=2, S=4, W=8) | Yes (CR31 NE=1, SE=2, SW=4, NW=8) |
| Tile count | 16 unique | 16 unique | 16 unique |

**Practical "what does my image look like":** all three are 4×4 grids of 16 tiles. The art differs because each system reads neighbor data differently, but the atlas SHAPE is the same.

The pivotal practical difference is **what the 16 tiles depict**:
- **Dual-Grid 16** — each tile shows a piece of terrain that lives at the *intersection* of 4 logic cells. Tile at mask 15 is "all 4 logic cells filled" (solid terrain). Tile at mask 0 is "all 4 logic cells empty" (you'd never paint this; it's the background).
- **Wang 2-Edge** — each tile shows what its 4 *edges* connect to. Tile at mask 15 shows all 4 edges connected. Tile at mask 0 shows a fully-isolated piece (e.g., a road segment that connects to nothing on any side).
- **Wang 2-Corner** — same idea as Dual-Grid 16, but bits are labeled cardinally.

---

## Tilesetter vs Godot — Same Mask, Different Slot Order

This was your other question. Both Tilesetter and Godot's terrain system support the **same mask systems** (corner / edge / mixed), but they store atlas data **differently**.

| Aspect | Tilesetter (Wang 16 export) | Godot Match Corners | Compatible? |
|---|---|---|---|
| Mask system | 4-bit edge | 4-bit corner peering | **No — different mask** (Tilesetter Wang is edge; Godot Match Corners is corner) |
| Tile count | 16 | up to 16 | Yes |
| Slot order | Vendor-defined (4×4 in NESW-bit-order) | None — peering bits stored per-tile in `.tres` | Tilesetter's order is fixed; Godot's is metadata-driven |
| Authoring | Tilesetter generates the atlas | Author paints peering bits per tile in TileSet inspector | Tilesetter eliminates the manual authoring; Godot requires it |

| Aspect | Tilesetter (Blob 47 export) | Godot Match Corners and Sides | Compatible? |
|---|---|---|---|
| Mask system | 8-bit Moore with corner-gating (47 reachable) | 8-bit Moore peering | **Yes** — same mask |
| Tile count | 47 | up to 47 (engineering limit 256) | Yes |
| Slot order | 7×8 grid, vendor-defined order | None — peering bits per tile | Tilesetter's order is fixed; Godot's is metadata-driven |
| Authoring | Tilesetter generates the atlas | 376 clicks per blob terrain to author peering bits | Tilesetter wins on UX |

**The headline:** Tilesetter and Godot agree on the *mask system* for Blob 47, but Godot doesn't impose a slot order — every tile has its own peering metadata. Tilesetter's 7×8 slot order IS the atlas order; Godot doesn't care about your atlas order, only your peering bits.

For TetraTile, this means:
- A `TetraTileLayoutTilesetterBlob47` Resource is feasible: read slot N, look up the corresponding mask, paint it.
- A `TetraTileLayoutGodotBlob47` Resource is NOT meaningful — Godot's "layout" is whatever the author decides, with bits stored as metadata. You'd need to read the TileSet's peering bits at runtime, which is essentially re-implementing Godot's terrain system. Out of scope per [MASK_UNIFICATION.md](MASK_UNIFICATION.md) (Approach B explicitly rejects this).

**Tilesetter's Godot export pre-configures Godot's peering bits.** So a Tilesetter Blob 47 atlas plugged into Godot's stock terrain system "just works" — but at that point you don't need TetraTile. TetraTile's value is the alternative: skip the peering-bits authoring entirely, attach a layout Resource, done.

---

## Tiled & LDtk — Why They Don't Fit the Same Pattern

Both editors store autotile rules in their **project file**, not in the atlas image. This makes them fundamentally different from Tilesetter / Tetra / Dual-Grid 16.

### Tiled Map Editor

- **What's in the atlas image:** whatever the artist wants. No fixed slot order.
- **What's in the `.tsx` / `.tmx`:** per-tile `wangid` metadata mapping each atlas slot to an 8-tuple of color indices `(top, top-right, right, bottom-right, bottom, bottom-left, left, top-left)`.
- **Mask system:** Edge / Corner / Mixed (configurable per Wang Set in the editor).
- **Up to 254 colors per set** (= multi-terrain natively).

To support a Tiled atlas drop-in, TetraTile would need a `.tsx` parser that reads `wangid` records and translates them into a TetraTile mask lookup. That's a **rule-importer** feature, not a layout-Resource feature. Out of scope.

**Note:** if someone authors their atlas in Tiled but uses a *known fixed convention* (e.g., they happened to lay out tiles in CR31's 4×4 NESW order), that's actually the Wang 2-Edge layout. They'd attach `TetraTileLayoutWang2Edge` and it would work. But that's a coincidence of layout, not Tiled compatibility per se.

### LDtk

- **What's in the atlas image:** whatever the artist wants. No fixed slot order.
- **What's in the `.ldtk` JSON:** rule patterns (1×1 / 3×3 / 5×5 / 7×7 grids of "this neighborhood paints this tile") with rich modifiers — modulo gating, perlin gating, break-on-match, etc.
- **Mask system:** generalized pattern matching. Strictly more expressive than corner/edge masks. Rules can express things bitmasks can't (e.g., "paint X if 5 cells away is a wall").

To support an LDtk atlas drop-in, TetraTile would need a `.ldtk` rule parser AND a runtime that can evaluate LDtk rule patterns. That's a much bigger feature than a layout Resource.

**Note:** LDtk's "Quick Rules" templates (1.2.0+) generate auto-rules from a fixed-shape user-painted layout. If those layouts match Wang or Blob conventions, the user can take the LDtk-painted atlas and attach the matching TetraTile layout Resource. Same coincidence-of-layout argument as Tiled.

### Verdict

**Tiled and LDtk drop-in support is out of scope.** What IS in scope: documenting that *if* a user authors their atlas in those tools using a layout convention TetraTile supports (Wang 2-Edge, Wang 2-Corner, Blob 47, Dual-Grid 16, Tetra), they can attach the matching Resource and use the atlas image. They lose the editor's rule magic but gain TetraTile's autotiling.

---

## Godot Native Terrain Modes — Where They Fit

| Mode | Mask system | Equivalent layout |
|---|---|---|
| `MATCH_CORNERS_AND_SIDES` | 8-bit Moore, peering-per-tile | Topologically Blob 47 |
| `MATCH_CORNERS` | 4-bit corner peering | Topologically Wang 2-Corner / Marching Squares |
| `MATCH_SIDES` | 4-bit edge peering (disputed; see Godot issue [#79411](https://github.com/godotengine/godot/issues/79411)) | Topologically Wang 2-Edge |

Each Godot mode uses **per-tile peering bit metadata** rather than fixed atlas slots. A user who has an atlas with peering bits already authored doesn't need TetraTile — they're using Godot's stock pipeline. TetraTile's value proposition is the OPPOSITE: skip the peering-bits step, ship a layout Resource that maps slot → mask once, and never author per-tile metadata.

This is why [GODOT_TERRAIN.md](GODOT_TERRAIN.md) recommends *not* integrating with Godot's terrain system. Doing so would defeat the v0.1 selling point of "no manual bitmask authoring."

---

## Recommended v0.2 Layout Library

Based on the research, the recommended built-in library:

| Resource class | Mask | Tile count | Atlas |
|---|---|---|---|
| `TetraTileLayoutTetraHorizontal` | corner (rotation reuse) | 4 | 4×1 |
| `TetraTileLayoutTetraVertical` | corner (rotation reuse) | 4 | 1×4 |
| `TetraTileLayoutDualGrid16` | corner | 16 | 4×4 |
| `TetraTileLayoutWang2Edge` | edge | 16 | 4×4 (NESW-bit) |
| `TetraTileLayoutWang2Corner` | corner | 16 | 4×4 (NE/SE/SW/NW-bit) |
| `TetraTileLayoutBlob47Tilesetter` | Moore | 47 | 7×8 (Tilesetter slot order) |
| `TetraTileLayoutBlob47Excalibur` | Moore | 47 | 12×4 (jaconir / Excalibur slot order) |

**Deferred to v0.3+:**

| Resource | Reason |
|---|---|
| `TetraTileLayoutSubBlob20` | Quarter-tile composition pipeline not in v0.2 |
| `TetraTileLayoutMicroBlob13` | Same |
| `TetraTileLayoutRPGMakerA2` | Subtile compositor not in v0.2 |
| `TetraTileLayoutRPGMakerA4` | Same |
| Tiled `.tsx` importer | Rule-importer, not layout Resource |
| LDtk `.ldtk` importer | Rule-importer + rule runtime |

**Out of scope indefinitely:**

| Item | Reason |
|---|---|
| Godot Native Terrain integration | Defeats the "no manual bitmask authoring" selling point |
| Multi-terrain Wang (3+ terrains per atlas) | PROJECT.md identity guardrail rules out multi-terrain |

---

*Reference compiled: 2026-04-25 from TAXONOMY.md, EDITORS.md, GODOT_TERRAIN.md, MASK_UNIFICATION.md.*

---

## Corrections Log (2026-04-25)

After publishing this file, two follow-up audits ([`TILESETTER_AND_GODOT.md`](TILESETTER_AND_GODOT.md) and [`TILEBITTOOLS.md`](TILEBITTOOLS.md)) corrected several claims in the sections above. The corrections are recorded here rather than rewritten inline so the original reasoning trail is preserved.

### Tilesetter Wang is 15 tiles, not 16

The "Tilesetter Wang Set = 16 tiles" claim came from secondary sources. TileBitTools' MIT-licensed `tilesetter_wang.tres` (which encodes Tilesetter's actual export) shows **15 tiles in a 5×3 atlas**, with the "stray fill tile" handled separately. The new layout-library naming reflects this: `TetraTileLayoutTilesetterWang15`.

### Tilesetter Blob is 11×5 with sub-block gaps, not 7×8

The "Tilesetter Blob = 7×8 grid with 9 trailing unused cells" diagram in this file was wrong — it was inferred from CR31's reference, not from Tilesetter's actual output. TBT's `tilesetter_blob.tres` confirms an **11-column × 5-row layout with discrete sub-block gaps** (matching the user's reference images). The exact slot diagram is in [`TILEBITTOOLS.md`](TILEBITTOOLS.md).

### Tilesetter slot tables are no longer "pending empirical fingerprinting"

This file said: *"Slot-to-mask mapping is empirical. The exact mapping for each of the 47 slots requires painting a fingerprint atlas in Tilesetter and observing which mask lands where."* That step is no longer needed — TileBitTools has already decoded both Tilesetter slot tables under the MIT license. TetraTile transcribes them with attribution rather than re-fingerprinting.

### Drop Excalibur/jaconir Blob 47

The user's pivot is "support what people actually use in Godot." Excalibur is a JavaScript engine; the jaconir convention is web-game indie. Neither has meaningful Godot adoption. **Excalibur/jaconir is removed from the layout library.**

### Drop Stormcloak / OpenGameArt CR31 community Blob variants

Lower-traffic conventions with no demonstrated Godot adoption. Removed from the library.

### Locked: Godot Blob 47 = TileBitTools convention

The "Godot community blob template" the user referred to is the TileBitTools convention. Renamed: `TetraTileLayoutBlob47Godot` (was previously `Blob47GodotCommunity`).

### Match Sides skipped

Godot's `MATCH_SIDES` mask semantics are disputed in the engine ([issue #79411](https://github.com/godotengine/godot/issues/79411)). Skipped for v0.2; documented as such.

### RPG Maker A1/A2/A3/A4 deferred

Subtile composition pipeline doesn't fit the unified `_update_cells` dispatch. Architecturally reserved for v0.3+ per [`MASK_UNIFICATION.md`](MASK_UNIFICATION.md). No change from earlier — included here for completeness.

### Final v0.2 layout-library lineup (after corrections)

| Resource | Source | Tile count | Atlas shape |
|---|---|---|---|
| `TetraTileLayoutTetraHorizontal` | TetraTile native (v0.1 inheritance) | 4 | 4×1 |
| `TetraTileLayoutTetraVertical` | TetraTile native | 4 | 1×4 |
| `TetraTileLayoutDualGrid16` | TetraTile native | 16 | 4×4 |
| `TetraTileLayoutWang2Edge` | CR31 standard | 16 | 4×4 NESW |
| `TetraTileLayoutWang2Corner` | CR31 standard | 16 | 4×4 NE/SE/SW/NW |
| `TetraTileLayoutBlob47Godot` | decoded from TileBitTools (MIT, attributed) | 47 | TBT convention |
| `TetraTileLayoutTilesetterWang15` | decoded from TileBitTools `tilesetter_wang.tres` | 15 | 5×3 + stray fill |
| `TetraTileLayoutTilesetterBlob47` | decoded from TileBitTools `tilesetter_blob.tres` | 47 | 11×5 with gaps |

Each Resource also carries a `template_image: Texture2D`, a `fallback_tile_set: TileSet`, and a `description: String` for inspector hinting (per the v0.2 design).

---

*Corrections appended: 2026-04-25 after TILESETTER_AND_GODOT.md and TILEBITTOOLS.md audits.*
