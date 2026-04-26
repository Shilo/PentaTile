# Spike Conventions

Patterns established across spike sessions. New spikes follow these unless the question requires otherwise.

## Stack

- **Python 3 + Pillow** for image-processing prototypes. Algorithms transfer cleanly to GDScript via `Image.get_pixel()` / `Color`. Pillow is already a project dependency (`addons/tetra_tile/templates/_generate_greybox_templates.py`).
- **No GDScript spike prototypes** unless the question is specifically about Godot runtime behavior (e.g. signal lifecycle, Resource serialization, `_update_cells` ordering). Python iterates faster.

## Structure

```
.planning/spikes/
  MANIFEST.md             # spike index + requirements
  CONVENTIONS.md          # this file
  NNN-descriptive-name/
    README.md             # frontmatter + research + investigation trail + results
    decode.py             # primary script (or test-*.py for multi-script spikes)
    out/                  # generated artifacts (PNGs, reports, benchmarks)
      report.txt
      decode_*.png
```

- Number from `001`, zero-padded.
- Slug uses `kebab-case`.
- Output artifacts go in `out/` (gitignored if heavy; committed if small + useful).

## Patterns

- **Visual output by default.** Spikes that touch pixel data render annotated PNGs (template scaled 8×, decoded vs expected overlaid per slot). The user can open the PNG and *see* the decode worked, not just trust a console PASS.
- **Plain-text `report.txt` alongside the PNG.** Console output is reproduced as a file so future-me can grep results without re-running.
- **Failure-mode probes are first-class.** Every feasibility spike includes synthetic adversarial tests (anti-aliased input, ambiguous data, missing data, edge cases). A spike that only validates the happy path is incomplete.
- **Investigation Trail in README documents the iterations**, not just the final state. Iteration 1 → findings → iteration 2 → final verdict. Lessons learned stay attached to the artifact.

## Tools & Libraries

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.14.2 (verified) | Anything ≥ 3.10 fine — type hints use built-in generics |
| Pillow | 12.0.0 (verified) | `Image.getpixel()`, `ImageDraw`, `ImageFilter.GaussianBlur` |

Avoid: heavy package management (only stdlib + Pillow). No bundlers, no Docker, no env files.
