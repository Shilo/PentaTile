# Spike Conventions

Patterns established across spike sessions. New spikes follow these unless the question requires otherwise.

## Stack

- **Python 3 + Pillow** for image-processing prototypes. Algorithms transfer cleanly to GDScript via `Image.get_pixel()` / `Color`. Pillow is already a project dependency (`tools/_generate_bitmasks.py`).
- **No GDScript spike prototypes** unless the question is specifically about Godot runtime behavior (e.g. signal lifecycle, Resource serialization, `_update_cells` ordering). Python iterates faster.
- **JSON reports** for structured data output (gap analysis, scoring matrices). Write to `out/report_name.json`.

## Structure

```
.planning/spikes/
  MANIFEST.md             # spike index + requirements
  CONVENTIONS.md          # this file
  NNN-descriptive-name/
    README.md             # frontmatter + research + investigation trail + results
    script_name.py        # primary spike script
    out/                  # generated artifacts (PNGs, reports, JSON)
      report.json
      atlas.png
```

- Number from `001`, zero-padded.
- Slug uses `kebab-case`.
- Output artifacts go in `out/` (gitignored if heavy; committed if small + useful).

## Patterns

- **Visual output by default.** Spikes that touch pixel data render annotated PNGs (template scaled 8×, decoded vs expected overlaid per slot). The user can open the PNG and *see* the decode worked, not just trust a console PASS.
- **Plain-text `report.txt` alongside the PNG.** Console output is reproduced as a file so future-me can grep results without re-running.
- **Failure-mode probes are first-class.** Every feasibility spike includes synthetic adversarial tests (anti-aliased input, ambiguous data, missing data, edge cases). A spike that only validates the happy path is incomplete.
- **Investigation Trail in README documents the iterations**, not just the final state. Iteration 1 → findings → iteration 2 → final verdict. Lessons learned stay attached to the artifact.
- **Cross-spike references.** When a spike's findings affect another spike's design, document the dependency in `related: []` frontmatter and link to the specific section.
- **Competitive comparison tables.** When evaluating approaches, always include a comparison table (Approach | Tool/Library | Pros | Cons | Status). Chosen approach with explicit rationale.
- **LOC estimates for each change.** Every architectural spike includes per-feature LOC estimates, cumulative totals, and identity guardrail checks.
- **Python scripts in spike directory.** Scripts write output to `out/` and use `os.makedirs("out", exist_ok=True)` for CWD independence. Run from repo root with `python ".planning/spikes/NNN-name/script.py"`.

## Tools & Libraries

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.14.2 (verified) | Anything >= 3.10 fine — type hints use built-in generics |
| Pillow | 12.0.0 (verified) | `Image.getpixel()`, `ImageDraw`, `ImageFilter.GaussianBlur` |

Avoid: heavy package management (only stdlib + Pillow). No bundlers, no Docker, no env files.

## Spike Session 2026-04-30 (Spikes 004-008)

### Patterns established this session:
- **Gap analysis as structured JSON**: Spike 004 (gap_analysis.py) and spike 008 (audit_scorer.py) output machine-readable JSON reports. These feed into plan-phase and todo generation.
- **Atlas generation for layout validation**: Spike 005 (slope_design.py) generates annotated atlas PNGs that validate mask-to-slot tables visually. The "generate the atlas and look at it" pattern supplements numerical verification.
- **Terrain API pseudo-code**: Spike 007 includes concrete GDScript pseudo-code for `_build_terrain_index()`, `_peering_bits_to_mask()`, and `_pick_terrain_variant()`. These are directly copyable into implementation phases.
- **Competitive baseline scoring**: Spike 008 formalized the (completeness × demand × risk) scoring matrix for feature prioritization. Future audits should reuse the same formula.
- **Anti-feature register**: Spikes 004, 005, 006, 007 all include explicit "what this does NOT handle" sections with impact/mitigation tables. Spike 008 formalized the anti-feature register with competitive justification.
