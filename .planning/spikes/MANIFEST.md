# Spike Manifest

## Idea

TetraTile v0.2 layout-library milestone — Phase 1 redirected from "ship the contract / layout / slot Resource skeleton with hand-authored slot data" toward "users author custom layouts via template images, with the slot table auto-decoded from pixel data — no primitive `AtlasSlot` Resource authoring required." Spikes validate the decoder mechanism before milestone scope locks.

See `.planning/phases/01-contract-skeleton-tetra-layouts/01-PRE-SPIKE-NOTES.md` for the brainstorm that produced this spike.

## Requirements

Design decisions emerging from spike findings — non-negotiable for the real build.

- **Layout subclass declares topology.** Auto-detection from a single image is fragile across slot-0 conventions (Tetra's slot 0 = mask 15, others' slot 0 = mask 0). The `TetraTileLayout` base owns a `topology()` virtual; auto-detect stays as a courtesy tooling fallback only.
- **Decoder uses 3×3 majority vote at geometric anchors.** Alpha-only opacity check (no brightness floor — outlines are excluded by anchor placement, not pigment). Resilient to anti-aliased user art and single-pixel anomalies.
- **Decode at Resource load, cache the result.** Sub-millisecond cost (250 µs for 16-tile atlas) means no perf concerns; caching is for code cleanliness.
- **Surface ambiguous / missing / unrecognized slots.** Validate the decoded slot table; report gaps via `update_configuration_warnings()` so broken templates flag at edit time.

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | template-decoder-feasibility | standard | Given a greybox template PNG, when sampled per a fixed anchor + 3×3 majority rule, the decoded mask table matches the documented mask convention without hand-authored slot data | ✓ VALIDATED | decoder, layouts, image-sampling, gdscript-port-pending |
