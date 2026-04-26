# Phase 1: Contract Skeleton + Tetra Layouts — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 01-contract-skeleton-tetra-layouts
**Areas discussed:** Slot data ownership, Decoder mechanism (template-driven authoring), Decoder validation against blob47, Dual-grid vs single-grid declaration, PixelLab format support, v0.2 scope expansion

---

## Initial gray areas presented

| Option | Description | Selected |
|--------|-------------|----------|
| Slot data ownership | Where the mask→atlas slot tables live (contract / layout / hybrid) | (superseded — pivot to template-driven authoring) |
| Null-contract fallback path | Lazy singleton vs retain v0.1 inline match as parallel `_resolve_slot_legacy` | (resolved via template-driven approach: lazy singleton wins) |
| `atlas_layout` enum disposition | Hard remove now / soft-deprecate / keep working | (resolved: hard remove in Phase 1) |
| Bundled `.tres` Resources | Ship ready-to-use defaults vs classes only | (resolved: ship default contract + Tetra H/V layout `.tres`) |

**User's choice / redirect:** *"I would like the user to be able to create custom resources and apply their own mask. […] Even cooler approach would be to dynamically apply the masking/bitmasking based on the template colors. […] The priority is to allow users to intuitively create a template and bitmasks without relying on creating each primitive data value."*

Result: pivoted away from "AtlasSlot[16] authoring" toward template-driven decoder. The original 4 gray areas resolved implicitly via this redirection.

**User feedback noted:** *"You didn't tell me what's recommended."* — corrected for subsequent question rounds.

---

## Decoder mechanism — three candidates

| Option | Description | Selected |
|--------|-------------|----------|
| A. Silhouette quadrant sampling (one image) | Sample 4 fixed pixels per slot; opaque = bit set | |
| B. Two-image system (visual + decoder) | Visual = artist's canvas; decoder = parallel PNG declaring the mask. Decoder defaults to auto-generated from silhouette inference. | ✓ (recommended; closest match to user's "even better" instinct) |
| C. Reserved-region tagging | Reserve a small pixel strip per slot for binary metadata | |

**User's choice:** "Spike the decoder (Recommended)" → spike 001 launched.

**Notes:** Path B chosen as the architectural target. Spikes 001 + 002 then validated the unified rule that the user articulated mid-session: *"any pixel that isn't transparent or white is a bit mask peer connection."*

---

## Spike 001 outcomes

| Probe | Result |
|-------|--------|
| Decode against shipped greybox templates (5 templates, 16-px tiles) | PASS — 56/56 slots correct |
| Anti-aliased painted-template robustness | PASS (after iteration: dropped brightness floor, added 3×3 majority vote) |
| Topology auto-detect | PASS with all-slots heuristic; layout subclass should declare topology in production |
| Ambiguous / missing / unrecognized failure modes | PASS — all detectable |
| Performance | sub-millisecond decode per atlas |

**Verdict:** VALIDATED. Locked: alpha-only sampling at geometric anchors, 3×3 majority vote, layout declares topology.

---

## Dual-grid vs single-grid distinction

**User raised:** *"Most of these layouts/templates will not need the Dual Grid (second tilemaplayer) system. So we probably need an export to check whether it needs a dual grid system or a way to automatically detect."*

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect from mask topology | Same template visuals serve both grid models — won't work | |
| Auto-detect from template visuals | Identical for both — won't work | |
| Explicit declaration on layout subclass (`is_dual_grid()` virtual) | Subclass owns the architectural decision | ✓ |

**Notes:** 3 of 8 v0.2 layouts dual-grid (Tetra H/V, DualGrid16); 5 of 8 single-grid (Wang2C, Wang2E, TWang15, Blob47G, TBlob47). PixelLab adds 2 more single-grid → 5 dual-grid : 6 single-grid in expanded scope.

**Architectural impact:** TetraTileMapLayer carries BOTH paint pipelines from Phase 1 onward — keeps Phase 2/3/3.5 as pure subclass adds.

---

## Spike 002 outcomes (after dandeliondino + Better Terrain + Godot terrain research)

Tested generalized decoder against 9 templates total (5 TetraTile greyboxes + 4 dandeliondino references including 47-tile blob).

| Result | Detail |
|--------|--------|
| All 9 templates decode correctly | 56 + clean PASS on dandeliondino sides/corners/corners_alt; 47/48 unique masks on blob47 with 2 mask-0 slots (semantic distinction: blank vs isolated) |
| Background detection unified | Single rule "transparent OR opaque-white = empty" handles both alpha-encoded greyboxes AND color-encoded silhouettes |
| Tile-size-invariant | Verified at 16 px and 64 px |
| Performance | ≤1.7 ms for 48-slot blob; sub-millisecond for everything else |

**Verdict:** VALIDATED. Locked the unified background rule and 8-anchor sampler.

**Key finding:** the dandeliondino blob47 has 2 cells decoding to mask 0 (blank vs isolated-tile). Resolved via D-14: dual-grid erases on mask 0; single-grid optionally points `mask_slots[0]` at the isolated tile.

---

## PixelLab support — discussion path

User initially asked for PixelLab support; I dispatched a docs-only subagent that concluded "no native format, just three exports." User corrected:

1. **First correction:** *"All the images are the native output directly. The export support we already cover but I also want to cover the native output to specifically support PixelLab if we don't already support it."*
2. **Second correction:** *"I was wrong about PixelLab native = template_corners. The previous images came from the web editor which formats to Tileset 15. The Aseprite plugin has DIFFERENT native visuals."*
3. **User direction:** *"I want to support Godot Minimal3x3 as well as PixelLab top down and side scroller outputs. […] We can reverse engineer how the outputs work, by reading the source code here: C:\\Users\\shilo\\AppData\\Roaming\\Aseprite\\extensions\\pixellab. Please run a subagent to verify the correct layout."*

**Subagent dispatch:** read Aseprite extension source code; documented the 8×8 atlas with hardcoded `tileset_output` / `tileset_output_side` cell-to-role tables. Identified one unknown: bit-to-corner mapping (Sprite-Fusion convention assumed but unverified).

**User's verification choice:** *"Generate + share one tileset (Recommended)"* → user supplied 16 PixelLab samples (7 top-down + 9 side-scroller, both PNG and JSON request settings).

---

## Spike 003 outcomes — PixelLab role-to-mask verification

| Probe | Result |
|-------|--------|
| Standard Sprite-Fusion convention test (role N = mask N) | FAILED — role 0 silhouette = mask 4 (BL inner), role 15 = mask 1 (TL inner) |
| Per-corner pixel coverage on cleanest top-down sample | Mapping discovered: `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]` |
| Cross-verification on cleanest side-scroller sample | Mapping IDENTICAL — 16/16 match |
| Full 16-sample sweep | 12 of 16 PASS; 4 partial (AI noise on single-corner masks, doesn't contradict mapping) |

**Verdict:** VALIDATED. Role-to-mask mapping locked. PixelLab native is single-grid 4-bit corner mask with variation banks (multiple cells per role).

**Variation insight:** PixelLab's own exporter does first-occurrence-only and discards duplicates. TetraTile reading the full 8×8 picks up free variation (28 variants of mask 15 in top-down; 16 of mask 0 + 13 of mask 15 in side-scroller).

---

## v0.2 scope expansion

User-confirmed direction: add 3 new layouts to v0.2.

| Layout | Phase | Reason |
|--------|-------|--------|
| `TetraTileLayoutMinimal3x3` | 2 | PixelLab "Tileset 3×3" export + RPG Maker A2 + legacy Godot 3.x |
| `TetraTileLayoutPixelLabTopDown` | 3.5 | PixelLab Aseprite native top-down |
| `TetraTileLayoutPixelLabSideScroller` | 3.5 | PixelLab Aseprite native side-scroller |

Plus minimal `variation_seed` wiring (Phase 3.5 prerequisite).

ROADMAP.md and REQUIREMENTS.md updates flagged for the planner — not Phase 1 implementation work, but planning prerequisite.

---

## Claude's discretion (areas where user said "you decide")

- File layout / folder structure for new `.gd` files
- Default `.tres` file naming conventions
- `Resource.changed` signal-storm coalescing details (preserve v0.1's `_queue_rebuild` pattern)
- `update_configuration_warnings()` exact warning copy

---

## Deferred ideas (noted during discussion, captured in CONTEXT.md `<deferred>` section)

- Editor visualizer (`@tool` Control rendering decoded mask grid)
- TileMapDual deep audit (user picked "PixelLab only, then conclude")
- Free-form atlas decoder for PixelLab (superseded by fixed-grid finding)
- Y-axis variation full machinery (`TileData.probability`)
- Top-tile support
- RPG Maker A2/A4 subtile composition
- Tiled / LDtk rule importers
- TetraBake / Tileset converter
- Multi-terrain transitions
- Shader fallback for diagonal compositing
