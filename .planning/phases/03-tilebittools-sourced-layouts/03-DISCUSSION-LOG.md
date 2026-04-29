# Phase 3: Public-Convention Layouts (Blob47 + Tilesetter) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 03-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 03-tilebittools-sourced-layouts (slug pending rename to `03-public-convention-layouts`)
**Areas discussed:** TBT workflow + ATTRIBUTION + PNGs, 8-bit Moore mask convention, Mask 0 + out-of-table dispatch, Single-grid vs dual-grid per layout

---

## Pre-discussion area selection

| Option | Description | Selected |
|--------|-------------|----------|
| TBT workflow + ATTRIBUTION + PNGs | TBT data acquisition, decoding, attribution, greybox PNG generation | ✓ |
| 8-bit Moore mask convention | First-time-in-PentaTile 8-bit mask bit ordering for the 47-blob layouts | ✓ |
| Mask 0 + out-of-table dispatch | TilesetterWang15 stray fill, 47-blob 256→47 collapse, Pitfall #9 mitigations | ✓ |
| Single-grid vs dual-grid per layout | is_dual_grid() answer per new layout + pipeline reuse | ✓ |

**User's choice:** All four areas selected. **User's added context (verbatim):** *"TileBitTools's source code is here: C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools . this product is abandoned and 3 years stale source code, but it's still using Godot 4 and it may have designs and features that may inspire PentaTile to be better. Edit the plan to fully read the source code and research and compare with PentaTile and TileMapDual and figure out if theres any other implementations and designs taht will be of use for PentaTile."*

**Effect on discussion:** local TBT source path verified at `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\` (LICENSE, README.md, plugin.cfg, plugin.gd, inspector_plugin.gd, controls/, core/, examples/, templates/ all present). Folded into Area 1 as "deep TBT source-code audit" sub-question and ultimately as Wave 0 deliverable `03-TBT-DEEP-AUDIT.md` (D-84).

---

## Area 1 — TBT workflow + ATTRIBUTION + PNGs

### Q1.1 — How should we handle TBT source artifacts within the PentaTile repo?

| Option | Description | Selected |
|--------|-------------|----------|
| Vendor 3 .tres + LICENSE into .planning/ | Copy ONLY the 3 needed .tres + LICENSE into .planning/research/tbt-vendored/. Phase 3 self-contained. (Recommended) | ✓ (initial) |
| Reference local clone only | Phase 3 docs reference C:\Programming_Files\... but PentaTile repo holds nothing. | |
| Vendor full TBT addon under .planning/research/ | Copy entire ~3,800-LOC addon. Self-contained for the deep-audit task too. | |

**User's choice:** Vendor 3 .tres + LICENSE.
**Subsequent override:** SUPERSEDED by user policy in Q1.4 — no .tres vendoring, no decoding. See D-73.
**Notes:** Initial answer was the recommended option, but a stronger policy emerged in Q1.4 that overrode this choice. Final state: nothing from TBT enters the PentaTile repo.

### Q1.2 — How should the .tres peering bits get turned into GDScript mask→atlas tables?

| Option | Description | Selected |
|--------|-------------|----------|
| One-shot Python decoder script | _decode_tbt_templates.py reads .tres, walks _tiles dict, decodes peering bits → mask, writes hard-coded const dicts into each layout. (Recommended) | ✓ (initial) |
| Hand-decoded const dicts | Plan-phase produces tables manually from .tres files. | |
| Runtime decode from shipped .tres | Ship .tres files inside addons/. Adds runtime cost + license-redistribution surface. | |

**User's choice:** One-shot Python decoder script (recommended).
**Subsequent override:** SUPERSEDED by user policy in Q1.4 — no decoder script needed because no .tres is ever read. See D-73.
**Notes:** The decoder approach is technically clean (PentaTile-authored output, no code copied from TBT) but the no-data-lift policy makes it irrelevant — slot tables come from each format's own primary reference, not from TBT's encoding.

### Q1.3 — Scope for the user-requested 'read TBT source + compare vs PentaTile + TileMapDual' research deliverable?

| Option | Description | Selected |
|--------|-------------|----------|
| Full audit → 03-TBT-DEEP-AUDIT.md | Wave 0 research artifact reading full ~3,825 LOC. Structured ADOPT/PARTIAL/REJECT table cross-referenced against TileMapDual. (Recommended — user explicitly asked) | ✓ |
| Targeted audit on 3 specific subsystems | Read only what touches Phase 3's transcription work; skip UI / inspector / save dialog. | |
| Skim + flag-then-defer | Quick pass; capture obvious patterns as backlog ideas without structured artifact. | |

**User's choice:** Full audit → 03-TBT-DEEP-AUDIT.md.
**Notes:** D-84 elevated to Wave 0 deliverable. The audit produces only ideas/recommendations; per D-73 no TBT code or data is lifted. If the audit surfaces a pattern worth folding into Phase 3 itself (e.g., a clean way to declare 8-bit Moore conventions), Wave 0 ordering means we don't have to retrofit later.

### Q1.4 — Given the no-code-copy policy (only data is transcribed), how thorough should ATTRIBUTION.md be?

| Option | Description | Selected |
|--------|-------------|----------|
| Full — license body + per-file data map | Full ATTRIBUTION.md with TBT identity, commit hash, MIT body, per-file source map, no-code-copy clause. (Recommended given Q1.1+Q1.2 picks) | |
| Lean — link license, omit body | Smaller diff; legally defensible since URL is permanent. | |
| Per-layout doc-comments only | No standalone ATTRIBUTION.md. Conflicts with TBT-04 / DOC-05. | |

**User's choice (verbatim):** *"I still dont understand this need. We should be only using TBT as an inspiration. and then looking at Blob, Tilesetter and any other format we need and implement it ourselves. No attribution required. No copying required."*
**Effect:** Established the harder policy that supersedes Q1.1 and Q1.2. NO data lift, NO code lift, NO attribution. Each layout sourced from the format's own primary reference. Captured as D-73 (TBT engagement policy) and cross-session memory `feedback_no_competitor_code_copy.md`.
**Notes:** This decision rippled across the entire Phase 3 scope. ROADMAP TBT-04 + REQUIREMENTS DOC-05 were earmarked for rewrite/deletion (Q1.7 follow-up).

### Q1.5 — Where does PentaTileLayoutBlob47Godot's slot table come from? (follow-up after Q1.4 reset)

| Option | Description | Selected |
|--------|-------------|----------|
| BorisTheBrave 47-blob reference | boristhebrave.com canonical 47-tile blob convention. Long-standing community reference. (Recommended) | ✓ |
| Godot 3 docs (3x3 minimal autotile) | Godot 3's original documentation; persists on wayback + community wikis. | |
| Defer to plan-phase research | Plan-phase agent picks the most authoritative reference; surfaces ambiguity. | |

**User's choice:** BorisTheBrave 47-blob reference.
**Notes:** D-74. The "Godot" suffix in the layout name reflects "the convention common in the Godot ecosystem," whose canonical mathematical description is BorisTheBrave's.

### Q1.6 — Where do PentaTileLayoutTilesetterWang15 + PentaTileLayoutTilesetterBlob47 slot tables come from?

| Option | Description | Selected |
|--------|-------------|----------|
| User exports from Tilesetter | User runs Tilesetter, exports Set View, sends slot order. Authoritative; one-time effort. | |
| Plan-phase web research | Plan-phase searches Tilesetter docs/forum/tutorials. May surface enough; risks transcription error. | ✓ |
| Defer Tilesetter layouts to v0.3+ | Drop both from v0.2 entirely; ship only Blob47Godot in Phase 3. | |

**User's choice:** Plan-phase web research.
**Notes:** D-75. Plan-phase MUST surface the gap explicitly if research is inconclusive (D-86). Three fallback options (user runs Tilesetter / defer / accept "Empirical" tag) become the user-decision triggers if so.

### Q1.7 — Phase 3 title rename (current 'TileBitTools-Sourced Layouts' no longer fits)?

| Option | Description | Selected |
|--------|-------------|----------|
| Public-Convention Layouts (Blob47 + Tilesetter) | Describes what's shipped without TBT reference. (Recommended) | ✓ |
| Community Layouts | More concise; captures BorisTheBrave + Godot 3 + Tilesetter heritage. | |
| Keep 'TileBitTools-Sourced Layouts' with reframing | Confusing if read literally; not recommended. | |

**User's choice:** Public-Convention Layouts (Blob47 + Tilesetter).
**Notes:** D-72. Plan-phase MUST update ROADMAP.md, REQUIREMENTS.md, STATE.md, and optionally rename the directory.

### Q1.8 — Should ROADMAP TBT-04 + REQUIREMENTS DOC-05 (the ATTRIBUTION.md deliverables) be deleted or retained?

| Option | Description | Selected |
|--------|-------------|----------|
| Delete TBT-04 + DOC-05 entirely | Remove from REQUIREMENTS.md and ROADMAP.md. Cleanest. (Recommended) | |
| Convert into a brief 'Design Inspiration' note | 1-line README footnote acknowledging TBT as design inspiration. | ✓ |
| Defer to v0.3+ as backlog | Move to v2 backlog. | |

**User's choice:** Convert into 1-line README footnote.
**Notes:** D-72. Acknowledges TBT's role as inspiration without creating an ATTRIBUTION.md or claiming any lift. README footnote lives in `addons/penta_tile/README.md`.

### Q1.9 — How should the 3 new bitmask PNGs be generated?

| Option | Description | Selected |
|--------|-------------|----------|
| Extend _generate_bitmasks.py with greybox archetype drawers | Add new generator functions; matches TEMPLATE-03 pattern. Greybox-only, regenerable. (Recommended) | ✓ |
| Hand-author 3 PNGs in Aseprite/etc. | Faster initial write; breaks 'regenerable from source' rule. | |
| Use TBT example PNGs (Kenney CC0 art) | Adds Kenney attribution path; visual style mismatch; conflicts with no-lift policy. | |

**User's choice:** Extend _generate_bitmasks.py.
**Notes:** D-85. New helpers + 3 new gen_<slug>() functions. 47-blob silhouette helper specced by plan-phase.

---

## Area 2 — 8-bit Moore mask convention

### Q2.1 — Bit ordering for 8-bit Moore masks

| Option | Description | Selected |
|--------|-------------|----------|
| BorisTheBrave / cardinal-anchored (N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128) | Edges in low nibble (matches Wang2Edge), corners in high nibble. (Recommended) | ✓ |
| Corner-first (NE=1, SE=2, SW=4, NW=8, N=16, E=32, S=64, W=128) | Corners in low nibble (matches Wang2Corner). | |
| Clockwise from N (N=1, NE=2, E=4, SE=8, ...) | All 8 neighbors interleaved clockwise. Doesn't decompose cleanly into 4-bit precedents. | |
| Defer to plan-phase research | Plan-phase reads BorisTheBrave + similar references; picks consensus. | |

**User's choice:** BorisTheBrave / cardinal-anchored.
**Notes:** D-76. Both Blob47Godot and TilesetterBlob47 use the SAME ordering. Documented in each layout's class doc-comment.

### Q2.2 — Should PentaTile expose a shared 8-bit Moore helper or keep compute_mask local?

| Option | Description | Selected |
|--------|-------------|----------|
| Local per-layout compute_mask | Each layout writes its own compute_mask. Slightly duplicated (~10 lines × 2). Matches Phase 2 precedent. (Recommended) | ✓ |
| Shared helper on PentaTileLayout base | Add _compute_moore_mask to base. DRYs ~10 LOC; expands base API surface. | |
| Free function in penta_tile_layout.gd | Module-level static func. Awkward GDScript; uncommon in this codebase. | |

**User's choice:** Local per-layout compute_mask.
**Notes:** D-77. Avoids expanding the base class API beyond abstract virtuals + _pack_alternative.

### Q2.3 — How is the 256→47 collapse encoded?

| Option | Description | Selected |
|--------|-------------|----------|
| Algorithmic collapse function | BorisTheBrave's 'corner bit only matters if both adjacent edges set' rule. compute_mask reduces 8-bit → effective; mask_to_atlas dispatches via 47-entry dict. (Recommended) | ✓ |
| Full 256-entry lookup table | Pre-compute 256→slot dict at module load. Single dict lookup. | |
| Both — collapse used to GENERATE the 256 table at parse time | Algorithmic clarity + O(1) dispatch. Negligible boot-time work. | |

**User's choice:** Algorithmic collapse function.
**Notes:** D-78. Plan-phase MUST add a unit test enumerating all 256 masks → confirming every result hits a valid 47-entry dict slot.

---

## Area 3 — Mask 0 + out-of-table dispatch

### Q3.1 — TilesetterWang15: how is the 'stray fill' tile addressed?

| Option | Description | Selected |
|--------|-------------|----------|
| Reserved 16th slot at fixed coord | Convention: stray fill at Vector2i(5, 0); mask=0 returns that. Mirrors Tilesetter's documented workflow. (Recommended) | ✓ |
| Reuse a present-but-similar slot | mask=0 maps to fully-connected tile. Visually wrong; violates Pitfall #9 silhouette correctness. | |
| Fail loud via update_configuration_warnings | TilesetterWang15 doesn't support isolated cells; mask=0 returns null + warning. | |

**User's choice:** Reserved 16th slot at fixed coord.
**Notes:** D-79. Effective atlas grid 6×3. Plan-phase locks the exact stray-fill coord (suggested Vector2i(5, 0)). Bundled bitmask PNG includes pre-greyboxed stray-fill slot.

### Q3.2 — 47-blob layouts: when 8-bit mask falls outside 47 valid configurations after collapse?

| Option | Description | Selected |
|--------|-------------|----------|
| Collapse rule covers all 256 → 47 slots | Total — every 8-bit mask reduces to one of 47. No fallback needed. Verify with unit test. (Recommended) | ✓ |
| Reserve a 48th 'fallback' slot | Add unused atlas cell. Bloats atlas + bitmask PNG. | |
| Map unmapped → 'isolated' slot (mask=0) | Cheap fallback; visually wrong if collapse misses a case. | |

**User's choice:** Collapse rule covers all 256.
**Notes:** D-78 (algorithmic collapse) + D-80 (mask=0 maps to lonely-tile slot, which is one of the 47 valid configurations).

### Q3.3 — How is the universal 'mask=0 must dispatch' rule (Pitfall #9) implemented?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-layout decision baked into mask_to_atlas | Each layout's mask_to_atlas handles mask=0 explicitly. Matches Wang2Corner's pattern. (Recommended) | ✓ |
| Layer-level fallback if mask_to_atlas returns null | Adds layer-side complexity; conflicts with Phase 2 design (commit 81813cd). | |

**User's choice:** Per-layout decision baked into mask_to_atlas.
**Notes:** D-81. No layer-side null-handling added.

---

## Area 4 — Single-grid vs dual-grid per layout

### Q4.1 — PentaTileLayoutBlob47Godot.is_dual_grid()?

| Option | Description | Selected |
|--------|-------------|----------|
| Single-grid (logic-painted only) | Artist paints at logic cell. compute_mask samples 8 Moore neighbors. Matches BorisTheBrave's documented use. (Recommended) | ✓ |
| Dual-grid (2×2 corner-quadrant composition) | Mismatches the 47-blob convention. Reject. | |

**User's choice:** Single-grid.
**Notes:** D-82.

### Q4.2 — PentaTileLayoutTilesetterWang15 + PentaTileLayoutTilesetterBlob47.is_dual_grid()?

| Option | Description | Selected |
|--------|-------------|----------|
| Single-grid for both | Tilesetter exports tiles as whole-cell silhouettes. Artist paints at logic cell. (Recommended) | ✓ |
| Dual-grid for one or both | Mismatches Tilesetter's authoring model. Reject unless plan-phase research shows otherwise. | |

**User's choice:** Single-grid for both.
**Notes:** D-82.

### Q4.3 — Phase 2's PentaTileMapLayer single-grid pipeline reused as-is, or 47-blob-specific tweaks needed?

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse as-is; surface tweaks during planning | Plan-phase audits existing pipeline for 8-Moore compatibility (neighbor-affected radius, mask=0 path, erase semantics). (Recommended) | ✓ |
| Pre-spike before planning | Run Spike 004 to paint 47-blob test region against existing pipeline. | |
| Hand-design tweaks now | User sketches expected tweaks here. Risky without code in hand. | |

**User's choice:** Reuse as-is; surface tweaks during planning.
**Notes:** D-83 + D-87 (audit gate before Wave 1).

---

## Closing — Ready for context?

| Option | Description | Selected |
|--------|-------------|----------|
| I'm ready for context | Write CONTEXT.md + DISCUSSION-LOG.md, commit. (Recommended) | ✓ |
| Explore more gray areas | Surface additional gray areas. | |

**User's choice:** Ready for context.

---

## Claude's Discretion

- Exact filename slug for renamed phase directory (`03-public-convention-layouts` vs keeping `03-tilebittools-sourced-layouts`) — plan-phase decides.
- Exact stray-fill atlas coord for TilesetterWang15 (suggested `Vector2i(5, 0)`) — plan-phase locks.
- Whether the 47-blob silhouette helper in `_generate_bitmasks.py` is one function or composed.
- Wave breakdown structure.

## Deferred Ideas

- TBT-pattern adoption candidates (custom_tags vocabulary, Project Settings keys, color-blind palette) — flagged in `03-TBT-DEEP-AUDIT.md`; concrete adoption deferred to v0.3+ if/when justification surfaces.
- Editor inspector polish — explicit reject per CLAUDE.md identity guardrail.
- 256-tile blob support — explicit out-of-scope per REQUIREMENTS.md.
- Multi-terrain layouts — v2 backlog (MULTITERR-01..05).
