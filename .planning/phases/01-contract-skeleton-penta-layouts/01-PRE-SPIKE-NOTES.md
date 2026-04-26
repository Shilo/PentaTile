# Phase 1 — Pre-Spike Brainstorm Notes

**Captured:** 2026-04-25 during `/gsd-discuss-phase 1`, paused for spike.
**Status:** Discussion paused — spike must validate decoder feasibility before phase context can lock.

## Why we paused

User redirected Phase 1 mid-discussion: instead of just shipping the polymorphic `TetraTileAtlasContract` + `TetraTileLayout` Resource skeleton (with hand-authored `AtlasSlot[16]` data), they want users to author *custom layouts via template images* — the addon decodes the mask→atlas table from pixel data, eliminating primitive-data authoring.

## Locked priority (user-stated)

> Allow users to intuitively create a template AND its bitmask without authoring each primitive data value (no manual `AtlasSlot` records per slot).

## Decoder-mechanism candidates

### A. Silhouette quadrant sampling (one image)

For each slot, sample 4 fixed pixels (TL/TR/BL/BR for corner masks; N/E/S/W for edge masks). Opaque/colored = bit set. Greybox templates already follow this convention.

- ✓ One image, no extra concept
- ✓ Existing `addons/tetra_tile/templates/*.png` already conform
- ✗ Brittle for abstract art that doesn't fill quadrants
- ✗ Cannot disambiguate Wang2Edge vs Wang2Corner (same 4-bit topology, different bit names)

### B. Two-image system: visual template + decoder image — **RECOMMENDED**

Visual template = artist's authoring canvas (final art). Decoder image = parallel PNG, same grid/dimensions, declaring the mask via simple greybox/color hints. Decoder defaults to auto-generated from silhouette inference (Option A under the hood); user can override when visual diverges from quadrant conventions.

- ✓ Clean separation of concerns
- ✓ Supports any layout topology (corner / edge / blob / future)
- ✓ Auto-default keeps one-image UX; explicit decoder is a power-user override
- ✗ Two images per layout in the explicit case
- ✗ Decoder image format needs a small spec ("which pixels matter, what colors mean what")

### C. Reserved-region tagging (one image, hybrid)

Reserve a small pixel strip per slot for binary metadata.

- ✓ Explicit, no heuristics
- ✗ Visually ugly — metadata pixels on every tile
- ✗ Conflicts with how artists actually work (no spare pixel rows)

## Recommendation

**Option B with auto-generated decoder as default.** Default flow stays one-image-easy; explicit decoder is the escape hatch. Only mechanism that disambiguates Wang2Edge vs Wang2Corner without ambiguity.

## Sequencing — user chose: SPIKE FIRST

Other options surfaced (reserved):
- Expand Phase 1 to include the decoder
- Add Phase 1.5 after the architecture skeleton lands (LEAST preferred — primitive `AtlasSlot` authoring would ship then retire)

## Open questions the spike must answer

1. Can pixel sampling reliably distinguish "filled" from "empty" across grayscale, colored, and anti-aliased silhouettes? What's the threshold rule?
2. What sample points fit each layout topology?
   - Corner masks (Tetra / DualGrid16 / Wang2Corner): 4 corner pixels?
   - Edge masks (Wang2Edge): 4 edge midpoints?
   - Blob47 (8-bit): 4 corners + 4 edges?
3. How does the decoder distinguish Wang2Edge vs Wang2Corner? (Layout subclass declares its mask topology; decoder rule varies per topology.)
4. When does decoding run? Load-time + cached is the obvious answer — confirm.
5. Cache-invalidation: what triggers a re-decode? Texture reassignment, `Resource.changed`, or explicit method?
6. Performance: cost of one-pass decode of a 16-tile atlas. Almost certainly negligible; worth a quick `Time.get_ticks_usec` measurement.
7. Failure modes: ambiguous slots (two slots decode to the same mask), missing masks (no slot encodes mask 7), unrecognized pixel patterns. How does the layout report the gap to the user?

## Editor visualizer — parked

User mentioned a `@tool` editor script that visualizes layouts. `PROJECT.md` bans `EditorInspectorPlugin` polish. Lighter alternatives:
- `@tool`-mode `Control` that renders the decoded mask grid alongside the template
- Node-based visualizer in the demo scene

Defer this until decoder mechanism locks.

## What the spike should produce

A working `decode_mask_from_template(image: Image, topology: int) -> Array[int]` GDScript function that:
1. Reads the existing `addons/tetra_tile/templates/dual_grid_16.png`
2. Returns a 16-entry array where each entry is the mask integer that slot encodes
3. Matches the documented mask convention (TL=1, TR=2, BL=4, BR=8)

If the decode succeeds against the existing greybox template without hand-authored slot data, Option B is feasible and Phase 1 can absorb it.

---

*Spike will write findings to `.planning/spikes/<spike-id>/`. After `/gsd-spike-wrap-up`, re-run `/gsd-discuss-phase 1` — it will fold spike findings into the discussion automatically.*
