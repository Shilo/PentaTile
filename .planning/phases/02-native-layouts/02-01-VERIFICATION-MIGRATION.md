---
phase: 02-native-layouts
supersedes: .planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md
migrated: 2026-04-26
test_count: 16
---

# Phase 2 Verification — Migrated from Phase 1 + New Mode Coverage

Phase 1's 26 tests reference the deleted API surface (`atlas_contract`, `PentaTileLayoutPentaHorizontal/Vertical`, `template_image`, `_overlay_layer`). This file rewrites them against Phase 2's new surface AND adds coverage for the new modes (TWO/THREE/FIVE + AUTO_STRIP).

## Migration Map (Phase 1 → Phase 2)

| Phase 1 Test | New API Reference | Notes |
|---|---|---|
| `atlas_contract = ExtResource(default_horizontal.tres)` → bit-identical to v0.1 | DEPRECATED — slot ordering changed; v0.1 bit-identity no longer holds. Replaced by FOUR-mode regression baseline (PENTA-SYNTH-12). | Wave 6 captures fresh baseline. |
| `atlas_contract = null` → v0.1 lazy fallback | DELETED — no `_DEFAULT_LAYOUT` singleton in Phase 2; `layout == null` renders nothing (LAYER-02). | New test: `layer.layout = null` → no paint, no errors. |
| `atlas_contract = same value` → 0 rebuilds (idempotence) | Migrated to `layer.layout = layer.layout` → 0 rebuilds. Setter at penta_tile_map_layer.gd `layout` property (Wave 2). | Same idempotence pattern (PITFALLS §5). |
| Burst-of-10 emits → 10 rebuilds (no signal storm) | Migrated to `layer.layout.changed` × 10 → 10 rebuilds (1:1; deferred coalescing at `rebuild.call_deferred`). | Same pattern. |
| `PentaTileLayout` subclassable, picker shows subclasses | Migrated unchanged (typed `@export var layout: PentaTileLayout`). | New subclasses Wave 3-4. |
| `template_image` renders in inspector | `bitmask_template` renders in inspector (rename per LAYOUT-03 / PREVIEW-01). | Stock Texture2D preview; no behavior change. |
| LOC checkpoint logged | LOC checkpoint at Wave 7 (~1230-1530 expected; ~1500 upper bound). | New target. |
| 5 patterns × `default_horizontal.tres` pixel-diff=0 vs v0.1 | DELETED — slot ordering changed in Phase 2. Replaced by FOUR-mode baseline test (PENTA-SYNTH-12) at Wave 6. | Fresh capture, NOT v0.1 bit-equiv. |
| 5 patterns × null contract pixel-diff=0 vs v0.1 | DELETED — null layout renders nothing in Phase 2. | LAYER-02 acceptance criterion. |
| (D-19 silently-dropped `atlas_layout` enum) | Migrated as historical record only — `atlas_layout` and `atlas_contract` both gone. | No active test. |

## New Tests (Phase 2 modes not covered in Phase 1)

Add these test specs to be exercised at Wave 6 (visual + behavioral) and Wave 7 (closeout):

1. **PENTA-SYNTH-02 AUTO detection** — `PentaTileLayoutPenta(axis=HORIZONTAL, tile_count=AUTO)` on a 1×N atlas → mode resolves to ONE; on 4×N → FOUR; on 5×N → FIVE. Other axis sizes (0, 6+) → render disabled + warning.
2. **PENTA-SYNTH-03 AUTO_STRIP detection** — `PentaTileLayoutPenta(tile_count=AUTO_STRIP)` on a 5×3 atlas with strip 0 = 5 tiles, strip 1 = 1 tile, strip 2 = 4 tiles → strips render with mode FIVE/ONE/FOUR respectively. Different strips can use different modes.
3. **PENTA-SYNTH-08 warnings** — explicit `tile_count=FIVE` on a 4×N atlas → `update_configuration_warnings()` returns the explicit-mismatch warning. AUTO_STRIP gap (slot 2 populated, slot 1 empty) → AUTO_STRIP-gap warning.
4. **TWO mode synthesis** — `PentaTileLayoutPenta(tile_count=TWO)` on a 2×1 atlas (slot 0 = IsolatedCell, slot 1 = Fill) → all 16 mask states paint; slot 1 used for mask 15; remaining masks synthesize from slot 0 sub-regions.
5. **THREE mode synthesis** — 3×1 atlas (slot 0/1/2 = IsolatedCell/Fill/Border) → 16 mask states paint; Border (mask 3, 5, 10, 12) uses slot 2; InnerCorner + OppositeCorners synthesize from slot 0.
6. **FIVE mode pure-authored** — 5×1 atlas with all five archetypes hand-drawn → 16 mask states paint; only OuterCorner derived from slot 0 (the implicit archetype across all modes).
7. **PENTA-SYNTH-06 determinism** — synthesize twice with the same `(layout, axis, tile_count, source tile_set)`; hash both atlases via `Image.get_data().hash()`; assert equal. Bit-identical across 10 consecutive runs.
8. **PENTA-SYNTH-07 overlay deletion** — `PentaTileMapLayer` instance has exactly ONE child visual layer named `_PentaTileVisual`; no `_PentaTileDiagonalOverlay` child exists. Verified via `find_child("_PentaTileDiagonalOverlay")` returns null.
9. **LAYER-04 demo rebind** — opening `addons/penta_tile/demo/penta_tile_demo.tscn` in Godot 4.6 editor produces zero "missing dependency" / "missing script" errors after Wave 2 lands; PentaTileMapLayer node has `layout` property bound (not `atlas_contract`).
10. **NATIVE-01..03 + MIN3x3-01** — each native layout's 16 mask states paint without seams on a 5×5 painted region (visual regression).

## Test Count

Migrated from Phase 1 (still applicable): ~6 tests (idempotence, signal-storm, subclassable picker, bitmask_template inspector preview, LOC checkpoint, no-anti-patterns scan).

Removed (Phase 1-only; v0.1 bit-equivalence no longer holds): 20 tests (10 visual-regression rows + 10 wiring rows that referenced now-deleted `atlas_contract` / `_DEFAULT_LAYOUT` / `_overlay_layer`).

NEW (Phase 2 modes + architectural sweep): 10 tests above.

Final test_count = ~16 — refined as new layouts ship in Waves 3-4. Wave 7 closeout updates the final number.
