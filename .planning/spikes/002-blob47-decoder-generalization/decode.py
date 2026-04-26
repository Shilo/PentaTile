"""Spike 002 — generalize the template decoder to blob47 + dandeliondino color
encoding + arbitrary tile sizes.

Validates that the 8-anchor sampler (4 corners + 4 edges; center ignored) decodes:
- TetraTile's existing greyboxes (alpha-encoded, 16-px tiles, transparent BG)
- dandeliondino's terrain-set templates (color-encoded, 64-px tiles, white BG):
    * template_sides.png         (4×4, 16 edge masks)
    * template_corners.png       (4×4, 16 corner masks, connected layout)
    * template_corners_alt.png   (5×3, 15 corner masks, outside-corner layout)
    * template_corners_and_sides.png (12×4, 47 + 1 blank = 48 blob masks)

Locked rules from spike 001 (still used here):
- 3×3 majority vote at each anchor; 5+ of 9 votes = bit set
- Anchors placed geometrically inside the slot to avoid outline / grid-line pixels
- Layout subclass declares which subset of {TL, TR, BL, BR, T, E, B, W} are mask bits

NEW for spike 002:
- "is_bit_set(pixel)" handles both background styles:
    * transparent (alpha < threshold) = empty (TetraTile greybox style)
    * opaque white (rgb ~ 255,255,255) = empty (dandeliondino style)
    * everything else = bit set
- Anchors scale with tile size (works at 16, 32, 64, 128 px)
- Validates blob47 constraint: corner bit set → both adjacent edge bits must be set
"""

from __future__ import annotations
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import time
import sys


# ---- Paths ---------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[3]
SPIKE_DIR = Path(__file__).resolve().parent
TT_TEMPLATE_DIR = REPO_ROOT / "addons" / "tetra_tile" / "templates"
DD_TEMPLATE_DIR = SPIKE_DIR / "templates"
OUT_DIR = SPIKE_DIR / "out"


# ---- Sampling primitives -------------------------------------------------

ALPHA_THRESHOLD = 64
WHITE_FLOOR = 240   # rgb >= this = "background white"
KERNEL_RADIUS = 1
KERNEL_VOTES_REQUIRED = 5


def is_bit_set(pixel) -> bool:
    """Unified background-detection rule.

    Returns True iff the pixel is *neither* transparent *nor* opaque-white.
    Handles:
      - TetraTile greyboxes: empty = alpha 0 (transparent), filled = #888 alpha 255
      - dandeliondino:       empty = white alpha 255, filled = #478cbf alpha 255
      - User art:            empty = transparent or white background, filled = anything else
    """
    if len(pixel) == 4:
        r, g, b, a = pixel
    else:
        r, g, b = pixel[:3]
        a = 255
    if a < ALPHA_THRESHOLD:
        return False
    if r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR:
        return False
    return True


def sample_anchor(img: Image.Image, ax: int, ay: int) -> bool:
    """3×3 majority vote at an anchor point."""
    width, height = img.size
    votes = 0
    for dy in range(-KERNEL_RADIUS, KERNEL_RADIUS + 1):
        for dx in range(-KERNEL_RADIUS, KERNEL_RADIUS + 1):
            x, y = ax + dx, ay + dy
            if 0 <= x < width and 0 <= y < height:
                if is_bit_set(img.getpixel((x, y))):
                    votes += 1
    return votes >= KERNEL_VOTES_REQUIRED


# ---- Anchor placement ----------------------------------------------------

def corner_anchors(tile: int) -> dict[str, tuple[int, int]]:
    """Per-quadrant anchors at quadrant centers (well inside the slot)."""
    quarter = tile // 4
    return {
        "TL": (quarter, quarter),
        "TR": (tile - quarter - 1, quarter),
        "BL": (quarter, tile - quarter - 1),
        "BR": (tile - quarter - 1, tile - quarter - 1),
    }


def edge_anchors(tile: int) -> dict[str, tuple[int, int]]:
    """Per-edge anchors at edge midpoints, just inside the slot border.

    Inset scales with tile size: max(2, tile // 16) keeps the anchor 2 px in
    for 16-px tiles (matches spike 001) and 4 px in for 64-px tiles.
    """
    half = tile // 2
    inset = max(2, tile // 16)
    return {
        "T": (half - 1, inset),
        "E": (tile - inset - 1, half - 1),
        "B": (half - 1, tile - inset - 1),
        "W": (inset, half - 1),
    }


# ---- Mask bit assignments ------------------------------------------------
#
# 8-bit unified mask. Corner bits are the LOW nibble; edge bits are the HIGH nibble.
# This lets a 4-bit corner-only layout consume mask & 0x0F, and a 4-bit edge-only
# layout consume (mask >> 4) & 0x0F. Blob layouts use the full 8 bits.

CORNER_BITS = {"TL": 1, "TR": 2, "BL": 4, "BR": 8}
EDGE_BITS   = {"T": 16, "E": 32, "B": 64, "W": 128}


def decode_slot(img: Image.Image, col: int, row: int, tile: int,
                anchors_corners: bool, anchors_edges: bool) -> int:
    """Decode one slot. Layout decides which anchor set is sampled."""
    base_x, base_y = col * tile, row * tile
    mask = 0
    if anchors_corners:
        for name, (px, py) in corner_anchors(tile).items():
            if sample_anchor(img, base_x + px, base_y + py):
                mask |= CORNER_BITS[name]
    if anchors_edges:
        for name, (px, py) in edge_anchors(tile).items():
            if sample_anchor(img, base_x + px, base_y + py):
                mask |= EDGE_BITS[name]
    return mask


def decode_atlas(img: Image.Image, cols: int, rows: int, tile: int,
                 corners: bool, edges: bool) -> list[int]:
    out: list[int] = []
    for row in range(rows):
        for col in range(cols):
            out.append(decode_slot(img, col, row, tile, corners, edges))
    return out


# ---- Blob47 validity -----------------------------------------------------

def is_valid_blob_mask(mask: int) -> bool:
    """Corner-bit-set requires both adjacent edge bits set (blob47 constraint)."""
    if mask & CORNER_BITS["TL"] and not (mask & EDGE_BITS["T"] and mask & EDGE_BITS["W"]):
        return False
    if mask & CORNER_BITS["TR"] and not (mask & EDGE_BITS["T"] and mask & EDGE_BITS["E"]):
        return False
    if mask & CORNER_BITS["BL"] and not (mask & EDGE_BITS["B"] and mask & EDGE_BITS["W"]):
        return False
    if mask & CORNER_BITS["BR"] and not (mask & EDGE_BITS["B"] and mask & EDGE_BITS["E"]):
        return False
    return True


def all_valid_blob_masks() -> set[int]:
    """The 47 reachable blob masks + the empty mask 0 = 48."""
    return {m for m in range(256) if is_valid_blob_mask(m)}


# ---- Visualization -------------------------------------------------------

def render_annotated(img: Image.Image, cols: int, rows: int, tile: int,
                     decoded: list[int], expected_set: set[int] | None,
                     out_path: Path, scale: int = 4) -> None:
    """Scale up the template; overlay decoded mask + validity flag per slot."""
    big = img.resize((cols * tile * scale, rows * tile * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big, "RGBA")
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = ImageFont.load_default()

    for i, mask in enumerate(decoded):
        col, row = i % cols, i // cols
        x = col * tile * scale + 4
        y = row * tile * scale + 4
        if expected_set is None:
            text = f"m={mask}"
            color = (120, 240, 120, 255)
        else:
            ok = mask in expected_set
            text = f"m={mask}\n{'OK' if ok else 'INVALID'}"
            color = (120, 240, 120, 255) if ok else (240, 80, 80, 255)
        bbox = draw.multiline_textbbox((x, y), text, font=font)
        draw.rectangle(bbox, fill=(0, 0, 0, 200))
        draw.multiline_text((x, y), text, fill=color, font=font)

    big.save(out_path)


# ---- Test cases ----------------------------------------------------------

# (path, cols, rows, tile, corners, edges, expected_unique_count, validity_set, label)
CASES = [
    # TetraTile shipped greyboxes (16-px, alpha-encoded)
    (TT_TEMPLATE_DIR / "tetra_horizontal.png",  4, 1, 16, True, False, 4, None, "TT tetra_horizontal (corner; 4 archetypes)"),
    (TT_TEMPLATE_DIR / "tetra_vertical.png",    1, 4, 16, True, False, 4, None, "TT tetra_vertical (corner; 4 archetypes)"),
    (TT_TEMPLATE_DIR / "dual_grid_16.png",      4, 4, 16, True, False, 16, None, "TT dual_grid_16 (corner; 16 unique)"),
    (TT_TEMPLATE_DIR / "wang_2corner.png",      4, 4, 16, True, False, 16, None, "TT wang_2corner (corner; 16 unique)"),
    (TT_TEMPLATE_DIR / "wang_2edge.png",        4, 4, 16, False, True, 16, None, "TT wang_2edge (edge; 16 unique)"),
    # dandeliondino templates (64-px, color-encoded)
    (DD_TEMPLATE_DIR / "template_sides.png",            4, 4, 64, False, True, 16, None, "DD template_sides (edge; 16 unique)"),
    (DD_TEMPLATE_DIR / "template_corners.png",          4, 4, 64, True, False, 16, None, "DD template_corners (corner; 16 unique)"),
    (DD_TEMPLATE_DIR / "template_corners_alt.png",      5, 3, 64, True, False, 15, None, "DD template_corners_alt (corner; 15 unique, no blank)"),
    (DD_TEMPLATE_DIR / "template_corners_and_sides.png", 12, 4, 64, True, True, 48, all_valid_blob_masks(), "DD template_corners_and_sides (blob47; 47 valid + 1 blank)"),
]


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report: list[str] = []
    report.append("# Spike 002 — generalized template decoder — report")
    report.append(f"Python: {sys.version.split()[0]}")
    from PIL import __version__ as pil_version
    report.append(f"Pillow: {pil_version}")
    report.append("")

    valid_blob = all_valid_blob_masks()
    report.append(f"Computed valid blob47 masks: {len(valid_blob)} (expected 48: 47 reachable + mask 0)")
    report.append("")

    overall_pass = True
    timings: list[tuple[str, float]] = []

    for path, cols, rows, tile, corners, edges, expected_count, validity_set, label in CASES:
        report.append(f"=== {label} ===")
        if not path.exists():
            report.append(f"  [SKIP] {path} not found")
            report.append("")
            continue

        img = Image.open(path).convert("RGBA")
        report.append(f"  source: {path.relative_to(REPO_ROOT)}  ({img.size[0]}x{img.size[1]} px)")

        # Warm + time
        decode_atlas(img, cols, rows, tile, corners, edges)
        t0 = time.perf_counter_ns()
        decoded = decode_atlas(img, cols, rows, tile, corners, edges)
        elapsed_us = (time.perf_counter_ns() - t0) / 1000.0
        timings.append((label, elapsed_us))

        unique = set(decoded)
        report.append(f"  decode time: {elapsed_us:.1f} us  ({elapsed_us / len(decoded):.2f} us/slot)")
        report.append(f"  slots decoded: {len(decoded)}; unique masks: {len(unique)}; expected {expected_count}")

        # For blob templates: validate the blob47 constraint and uniqueness
        if validity_set is not None:
            invalid = [(i, m) for i, m in enumerate(decoded) if m not in validity_set]
            if invalid:
                report.append(f"  [FAIL] {len(invalid)} slots decoded to INVALID blob masks (corner without both adjacent edges):")
                for i, m in invalid[:5]:
                    report.append(f"      slot index {i} (col={i % cols}, row={i // cols}): mask={m}")
                if len(invalid) > 5:
                    report.append(f"      ... and {len(invalid) - 5} more")
                overall_pass = False
            else:
                report.append("  [OK] all decoded masks satisfy blob47 corner-implies-adjacent-edges constraint")
            # Count how many of the 47 reachable non-zero masks are present
            nonzero_present = (unique & valid_blob) - {0}
            report.append(f"  [INFO] {len(nonzero_present)}/47 non-zero blob masks present; mask 0 (blank) {'present' if 0 in unique else 'absent'}")

        # Uniqueness check (for templates that should have all-unique slots)
        if len(unique) != expected_count:
            report.append(f"  [WARN] expected {expected_count} unique masks, got {len(unique)}")
            # Identify duplicates
            from collections import Counter
            counts = Counter(decoded)
            dups = {m: c for m, c in counts.items() if c > 1}
            if dups:
                report.append(f"      duplicates: {dups}")

        # Render annotated visualization
        out_path = OUT_DIR / f"decode_{path.stem}.png"
        render_annotated(img, cols, rows, tile, decoded, validity_set, out_path)
        report.append(f"  visualization: {out_path.relative_to(REPO_ROOT)}")
        report.append("")

    # Summary
    report.append("=" * 60)
    report.append("## Summary")
    if overall_pass:
        report.append("  All blob47 constraints satisfied; decoder generalizes across template styles.")
    else:
        report.append("  FAIL: at least one blob47 violation detected.")
    avg_us = sum(us for _, us in timings) / len(timings) if timings else 0
    max_label, max_us = max(timings, key=lambda x: x[1]) if timings else ("none", 0)
    report.append(f"  decode timing: avg {avg_us:.1f} us per atlas across {len(timings)} templates")
    report.append(f"  worst case: {max_us:.1f} us ({max_label})")

    out_text = "\n".join(report)
    print(out_text)
    (OUT_DIR / "report.txt").write_text(out_text, encoding="utf-8")
    print(f"\nReport written to {OUT_DIR / 'report.txt'}")
    return 0 if overall_pass else 1


if __name__ == "__main__":
    sys.exit(main())
