---
phase: 01-contract-skeleton-tetra-layouts
plan: 02
subsystem: api
tags: [godot, resource, gdscript, atlas-contract, layout-base, atlas-slot, signal-storm-mitigation]

requires:
  - phase: 01-contract-skeleton-tetra-layouts/01
    provides: _rebuild_count instrumentation enables Plan 05 to verify the new contract setter is signal-storm-safe
provides:
  - TetraTileAtlasSlot Resource (passive 4-field data record)
  - TetraTileLayout abstract base Resource (3 virtuals + 4 exports + _pack_alternative + _set_contract back-ref)
  - TetraTileAtlasContract Resource with locked D-08 setter (idempotence + disconnect-before-reconnect + back-ref wiring)
affects: [01-03, 01-04, 01-05, phase-2, phase-3, phase-3.5]

tech-stack:
  added: []
  patterns:
    - "Strategy-pattern Resource hierarchy: TetraTileLayout subclasses own mask topology + slot resolution; dispatcher in TetraTileMapLayer stays generic"
    - "WeakRef back-reference (layout._contract -> contract) prevents the cycle that an owning ref would create"
    - "Setter discipline for Resource.changed signals: idempotence-guard FIRST → disconnect OLD → assign → connect NEW → emit_changed (PITFALLS §5 recipe)"

key-files:
  created:
    - addons/tetra_tile/tetra_tile_atlas_slot.gd (17 LOC)
    - addons/tetra_tile/layouts/tetra_tile_layout.gd (57 LOC)
    - addons/tetra_tile/tetra_tile_atlas_contract.gd (40 LOC)
  modified: []

key-decisions:
  - "Layout files live in addons/tetra_tile/layouts/ subdir; AtlasSlot + AtlasContract stay at addon root (per locked planner decision)"
  - "Three virtuals push_error on the base + return safe defaults — subclass-forgot-to-override surfaces a loud error rather than silently rendering wrong"
  - "Layout's _contract back-ref is WeakRef (Phase 1 declares but doesn't exercise; Phase 3.5 PixelLab variation pick consumes it)"
  - "All 3 files use @tool; none use @icon (Resources don't appear in the Add Node menu)"

patterns-established:
  - "@tool + class_name + extends Resource for every TetraTile data Resource"
  - "Abstract virtuals: parameter names with leading underscore (_coord, _sample_fn, _mask) silence unused-param warnings; body is push_error + safe-default return"
  - "AtlasContract setter: 7-step locked recipe (idempotence-guard, disconnect, clear-old-back-ref, assign, connect, set-new-back-ref, emit_changed) — D-08 + PITFALLS §5"

requirements-completed:
  - CONTRACT-02
  - LAYOUT-01
  - LAYOUT-02
  - LAYOUT-03
  - LAYOUT-04
  - LAYOUT-05
  - PREVIEW-01

duration: ~5min
completed: 2026-04-26
---

# Plan 01-02: Resource Skeletons Summary

**Three Resource subclass files create the data shape the rest of v0.2 plugs into — TetraTileAtlasSlot + TetraTileLayout (abstract) + TetraTileAtlasContract with the locked signal-storm-safe setter — all parse cleanly together under Godot 4.6.2.**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-04-26
- **Tasks:** 3
- **Files created:** 3 (all .gd)

## Accomplishments

- `TetraTileAtlasSlot` Resource shipped: 4 typed `@export` fields, no methods, `(-1, -1)` no-overlay sentinel for diagonal_complement (LAYOUT-04)
- `TetraTileLayout` abstract base shipped with 3 virtuals (`compute_mask` / `mask_to_atlas` / `is_dual_grid`), 4 declared `@exports` (`template_image` / `fallback_tile_set` / `description` / `decoder_image`), the `_pack_alternative` bit-collision guard, and the `_contract` WeakRef back-reference (LAYOUT-01..03, LAYOUT-05, PREVIEW-01)
- `TetraTileAtlasContract` Resource shipped with the LOCKED D-08 setter — first MITIGATION of T-01-03 (Resource.changed signal-storm DoS) — including back-reference wiring on both attach and detach (CONTRACT-02, CONTRACT-05 setter half)
- All three files parse together cleanly under Godot --headless --check-only; cross-file types resolve (TetraTileLayout returns TetraTileAtlasSlot; TetraTileAtlasContract holds TetraTileLayout)

## Task Commits

1. **Task 1.1: TetraTileAtlasSlot Resource** — `1ac3492` (feat) — 17 LOC, 4 @exports, 0 methods
2. **Task 1.2: TetraTileLayout abstract base Resource** — `00e7695` (feat) — 57 LOC, 4 @exports + 5 methods + `_contract` field
3. **Task 1.3: TetraTileAtlasContract Resource (locked D-08 setter)** — `1e35e2f` (feat) — 40 LOC, 3 @exports + 1 method, full PITFALLS §5 recipe

## Files Created/Modified

- `addons/tetra_tile/tetra_tile_atlas_slot.gd` — 17 LOC. Pure data Resource. 4 `@export` fields: `atlas_coords` (Vector2i), `transform_flags` (int), `alternative_tile` (int), `diagonal_complement_atlas_coords` (Vector2i = -1,-1).
- `addons/tetra_tile/layouts/tetra_tile_layout.gd` — 57 LOC. Abstract base Resource. 4 `@exports` for inspector contract, 3 abstract virtuals (push_error on base), `_pack_alternative(alt_id, transform_flags)` helper with `assert(alt_id < 4096)`, `_contract: WeakRef` back-ref + `_set_contract(contract)` setter.
- `addons/tetra_tile/tetra_tile_atlas_contract.gd` — 40 LOC. Bundle Resource. 3 `@exports` (`version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0`). The `layout` setter implements the full 7-step locked D-08 recipe (idempotence → disconnect → clear-old-back-ref → assign → connect → set-new-back-ref → emit_changed) plus `_on_layout_changed()` that bubbles `changed` up via `emit_changed()` (no setter call — storm-safe).

## Decisions Made

- Followed plan VERBATIM. The plan's `<action>` blocks specified literal file content for all 3 files; that content was used as-is, no improvisation.
- Confirmed cross-file parse via `--check-only` on all 3 files together (exit 0). The `--check-only` flag resolves type references, so this proves the cross-references (TetraTileLayout → TetraTileAtlasSlot; TetraTileAtlasContract → TetraTileLayout) are syntactically and type-correctly wired.

## Deviations from Plan

None — plan executed exactly as written. All 3 files match the verbatim content blocks in the plan. All grep checks pass:
- AtlasSlot: 17 LOC (within 12-25); 0 `func ` matches (no methods); 0 `@icon` matches.
- TetraTileLayout: 57 LOC (within 50-80); all required `@export`/`var`/`func` signatures present; 3 `push_error` lines (one per abstract virtual); `assert(alt_id < 4096)` present.
- TetraTileAtlasContract: 40 LOC (within 35-60); all setter-recipe lines present (`if layout == value:`, `is_connected(_on_layout_changed)`, `disconnect`, `connect`, `_set_contract(self)`, `_set_contract(null)`, 2× `emit_changed()`).

## Issues Encountered

None. The first `--check-only` invocation appeared to hang earlier in the session (Plan 01-01 Task 0.3) — that was a non-destructive symptom of running without `--quit-after`. Subsequent `--check-only --quit-after 100` invocations exit cleanly.

## User Setup Required

None.

## Next Phase Readiness

- ✅ **Plan 01-03** can now create `TetraTileLayoutTetraHorizontal` (extends `TetraTileLayout`, override `compute_mask` / `mask_to_atlas` / `is_dual_grid()` returning true) and `TetraTileLayoutTetraVertical` (subclass of horizontal, axis-swap override).
- ✅ **Plan 01-04** can typed-export `@export var atlas_contract: TetraTileAtlasContract` on `TetraTileMapLayer`, connect to `_atlas_contract.changed`, and call into `layout.compute_mask` / `layout.mask_to_atlas`.
- ✅ **Plan 01-05** can instantiate `TetraTileAtlasContract.new()` and `TetraTileLayoutTetraHorizontal.new()` for bundled `.tres` files.
- ✅ **Phase 3.5 prerequisite met:** `_contract` back-ref + `variation_seed` field both declared, ready for the PixelLab variation pick to consume.

---
*Phase: 01-contract-skeleton-tetra-layouts*
*Completed: 2026-04-26*
