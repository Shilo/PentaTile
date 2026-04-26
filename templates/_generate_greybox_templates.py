"""Generate greyboxed silhouette template PNGs for each PentaTile layout.

Run with: python addons/penta_tile/templates/_generate_greybox_templates.py

Produces transparent-background PNGs where each slot is filled with a grey
silhouette indicating which logic-cell quadrants (corner masks) or edge
connections (edge masks) the slot represents. Slot boundaries are marked
with a 1-px dark grey outline. Artists paint over these silhouettes; the
shapes are purely a visual hint for "what does this slot need to look like."

Mask conventions LOCKED here (also documented in templates/README.md):
- Corner masks (Penta / DualGrid16 / Wang2Corner): TL=1, TR=2, BL=4, BR=8
- Edge masks (Wang2Edge): N=1, E=2, S=4, W=8 (CR31 standard)

This script is committed alongside the generated PNGs so anyone can
regenerate / tweak the greyboxes without reverse-engineering pixel data.
"""
from PIL import Image, ImageDraw
from pathlib import Path

TILE = 16  # pixels per tile (matches v0.1 demo)
GREY = (136, 136, 136, 255)        # #888 mid-grey fill
OUTLINE = (68, 68, 68, 255)        # #444 dark grey outline
HINT = (170, 170, 170, 255)        # #aaa light grey for the always-on center hint
TRANSPARENT = (0, 0, 0, 0)

OUT_DIR = Path(__file__).parent


def new_atlas(cols: int, rows: int) -> Image.Image:
    """Blank transparent atlas of the requested tile dimensions."""
    return Image.new("RGBA", (cols * TILE, rows * TILE), TRANSPARENT)


def draw_slot_outline(draw: ImageDraw.ImageDraw, col: int, row: int) -> None:
    """1-px dark outline around a slot."""
    x0, y0 = col * TILE, row * TILE
    x1, y1 = x0 + TILE - 1, y0 + TILE - 1
    draw.rectangle((x0, y0, x1, y1), outline=OUTLINE, width=1)


def draw_corner_mask(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Fill quadrants of slot (col, row) per a corner mask.

    Bits: TL=1, TR=2, BL=4, BR=8.
    """
    x0, y0 = col * TILE, row * TILE
    half = TILE // 2
    # quadrant rectangles: (bit, x0, y0, x1, y1)
    quads = [
        (1, x0, y0, x0 + half - 1, y0 + half - 1),               # TL
        (2, x0 + half, y0, x0 + TILE - 1, y0 + half - 1),         # TR
        (4, x0, y0 + half, x0 + half - 1, y0 + TILE - 1),         # BL
        (8, x0 + half, y0 + half, x0 + TILE - 1, y0 + TILE - 1),  # BR
    ]
    for bit, qx0, qy0, qx1, qy1 in quads:
        if mask & bit:
            draw.rectangle((qx0, qy0, qx1, qy1), fill=GREY)


def draw_edge_mask(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Plus-sign silhouette per an edge mask: center hint + arms.

    Bits: N=1, E=2, S=4, W=8.
    """
    x0, y0 = col * TILE, row * TILE
    cx0, cy0 = x0 + 6, y0 + 6
    cx1, cy1 = x0 + 9, y0 + 9
    # always-on center hint so empty masks still show something
    draw.rectangle((cx0, cy0, cx1, cy1), fill=HINT)
    # arms — 4×6 stubs from center to each edge
    if mask & 1:  # N
        draw.rectangle((cx0, y0, cx1, cy1), fill=GREY)
    if mask & 2:  # E
        draw.rectangle((cx0, cy0, x0 + TILE - 1, cy1), fill=GREY)
    if mask & 4:  # S
        draw.rectangle((cx0, cy0, cx1, y0 + TILE - 1), fill=GREY)
    if mask & 8:  # W
        draw.rectangle((x0, cy0, cx1, cy1), fill=GREY)


# ---- Layouts -------------------------------------------------------------

def gen_penta_horizontal() -> Image.Image:
    """4×1 strip — Fill / Inner Corner / Border / Outer Corner (v0.1 default)."""
    img = new_atlas(4, 1)
    draw = ImageDraw.Draw(img)
    archetypes = [
        15,  # Fill — all 4 corners filled
        7,   # Inner Corner — TL+TR+BL filled, BR empty (3-of-4)
        3,   # Border — TL+TR filled (top half)
        1,   # Outer Corner — TL only
    ]
    for col, mask in enumerate(archetypes):
        draw_corner_mask(draw, col, 0, mask)
        draw_slot_outline(draw, col, 0)
    return img


def gen_penta_vertical() -> Image.Image:
    """1×4 strip — same archetypes, stacked."""
    img = new_atlas(1, 4)
    draw = ImageDraw.Draw(img)
    archetypes = [15, 7, 3, 1]
    for row, mask in enumerate(archetypes):
        draw_corner_mask(draw, 0, row, mask)
        draw_slot_outline(draw, 0, row)
    return img


def gen_dual_grid_16() -> Image.Image:
    """4×4 grid — slot index = mask value (0..15) reading L→R, T→B."""
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for mask in range(16):
        col, row = mask % 4, mask // 4
        draw_corner_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img


def gen_wang_2corner() -> Image.Image:
    """4×4 grid — same silhouettes as DualGrid16; only the bit names differ.

    NE=1, SE=2, SW=4, NW=8 (CR31). Visually identical to DualGrid16's
    TL=1/TR=2/BL=4/BR=8 because both are corner masks.
    """
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for mask in range(16):
        col, row = mask % 4, mask // 4
        draw_corner_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img


def gen_wang_2edge() -> Image.Image:
    """4×4 grid — slot index = mask value (0..15) reading L→R, T→B."""
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for mask in range(16):
        col, row = mask % 4, mask // 4
        draw_edge_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img


# ---- Main ----------------------------------------------------------------

def main() -> None:
    outputs = {
        "penta_horizontal.png": gen_penta_horizontal(),
        "penta_vertical.png": gen_penta_vertical(),
        "dual_grid_16.png": gen_dual_grid_16(),
        "wang_2corner.png": gen_wang_2corner(),
        "wang_2edge.png": gen_wang_2edge(),
    }
    for name, img in outputs.items():
        path = OUT_DIR / name
        img.save(path, "PNG")
        print(f"wrote {path.name}  {img.size[0]}x{img.size[1]} px")


if __name__ == "__main__":
    main()
