# TetraTile Atlas Templates

Greyboxed reference templates for every layout TetraTile supports. Open one in your art tool, paint over the silhouettes, save the result as your tileset image.

> Templates land as part of the v0.2.0 milestone. The v0.1.0 reference template at [`addons/tetra_tile/tetra_tile_template.png`](../tetra_tile_template.png) will be deprecated in favor of [`tetra_horizontal.png`](tetra_horizontal.png) here.

For the *why* and *when to pick what*, see [`.planning/research/layouts/COMPARISON.md`](../../../.planning/research/layouts/COMPARISON.md). This file is the artist-facing reference: dimensions, slot grid, what each silhouette represents.

## What "Greybox" Means Here

Each shipped template is a transparent-background PNG where every slot is filled with a mid-grey silhouette indicating *which logic-cell quadrants* (corner masks) or *which edge connections* (edge masks) that slot represents. Slot boundaries are marked with a 1-px dark grey outline.

The silhouettes are not art — they're a visual hint for "what shape does this slot need." Paint over them.

Color palette:

| Element | Color | Purpose |
|---|---|---|
| Background | transparent | so over-paint composes cleanly |
| Silhouette fill | `#888888` | indicates "this region of the slot should be terrain" |
| Slot outline | `#444444` | 1-px slot boundary so the grid stays visible |
| Center hint (edge masks) | `#aaaaaa` | always-on dot in the middle so empty masks aren't fully transparent |

## Shipped Templates (v0.2.0)

```text
addons/tetra_tile/templates/
  README.md                       # this file
  _generate_greybox_templates.py  # Python+PIL script that produces every PNG below
  tetra_horizontal.png            # 4×1 strip, 64×16 px, 4 archetypes
  tetra_vertical.png              # 1×4 strip, 16×64 px, 4 archetypes
  dual_grid_16.png                # 4×4 grid, 64×64 px, 16 corner-mask silhouettes
  wang_2corner.png                # 4×4 grid, 64×64 px, 16 corner-mask silhouettes (cardinal naming)
  wang_2edge.png                  # 4×4 grid, 64×64 px, 16 edge-mask silhouettes
```

## Pending Templates

The Blob 47 family ships when we transcribe TileBitTools' `tilesetter_blob.tres` and the matching Godot template `.tres` files into TetraTile's slot-to-mask lookup tables (TBT is MIT-licensed; we attribute and decode). Until those tables are pinned down, painting over a guessed slot order would produce non-working atlases — so we hold the templates rather than ship misleading placeholders.

```text
  blob_47_godot.png               # ~256-cell template, TBT Godot convention — pending
  blob_47_tilesetter.png          # 11×5 with discrete sub-block gaps — pending
```

Tilesetter Blob is **NOT** the 7×8 grid an earlier draft of this README claimed. Per the [`TILESETTER_AND_GODOT.md`](../../../.planning/research/layouts/TILESETTER_AND_GODOT.md) and [`TILEBITTOOLS.md`](../../../.planning/research/layouts/TILEBITTOOLS.md) audits, Tilesetter ships an 11-column × 5-row layout with discrete sub-block gaps (matching the user's reference images). Tilesetter Wang is **15 tiles, not 16** (5×3 with one stray fill). Both diagrams will land alongside the PNG templates when we transcribe TBT's slot tables.

```text
Future (deferred to v0.3+):
  sub_blob_20.png                 # 20-tile quarter-tile sub-blob
  micro_blob_13.png               # 13-tile quarter-tile micro-blob
  rpg_maker_a2.png                # 768×576 RPG Maker A2 ground (subtile compositor)
  rpg_maker_a4.png                # 768×720 RPG Maker A4 walls
```

## Mask Conventions (Locked)

These bit numberings are locked into the layout Resources and the greybox generator script. Don't change them without bumping the layout version.

**Corner masks** (Tetra / DualGrid16 / Wang2Corner):

```text
TL=1   TR=2
BL=4   BR=8

Mask = TL_filled + TR_filled*2 + BL_filled*4 + BR_filled*8
```

So slot `m=15` (all bits) = solid grey; `m=12` (BL+BR) = bottom half grey; `m=1` (TL only) = top-left quadrant grey.

**Wang 2-Corner names the same bits cardinally** (NE/SE/SW/NW per CR31), but the silhouettes are visually equivalent — TetraTile uses the TL/TR/BL/BR convention internally for the lookup table; the layout Resource translates Wang2Corner's NE/SE/SW/NW labels onto the same bit positions.

**Edge masks** (Wang2Edge):

```text
        N=1
   W=8       E=2
        S=4

Mask = N_connected + E_connected*2 + S_connected*4 + W_connected*8
```

So slot `m=15` (all edges) = full plus-sign extending to all 4 borders; `m=5` (N+S) = vertical bar; `m=10` (E+W) = horizontal bar; `m=0` (no edges) = small `#aaaaaa` center hint only.

## Tile Size Guidance

Templates ship at **16×16 px per tile**. To target a different tile size:

- **8×8 px:** scale down 2× nearest-neighbor before painting
- **32×32 px:** scale up 2× nearest-neighbor before painting
- **Other sizes:** the silhouettes are quadrant-aligned, so any power-of-two scale works cleanly

The `_generate_greybox_templates.py` script can be edited to change the `TILE = 16` constant and regenerate at any size.

## Per-Template Specs

### `tetra_horizontal.png` — 4×1 strip

Dimensions: **64 × 16 px** (4 tiles × 16 px wide). Mask system: 4-bit corner with rotation symmetry. Use case: minimal authoring.

```text
slot 0 (m=15)  slot 1 (m=7)   slot 2 (m=3)   slot 3 (m=1)
┌────┬────┬────┬────┐
│ ██ │ ██ │ ██ │ ▒  │
│ ██ │ █  │    │    │
└────┴────┴────┴────┘
 Fill  Inner  Border  Outer
       Corner         Corner
```

The other 12 mask states are produced by Godot's `TRANSFORM_FLIP_*` rotations of these 4 + the addon's overlay-layer trick for masks 6 and 9 (disconnected diagonals).

### `tetra_vertical.png` — 1×4 strip

Dimensions: **16 × 64 px**. Same archetypes as horizontal, stacked top-to-bottom in slot order.

### `dual_grid_16.png` — 4×4 grid

Dimensions: **64 × 64 px**. Mask system: 4-bit corner (no rotation reuse). Slot index = mask value reading L→R, T→B. So slot at column `c`, row `r` shows mask = `r*4 + c`.

```text
     col 0    col 1    col 2    col 3
row 0  m=0     m=1      m=2      m=3
row 1  m=4     m=5      m=6      m=7
row 2  m=8     m=9      m=10     m=11
row 3  m=12    m=13     m=14     m=15
```

Slot 0 (m=0) is empty by definition — the addon erases the visual cell when no logic corners are filled, so this slot is unused at runtime. The greybox shows it as transparent + outline only.

### `wang_2corner.png` — 4×4 grid

Dimensions: **64 × 64 px**. Mask system: 4-bit corner. **Same silhouettes as `dual_grid_16.png`** — only the bit naming differs (CR31 NE/SE/SW/NW vs TL/TR/BL/BR). Pick whichever Resource has the bit naming you prefer; the tiles are visually interchangeable if you remap the mask.

### `wang_2edge.png` — 4×4 grid

Dimensions: **64 × 64 px**. Mask system: 4-bit edge. Use case: roads, fences, paths, platforms — anything where the *line* of connection matters. Slot index = mask value (CR31 N=1/E=2/S=4/W=8) reading L→R, T→B.

```text
slot 0 (m=0)   slot 1 (m=1)   slot 2 (m=2)   slot 3 (m=3)
center hint    N stub          E stub          NE corner
              ↑                ↑               ↑
          (top arm)        (right arm)     (top + right)

slot 5 (m=5)   slot 10 (m=10)  slot 15 (m=15)
N+S = bar      E+W = bar       all 4 = full plus
```

## Authoring Workflow

1. **Pick a layout** by reading [COMPARISON.md](../../../.planning/research/layouts/COMPARISON.md).
2. **Open the matching template PNG** from this folder.
3. **Paint each slot** — replace the grey silhouettes with your art. The silhouette tells you which region of the tile should be the "terrain" terrain.
4. **Save your image** somewhere in your project (e.g. `addons/my_game/tilesets/grass.png`).
5. **In Godot**, create a `TileSet` resource with a `TileSetAtlasSource` pointing at your saved image.
6. **In your scene**, on the `TetraTileMapLayer` node:
   - Set `tile_set` to your TileSet (or leave null to use the layout's bundled fallback for prototyping)
   - Set `atlas_contract` to a `TetraTileAtlasContract` Resource with `layout` pointing at the matching `TetraTileLayoutXxx`
7. **Paint** with the standard `set_cell()` API or the editor brush. TetraTile picks the right tile from your atlas based on the layout Resource's slot-to-mask mapping.

No bitmask authoring per tile. No peering bits. Drop the atlas in, attach the layout, paint.

## Regenerating Templates

The greybox PNGs are produced by [`_generate_greybox_templates.py`](_generate_greybox_templates.py). To regenerate (e.g. after editing the script to change tile size or color palette):

```bash
python addons/tetra_tile/templates/_generate_greybox_templates.py
```

Requires Pillow (`pip install pillow`). The script is committed alongside the PNGs so anyone can tweak without reverse-engineering pixel data.

## Custom Layouts

Custom layouts are supported by subclassing `TetraTileLayout` and implementing `compute_mask()` + `mask_to_atlas()`. See [`MASK_UNIFICATION.md`](../../../.planning/research/layouts/MASK_UNIFICATION.md) for the architectural reference.

This is an experimental API — the built-in layouts in this folder are the supported surface.

---

*Templates spec: 2026-04-25. Greyboxes generated by `_generate_greybox_templates.py`. Blob 47 templates pending TBT slot-table transcription.*
