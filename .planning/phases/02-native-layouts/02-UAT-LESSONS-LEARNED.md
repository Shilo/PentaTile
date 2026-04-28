# Phase 2 UAT — Lessons Learned

**Status:** retrospective written 2026-04-28 after the UAT bug-hunting cycle that produced commits `7cffd73` through `205fb67` (≈10 commits over ~24 hours of session time).

This document is for future-Claude (and future-Shilo) so the next phase doesn't repeat the same mistakes. It pairs with `CLAUDE.md` § Test Methodology and the `feedback_visual_testing.md` / `feedback_root_cause_discipline.md` memories.

---

## What happened (timeline)

Phase 2 was code-complete at commit `6553380` ("fix(02): slot 0 = single BL-quadrant for ALL Penta modes"). 9 tests green. UAT began — and a single-paragraph user complaint cycled through the following bug classes over ~10 commits:

1. **Bitmask greybox plus-pattern (commits before this retro)** — bundled `*.png` greyboxes drew center+arms silhouettes. Adjacent painted cells had transparent corners → visible dark squares between cells. Fixed by switching to corner-cut design. (`ef46977`)
2. **Corner cuts in wrong place** — corner-cut greyboxes left transparent 16×16 at outer region corners. User said tiles must be "entirely full in given bounds." Switched to solid 32×32. (`9183d07`)
3. **Min3x3 painted region too big** — solid greybox + lossy 9-tile dispatch meant single-bit-mask "background extension" cells (mask=1/2/4/8 around the painted region) rendered as solid full tiles, growing the visual region by a full cell on each side. Fixed by single-bit-mask null in Min3x3. (`bee97d7`)
4. **Penta-style rounded corners didn't match Min3x3** — actually misdiagnosis: Penta has clean rectangles, not rounded corners. Reverted greyboxes to solid + moved fix to layer level (`_paint_via_layout` skips non-logic-painted single-grid cells). (`a9d9716`)
5. **Wang2Corner partial-quadrant artifacts** — Wang2Corner is single-grid but inherited DualGrid16's atlas (partial-quadrant fills designed for dual-grid composition). Single-grid can't compose those. Fixed by giving Wang2Corner its own solid 32×32 atlas. (`022af2e`)
6. **1×1, 1×N lines didn't render** — `mask=0` short-circuit + single-grid `mask_to_atlas` returning null for mask=0 dropped isolated cells and 1×N lines (especially Wang2Corner where straight lines have no diagonals). Fixed by gating mask=0 short-circuit on `is_dual_grid` + dispatching mask=0 to default atlas in all 3 single-grid layouts. (`81813cd`)
7. **Penta + user's `penta_tile_ground.tres` → orange bleed in hole** — artist drew an inner-corner outline at col 8 rows 1-7 of slot 3, INSIDE the canonical TR-cut quadrant. Penta's rotation flags mapped these source pixels to the hole-facing side at each of 4 inner corners (4 × 7 = 28 stray pixels). Fixed by `_apply_canonical_silhouette()` enforcing per-archetype expected opaque region during synthesis. (`205fb67`)

## Pattern across all 7 bug classes

Every single one was a **rendering-pipeline bug** — synthesis or layer-level — that:

1. **Tests didn't catch initially** because tests verified dispatch semantics (mask N → atlas (c, r) with transform T), not rendered pixels.
2. **My fixes treated symptoms** in one subsystem when the cause lived elsewhere. I oscillated greyboxes through plus → cut → solid → cut → solid before realizing the fix belonged at the layer.
3. **The user's real fixture exposed bugs** the bundled greyboxes hid. The `penta_tile_ground.tres` orange bleed only appeared on artist art, not on synthesized greyboxes.
4. **Each fix introduced regressions** because I lacked a comprehensive coverage matrix. After ≈5 cycles I added `comprehensive_bitmask_test.gd` (16 patterns × 5 layouts) and `penta_ground_hollow_test.gd` (user fixture); both immediately found the remaining 2 bug classes.

## Why the original tests didn't catch these

| Original test | What it asserted | What it missed |
|---|---|---|
| `paint_test` | basic paint → cell present | rendered pixels |
| `all_layouts_test` | mask → atlas dispatch matches table | rotation-bleed, partial-fill artifacts |
| `visual_render_test` | quadrant pattern matches mask bits | composition across cells, single-grid solidity |
| `strict_pixel_test` | individual tile pixel exactness | rendered region structural invariants |
| `layout_swap_test` | swap doesn't break dispatch | per-pattern coverage, hollow regions |
| `determinism_test` | re-runs identical | functional correctness |

None of them composed the full painted region into a virtual canvas and asserted bbox / hole / extension invariants. None of them painted patterns other than rectangles. None of them used a real artist's `tile_set`. All 6 missing dimensions correlated with the bug classes above.

## Tests that actually closed the gap

Added during the UAT cycle:

- **`bitmask_bounds_test.gd`** — per-slot expected silhouette pixel-by-pixel verification of every bundled greybox. Catches generator drift.
- **`all_layouts_swap_pixel_test.gd`** (gradually fortified) — added: edge-continuity (≥80% opacity at painted-neighbor edges), interior coverage (mask=15 ≥ 80%), bbox bounds (no cells outside user-painted), per-cell solidity (single-grid 100% opaque).
- **`comprehensive_bitmask_test.gd`** — pattern × layout matrix (16 × 5 = 80 combos), each verifying: every painted cell renders, single-grid solidity, dual-grid sanity opacity, no out-of-bounds cells, opaque bbox matches user-painted bounds.
- **`penta_ground_hollow_test.gd`** — uses the actual `penta_tile_ground.tres`, paints the UAT hollow ring, asserts opaque bbox + hole emptiness. Caught the `_apply_canonical_silhouette` requirement.

The combination of all four catches every bug class above. **Stashing each fix and re-running confirms each test fails on the broken code.** That's the gold standard.

## Methodology for future visual-rendering work

When a future phase adds a new layout, modifier, or rendering feature:

1. **Before writing the code, write the tests.**
   - A pattern × layout matrix variant (extend `comprehensive_bitmask_test`).
   - A fixture-based test using a real `tile_set` that exercises the feature.
   - Bbox + structural invariants (opaque region, hole emptiness if applicable).
2. **When a UAT bug is reported:**
   - Reproduce locally with the user's fixture and paint pattern. Don't guess.
   - Save rendered output as PNG (`Image.save_png("user://...")` + `Read` tool).
   - Trace the full pipeline (`_paint_via_layout` → `_synthesize_slot_image` → `_extract_tile_image` → atlas blit → render transform) BEFORE writing a fix. The bug lives at one stage; pick by evidence.
   - Write a test that fails on the bug. Stash the planned fix, confirm test fails. Apply fix, confirm test passes.
3. **When fixes cascade (each one breaks something else):**
   - The mental model is wrong. Stop. Read the codebase fresh. Reset assumptions.
   - Don't ship 5 patches in a row hoping to converge.
4. **For Penta specifically:**
   - Pixels in canonical "cut" quadrants of authored slots WILL bleed into adjacent painted cells via rotation transforms. `_apply_canonical_silhouette` must run on every authored slot.
   - The 5 archetypes' canonical opaque regions are: IsolatedCell=BL only, Fill=full, Border=bottom half, InnerCorner=full minus TR, OppositeCorners=TL+BR diagonal.
5. **For single-grid layouts:**
   - Only logic-painted cells render. The layer's `_paint_via_layout` enforces this.
   - mask=0 must dispatch to a default atlas slot — null returns drop isolated cells and 1×N lines.
   - Atlases must be fully solid 32×32 (single-grid can't compose partial fills).
6. **For dual-grid layouts:**
   - Display cells extend beyond painted logic region by half a tile, but opaque pixels stay within painted-cells × tile_size bounds (perimeter cells fill INNER quadrants).
   - Don't try to make single-grid match dual-grid by adding cuts to the silhouette — fix at the layer level instead.

## Final test inventory (12 tests, all green at commit 205fb67)

```
paint_test
all_layouts_test
visual_render_test
strict_pixel_test
penta_one_mode_test
auto_strip_axis_test
layout_swap_test
all_layouts_swap_pixel_test     ← strengthened during UAT
bitmask_bounds_test              ← added during UAT
comprehensive_bitmask_test       ← added during UAT
penta_ground_hollow_test         ← added during UAT
determinism_test
```

The 4 marked tests above are the ones that catch UAT-class bugs. Future visual features should add equivalents.

## Cross-references

- Memory: `feedback_visual_testing.md`, `feedback_root_cause_discipline.md`
- CLAUDE.md: § Critical Pitfalls items 8–10, § Test Methodology
- Code: `addons/penta_tile/penta_tile_synthesis.gd::_apply_canonical_silhouette`, `addons/penta_tile/penta_tile_map_layer.gd::_paint_via_layout` (single-grid logic-painted gate + dual-grid mask=0 short-circuit)
