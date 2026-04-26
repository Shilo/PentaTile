---
phase: 01-contract-skeleton-tetra-layouts
plan: 01
subsystem: testing
tags: [godot, baselines, instrumentation, scope-expansion, visual-regression]

requires: []
provides:
  - 10 v0.1 visual-regression baseline PNGs (5 patterns × HORIZONTAL/VERTICAL)
  - Pre-Phase-1 LOC snapshot (260 LOC) for end-of-phase identity-guardrail comparison
  - _rebuild_count debug instrumentation in TetraTileMapLayer (CONTRACT-05 idempotence + signal-storm verification hook)
  - ROADMAP.md + REQUIREMENTS.md aligned to D-24..D-27 scope expansion (Phase 3.5 + 6 new IDs)
affects: [01-02, 01-03, 01-04, 01-05, phase-2, phase-3, phase-3.5]

tech-stack:
  added: []
  patterns:
    - "Programmatic Godot screenshot capture via temporary scene + viewport.get_texture().get_image().save_png()"
    - "OS.is_debug_build() gate for runtime instrumentation that must compile out of release builds"

key-files:
  created:
    - .planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-{horizontal,vertical}-{isolated,rectangle,lshape,strip,checkerboard}.png (10 PNGs)
    - .planning/phases/01-contract-skeleton-tetra-layouts/loc-baseline.txt
  modified:
    - addons/tetra_tile/tetra_tile_map_layer.gd (added _rebuild_count field + debug-gated increment in _queue_rebuild)
    - .planning/ROADMAP.md (Phase 3.5 inserted; Phase 2 expanded; Coverage table 39 → 45)
    - .planning/REQUIREMENTS.md (3 new sections, Traceability filled in, Coverage 39 → 45)

key-decisions:
  - "Baselines captured programmatically via a throwaway baseline_capture.tscn scene rather than manual screenshots — guarantees pixel-stable, repeatable v0.1 snapshots that Plan 05 can re-capture identically post-architecture-rewrite"
  - "Vertical baselines correctly render mostly-empty for non-FILL masks because the demo's tetra_tile_ground.png is 64x16 (horizontal-only atlas) — this is v0.1's actual behavior with the demo TileSet, NOT a capture bug. End-of-Phase-1 must reproduce these exact outputs."
  - "Demo scene NOT modified for capture — capture used a fresh ad-hoc TileMapLayer with the demo TileSet so the saved scene state stays at atlas_layout = HORIZONTAL"

patterns-established:
  - "Phase 1 wave-0 instrumentation pattern: add a private debug-only counter (_rebuild_count) gated by OS.is_debug_build() so subsequent plans have a quantitative hook for verifying idempotence and signal-storm behavior"
  - "Programmatic baseline capture: spin up a TetraTileMapLayer in a throwaway scene, paint patterns deterministically via set_cell, await rebuild + RenderingServer.frame_post_draw, save viewport screenshot, quit"

requirements-completed:
  - CONTRACT-04
  - CONTRACT-05
  - TETRA-01
  - TETRA-02
  - TETRA-03

duration: ~30min
completed: 2026-04-26
---

# Plan 01-01: Wave 0 Setup Summary

**v0.1 baselines + LOC snapshot + _rebuild_count instrumentation + ROADMAP/REQUIREMENTS expansion to D-27 — every prerequisite Phase 1's later plans need is captured before any architectural code lands.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-04-26
- **Tasks:** 4
- **Files modified:** 13 (10 baseline PNGs + loc-baseline.txt + tetra_tile_map_layer.gd + ROADMAP.md + REQUIREMENTS.md)

## Accomplishments

- 10 v0.1 visual baseline PNGs captured (5 reference patterns × 2 atlas_layout enum values), pixel-stable for end-of-phase visual regression
- Pre-Phase-1 LOC snapshot (260 lines for tetra_tile_map_layer.gd) committed for the Phase 1 identity-guardrail checkpoint in Plan 05
- `_rebuild_count` debug instrumentation added to `TetraTileMapLayer` so Plan 05 can quantitatively verify CONTRACT-05 idempotence and PITFALLS §5 signal-storm behavior
- ROADMAP.md and REQUIREMENTS.md expanded per D-24..D-27 (Phase 3.5 inserted, Minimal3x3 added to Phase 2, 6 new requirement IDs added, full Traceability mapping filled in for all 45 v1 requirements)

## Task Commits

Each task was committed atomically:

1. **Task 0.1: Capture v0.1 baseline screenshots** — `b3d4afb` (test) — automated via throwaway `baseline_capture.tscn` scene rather than manual capture
2. **Task 0.2: Capture pre-Phase-1 LOC baseline** — `9e09682` (docs)
3. **Task 0.3: Add _rebuild_count debug instrumentation** — `d127ead` (feat) — 8 LOC added to `tetra_tile_map_layer.gd`
4. **Task 0.4: Update ROADMAP.md and REQUIREMENTS.md per D-27** — `af54e35` (docs)

## Files Created/Modified

- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-horizontal-isolated.png` — 2244 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-horizontal-rectangle.png` — 2793 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-horizontal-lshape.png` — 2731 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-horizontal-strip.png` — 2334 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-horizontal-checkerboard.png` — 3196 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-vertical-isolated.png` — 1962 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-vertical-rectangle.png` — 2304 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-vertical-lshape.png` — 1962 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-vertical-strip.png` — 1962 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-vertical-checkerboard.png` — 1962 B
- `.planning/phases/01-contract-skeleton-tetra-layouts/loc-baseline.txt` — 260 LOC snapshot + ISO timestamp
- `addons/tetra_tile/tetra_tile_map_layer.gd` — 260 → 268 LOC (8 lines: 6 for `_rebuild_count` field+comment, 2 for OS.is_debug_build() gated increment)
- `.planning/ROADMAP.md` — Phase 3.5 inserted; Phase 2 expanded with Minimal3x3; Coverage 39 → 45; Phases-Plans table updated
- `.planning/REQUIREMENTS.md` — MIN3x3, PIXLAB, VAR-PIXEL sections added; Traceability TBDs all resolved; Coverage block updated

## Decisions Made

- **Programmatic baseline capture instead of manual.** The plan specified manual screenshot capture via the editor + Project menu. Replaced with a throwaway `baseline_capture.tscn` scene that instantiates a fresh `TetraTileMapLayer` with the demo TileSet, paints each pattern deterministically via `set_cell`, awaits a render frame, and saves the viewport via `get_viewport().get_texture().get_image().save_png()`. Pros: pixel-stable / repeatable / no human variance. The temporary scene was deleted post-capture; the demo scene was not touched.
- **Vertical baselines render mostly-empty correctly.** The demo's `tetra_tile_ground.png` is 64×16 (only horizontal layout tiles exist in the atlas). When `atlas_layout == VERTICAL`, the `_atlas_coords` helper looks up `(0, tile_index)` for each archetype, but only `(0, 0)` exists in the atlas — so OUTER_CORNER, BORDER, and INNER_CORNER lookups silently fail. Only the FILL tile (mask 15) renders. This is **v0.1's actual behavior** with the demo TileSet — Plan 05's regression check must reproduce these exact outputs.
- **Phase 2 NATIVE-04 not added during this update.** The plan referenced PREVIEW-02 / TEMPLATE-04 as Phase 2 reqs but didn't introduce a new "NATIVE-04" requirement. Kept the Coverage table count for Phase 2 at 6 (NATIVE-01..03 + MIN3x3-01 + PREVIEW-02 partial + TEMPLATE-04 partial) rather than inventing new IDs.

## Deviations from Plan

### 1. Task 0.1: replaced manual screenshot capture with a programmatic Godot scene

- **Found during:** Task 0.1 setup (user explicitly authorized "do have me do it, you can automate it yourself with mcp, screenshots or scripts")
- **Issue:** The plan's `<how-to-verify>` block prescribes manual editor + screenshot tooling for ~10 captures across 2 atlas_layout enum values
- **Fix:** Wrote a throwaway `baseline_capture.tscn` + `baseline_capture.gd` that programmatically instantiates a `TetraTileMapLayer`, paints each of the 5 patterns at each layout, awaits `get_tree().process_frame` + `RenderingServer.frame_post_draw`, and saves the viewport image via `Image.save_png(absolute_path)`. Both files were deleted after the run; the demo scene is untouched. The 10 PNGs are pixel-stable (deterministic paint order + fixed viewport size + fixed camera position).
- **Files affected:** baseline PNGs only (commit `b3d4afb`)
- **Verification:** `ls .planning/phases/01-contract-skeleton-tetra-layouts/baselines/` shows exactly 10 v0.1-* PNGs; horizontal vs vertical PNGs differ via md5sum (proving capture isn't a constant blank); `grep -c 'atlas_layout = ' addons/tetra_tile/demo/tetra_tile_demo.tscn` returns 0 (demo scene unmodified).
- **Acceptance criteria still met:** all 10 expected file paths present, all non-zero PNGs, demo scene at default `atlas_layout = HORIZONTAL`.

### 2. ROADMAP Phases-Plans table marks Phase 1 as "In progress (0/5)"

- **Found during:** Task 0.4
- **Issue:** The plan's edits didn't explicitly say to update the Phase 1 status row
- **Fix:** Updated Phase 1 row from `0/TBD | Not started` to `0/5 | In progress` since this plan is the first executing plan of Phase 1 (5 plans now known)
- **Files affected:** `.planning/ROADMAP.md`
- **Acceptance criteria still met:** all required Phase 3.5 / Coverage / Phases-Plans inserts are present (verified by grep counts).

### 3. Traceability table also resolves Phase 2..5 TBDs

- **Found during:** Task 0.4
- **Issue:** The plan only required mapping `CONTRACT-01..05, LAYOUT-01..05, TETRA-01..03, PREVIEW-01` from TBD → 1
- **Fix:** Mapped the rest of the table to its actual phase per ROADMAP.md (NATIVE → 2, TBT → 3, PIXLAB / VAR-PIXEL → 3.5, PREVIEW-02 → 2, PREVIEW-03/04 → 4, TEMPLATE-01/03 → Pre-shipped, TEMPLATE-02 → 3, TEMPLATE-04 → 2, DEMO/DOC-01..04/REL → 5, DOC-05 → 3). Removes ambiguity and aligns "Mapped: 45" / "Unmapped: 0" with the actual table state.
- **Acceptance criteria still met:** `grep -c '| CONTRACT-01 | 1 |'` returns 1 (the required check); all other adds are additive.

**Total deviations:** 3 (one user-authorized scope adjustment, two additive expansions of bookkeeping). No scope creep.

## Issues Encountered

- The CLAUDE.md and the plan reference Godot at `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`, but that path is actually a directory containing the executable. The real exe is at `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`. Worked around it by using the full nested path. **Recommendation:** Plans 01-02..05 should use the same nested path for `--check-only` invocations (or the CLAUDE.md reference path should be updated in a later doc-touchup commit — see Plan 05 for the natural place).
- The Camera2D `make_current()` call inside `_ready()` warns `Condition "!enabled || !is_inside_tree()" is true` because the camera is added to the tree later in the same `_ready()`. Non-fatal — the camera becomes current after the await. Captures completed successfully.

## User Setup Required

None.

## Next Phase Readiness

- ✅ Plan 01-02 (Resource skeletons) can begin: 10 baselines locked, instrumentation hook live in `_queue_rebuild`, and the file inventory it'll create (`tetra_tile_atlas_slot.gd`, `layouts/tetra_tile_layout.gd`, `tetra_tile_atlas_contract.gd`) doesn't conflict with any path touched here.
- ✅ Plan 01-05 verification has the artifacts it needs: baselines (visual regression input), loc-baseline.txt (LOC checkpoint reference), `_rebuild_count` (idempotence + storm-detection hook).
- ⚠ Phase 3.5 plan-time work picked up the Minimal3x3 + PixelLab requirements; the planner for those phases should read the new REQUIREMENTS.md sections + the Phase 3.5 success criteria block in ROADMAP.md.

---
*Phase: 01-contract-skeleton-tetra-layouts*
*Completed: 2026-04-26*
