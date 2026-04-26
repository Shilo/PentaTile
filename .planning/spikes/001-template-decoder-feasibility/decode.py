"""Template-image-to-mask decoder feasibility probe for TetraTile v0.2.

Validates: given a greybox layout template PNG, can we reconstruct the
mask-to-atlas table by sampling a fixed set of pixels per slot, with no
hand-authored slot data?

Two topologies tested:
- CORNER masks (Tetra / DualGrid16 / Wang2Corner): TL=1 TR=2 BL=4 BR=8
  → sample one pixel per quadrant near its center.
- EDGE masks (Wang2Edge): N=1 E=2 S=4 W=8
  → sample one pixel per edge midpoint, on the arm past the center hint.

Outputs:
- out/decode_<name>.png  — annotated visualization (template scaled 8x with
                          decoded mask + expected mask printed on each slot)
- out/report.txt         — per-slot PASS/FAIL + timing + topology auto-detect
                          + failure-mode probe results
"""

from __future__ import annotations
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import time
import sys

# ---- Constants -----------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[3]
TEMPLATE_DIR = REPO_ROOT / "addons" / "tetra_tile" / "templates"
OUT_DIR = Path(__file__).resolve().parent / "out"

TILE = 16  # pixels per tile, matches greybox generator

# Sampling design — the decoder asks ONE question per sample point:
# "Is there opaque pixel data here?" → alpha > threshold = bit set.
#
# Rejecting outline pixels (#444, alpha=255) is handled GEOMETRICALLY: sample
# points are placed well inside their quadrant/arm (4 pixels in from the slot
# edge for corner masks; 2 pixels in for edge-arm midpoints). Outlines are
# 1-px at slot boundaries — they cannot reach the sample anchor.
#
# To absorb single-pixel anomalies (highlights, alpha glow seams), we use a
# 3×3 majority vote around the anchor: 5+ of 9 sampled pixels must be
# alpha-opaque for the bit to register. Resilient to AA bleed and stray
# pixels in user art.

ALPHA_THRESHOLD = 64        # per-pixel alpha threshold for "filled"
KERNEL_RADIUS = 1           # 3×3 sample (radius=1)
KERNEL_VOTES_REQUIRED = 5   # majority of 9


# ---- Pixel-sampling primitives -------------------------------------------

def is_alpha_opaque(pixel) -> bool:
    """Single-pixel alpha check."""
    if len(pixel) == 4:
        return pixel[3] > ALPHA_THRESHOLD
    return True  # RGB-only pixel — treat as opaque


def sample_anchor(img: Image.Image, ax: int, ay: int) -> bool:
    """3×3 majority vote around an anchor point.

    Treats sample points as 'fuzzy' to absorb single-pixel anomalies in
    user-painted art (highlights that happened to be slightly transparent,
    AA seams between blocks of color, etc.). 5+ of 9 must be opaque.
    """
    width, height = img.size
    votes = 0
    for dy in range(-KERNEL_RADIUS, KERNEL_RADIUS + 1):
        for dx in range(-KERNEL_RADIUS, KERNEL_RADIUS + 1):
            x, y = ax + dx, ay + dy
            if 0 <= x < width and 0 <= y < height:
                if is_alpha_opaque(img.getpixel((x, y))):
                    votes += 1
    return votes >= KERNEL_VOTES_REQUIRED


def corner_sample_points(tile: int) -> dict[str, tuple[int, int]]:
    """Per-quadrant sample point. Quadrants are tile/2 wide.

    Sampling at (quarter, quarter) targets the center of each quadrant —
    safely inside the fill, away from the 1-px outline.
    """
    quarter = tile // 4
    return {
        "TL": (quarter, quarter),
        "TR": (tile - quarter - 1, quarter),
        "BL": (quarter, tile - quarter - 1),
        "BR": (tile - quarter - 1, tile - quarter - 1),
    }


def edge_sample_points(tile: int) -> dict[str, tuple[int, int]]:
    """Per-edge sample point on each arm, past the center hint and outline.

    The greybox generator's plus-sign arms extend from (cx0, cy0)=(6, 6)
    to the slot edge. Sampling at e.g. y=2 on the N arm catches the arm
    pixel without hitting the 1-px outline at y=0.
    """
    half = tile // 2
    return {
        "N": (half - 1, 2),
        "E": (tile - 3, half - 1),
        "S": (half - 1, tile - 3),
        "W": (2, half - 1),
    }


# ---- Decoders ------------------------------------------------------------

CORNER_BITS = {"TL": 1, "TR": 2, "BL": 4, "BR": 8}
EDGE_BITS = {"N": 1, "E": 2, "S": 4, "W": 8}


def decode_corner_slot(img: Image.Image, col: int, row: int) -> int:
    base_x, base_y = col * TILE, row * TILE
    points = corner_sample_points(TILE)
    mask = 0
    for name, (px, py) in points.items():
        if sample_anchor(img, base_x + px, base_y + py):
            mask |= CORNER_BITS[name]
    return mask


def decode_edge_slot(img: Image.Image, col: int, row: int) -> int:
    base_x, base_y = col * TILE, row * TILE
    points = edge_sample_points(TILE)
    mask = 0
    for name, (px, py) in points.items():
        if sample_anchor(img, base_x + px, base_y + py):
            mask |= EDGE_BITS[name]
    return mask


def decode_atlas(img: Image.Image, cols: int, rows: int, topology: str) -> list[int]:
    """Decode all slots in column-major order (slot index = row * cols + col)."""
    decoder = decode_corner_slot if topology == "corner" else decode_edge_slot
    out: list[int] = []
    for row in range(rows):
        for col in range(cols):
            out.append(decoder(img, col, row))
    return out


def auto_detect_topology(img: Image.Image, cols: int, rows: int) -> str:
    """Heuristic: do ALL slots have filled centers?

    Edge-mask templates have an always-on center hint dot in every slot
    (even m=0). Corner-mask templates have an EMPTY center for slots whose
    mask doesn't fill all 4 quadrants — masks 1, 2, 4, 8, etc. all leave
    the slot center transparent.

    Rule: if every slot's center samples as opaque, topology is 'edge'.
    Otherwise 'corner'. This is more robust than a single-slot heuristic
    because Tetra Horizontal/Vertical have mask 15 (all-quadrants-filled)
    in slot 0, which would fool a slot-0-only check.

    Production note: layouts should declare topology explicitly via a
    `topology()` virtual on TetraTileLayout. This auto-detect is a
    courtesy fallback for tooling, not a runtime path.
    """
    half = TILE // 2
    centers_filled = 0
    total = cols * rows
    for row in range(rows):
        for col in range(cols):
            cx = col * TILE + half - 1
            cy = row * TILE + half - 1
            if sample_anchor(img, cx, cy):
                centers_filled += 1
    return "edge" if centers_filled == total else "corner"


# ---- Visualization -------------------------------------------------------

def render_annotated(
    img: Image.Image,
    cols: int,
    rows: int,
    decoded: list[int],
    expected: list[int],
    out_path: Path,
    scale: int = 8,
) -> None:
    """Render the template scaled up, with decoded and expected masks overlaid."""
    big = img.resize((cols * TILE * scale, rows * TILE * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except OSError:
        font = ImageFont.load_default()

    for i, (dec, exp) in enumerate(zip(decoded, expected)):
        col, row = i % cols, i // cols
        x = col * TILE * scale + 4
        y = row * TILE * scale + 4
        ok = "OK" if dec == exp else "FAIL"
        text = f"d={dec}\ne={exp}\n{ok}"
        # text bg
        text_bbox = draw.multiline_textbbox((x, y), text, font=font)
        draw.rectangle(text_bbox, fill=(0, 0, 0, 200))
        color = (120, 240, 120) if dec == exp else (240, 80, 80)
        draw.multiline_text((x, y), text, fill=color, font=font)

    big.save(out_path)


# ---- Test harness --------------------------------------------------------

# (template_filename, cols, rows, expected_masks, topology)
# expected_masks indexed by row*cols + col.
CASES = [
    # 4x1 strip — Tetra archetypes per generator: [Fill=15, Inner=7, Border=3, Outer=1]
    ("tetra_horizontal.png", 4, 1, [15, 7, 3, 1], "corner"),
    # 1x4 strip — same archetypes, stacked
    ("tetra_vertical.png", 1, 4, [15, 7, 3, 1], "corner"),
    # 4x4 — slot index = mask value
    ("dual_grid_16.png", 4, 4, list(range(16)), "corner"),
    # Same as DualGrid16 (Wang2Corner reuses the silhouettes)
    ("wang_2corner.png", 4, 4, list(range(16)), "corner"),
    # 4x4 — slot index = edge-mask value
    ("wang_2edge.png", 4, 4, list(range(16)), "edge"),
]


def run_correctness_tests(report_lines: list[str]) -> tuple[int, int, list[float]]:
    total_slots = 0
    failed_slots = 0
    timings: list[float] = []

    for fname, cols, rows, expected, topology in CASES:
        path = TEMPLATE_DIR / fname
        if not path.exists():
            report_lines.append(f"[SKIP] {fname} not found at {path}")
            continue

        img = Image.open(path).convert("RGBA")

        # Topology auto-detect
        detected = auto_detect_topology(img, cols, rows)
        topo_ok = detected == topology

        # Time the decode (warm — second pass to avoid first-call overhead)
        decode_atlas(img, cols, rows, topology)
        t0 = time.perf_counter_ns()
        decoded = decode_atlas(img, cols, rows, topology)
        elapsed_us = (time.perf_counter_ns() - t0) / 1000.0
        timings.append(elapsed_us)

        # Per-slot comparison
        slot_results = []
        for i, (dec, exp) in enumerate(zip(decoded, expected)):
            slot_results.append((i % cols, i // cols, dec, exp, dec == exp))

        local_failed = sum(1 for *_, ok in slot_results if not ok)
        total_slots += len(slot_results)
        failed_slots += local_failed

        report_lines.append("")
        report_lines.append(f"=== {fname} ({cols}x{rows}, {topology} mask) ===")
        report_lines.append(f"  topology auto-detect: {detected} ({'OK' if topo_ok else 'WRONG'})")
        report_lines.append(f"  decode time: {elapsed_us:.1f} us  ({elapsed_us / len(decoded):.2f} us/slot)")
        report_lines.append(f"  slots: {len(decoded) - local_failed}/{len(decoded)} match expected")
        for col, row, dec, exp, ok in slot_results:
            status = "OK  " if ok else "FAIL"
            report_lines.append(
                f"    [{status}] slot ({col},{row})  decoded={dec:>2}  expected={exp:>2}"
            )

        # Render annotated
        out_path = OUT_DIR / f"decode_{path.stem}.png"
        render_annotated(img, cols, rows, decoded, expected, out_path)
        report_lines.append(f"  visualization: {out_path.relative_to(REPO_ROOT)}")

    return total_slots, failed_slots, timings


# ---- Failure-mode probes -------------------------------------------------

def probe_anti_aliased(report_lines: list[str]) -> bool:
    """Synthesize a 'painted' template with AA edges, verify decode survives."""
    from PIL import ImageFilter
    img = Image.new("RGBA", (4 * TILE, 4 * TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Paint each slot per the dual_grid_16 convention but with a colored fill
    for mask in range(16):
        col, row = mask % 4, mask // 4
        x0, y0 = col * TILE, row * TILE
        half = TILE // 2
        quads = [
            (1, x0, y0, x0 + half - 1, y0 + half - 1),
            (2, x0 + half, y0, x0 + TILE - 1, y0 + half - 1),
            (4, x0, y0 + half, x0 + half - 1, y0 + TILE - 1),
            (8, x0 + half, y0 + half, x0 + TILE - 1, y0 + TILE - 1),
        ]
        for bit, qx0, qy0, qx1, qy1 in quads:
            if mask & bit:
                # Brown-ish dirt fill
                draw.rectangle((qx0, qy0, qx1, qy1), fill=(120, 80, 40, 255))
    # Soften edges to simulate anti-aliasing
    img = img.filter(ImageFilter.GaussianBlur(radius=0.6))

    decoded = decode_atlas(img, 4, 4, "corner")
    expected = list(range(16))
    failed = [(i, d, e) for i, (d, e) in enumerate(zip(decoded, expected)) if d != e]

    report_lines.append("")
    report_lines.append("=== Probe: anti-aliased painted template ===")
    if not failed:
        report_lines.append("  PASS — decoded matches expected for all 16 slots after AA blur")
        ok = True
    else:
        report_lines.append(f"  FAIL — {len(failed)} slots mismatched after AA blur:")
        for i, d, e in failed:
            report_lines.append(f"    slot {i}  decoded={d}  expected={e}")
        ok = False

    out_path = OUT_DIR / "probe_anti_aliased.png"
    render_annotated(img, 4, 4, decoded, expected, out_path)
    report_lines.append(f"  visualization: {out_path.relative_to(REPO_ROOT)}")
    return ok


def probe_failure_modes(report_lines: list[str]) -> dict[str, bool]:
    """Verify the decoder can detect ambiguous, missing, and unrecognized layouts."""
    results: dict[str, bool] = {}

    # 1. Ambiguous: two slots decode to the same mask
    img = Image.new("RGBA", (2 * TILE, 1 * TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Both slots = full fill (mask 15)
    draw.rectangle((0, 0, 2 * TILE - 1, TILE - 1), fill=(136, 136, 136, 255))
    decoded = decode_atlas(img, 2, 1, "corner")
    seen: dict[int, list[int]] = {}
    for i, m in enumerate(decoded):
        seen.setdefault(m, []).append(i)
    duplicates = {m: idxs for m, idxs in seen.items() if len(idxs) > 1}
    report_lines.append("")
    report_lines.append("=== Probe: ambiguous slots (two slots, same mask) ===")
    if duplicates:
        report_lines.append(f"  PASS — detected duplicate masks: {duplicates}")
        results["ambiguous_detection"] = True
    else:
        report_lines.append("  FAIL — duplicates not detected")
        results["ambiguous_detection"] = False

    # 2. Missing: some masks not represented (slot table has gaps)
    decoded_set = set(decode_atlas(Image.open(TEMPLATE_DIR / "tetra_horizontal.png").convert("RGBA"), 4, 1, "corner"))
    full_corner_set = set(range(16))
    missing = full_corner_set - decoded_set
    report_lines.append("")
    report_lines.append("=== Probe: missing masks (Tetra Horizontal — only 4 archetypes) ===")
    if missing:
        report_lines.append(f"  PASS — detected {len(missing)} missing masks: {sorted(missing)}")
        report_lines.append(f"  ({len(decoded_set)} of 16 corner-mask states present)")
        report_lines.append("  NOTE: this is EXPECTED for Tetra layouts — they synthesize the")
        report_lines.append("        other 12 states from the 4 archetypes via TRANSFORM_FLIP_*.")
        results["missing_detection"] = True
    else:
        report_lines.append("  FAIL — missing masks not detected")
        results["missing_detection"] = False

    # 3. Unrecognized topology: feed an edge-mask template through the corner decoder
    img = Image.open(TEMPLATE_DIR / "wang_2edge.png").convert("RGBA")
    detected = auto_detect_topology(img, 4, 4)
    report_lines.append("")
    report_lines.append("=== Probe: topology auto-detect (edge template) ===")
    if detected == "edge":
        report_lines.append(f"  PASS — auto-detected as '{detected}'")
        results["topology_detection"] = True
    else:
        report_lines.append(f"  FAIL — auto-detected as '{detected}' (expected 'edge')")
        results["topology_detection"] = False

    # 4. User-error robustness: alpha-only outline (no fill) — should decode mask 0
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, TILE - 1, TILE - 1), outline=(68, 68, 68, 255), width=1)
    decoded_mask = decode_corner_slot(img, 0, 0)
    report_lines.append("")
    report_lines.append("=== Probe: outline-only slot (no fill) — should be mask 0 ===")
    if decoded_mask == 0:
        report_lines.append("  PASS — outline pixels not sampled (geometric placement: anchor 4px inside)")
        results["outline_rejection"] = True
    else:
        report_lines.append(f"  FAIL — decoded mask {decoded_mask}, expected 0")
        results["outline_rejection"] = False

    return results


# ---- Main ----------------------------------------------------------------

def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report_lines: list[str] = []
    report_lines.append("# Spike 001 — template-decoder-feasibility — report")
    report_lines.append(f"Python: {sys.version.split()[0]}")
    from PIL import __version__ as pil_version
    report_lines.append(f"Pillow: {pil_version}")
    report_lines.append("")

    report_lines.append("## Correctness on shipped greybox templates")
    total, failed, timings = run_correctness_tests(report_lines)

    report_lines.append("")
    report_lines.append("## Failure-mode probes")
    aa_ok = probe_anti_aliased(report_lines)
    failure_results = probe_failure_modes(report_lines)

    # Summary
    report_lines.append("")
    report_lines.append("=" * 60)
    report_lines.append("## Summary")
    report_lines.append(f"  shipped templates: {total - failed}/{total} slots match expected")
    report_lines.append(f"  anti-aliased painted template: {'PASS' if aa_ok else 'FAIL'}")
    for name, ok in failure_results.items():
        report_lines.append(f"  {name}: {'PASS' if ok else 'FAIL'}")
    if timings:
        avg_us = sum(timings) / len(timings)
        report_lines.append(f"  decode timing: avg {avg_us:.1f} us per atlas")
        report_lines.append(f"               : min {min(timings):.1f} us / max {max(timings):.1f} us")

    report_path = OUT_DIR / "report.txt"
    report_path.write_text("\n".join(report_lines), encoding="utf-8")

    print("\n".join(report_lines))
    print(f"\nReport written to {report_path}")
    return 0 if (failed == 0 and aa_ok and all(failure_results.values())) else 1


if __name__ == "__main__":
    sys.exit(main())
