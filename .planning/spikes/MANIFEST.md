# Spike Manifest

## Idea

TetraTile v0.2 layout-library milestone — Phase 1 redirected from "ship the contract / layout / slot Resource skeleton with hand-authored slot data" toward "users author custom layouts via template images, with the slot table auto-decoded from pixel data — no primitive `AtlasSlot` Resource authoring required." Spikes validate the decoder mechanism before milestone scope locks.

See `.planning/phases/01-contract-skeleton-tetra-layouts/01-PRE-SPIKE-NOTES.md` for the brainstorm that produced this spike.

## Requirements

Design decisions emerging from spike findings — non-negotiable for the real build.

- **Layout subclass declares topology + dual-grid model.** Auto-detection from a single image is fragile across slot-0 conventions (Tetra's slot 0 = mask 15, others' slot 0 = mask 0). The `TetraTileLayout` base owns `topology()` AND `is_dual_grid()` virtuals; auto-detect stays as a courtesy tooling fallback only. Same template visuals serve both grid models, so this MUST be explicit per subclass.
- **Unified decoder background rule:** `transparent OR opaque-white = empty; anything else = bit set`. Handles both TetraTile's alpha-encoded greyboxes and dandeliondino's color-encoded silhouette templates. (User's stated rule, validated in spike 002.)
- **3×3 majority vote at geometric anchors.** Anchors at quadrant centers (corners) and edge midpoints (sides), with `inset = max(2, tile // 16)` to scale across tile sizes. Resilient to AA art and single-pixel anomalies.
- **8-anchor sampler covers every v0.2 layout.** 4 corners + 4 edges, no center bit. Layout subclass declares which subset are mask bits (corner-only / edge-only / both).
- **Decode at Resource load, cache the result.** Sub-millisecond cost across all v0.2 templates (≤1.7 ms for 48-slot blob at 64-px tiles) means no perf concerns.
- **Mask 0 disambiguation per grid model.** Dual-grid layouts erase on mask 0 (v0.1 behavior). Single-grid layouts optionally point `mask_slots[0]` at an isolated/lonely-tile slot; otherwise erase.
- **Surface ambiguous / missing / unrecognized slots** via `update_configuration_warnings()` so broken templates flag at edit time.

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | template-decoder-feasibility | standard | Given a greybox template PNG, when sampled per a fixed anchor + 3×3 majority rule, the decoded mask table matches the documented mask convention without hand-authored slot data | ✓ VALIDATED | decoder, layouts, image-sampling, gdscript-port-pending |
| 002 | blob47-decoder-generalization | standard | Decoder generalizes across template styles (alpha-encoded TT greyboxes + color-encoded dandeliondino silhouettes), tile sizes (16, 64 px), and mask topologies (corner-only, edge-only, blob47), with the unified "not-transparent-not-white = bit set" rule | ✓ VALIDATED | decoder, blob47, dandeliondino, color-encoding, tile-size, gdscript-port-pending |
