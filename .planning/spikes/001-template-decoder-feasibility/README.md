---
spike: 001
name: template-decoder-feasibility
type: standard
validates: "Given a greybox layout template PNG, when sampled per a fixed pixel-anchor rule, then the decoded mask table matches the documented mask convention without hand-authored slot data."
verdict: VALIDATED
related: []
tags: [decoder, layouts, image-sampling, gdscript-port-pending]
---

# Spike 001: Template Decoder Feasibility

## What This Validates

**Given** a TetraTile layout template PNG (e.g. `dual_grid_16.png` shipped in `addons/tetra_tile/templates/`),
**when** we sample a fixed set of pixels per slot using a geometric anchor + 3×3 majority-vote rule,
**then** the resulting mask integer per slot matches the documented mask convention (corner: TL=1 TR=2 BL=4 BR=8; edge: N=1 E=2 S=4 W=8) — with **no hand-authored slot data**.

This is the load-bearing test for the Phase 1 brainstorm option B: "two-image system, with the decoder auto-generated from silhouette inference as the default." If decode works on the shipped greybox templates without any per-slot Resource authoring, Option B is feasible and Phase 1 can absorb the auto-decoder.

## Research

### Prior art

- **TileBitTools** (MIT, dandeliondino) — does the inverse: reads an authored atlas and infers what mask each tile encodes. Confirms the general "infer slot semantics from pixel data" approach is well-trod. We chose to *transcribe* TBT's slot tables for the Phase 3 layouts rather than re-decode at runtime, but the auto-decode pattern itself is established prior art.
- **Existing greybox generator** (`addons/tetra_tile/templates/_generate_greybox_templates.py`) — the inverse function we're trying to validate. The generator paints quadrants/arms per a known mask; the decoder reads pixels and reconstructs the mask. If the generator is canonical (it is — referenced from `templates/README.md` mask conventions), then "decode is generator's right inverse" is the feasibility statement.

### Approach comparison

| Approach | Technique | Pros | Cons | Verdict |
|----------|-----------|------|------|---------|
| Single-pixel anchor | One `Image.get_pixel` per quadrant/edge | Cheapest; simplest GDScript port | Brittle to single-pixel anomalies (highlights, AA bleed) | First iteration, then upgraded |
| **3×3 majority vote** | 9 pixels per anchor; 5+ alpha-opaque = bit set | Resilient to AA, glow seams, single-pixel artifacts; still O(n) per slot | ~7× more pixel reads than single-pixel | **CHOSEN** |
| Quadrant-area coverage | Count opaque pixels in entire quadrant; threshold on coverage % | Most robust to abstract art | Loses the "anchor is geometrically inside" simplification; complicates GDScript port | Rejected |
| Pre-blur + threshold | Gaussian blur slot, then sample center | Smoothest signal | Adds pre-processing step; needs in-engine blur | Rejected (not justified at this scale) |

### Chosen approach

**3×3 majority vote at geometric anchors.** Rejects outline contamination by *placement* (anchors are 4 px inside the slot for corner masks, 2 px from edge for arm midpoints — outlines are 1-px at slot boundaries and cannot reach). Uses alpha-only opacity check (no brightness floor needed). Majority voting (5 of 9 pixels alpha-opaque) absorbs single-pixel artifacts.

## How to Run

```bash
python .planning/spikes/001-template-decoder-feasibility/decode.py
```

## What to Expect

- 5 annotated PNGs written to `out/decode_<template>.png` (template scaled 8×, with `d=N e=N OK/FAIL` overlaid on each slot)
- 1 anti-aliased probe PNG: `out/probe_anti_aliased.png`
- 1 plain-text report: `out/report.txt`
- Console summary showing 56/56 slots match expected, all failure-mode probes PASS, sub-millisecond timing
- Process exits 0 if all assertions pass

## Investigation Trail

### Iteration 1: brightness floor + single-pixel sampling

First-pass decoder used a brightness floor (RGB mean > 80) plus alpha threshold to reject outline pixels (`#444 = brightness 68`). Sampled one pixel at `(quarter, quarter)` per quadrant.

**Findings:**
- Shipped greyboxes: 56/56 slots correctly decoded ✓
- Topology auto-detect failed for Tetra Horizontal/Vertical: identified as 'edge' instead of 'corner' ✗
- Anti-aliased painted-template probe: 0/16 slots correctly decoded ✗

**Why topology auto-detect failed:** the slot-0-only heuristic ("if center filled → edge") assumed slot 0 = mask 0. Tetra layouts put the FILL archetype (mask 15) in slot 0 — center is filled in a corner-mask template too, fooling the heuristic.

**Why anti-aliased decode failed:** the brown test fill `#785028` has RGB mean exactly 80 (`(120+80+40)/3`), which equaled the brightness floor. Strict `>` comparison rejected it. The brightness floor was added defensively against outline contamination — but anchors are placed 4 pixels inside the slot, far from the 1-px slot outline. The floor was solving a problem that didn't exist while creating a problem that did (rejecting dark user art).

### Iteration 2: alpha-only + 3×3 majority vote + all-slots topology heuristic

Three fixes:

1. **Drop the brightness floor entirely.** Outline rejection is now geometric (anchor placement), not pigment-based. User art with arbitrary RGB works.
2. **3×3 majority vote.** Each anchor samples 9 pixels (radius 1); 5+ alpha-opaque votes = bit set. Absorbs anti-aliasing seams and single-pixel anomalies in user-painted templates without losing precision against the deterministic greyboxes.
3. **All-slots topology heuristic.** Instead of looking at slot 0's center, count slots with filled centers. Edge templates have an always-on center hint in *every* slot (100%); corner templates have at least one slot with an empty center (mask 1, 2, 4, 8 — any single-quadrant slot has a transparent center). Robust across all 5 shipped templates including Tetra Horizontal's mask-15-in-slot-0.

**Findings after iteration 2:**
- Shipped greyboxes: 56/56 slots correctly decoded ✓
- Topology auto-detect: 5/5 templates correctly classified ✓
- Anti-aliased painted template: 16/16 slots correctly decoded after Gaussian blur radius 0.6 ✓
- Ambiguous-slot detection: PASS (decoder reports `{15: [0, 1]}` for two-slot duplicate fill)
- Missing-mask detection: PASS (reports the 12 missing masks for Tetra Horizontal — correctly noting Tetra synthesizes them via `TRANSFORM_FLIP_*` rotations)
- Outline-only-slot rejection: PASS (anchor placement keeps outline pixels out of the sample)
- Performance: 64 µs (4-tile) / 250 µs (16-tile) per atlas; ~16 µs per slot. Sub-millisecond, runs once at Resource load.

## Results

### Verdict: VALIDATED ✓

The auto-decoder works on every shipped greybox template, survives anti-aliased user-painted variants, detects all targeted failure modes, and runs in sub-millisecond time. Option B is feasible.

### Decoder rules (locked)

These rules transfer directly to the GDScript port:

| Rule | Value | Why |
|------|-------|-----|
| Sample primitive | `Image.get_pixel(x, y).a > 64` | Alpha-only; no brightness check needed |
| Anchor pattern | 3×3 majority vote (radius 1, ≥5 of 9 opaque) | Resilient to AA + single-pixel anomalies |
| Corner-mask anchors | TL/TR/BL/BR at `(quarter, quarter)` of each quadrant | 4 px inside slot — outline-free zone |
| Edge-mask anchors | N/E/S/W at 2 px from each slot edge, on arm centerline | Past outline + center hint |
| Topology declaration | Layout subclass owns it (`compute_mask` is virtual) | Auto-detect is courtesy fallback only |

### Surprises

1. **Brightness floor was anti-helpful.** It was added to reject outline pixels (rgb=68) but the anchor placement already excludes outlines geometrically. The floor only succeeded in rejecting darker user art. Lesson: rely on geometric placement first, color rules only when placement isn't sufficient.
2. **Slot-0-only topology detection is fragile.** Tetra layouts put mask 15 (FILL) in slot 0 to make the FILL archetype the canonical first tile. Any auto-detect that looks at slot 0 alone has to know about per-layout slot-ordering conventions. The all-slots heuristic ("do ALL centers have content?") is robust across this divergence — but the right answer is to let the layout subclass declare its topology, not auto-detect at all. The heuristic stays in the spike as a fallback for tooling.
3. **Performance was already a non-issue at the start.** Initial worry was "load-time decode might cost something." Actual cost: 250 µs for a 16-tile atlas. Going to 47-tile blob layouts: ~750 µs. All sub-millisecond, all once-per-Resource-load. No caching required (though we'll cache anyway for cleanliness).

### Edge cases NOT yet probed (open work for the build phase)

- **Blob 47** (8-bit mask, 47 tiles): same 4-corner + 4-edge anchor pattern should generalize to 8 anchors per slot, but unverified against TBT's actual `tilesetter_blob.tres` template. Confidence high; verify before Phase 3 ships.
- **Non-standard tile sizes** (8 px, 32 px, 64 px): the anchors are computed as `tile // 4` etc. — no assumption baked in. Should "just work" but worth a quick check during the GDScript port.
- **Wang2Edge vs Wang2Corner disambiguation** (same 4-bit topology, different bit names): topology auto-detect can distinguish corner-vs-edge silhouettes, but cannot tell Wang2Corner from DualGrid16 (visually identical). The layout subclass *must* declare which one it is — no decoder magic can resolve this from pixels alone. This confirms the production rule: **subclass declares topology**, decoder follows.
- **Translucent / partially-opaque user art** (alpha 32-63 — below threshold): currently rejected. If users paint with 25%-opacity layers, decode breaks. Either bump threshold up, or document "fills must be ≥25% opaque."

### Signal for the build

**Use:**
- 3×3 majority vote at geometric anchors (not single-pixel)
- Layout subclass declares topology (`corner | edge | blob47 | …`)
- Decode at Resource load + cache; do NOT decode per paint
- Surface ambiguous / missing / unrecognized slots via `update_configuration_warnings()` so the inspector flags broken templates at edit time

**Avoid:**
- Brightness-based outline rejection (geometric placement is sufficient and tolerates dark user art)
- Single-slot topology auto-detection (fragile across slot-0 conventions)
- Decoding on every paint (cache the table at Resource load)

**Watch for during GDScript port:**
- `Image.get_pixel()` returns `Color`, not RGBA tuple. Check `Color.a > 0.25` (≈ alpha 64/255).
- Non-32-bit-RGBA images need `Image.convert(Image.FORMAT_RGBA8)` first or `get_pixel` will fail on indexed-color sources.
- Anchors at `tile / 4` integer division — works fine in GDScript with `int(tile / 4)`.

## Output Files

| File | Purpose |
|------|---------|
| `out/decode_tetra_horizontal.png` | Annotated 4×1 strip — mask 15/7/3/1 |
| `out/decode_tetra_vertical.png` | Annotated 1×4 strip — same archetypes stacked |
| `out/decode_dual_grid_16.png` | Annotated 4×4 — slot=mask, all 16 corner states |
| `out/decode_wang_2corner.png` | Annotated 4×4 — visually identical to dual_grid_16 |
| `out/decode_wang_2edge.png` | Annotated 4×4 — edge-mask plus-sign silhouettes |
| `out/probe_anti_aliased.png` | Synthesized brown-fill 4×4 with Gaussian blur — proves AA tolerance |
| `out/report.txt` | Plain-text PASS/FAIL log + timings + topology auto-detect results |
