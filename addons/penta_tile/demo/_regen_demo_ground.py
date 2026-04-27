"""Regenerate addons/penta_tile/demo/penta_tile_ground.png to match Phase 2's
new Penta slot ordering: 0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner.

Keeps the demo's distinctive teal-rock + orange-wire aesthetic. Each tile is 16x16.
Output strip is 64x16 (4 tiles horizontal).

Run:
  python addons/penta_tile/demo/_regen_demo_ground.py
"""

from PIL import Image, ImageDraw
from pathlib import Path

TILE = 16
COLS = 4
ROWS = 1

# Demo aesthetic palette (eyeballed from the user's screenshot — dark teal stone
# with orange highlights).
TRANSPARENT = (0, 0, 0, 0)
STONE_DARK  = (60, 75, 80, 255)
STONE_MID   = (90, 105, 110, 255)
STONE_LIGHT = (130, 140, 145, 255)
ORANGE      = (240, 165, 60, 255)
ORANGE_DARK = (200, 130, 30, 255)


def _stippled_fill(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    """Fill rect with mid stone + light dots + orange specks (matches user's screenshot
    aesthetic). Reproducible — uses position parity, not random."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            # Stippled stone base
            base = STONE_DARK if (x + y) % 3 == 0 else STONE_MID
            if (x * 7 + y * 11) % 13 == 0:
                base = STONE_LIGHT
            # Sparse orange specks
            if (x * 5 + y * 3) % 19 == 0:
                base = ORANGE_DARK
            draw.point((x, y), fill=base)


def _orange_border(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, sides: str) -> None:
    """Draw an orange wire on selected sides (subset of 'TBLR'). Inset by 1px so the
    wire reads as inside-edge highlight, not outer outline."""
    if "T" in sides:
        for x in range(x0 + 1, x1 - 1):
            draw.point((x, y0 + 1), fill=ORANGE)
    if "B" in sides:
        for x in range(x0 + 1, x1 - 1):
            draw.point((x, y1 - 2), fill=ORANGE)
    if "L" in sides:
        for y in range(y0 + 1, y1 - 1):
            draw.point((x0 + 1, y), fill=ORANGE)
    if "R" in sides:
        for y in range(y0 + 1, y1 - 1):
            draw.point((x1 - 2, y), fill=ORANGE)


def draw_isolated_cell(img: Image.Image, col: int) -> None:
    """Slot 0 — IsolatedCell. Authored as ONLY the BL-quadrant outer-corner art
    so the OuterCorner-via-rotation dispatch (masks 1/2/4/8 → slot 0 + ROTATE_*)
    places the corner art at the correct corner of each display cell. The other
    3 quadrants are fully transparent — rotated copies don't overdraw each other
    when 4 display cells render around a single painted logic cell, so the 4
    rotations compose to form ONE coherent silhouette of the painted cell.

    Anchoring derivation (16x16 tile, slot 0 = BL quadrant filled at pixels
    x:0-7, y:8-15):
      - ROTATE_0 (mask 4 / BL bit set, cell south of painted cell): BL → BL of
        cell. Lands at the cell's BL corner = the corner adjacent to the
        painted cell's lower-left visual.
      - ROTATE_90 (mask 1, cell SE of painted): BL → TL of cell. Lands at the
        cell's TL corner = adjacent to the painted cell's upper-left visual.
      - ROTATE_180 (mask 2, cell SW of painted): BL → TR of cell. Lands at the
        cell's TR corner = adjacent to the painted cell's upper-right visual.
      - ROTATE_270 (mask 8, cell NW of painted): BL → BR of cell. Lands at the
        cell's BR corner = adjacent to the painted cell's lower-right visual.
    All 4 corner pieces meet at the painted cell's center → coherent silhouette.

    Tradeoff (Gate 1 documented escape hatch — see 02-02-PLAN.md:134):
    slot 4 OppositeCorners synthesis (FOUR mode) extracts TL+BR quadrants of
    slot 0, which are now transparent. Masks 6 and 9 (diagonal-only
    OppositeCorners) will render empty in the demo. Acceptable — diagonal-only
    paints are rare in the demo's terrain layout. Artists who need pixel-perfect
    OppositeCorners can author slot 4 explicitly via FIVE-mode atlases.

    The bundled greybox PNGs (addons/penta_tile/_generate_bitmasks.py) keep
    the full-silhouette slot 0 as the documentation reference; this faded
    variant is demo-specific."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    mid_x, mid_y = x0 + TILE // 2, y0 + TILE // 2
    bl_x1, bl_y1 = mid_x, y0 + TILE
    # BL quadrant only — TL/TR/BR stay transparent.
    _stippled_fill(draw, x0, mid_y, bl_x1, bl_y1)
    # Orange wires on the L and B sides of the BL quadrant — these become the
    # outer perimeter of the composed silhouette under rotation+tiling.
    _orange_border(draw, x0, mid_y, bl_x1, bl_y1, "LB")


def draw_fill(img: Image.Image, col: int) -> None:
    """Slot 1 — Fill. Solid stippled rect, no edges (fully surrounded)."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    _stippled_fill(draw, x0, y0, x1, y1)


def draw_border(img: Image.Image, col: int) -> None:
    """Slot 2 — Border. Canonical orientation = ROTATE_0 = mask 12 (BL+BR)
    (per penta_tile_layout_penta.gd: mask 12 → SLOT_BORDER, ROTATE_0).
    That means the BOTTOM half is filled stone with the TOP transparent —
    a horizontal edge facing up."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    mid_y = y0 + TILE // 2
    _stippled_fill(draw, x0, mid_y, x1, y1)
    _orange_border(draw, x0, mid_y, x1, y1, "T")


def draw_inner_corner(img: Image.Image, col: int) -> None:
    """Slot 3 — InnerCorner. Canonical orientation = ROTATE_0 = mask 13 (TL+BL+BR)
    (per penta_tile_layout_penta.gd: mask 13 → SLOT_INNER_CORNER, ROTATE_0).
    That means the TOP-RIGHT quadrant is empty; the L-shape (TL + BL + BR) is filled."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    mid_x, mid_y = x0 + TILE // 2, y0 + TILE // 2
    # TL quadrant
    _stippled_fill(draw, x0, y0, mid_x, mid_y)
    # BL quadrant
    _stippled_fill(draw, x0, mid_y, mid_x, y1)
    # BR quadrant
    _stippled_fill(draw, mid_x, mid_y, x1, y1)
    # Orange wire around the inner corner (top-right cutout)
    for x in range(mid_x, x1 - 1):
        draw.point((x, mid_y), fill=ORANGE)
    for y in range(y0 + 1, mid_y):
        draw.point((mid_x, y), fill=ORANGE)


def main() -> None:
    out_path = Path(__file__).parent / "penta_tile_ground.png"
    img = Image.new("RGBA", (COLS * TILE, ROWS * TILE), TRANSPARENT)

    draw_isolated_cell(img, 0)
    draw_fill(img, 1)
    draw_border(img, 2)
    draw_inner_corner(img, 3)

    img.save(out_path)
    print(f"wrote {out_path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
