# Codebase Concerns

**Analysis Date:** 2026-04-26

## Overview

PentaTile is a young, focused addon with minimal scope (v0.1.0). The implementation is clean and well-researched. No critical bugs or security issues detected. Concerns are primarily about architectural limitations, performance unknowns, and future scalability.

---

## Tech Debt

**Fixed 4-tile atlas constraint:**
- Issue: The addon is hardcoded to exactly four tiles (Fill, Inner Corner, Border, Outer Corner). Extending to support different terrain types or visual variations will require architectural redesign.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 11-14, 182-185)
- Impact: Users cannot swap out atlases without rebuilding source code. No flexible terrain metadata system.
- Fix approach: Future roadmap includes optional "Y-axis variations" (atlas rows) and "PentaBake" (procedural composition). These are intentionally deferred until the 4-tile contract is proven in production.

**No persistent coordinate cache:**
- Issue: `_update_cells()` recalculates masks on-demand for affected cells rather than maintaining a cache of logic-grid state.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 67-83)
- Impact: On very large maps with frequent edits, recalculating masks for each changed cell could become a performance bottleneck. RESEARCH.md explicitly notes: "no persistent coordinate cache" to keep overrides lean.
- Fix approach: Benchmark on large maps (>10k cells). If needed, add optional state caching with careful cleanup to avoid memory leaks. Monitor `_update_cells()` performance first.

**Dual-layer composition for diagonals:**
- Issue: Two disconnected diagonal states (masks 6 and 9) require writing to two layers instead of one. This doubles the tile ops for those masks.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 129-140)
- Impact: Minor: Only masks 6 and 9 incur the overhead. The README acknowledges this as the deliberate cost of staying with four tiles instead of five.
- Fix approach: Roadmap mentions "Shader fallback: single-pass shader option for diagonal compositing." This is future work and optional.

---

## Known Issues

**None detected.**

The codebase has no TODO/FIXME/HACK/XXX/NOTE comments. All documented design decisions match the implementation.

---

## Fragile Areas

**Layer validity checks on every edit:**
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 199-202, 220, 244)
- Why fragile: `_primary_layer` and `_overlay_layer` are checked with `is_instance_valid()` on every single cell paint in `_update_cells()`. If an internal layer is deleted or becomes stale between frames, the code will silently recreate it. This is robust but depends on Godot's `_ready()` and internal layer lifecycle working correctly.
- Safe modification: Do not cache layer references across multiple `_update_cells()` calls. Keep the validity check pattern.
- Test coverage: No unit tests exist. Demo scene is functional but doesn't exercise layer deletion/recreation edge cases.

**Deferred rebuild() call:**
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 64, 260)
- Why fragile: `rebuild.call_deferred()` is used in `_ready()` and `_queue_rebuild()`. If `_ready()` is not called (e.g., node added to tree but never _ready), deferred rebuild will never fire and visuals won't exist.
- Safe modification: Ensure `PentaTileMapLayer` is always `add_child()`-ed before accessing visuals. The demo does this correctly.
- Test coverage: No test covers the case where a `PentaTileMapLayer` is created, configured, and used before `_ready()` completes.

**Atlas layout hard-coded in mask calculations:**
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 182-185)
- Why fragile: The enum `AtlasLayout.HORIZONTAL` vs `VERTICAL` is checked at paint time. If the export property is changed mid-play, subsequent paints will use the new layout but old visuals won't update until `rebuild()` is called. No automatic rebuild on layout change.
- Safe modification: Always call `rebuild()` after changing `atlas_layout`. The property setter does call `_queue_rebuild()`, so this is mitigated.
- Test coverage: Not tested: changing atlas_layout at runtime and verifying old cells repaint correctly.

---

## Performance Bottlenecks

**Mask calculation is O(1) per cell, but affects multiple layers:**
- Problem: Every changed logic cell marks four display cells as affected. Each affected display cell reads four neighboring logic cells to compute its mask.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 101-105, 155-165)
- Cause: Dual-grid sampling: a display cell is centered at the corner of four logic cells.
- Current impact: Minimal for small maps. On a 100x100 map with 100 random edits per frame, this is ~400 display-cell repaints with ~1600 logic-cell reads. Acceptable.
- Improvement path: For very large maps (>50k cells), consider:
  1. Batch edits into a single frame.
  2. Profile `_mask_at()` calls; consider memoizing if the same display cell is visited twice in one frame.
  3. Future: BVH or spatial hashing for affected-cell detection.

**No batching of visual layer updates:**
- Problem: Each affected display cell is painted individually in a loop.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 82-83)
- Cause: Godot's `TileMapLayer` batches draw updates internally, so individual `set_cell()` calls are not expensive. But the loop itself is O(affected_cells), which scales with map size and edit frequency.
- Current impact: Demo with ~100 cells and interactive painting is smooth. Production maps larger than 1000x1000 should be tested.
- Improvement path: Godot 4.6 batches updates at frame end automatically. No action needed unless profiling shows otherwise.

---

## Test Coverage Gaps

**No unit tests exist.**
- What's not tested: All core functions: `_update_cells()`, `_mask_at()`, `_paint_display_cell()`, layer creation/validity, property setters, `rebuild()`.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (entire file)
- Risk: High. A typo in mask bit positions (lines 157-164) would go unnoticed. A refactoring of layer sync logic (lines 217-233) could introduce subtle display bugs.
- Priority: High. Before 1.0 release, add unit tests for:
  1. Mask calculation for all 16 states.
  2. Correct tile/transform assignment for each mask (verify IMPLEMENTATION_PLAN.md table).
  3. Layer creation and cleanup.
  4. Property setters (atlas_source_id, atlas_layout, opacity, z_index, collision flags).

**No integration tests for runtime painting.**
- What's not tested: The interaction between `demo_runtime_painter.gd` and the map layer. Does painting persist? Does multi-layer composition actually render correctly?
- Files: `addons/penta_tile/demo/demo_runtime_painter.gd`, `addons/penta_tile/penta_tile_map_layer.gd`
- Risk: Medium. The demo runs successfully, but visual output is not automatically verified.
- Priority: Medium. Add:
  1. Visual regression tests (screenshot comparison).
  2. Serialize painted map state and verify it round-trips.

**No stress tests for large maps.**
- What's not tested: Performance with 1000+ cells, 10000+ cells, 100000+ cells. Edited cells. Runtime painting on large maps.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (performance-sensitive loops)
- Risk: Medium. Roadmap is silent on scaling limits.
- Priority: Medium. Before marketing as "lightweight," profile with large maps to document practical limits.

---

## Scaling Limits

**No documented map size limits.**
- Current capacity: Demo uses ~100 cells. No tests beyond that.
- Limit: Unknown. Likely bottleneck is Godot's `TileMapLayer` performance, not PentaTile's mask logic.
- Scaling path: Profile on a 200x200 map (~40k cells). If performance is acceptable, document the limits. If not, consider caching/chunking strategies.

**Dual layers double memory overhead for visuals.**
- Current capacity: For a 100x100 logic grid, two visual layers are created (~20k tile data total).
- Limit: Likely hits Godot's layer/draw-call limits before PentaTile's code is the bottleneck.
- Scaling path: Monitor memory and draw-call counts. If layers exceed 10, consider merging them or using a different rendering strategy.

---

## Godot Engine-Specific Concerns

**TileMapLayer visibility behavior:**
- Risk: RESEARCH.md and README both note that Godot may force cleanup when a TileMapLayer is set `visible=false`. PentaTile uses `self_modulate.a` on the *logic layer* to hide it instead.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (lines 248-251), README.md (line 101)
- Current mitigation: The logic layer is never hidden via the `visible` property.
- Recommendation: Document this constraint clearly. If a user manually sets the logic layer's `visible` to false, visuals will not follow. Add a guard or warning.

**_update_cells() performance caveat:**
- Risk: RESEARCH.md notes: "Implementing `_update_cells` may degrade performance." The override is marked @tool and runs in both editor and runtime.
- Files: `addons/penta_tile/penta_tile_map_layer.gd` (line 1, line 67)
- Current mitigation: The override is lean (no signal fanout, no persistent cache, no writes back to the same layer).
- Recommendation: Profile edit-time performance in the Godot editor on large maps. If the editor becomes sluggish, consider a deferred rebuild strategy or a "live preview" toggle.

**No autoloads or global state.**
- Risk: None. PentaTile is a pure class with no global dependencies.
- Current mitigation: N/A. Already clean.

---

## Dependencies at Risk

**No external dependencies.**

PentaTile depends only on Godot 4.6's native `TileMapLayer`, `TileSetAtlasSource`, and `Vector2i` APIs. No third-party packages. No version constraints beyond "Godot 4.6+".

- Godot 4.6 is stable and widely used.
- The `_update_cells()` virtual method and atlas transform flags are documented in official Godot 4.6 docs.
- No risk of deprecation in 4.7+ (virtual methods are stable API).

---

## Missing Critical Features

**Terrain transitions are not supported.**
- Problem: PentaTile only handles a single binary terrain (filled vs empty). No support for grass-to-dirt, water-to-land, or multi-terrain mosaics.
- Blocks: Users cannot create complex level layouts with multiple terrain types in a single map using one PentaTileMapLayer.
- Workaround: Use multiple PentaTileMapLayers, one per terrain type, offset in Z or space.
- Roadmap note: "Outer transition tile support" is listed as future work.

**No collision authoring tools.**
- Problem: Physics polygons must be manually defined in the TileSet. No procedural collision generation from visual tiles.
- Blocks: Users cannot quickly create platformer-friendly collision shapes without editing the TileSet directly.
- Workaround: Pre-author collision polygons in the demo TileSet and copy them.
- Roadmap note: "Collision tooling: research automatic collision generation and better collision presets" is future work.

**No editor autotile preview.**
- Problem: When editing in the Godot editor, the logic layer shows raw tiles, not the generated visuals.
- Blocks: Designers cannot see what the final map looks like until they export or play the game.
- Workaround: Use the demo scene to see live visuals. Toggle `logic_layer_opacity` to preview.
- Roadmap note: Intentionally deferred. TileMapDual supports this with editor integration; PentaTile's scope is intentionally narrow.

---

## Security Considerations

**No security-sensitive operations detected.**

PentaTile is pure gameplay code with no file I/O, networking, input validation beyond Godot's event handling, or user data handling. No secrets, API keys, or credentials in scope.

- Risk: Low. Suitable for open-source publication.

---

## Quality Notes

**Code clarity is high.**

- The implementation closely mirrors the IMPLEMENTATION_PLAN.md spec. The 16-state mapping is explicit in `_paint_display_cell()` (lines 116-152) and matches the plan's table.
- Naming is clear: `_mark_affected_display_cells()`, `_mask_at()`, `_set_visual_cell()`.
- The constraint of no persistent state or signal fanout makes the code easy to follow.

**Documentation is present but incomplete.**

- RESEARCH.md provides deep rationale (why 4 tiles, why dual-layer for diagonals, why V1 is square-grid only).
- README.md is thorough and includes a roadmap.
- IMPLEMENTATION_PLAN.md specifies the exact mask-to-tile mapping.
- Missing: In-code comments for the diagonal composition logic (lines 129-140) and the dual-grid offset (lines 155-165). Adding brief comments would help future maintainers.

**Demo is functional but limited.**

- `demo_runtime_painter.gd` works correctly for interactive painting.
- `demo_player.gd` is a simple platformer sprite with collision.
- Missing: Stress tests, edge cases (e.g., painting the same cell twice in one frame), performance benchmarks.

---

## Recommendations for Next Phases

1. **Before 1.0 release:** Add unit tests for all 16 mask states and property setters.
2. **Before 1.0 release:** Document map size limits and performance characteristics.
3. **Future (Y-axis variations):** Design a schema for atlas rows and implement tile-selection logic.
4. **Future (Shader fallback):** Profile diagonal composition; if overhead is measurable, implement a shader-based alternative.
5. **Future (Collision tooling):** Research auto-collision generation (e.g., marching squares on tile shape data).

---

*Concerns audit: 2026-04-26*
