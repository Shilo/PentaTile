# Phase 5 — Identity Audit

**Performed:** 2026-04-29
**PentaTile commit:** `905596c4e0c6d89b99abdfd32e84eef1f378ddf9`
**TileMapDual reference:** v5.0.2 (commit `9ff1e24f80be1816cfcd7aeec32800a699a94ccb`, dated 2026-01-03)
**Decision (per D-05-11):** **SHIP**

> The audit measures three independent axes (cumulative runtime LOC, public surface, hot-path complexity) and walks the anti-pattern register from CLAUDE.md "Identity Guardrails" and PITFALLS.md AP-1..AP-10. Per D-05-11 the audit is framed around hot-path minimalism and anti-pattern absence, not raw LOC delta. Per D-05-13 this is a developer-judgment prerequisite to the Phase 5 release run — NOT a CI gate (Plan D's release workflow does not check audit existence or LOC metrics).

---

## Axis 1 — Cumulative Runtime LOC

### PentaTile

Recipe (continuity from Phase 2/3/3.5/4 closes, recorded in STATE.md):

```bash
git ls-files 'addons/penta_tile/*.gd' 'addons/penta_tile/layouts/*.gd' \
  | grep -v 'tests/' \
  | grep -v 'demo/' \
  | xargs wc -l
```

Verbatim output:

```
   166 addons/penta_tile/layouts/penta_tile_layout.gd
   127 addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd
    64 addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd
   105 addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd
   510 addons/penta_tile/layouts/penta_tile_layout_penta.gd
   115 addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd
   118 addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd
    71 addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd
    65 addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd
    21 addons/penta_tile/penta_tile_atlas_slot.gd
   682 addons/penta_tile/penta_tile_map_layer.gd
   840 addons/penta_tile/penta_tile_synthesis.gd
  2884 total
```

Total: **2884** runtime LOC. (Matches Phase 4 close baseline — Plans 05-01 and 05-02 touch demo and docs only, runtime LOC unchanged.)

### TileMapDual v5.0.2

Recipe (adapted to TileMapDual's repo layout — runtime addon code lives under `addons/TileMapDual/`; the only other `.gd` file in the repo is `examples/rotating_light.gd`, which is excluded as an example):

```bash
cd /tmp/tmd
git ls-files 'addons/TileMapDual/*.gd' \
  | grep -v 'test' \
  | grep -v 'demo' \
  | grep -v 'example' \
  | xargs wc -l
```

Verbatim output:

```
    74 addons/TileMapDual/atlas_watcher.gd
    41 addons/TileMapDual/cursor_dual.gd
   164 addons/TileMapDual/display.gd
   104 addons/TileMapDual/display_layer.gd
    78 addons/TileMapDual/plugin.gd
    78 addons/TileMapDual/set.gd
   196 addons/TileMapDual/terrain_dual.gd
   126 addons/TileMapDual/terrain_layer.gd
   375 addons/TileMapDual/terrain_preset.gd
    76 addons/TileMapDual/tile_cache.gd
   170 addons/TileMapDual/tile_map_dual.gd
   408 addons/TileMapDual/tile_map_dual_legacy.gd
   175 addons/TileMapDual/tile_set_watcher.gd
    61 addons/TileMapDual/util.gd
  2126 total
```

Total: **2126** runtime LOC.

### Comparison

| Repo | Runtime LOC | Files | Notes |
|------|------------:|------:|-------|
| PentaTile | 2884 | 12 | 8 layouts + map layer + synthesis engine + base + slot resource |
| TileMapDual v5.0.2 | 2126 | 14 | Includes legacy v4.3 fallback (`tile_map_dual_legacy.gd` = 408 LOC) and a 375-LOC preset author-helper |
| Δ | +758 (PentaTile heavier by ~36%) | -2 | TileMapDual's bigger files (`tile_map_dual_legacy`, `terrain_preset`) carry concerns PentaTile doesn't have; PentaTile's bigger file (`penta_tile_synthesis.gd` = 840 LOC) carries one PentaTile uniquely needs (load-time 5-archetype synthesis). |

Per D-05-11: **LOC is reported as signal, not as a fail criterion.** The 758-LOC delta is real but PentaTile's biggest single file (`penta_tile_synthesis.gd`, 840 LOC) is the load-time synthesis engine that lets ONE..FOUR Penta modes ship without the user authoring 5 archetypes — that's a positive feature trade, not bloat. TileMapDual's biggest single file (`tile_map_dual_legacy.gd`, 408 LOC) is a Godot 4.3-compatibility fallback PentaTile chose not to write (Godot 4.6 baseline locked at project start, no compat shims per CLAUDE.md HARD RULE).

LOC is therefore SIGNAL not VERDICT — the verdict comes from Axis 3 (hot path) and the anti-pattern register.

## Axis 2 — Public Surface

### PentaTile

| Surface element | Count | Recipe |
|-----------------|------:|--------|
| `@export` properties | 15 | `grep -hcE '^@export' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd \| awk '{s+=$1} END {print s}'` |
| Public methods (`func [a-z]`) | 36 | `grep -hcE '^func [a-z]' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd \| awk '{s+=$1} END {print s}'` |
| `class_name`'d classes | 12 | `grep -hcE '^class_name ' addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd \| awk '{s+=$1} END {print s}'` |

Public methods on `PentaTileMapLayer` (the load-bearing user-facing API):
- `rebuild()` — force full re-dispatch

Public method surface on `PentaTileLayout` base + concrete subclasses (subclass virtuals; users implement these only when authoring custom layouts):
- `compute_mask(coord, sample_fn)` — 8 concrete impls (one per shipped layout) + abstract base
- `mask_to_atlas(mask, strip_index)` — 8 concrete + abstract base
- `is_dual_grid()` — 8 concrete + abstract base
- `resolve_display_strip(coord, sample_atlas_fn)` — abstract base default + Penta override
- `needs_synthesis()` — abstract base default + Penta override
- `get_fallback_tile_set()` — abstract base impl, no overrides
- Penta-specific: `resolve_active_mode(tile_set, source_id)`, `resolve_strip_modes(tile_set, source_id)`, `get_configuration_warnings_for(tile_set, source_id)`

Total: **36** public method definitions across 12 files (most are virtual overrides — the 5 user-facing virtuals appear 8× each, plus base abstracts and Penta extras).

Note on the count: the 36 figure inflates the apparent surface because virtual-method overrides count separately per subclass. The actual user-facing API surface is one method on `PentaTileMapLayer` (`rebuild()`) plus three virtual contracts on `PentaTileLayout` (`compute_mask`, `mask_to_atlas`, `is_dual_grid`) — about 4 LOAD-BEARING entry points total. The other 32 lines are subclass implementations of those virtuals.

### TileMapDual v5.0.2

| Surface element | Count | Recipe |
|-----------------|------:|--------|
| `@export` properties | 6 | same recipe applied to `addons/TileMapDual/*.gd` |
| Public methods | 38 | same |
| `class_name`'d classes | 14 | same |

Public methods on `TileMapDual` (the load-bearing user-facing API):
- `draw_cell(cell, terrain)` — paint a cell with a terrain id (parallel to `set_cell()`; this is the AP-5 surface PentaTile explicitly does not have)
- `get_cell(cell)` — read terrain id at cell

Plus public methods on supporting machinery (TileCache, TileSetWatcher, Display, DisplayLayer, TerrainDual, TerrainLayer, Set, plugin):
- `Display.update(updated)`, `DisplayLayer.update_tile(cache, cell)`, `DisplayLayer.update_tiles(cache, ...)`, `DisplayLayer.update_tiles_all(cache)`, `DisplayLayer.update_properties(parent)`, `DisplayLayer.reposition()`, `DisplayLayer.follow_path(cell, path)`
- `TileSetWatcher.update(tile_set)`, `.check_flags()`, `.check_tile_set(tile_set)` — the watcher API surface
- `TileCache.update(world, edited)`, `.xor(other)`, `.get_terrain_at(cell)` — the cache API surface
- `TerrainDual.read_tileset(tile_set)`, `.read_atlas(atlas, sid)`, `.read_tile(atlas, sid, tile)`, `TerrainLayer.apply_rule(terrain_neighbors, cell)` — the rule-trie API
- `Set.has`, `.insert`, `.remove`, `.clear`, `.union_in_place`, `.union`, `.diff_in_place`, `.diff`, `.xor_in_place`, `.xor` — collection helpers
- `tile_map_dual_legacy` exports 7 more public methods for v4.3 fallback

### Comparison

| Surface | PentaTile | TileMapDual | Observation |
|---------|----------:|------------:|-------------|
| `@export` | 15 | 6 | PentaTile is wider here — most are visual/collision toggles on `PentaTileMapLayer` (`logic_layer_opacity`, `visual_z_index_offset`, `generated_collision_enabled`, `logic_collision_enabled`, `atlas_source_id`) plus per-layout exports (`bitmask_template`, `description`, plus Penta's `axis` and `tile_count`). All are typed @exports, no advanced @export_group / @export_subgroup polish per the Identity Guardrails rule against EditorInspectorPlugin / inspector polish. |
| Public methods | 36 | 38 | Similar count; very different shape. PentaTile's are mostly virtual-override boilerplate (8 layouts × 3 virtuals = 24 of the 36). TileMapDual's are spread across **6 supporting classes** (Set, TileCache, TileSetWatcher, TerrainDual, TerrainLayer, DisplayLayer) — each adding API surface a user might (or might not) need to know about. |
| `class_name`'d classes | 12 | 14 | Comparable. PentaTile's 12 are: 1 layer node + 1 base layout + 8 concrete layouts + 1 atlas-slot resource + 1 synthesis utility. TileMapDual's 14 include several dedicated to internal machinery (Display, DisplayLayer, TerrainDual, TerrainLayer, TileSetWatcher, TileCache, AtlasWatcher, etc.) — the watcher/cache/display split is what makes its hot path deeper (see Axis 3). |

PentaTile's user-facing API is **narrower at the layer level** (1 public helper, `rebuild()`) but **wider at the layout level** (8 typed `@export` layouts + 3 virtual contract methods to override for custom layouts). TileMapDual's API is wider at the layer level (`draw_cell` + `get_cell`) and deeper at the machinery level (TileCache + TileSetWatcher + TerrainDual all expose methods).

**Identity-relevant detail:** TileMapDual exposes `draw_cell(cell, terrain)` as a public parallel-to-`set_cell()` API. CLAUDE.md "Identity Guardrails" rejects this pattern (parallel paint API) for PentaTile — confirmed absent (see Anti-Pattern Register Check below).

## Axis 3 — Hot-Path Complexity

### PentaTile per-cell paint path

File: `addons/penta_tile/penta_tile_map_layer.gd`

Verbatim trace from `_update_cells` to `set_cell`:

```
_update_cells(coords, forced_cleanup) [line 218]
  if forced_cleanup or tile_set == null: _clear_visual_layers; return [220-222]
  _sync_visual_layers() [224]
  if coords.is_empty(): rebuild(); return [225-227]
  active_layout = _resolve_layout() [229]
  source = _resolve_source_id() [232]
  for logic_cell in coords: _mark_affected_*_cells(affected, logic_cell) [239-243]
  for display_cell in affected.keys():
    _paint_via_layout(display_cell, active_layout, source, sample_fn) [245-246]
      → erase_cell(display_cell) [318]
      → if not is_dual_grid() and not sample_fn.call(display_cell): return [329-330]
      → mask = active_layout.compute_mask(display_cell, sample_fn) [332]
      → if is_dual_grid() and mask == 0: return [338-339]   (universal short-circuit per PITFALLS §4)
      → strip_index = active_layout.resolve_display_strip(display_cell, atlas_sample_fn) [342]
      → slot = active_layout.mask_to_atlas(mask, strip_index) [360]
      → _paint_with_slot(layer, slot, display_cell, source) [363]
        → layer.set_cell(display_cell, source, slot.atlas_coords, slot.transform_flags) [372]
```

**Depth: 4 stack frames** from `_update_cells` to `set_cell` (`_update_cells` → `_paint_via_layout` → `_paint_with_slot` → `set_cell` on the inherited `TileMapLayer`).

**Synthesis path is NOT in the per-cell hot path.** `PentaTileSynthesis._ensure_synthesized_tile_set` runs ONCE per `(layout, axis, tile_count, tile_set instance, source_id)` change at layout-bind time (cache key signature in `_ensure_synthesized_tile_set` lines 552-637). Per-paint cost: O(1) sample + O(1) dispatch.

**Side state on the per-cell path:**
- `affected` Dictionary (transient, single call invocation; not a persistent cache)
- `_synthesized_tile_set` (load-time computed; never touched per cell except a strip-clamp guard at lines 353-358)
- No watcher / signal fan-out — `Resource.changed` from `layout` triggers `_on_layout_changed → _queue_rebuild` (deferred coalesce); not on per-cell paint path.

### TileMapDual v5.0.2 per-cell paint path

File: `addons/TileMapDual/tile_map_dual.gd:166-168`

Verbatim trace from `_update_cells` to `set_cell`:

```
_update_cells(coords, _forced_cleanup) [tile_map_dual.gd:167]
  if is_instance_valid(_display): _display.update(coords) [tile_map_dual.gd:168]

Display.update(updated) [display.gd:107]
  if _tileset_watcher.tile_set == null: return [display.gd:108-109]
  _update_properties() [display.gd:110]                              ← copies parent props to ALL DisplayLayer children
  if not updated.is_empty():
    cached_cells.update(world, updated) [display.gd:112]             ← TileCache.update — refreshes the persistent cache
    world_tiles_changed.emit(updated) [display.gd:113]               ← SIGNAL DISPATCH

  → connected handler: _world_tiles_changed(changed) [display.gd:122]
    for child in get_children(true):
      child.update_tiles(cached_cells, changed) [display.gd:125]     ← signal-fanout to N DisplayLayers (1 for SQUARE, 2 for HEX/HALF_OFF)

DisplayLayer.update_tiles(cache, updated_world_cells) [display_layer.gd:78]
  already_updated = Set.new()                                         ← per-call helper, not the persistent cache
  for path in _terrain.display_to_world_neighborhood:                ← 4 paths for SQUARE dual-grid
    for world_cell in updated_world_cells:
      display_cell = follow_path(world_cell, path)                    ← graph walk via get_neighbor_cell
      if already_updated.insert(display_cell):
        update_tile(cache, display_cell)

DisplayLayer.update_tile(cache, cell) [display_layer.gd:90]
  terrain_neighbors = _terrain.display_to_world_neighborhood
                            .map(lambda path: cache.get_terrain_at(follow_path(cell, path)))
                                                                     ← N cache lookups per cell (4 for SQUARE)
  mapping = _terrain.apply_rule(terrain_neighbors, cell) [display_layer.gd:96]
                                                                     ← TerrainLayer.apply_rule — terrain-rule TRIE walk
  → TerrainLayer.apply_rule (terrain_layer.gd:64)
    is_empty check, normalize_terrain.map(...)
    node = _rules; for terrain in normalized_neighbors: node = node[terrain]   ← N trie hops
    return node['mappings'][...]
  set_cell(cell, mapping.sid, mapping.tile) [display_layer.gd:99]
```

**Depth: 8+ stack frames** from `_update_cells` to `set_cell` (counting the signal-emit hop as one frame). The path traverses:

1. Watcher null-check on tile_set (`_tileset_watcher`)
2. `_update_properties` — copies 13+ properties from parent to every DisplayLayer child
3. `TileCache.update` — refreshes the persistent coordinate-keyed cache (`tile_cache.gd`)
4. `world_tiles_changed.emit` — signal dispatch (signal fanout to N DisplayLayers)
5. Per-DisplayLayer `update_tiles` — iterates `display_to_world_neighborhood` paths
6. `follow_path(cell, path)` — graph walk via `get_neighbor_cell`
7. `apply_rule` — terrain-rule trie walk (`_rules: Dictionary` decision trie, terrain_layer.gd:65-79)
8. `set_cell`

**Side state on the per-cell path:**
- `TileCache.cells: Dictionary` — persistent coordinate-keyed cache, lookups via `get_terrain_at(cell)` per neighbor per cell
- `TileSetWatcher` — class with explicit "watcher" identity, polled on every `_update_cells` call via `_display.update()`
- `_rules: Dictionary` decision trie — recursive walk per cell (depth = number of neighbors in the topology)
- `_display.terrain.terrains: Dictionary[int, Dictionary]` — terrain-id-to-mapping table, exposed publicly via `draw_cell`
- `world_tiles_changed` signal — explicit fanout signal with connected handler, fires per `_update_cells` invocation

### Comparison

| Aspect | PentaTile | TileMapDual | Difference |
|--------|-----------|-------------|------------|
| Stack depth, `_update_cells` → `set_cell` | 4 frames | 8+ frames | PentaTile is half the depth |
| Persistent caches on hot path | None | `TileCache.cells` (Dictionary), `_rules` trie, `terrains` dict | PentaTile has zero |
| Signal hops on hot path | None (Resource.changed is for property edits, NOT per-cell paint) | `world_tiles_changed.emit` per `_update_cells` invocation, fanned-out to N DisplayLayer children | TileMapDual fans out per paint |
| Watchers on hot path | None | `TileSetWatcher` polled inside `_changed` and `_display.update`; `AtlasWatcher` and `tile_set_watcher` are class_name'd | PentaTile has zero watchers |
| Property copy per dispatch | None on hot path (`_sync_visual_layers` runs on property-setter changes, deferred) | `_update_properties` copies 13+ properties from parent to every child layer per `_update_cells` invocation (display_layer.gd:33-58) | PentaTile syncs only on property change |
| Trie / rule lookup per cell | None | `apply_rule` trie walk, depth = neighbor count (4 for SQUARE) | PentaTile dispatches via const dict lookup (or in Penta, synthesized atlas coord) |
| Per-cell sample function | One `Callable` (`_has_logic_cell`) checked O(1) | `display_to_world_neighborhood` array → `follow_path` graph walk per neighbor → `cache.get_terrain_at` lookup | PentaTile is O(1) per neighbor, no walk |

Per D-05-11: **PentaTile prioritizes hot-path minimalism over LOC delta.**

The hot path is the load-bearing identity statement. PentaTile's per-cell path has:
- Zero persistent caches
- Zero watcher dispatch
- Zero signal fanout
- Zero rule-trie walks
- Zero property-copy hops

TileMapDual's per-cell path traverses all five of those. The Phase 4 STATE.md note "hot-path complexity still simpler (no terrain-rule trie, no coordinate cache, no watcher system)" is verified by direct source inspection above.

## Anti-Pattern Register Check

### CLAUDE.md Identity Guardrails

The 6 reject items from `CLAUDE.md` § "Identity Guardrails" + a 7th absence check (parallel paint API, called out explicitly in the same section):

| Anti-pattern | Grep query | Result | Status |
|--------------|-----------|-------:|--------|
| Terrain peering metadata or terrain rule tries | `grep -rn "terrain_peering\|peering_bit\|TerrainSet" addons/penta_tile/` | 0 matches | ABSENT |
| Multi-terrain transitions (deferred to future milestone) | `grep -rn "transition_tile\|terrain_transition\|MULTITERR" addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd` | 2 matches, both doc-comment references to v2 backlog deferral (`MULTITERR-*` in Penta.gd:270 + PixelLab top-down.gd:16); NO implementation surface | ABSENT |
| Watcher / signal-fanout systems | `grep -rn "Watcher\|signal_fanout\|signal.*broadcast" addons/penta_tile/` | 0 matches | ABSENT |
| Persistent coordinate caches | `grep -rn "coord_cache\|persistent.*cache\|_cache_dict\|_coord_lookup" addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd` | 0 matches | ABSENT |
| Custom drawing API parallel to `set_cell()` | `grep -rn "func draw_cell\|func paint_cell\|custom_paint_api" addons/penta_tile/*.gd addons/penta_tile/layouts/*.gd` | 0 matches | ABSENT |
| `EditorInspectorPlugin` / `EditorPlugin` polish | `grep -rn "EditorInspectorPlugin\|EditorPlugin\|forward_canvas" addons/penta_tile/` | 0 matches | ABSENT |

All 6 CLAUDE.md guardrails are clean.

Note on the MULTITERR matches: both occurrences are doc comments (lines preceded by `#` or `##`) describing what is OUT OF SCOPE for v0.2 — the multi-terrain transitions are explicitly deferred to v2 backlog (`MULTITERR-01..05`). They are pointers to deferred work, not implementations of it.

### PITFALLS.md AP-1..AP-10 (Phase 3 TBT audit register)

The `03-TBT-DEEP-AUDIT.md` register defines 10 anti-patterns by REJECT verdict against patterns observed in TileBitTools. Each is checked here as a confirmation that PentaTile preserved its identity through Phase 3 / 3.5 / 4 / 5 (Plans 1-2):

| AP ID | Anti-pattern | Status | Evidence |
|-------|-------------|--------|----------|
| AP-1 | `EditorInspectorPlugin` scene-tree walking | ABSENT | `grep "EditorInspectorPlugin\|forward_canvas" addons/penta_tile/` returns 0 matches |
| AP-2 | SubViewport overlays in the editor | ABSENT | `grep "SubViewport" addons/penta_tile/` returns 0 matches |
| AP-3 | Editor theme harmonization | ABSENT | `grep "theme_updater\|theme_harmonization\|EditorThemeManager" addons/penta_tile/` returns 0 matches |
| AP-4 | Save-as / edit-template dialogs | ABSENT | `grep "save_template\|template_dialog\|edit_template" addons/penta_tile/` returns 0 matches |
| AP-5 | Speculative configuration palettes | ABSENT | No color-blind palettes, debug-channel enums, or multi-key Project Settings dictionaries; only typed `@export`s with concrete consumers |
| AP-6 | Peering-bit color overlay rendering | ABSENT | PentaTile renders silhouettes via `bitmask_template` PNG, not bit colors. No `bit_data_draw` equivalent. |
| AP-7 | 3-tier Resource hierarchy (base + live-editor + template) | ABSENT | `PentaTileLayout` (base) + concrete subclasses (e.g., `PentaTileLayoutPenta`); 2-tier only. No live-editor subclass. |
| AP-8 | Lifting TBT class names into PentaTile | ABSENT | `grep "TileBitTools\|tile_bit_tools\|TBT" addons/penta_tile/` returns 0 matches in code (planning-doc references only) |
| AP-9 | Lifting TBT `.tres` data | ABSENT | Each layout's slot table sourced from the format's primary reference (BorisTheBrave for Blob47, native Penta for Penta family, CR31 for Wang). No TBT-derived encodings. |
| AP-10 | `addons/penta_tile/ATTRIBUTION.md` | ABSENT | `test -f addons/penta_tile/ATTRIBUTION.md` returns absent. README footnote in "External Resources" is the only attribution work, per D-72/D-73. |

All 10 PITFALLS.md AP entries are clean. Phase 5 has not regressed any of them.

### Aggregate

- **CLAUDE.md guardrails: 6 of 6 ABSENT.**
- **PITFALLS.md AP-1..AP-10: 10 of 10 ABSENT.**
- **Total: 16 of 16 anti-pattern items confirmed ABSENT** at PentaTile commit `905596c4e0c6d89b99abdfd32e84eef1f378ddf9`.

## Decision per D-05-11

**Outcome:** **SHIP**

Rationale (cites the actual measurements above):

- **LOC:** PentaTile 2884 vs TileMapDual 2126 (Δ +758, PentaTile heavier by ~36%). Per D-05-11 LOC is signal not verdict — the delta is dominated by `penta_tile_synthesis.gd` (840 LOC), which is the load-time 5-archetype synthesis engine that lets ONE..FOUR Penta modes ship without the user authoring all 5 archetypes (a user-facing feature trade, not bloat). TileMapDual's 408-LOC `tile_map_dual_legacy.gd` is a Godot 4.3 fallback PentaTile chose not to write (no compat shims per CLAUDE.md HARD RULE). LOC delta does NOT trigger an extract-and-optimize per D-05-11.
- **Public surface:** PentaTile 15 @export / 36 public methods / 12 class_name's vs TileMapDual 6 / 38 / 14. PentaTile is wider on `@export` (visual/collision toggles + 8 typed layouts + Penta's axis/tile_count) but narrower at the layer-level user-facing API (1 public helper `rebuild()` vs TileMapDual's `draw_cell` + `get_cell`). The 36 PentaTile method count inflates with virtual-override boilerplate (24 of the 36 are `compute_mask` / `mask_to_atlas` / `is_dual_grid` overrides across 8 layouts); load-bearing API entry points are ~4 (one layer method + three virtual contracts).
- **Hot-path:** PentaTile **4 stack frames**, no caches, no watchers, no signals, no rule tries, no per-paint property-copies. TileMapDual **8+ stack frames**, traversing `TileSetWatcher` + `_update_properties` (13+ properties) + `TileCache` (persistent `cells: Dictionary`) + `world_tiles_changed.emit` signal fanout + `_rules: Dictionary` decision trie walk per cell. **PentaTile's per-cell hot path is half the depth and traverses zero of the five subsystems TileMapDual's path crosses.** This is the load-bearing identity statement per D-05-11.
- **Anti-pattern register:** 16 of 16 items checked (6 CLAUDE.md guardrails + 10 PITFALLS.md AP entries); all ABSENT. ZERO triggers.

**Decision logic** (D-05-11 tree):
- LOC large + clean hot path + zero anti-patterns → SHIP. ✓ This case applies.
- LOC large + identifiable inefficiencies / duplications → would EXTRACT+OPTIMIZE. Not applicable: hot path is clean and no specific inefficiency / duplication was identified during the audit. The synthesis engine is not duplicated work; the 8 layouts share virtual contracts, not implementations (no de-duplication target).
- Any anti-pattern triggered → would FIX-BEFORE-SHIP. Not applicable: 0 of 16 triggered.

**Action items:** None — ship as-is per D-05-11. Plan E (release run) is unblocked by this audit.

## README "Identity & Footprint" summary

The README placeholder will be replaced (Task 3) with this summary paragraph:

> PentaTile's per-cell paint path is **4 stack frames deep** and traverses zero persistent caches, zero watchers, zero signal fanout, zero rule-trie walks, and zero property-copy hops. The audit (against TileMapDual v5.0.2, commit `9ff1e24f`) confirms 16 of 16 anti-pattern register items absent — the 6 CLAUDE.md "Identity Guardrails" rejects (terrain peering, multi-terrain transitions, watcher/signal-fanout, coordinate caches, parallel paint APIs, EditorInspectorPlugin polish) and the 10 AP-1..AP-10 entries from PITFALLS.md. Cumulative runtime LOC (2884 PentaTile vs 2126 TileMapDual) is reported as signal, not as a fail criterion (per [D-05-11](.planning/phases/05-demo-refresh-documentation-release/05-CONTEXT.md)). Identity at v0.2.0 is **hot-path minimalism + anti-pattern absence**, not raw LOC delta.

---

*Audit performed 2026-04-29. PentaTile commit `905596c4e0c6d89b99abdfd32e84eef1f378ddf9`. TileMapDual reference v5.0.2 commit `9ff1e24f80be1816cfcd7aeec32800a699a94ccb`. Per D-05-13 this audit is a developer-judgment prerequisite to release, NOT a CI gate.*
