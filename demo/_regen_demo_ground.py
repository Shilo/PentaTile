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
    """Slot 0 — OuterCorner piece (BL quadrant of the silhouette).

    Per Phase 2 design: slot 0 stores ONE quadrant of the silhouette; the dispatcher
    rotates it 4 ways to produce the 4 outer-corner orientations. When the 4 display
    cells around a single painted logic cell render rotations of this piece, the
    quadrants tile into a coherent isolated-cell silhouette.

    Canonical _ROTATE_0 = BL-quadrant content. The other 3 quadrants of the tile
    must be transparent so rotated copies don't overdraw each other."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    half = TILE // 2  # 8 for TILE=16
    # BL quadrant: x ∈ [0, half), y ∈ [half, TILE)
    bl_x0 = x0
    bl_y0 = y0 + half
    bl_x1 = x0 + half
    bl_y1 = y0 + TILE
    _stippled_fill(draw, bl_x0, bl_y0, bl_x1, bl_y1)
    # Orange wires only on the silhouette OUTER edges of this quadrant (T-edge of the
    # BL quadrant is interior to the silhouette = no wire; L+B edges are silhouette
    # boundaries = orange wire). The R-edge (interior boundary between BL and BR
    # quadrants) is internal to the silhouette = no wire. Wait — for an ISOLATED
    # cell, ALL 4 silhouette edges show wires. The BL quadrant's silhouette-facing
    # edges are L and B. The other two edges (T and R) face the silhouette interior
    # in a multi-cell painted area but are exposed in a single isolated cell.
    # Convention: draw wires on L+B (always-silhouette boundaries for this quadrant).
    # T+R get no wires so multi-tile painted areas (Fill, Border, etc) don't show
    # weird internal lines where quadrants meet.
    _orange_border(draw, bl_x0, bl_y0, bl_x1, bl_y1, "LB")


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
