---
phase: 02-native-layouts
plan: 2
subsystem: synthesis-machinery
tags: [architecture, breaking-change, overlay-deletion, synthesis, atomic-sweep]
dependency_graph:
  requires: [02-01-PLAN]
  provides: [PentaTileSynthesis, layout-property, synthesis-wiring, contract-deleted, overlay-deleted]
  affects:
    - addons/penta_tile/penta_tile_map_layer.gd
    - addons/penta_tile/penta_tile_atlas_slot.gd
    - addons/penta_tile/layouts/penta_tile_layout.gd
    - addons/penta_tile/demo/penta_tile_demo.tscn
tech_stack:
  added:
    - PentaTileSynthesis (RefCounted @tool utility class)
  patterns:
    - synthesize-from-slot-0-sub-regions
    - needs_synthesis-virtual-for-forward-type-safety
    - effective_tile_set-routing-in-sync_visual_layers
    - Liang-Barsky-rect-clip-for-polygon-synthesis
    - INTERPOLATE_NEAREST-determinism-invariant
key_files:
  created:
    - addons/penta_tile/penta_tile_synthesis.gd
  modified:
    - addons/penta_tile/penta_tile_map_layer.gd
    - addons/penta_tile/penta_tile_atlas_slot.gd
    - addons/penta_tile/layouts/penta_tile_layout.gd
    - addons/penta_tile/demo/penta_tile_demo.tscn
  deleted:
    - addons/penta_tile/penta_tile_atlas_contract.gd
    - addons/penta_tile/penta_tile_atlas_contract.gd.uid
    - addons/penta_tile/contracts/default_horizontal.tres
    - addons/penta_tile/contracts/default_vertical.tres
    - addons/penta_tile/contracts/penta_horizontal_default.tres
    - addons/penta_tile/contracts/penta_vertical_default.tres
    - addons/penta_tile/penta_tile_template.png
    - addons/penta_tile/penta_tile_template.png.import
decisions:
  - "PentaTileSynthesis ships as RefCounted (@tool) — not autoload; static methods only; caller owns TileSet lifetime"
  - "needs_synthesis() virtual added to PentaTileLayout base (returns false) — avoids forward type reference to PentaTileLayoutPenta (Wave 3); Wave 3 overrides to true"
  - "Tasks 2.2 and 2.3 merged into one atomic commit (b6349fa) — synthesis wiring required adding needs_synthesis() virtual to penta_tile_layout.gd which was already in the atomic sweep commit; plan's two-commit structure became one logically coherent edit"
  - "_DEFAULT_LAYOUT singleton deleted atomically with _resolve_layout rewrite per CONTEXT.md D-68 constraint — both edits in same commit b6349fa"
  - "OuterCorner NOT synthesized (Path B per Gate 1) — slot 0 used verbatim with rotation flags at render time via mask_to_atlas; no synthesizer code path emits OuterCorner cells"
  - "_ensure_synthesized_tile_set typed PentaTileLayout (base) not PentaTileLayoutPenta — dynamic get('axis')/get('tile_count') used to read Penta-specific properties without forward type reference"
metrics:
  duration_seconds: 1247
  completed: 2026-04-26
  tasks_completed: 4
  tasks_total: 4
  files_modified: 5
  files_created: 1
  files_deleted: 8
---

# Phase 2 Plan 2: Wave 2 Architectural Sweep — Synthesis Machinery + Overlay Deletion + Contract Deletion + Demo Rebind Summary

Wave 2 builds `PentaTileSynthesis` (675 LOC), fills `get_fallback_tile_set()`, deletes the entire overlay-layer code path and `PentaTileAtlasContract`, replaces `atlas_contract` with `layout: PentaTileLayout` on `PentaTileMapLayer`, wires synthesis into the render path, and atomically rebinds `penta_tile_demo.tscn`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 2.1 | Build PentaTileSynthesis + fill get_fallback_tile_set() | e8e114a | addons/penta_tile/penta_tile_synthesis.gd, addons/penta_tile/layouts/penta_tile_layout.gd |
| 2.2 | Atomic sweep — atlas_contract→layout, overlay deletion, _DEFAULT_LAYOUT, demo rebind | b6349fa | penta_tile_map_layer.gd, penta_tile_atlas_slot.gd, penta_tile_layout.gd, penta_tile_demo.tscn + 8 deleted files |
| 2.3 | Synthesis wiring in PentaTileMapLayer | b6349fa | (included in Task 2.2 atomic commit — see Deviations) |
| 2.4 | Checkpoint: editor load verify | b6349fa | auto-approved (--auto mode); automated checks all pass |

## LOC Delta

| File | Before | After | Delta |
|------|--------|-------|-------|
| penta_tile_synthesis.gd | 0 (new) | 675 | +675 |
| penta_tile_map_layer.gd | 299 | 337 | +38 |
| penta_tile_layout.gd | 47 | 70 | +23 |
| penta_tile_atlas_slot.gd | 18 | 14 | -4 |
| penta_tile_atlas_contract.gd | 41 | DELETED | -41 |
| contracts/*.tres (4 files) | ~40 total | DELETED | -40 |
| penta_tile_template.png.import | — | DELETED | -0 (binary) |
| **Net GDScript addition** | | | **+696 LOC** |

Synthesis machinery at 675 LOC is above the 250-400 estimate in the plan LOC budget. The extra LOC comes from:
- Full `_extract_tile_polygons` implementation including collision/occlusion/navigation layer iteration (~80 LOC)
- Pixel-level sub-region compositing for all 4 synthesized archetypes, with proper edge clamping (~80 LOC)
- `_clip_segment_to_rect` Liang-Barsky implementation (~30 LOC)
- `_subrect_for_slot` lookup table per Gate 1 spec (~30 LOC)
- `_copy_polygons_to_tile_data` with full polygon validation (~50 LOC)
- Guard conditions, docstrings, and PENTA-SYNTH-06 determinism comments (~100 LOC)

The implementation is complete (not over-spec'd) — each LOC block serves a concrete acceptance criterion.

## Gate 1 Resolution: Sub-Region Anchoring (D-69 LOCKED)

Implemented per 02-02-PLAN.md spec:
- **Fill** (slot 1): center 50% of slot 0, stretched to tile_size via `INTERPOLATE_NEAREST`
- **Border** (slot 2): bottom-half slab (S-edge), stretched to tile_size
- **InnerCorner** (slot 3): full tile minus TR quadrant (L-shape), no resize needed
- **OppositeCorners** (slot 4): TL_quad composited at TL + BR_quad at BR on transparent canvas
- **OuterCorner**: NOT synthesized — slot 0 used verbatim with rotation flags (Path B)
- Square-tile assertion: `validate_tile_size` rejects non-square / odd tile_size with warnings

## Gate 2 Resolution: Polygon Transform Math (D-70 LOCKED)

Implemented per 02-02-PLAN.md spec:
- `transform_vertex`: TRANSPOSE first, then FLIP_H, then FLIP_V (canonical Godot order)
- `clip_polygon_to_subrect`: Liang-Barsky-style segment clipping; drops polygons < 3 vertices
- `_clip_segment_to_rect`: parametric edge-intersection helper
- NOT copied: animation frames, custom data, probability, Y-sort origin, material, z-index

## Key Architectural Changes Shipped

- `atlas_contract: PentaTileAtlasContract` → `layout: PentaTileLayout` on `PentaTileMapLayer`
- `_DEFAULT_LAYOUT` static singleton deleted; `_resolve_layout()` returns `self.layout` directly
- `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()` all deleted
- `AtlasSlot.diagonal_complement_atlas_coords` deleted
- `PentaTileAtlasContract` class + contracts/ folder + penta_tile_template.png all deleted
- `_sync_visual_layers` routes through `effective_tile_set = _synthesized_tile_set ?? tile_set`
- `_on_contract_changed` renamed to `_on_layout_changed`; invalidates synthesis cache
- Demo scene: `atlas_contract = ExtResource("6_contract")` → `layout = null` (placeholder until Wave 3)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Forward type reference to PentaTileLayoutPenta in Wave 2**
- **Found during:** Task 2.2 — GDScript IDE rejected `if resolved_layout is PentaTileLayoutPenta` because `PentaTileLayoutPenta` (Wave 3's class) doesn't exist yet
- **Fix:** Added `needs_synthesis() -> bool` virtual to `PentaTileLayout` base (returns false); `_ensure_synthesized_tile_set` typed as `PentaTileLayout` (base); `penta.axis` and `penta.tile_count` accessed via `get()` dynamic property accessor
- **Files modified:** `addons/penta_tile/penta_tile_atlas_slot.gd` (no), `addons/penta_tile/layouts/penta_tile_layout.gd` (yes), `addons/penta_tile/penta_tile_map_layer.gd` (yes)
- **Commit:** b6349fa

**2. [Rule 3 - Blocking] IDE also flagged PentaTileSynthesis as undeclared**
- **Found during:** Task 2.2 — IDE static analyzer cannot resolve class_name symbols across files without loading the Godot project
- **Fix:** Typed the `result` and `synthesized` variables explicitly (`var result: Dictionary` and `var synthesized: TileSet`) so the return type is pinned regardless of class_name resolution
- **Files modified:** `addons/penta_tile/penta_tile_map_layer.gd`
- **Commit:** b6349fa
- **Note:** `PentaTileSynthesis` IS correctly resolved at Godot project load time via `class_name`; the IDE check is a false positive. Explicit typing eliminates the warning.

**3. [Structural] Tasks 2.2 and 2.3 merged into single atomic commit**
- **Found during:** Task 2.2 — the `needs_synthesis()` virtual (Rule 3 fix) required adding a line to `penta_tile_layout.gd`, which was already part of the atomic sweep commit. Staging only some changes from the file was not possible without splitting the atomic guarantee.
- **Disposition:** Accepted. The plan's two-commit structure (2.2 = architectural sweep, 2.3 = synthesis wiring) became one logically coherent commit. All Task 2.3 acceptance criteria pass against the single commit. The `git log --grep="wire PentaTileSynthesis"` check in Task 2.3's acceptance criteria will NOT pass (that commit doesn't exist); documented here instead.
- **Plan acceptance criteria impact:** Task 2.3 `git log --grep=...` check: NOT MET (structural deviation). All substance checks pass.

## Task 2.4 Checkpoint

Auto-approved under `--auto` mode. Automated checks confirmed:
- `PentaTileSynthesis.synthesize_strip` wired in `_ensure_synthesized_tile_set`: 1 call
- `PentaTileSynthesis.build_tile_set_from_synthesis` wired: 1 call
- No stub language in `penta_tile_map_layer.gd`: 0 matches
- No shortcut `_synthesized_tile_set = tile_set`: 0 matches

Manual Godot editor verification deferred to user (demo loads with `layout = null` → no tiles rendered, no errors expected; player spawns and moves normally).

## Known Stubs

| Stub | File | Detail | Resolution |
|------|------|--------|------------|
| `layout = null` in demo scene | demo/penta_tile_demo.tscn | Placeholder until Wave 3 ships PentaTileLayoutPenta | Wave 3 + Wave 6 wire a real .tres instance |
| `needs_synthesis()` returns false on base | layouts/penta_tile_layout.gd | Wave 3 PentaTileLayoutPenta overrides to true | Wave 3 |
| `_ensure_synthesized_tile_set` AUTO/AUTO_STRIP path returns early | penta_tile_map_layer.gd | mode 0 (AUTO) and mode > 5 exit early; Wave 6 wires AUTO/AUTO_STRIP resolution | Wave 6 |

No stubs that prevent the plan's goal from being achieved — the synthesis path is fully wired for explicit ONE..FIVE modes (the Wave 2 scope per CONTEXT.md D-68).

## Threat Flags

None. No new network endpoints, auth paths, or trust-boundary schema changes. The synthesis path operates entirely on trusted addon-bundled Image data + Godot's TileData polygon API.

## Self-Check: PASSED

- `addons/penta_tile/penta_tile_synthesis.gd` exists, 675 lines, contains `class_name PentaTileSynthesis`, `static func synthesize_strip`, `static func build_tile_set_from_synthesis`, `INTERPOLATE_NEAREST`, no `INTERPOLATE_BILINEAR`
- `addons/penta_tile/penta_tile_map_layer.gd` exists, 337 lines, contains `@export var layout: PentaTileLayout`, `func _on_layout_changed`, `func _ensure_synthesized_tile_set`, `PentaTileSynthesis.synthesize_strip`, `effective_tile_set`, 0 refs to `_overlay_layer`/`_DEFAULT_LAYOUT`/`atlas_contract`
- `addons/penta_tile/penta_tile_atlas_slot.gd` exists, 14 lines, 0 refs to `diagonal_complement_atlas_coords`
- `addons/penta_tile/layouts/penta_tile_layout.gd` exists, 70 lines, contains `_cached_fallback_tile_set`, `func get_fallback_tile_set`, `func needs_synthesis`
- `addons/penta_tile/demo/penta_tile_demo.tscn`: 0 refs to `atlas_contract`, 0 refs to `contracts/default_horizontal.tres`, 1 `layout = null` line
- DELETED: `penta_tile_atlas_contract.gd` — confirmed absent
- DELETED: `contracts/` folder — confirmed absent
- DELETED: `penta_tile_template.png` — confirmed absent
- Commit e8e114a (Task 2.1) and b6349fa (Tasks 2.2+2.3) verified in git log
