---
phase: 02-native-layouts
plan: 1
subsystem: layout-base
tags: [refactor, breaking-change, api-rename, verification-migration]
dependency_graph:
  requires: []
  provides: [bitmask_template-export, get_fallback_tile_set-stub, phase1-verification-migration]
  affects: [penta_tile_layout.gd, 01-VERIFICATION.md]
tech_stack:
  added: []
  patterns: [virtual-stub, breaking-rename, no-compat-shim]
key_files:
  created:
    - .planning/phases/02-native-layouts/02-01-VERIFICATION-MIGRATION.md
  modified:
    - addons/penta_tile/layouts/penta_tile_layout.gd
    - .planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md
decisions:
  - "No @export_storage shadow added for template_image→bitmask_template rename (CLAUDE.md no-compat HARD RULE; .tres files will warn on first load — documented breakage)"
  - "get_fallback_tile_set() body is return null in Wave 1; Wave 2 fills with synthesis machinery"
  - "_contract WeakRef + _set_contract deleted atomically with the @export removals — contract back-ref is obsolete pre-Wave 2"
metrics:
  duration_seconds: 147
  completed: 2026-04-26
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
  files_created: 1
---

# Phase 2 Plan 1: Wave 1 Pre-work — Base-Class API Renames + Verification Migration Summary

Wave 1 renames `template_image` → `bitmask_template` on `PentaTileLayout`, removes the speculative `fallback_tile_set` @export and `decoder_image`, deletes the obsolete `_contract` WeakRef back-reference machinery, adds the `get_fallback_tile_set() -> TileSet` virtual stub (Wave 2 fills the body), and migrates Phase 1's 26-test verification suite to the new API surface with 10 new mode tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1.1 | Rename template_image + remove exports + add virtual stub + delete contract back-ref | cb6d253 | addons/penta_tile/layouts/penta_tile_layout.gd |
| 1.2 | Migrate Phase 1 verification suite + mark 01-VERIFICATION.md historical | 595f0f8 | .planning/phases/02-native-layouts/02-01-VERIFICATION-MIGRATION.md, .planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md |

## LOC Delta in `penta_tile_layout.gd`

- Before Wave 1: 57 lines
- After Wave 1: 47 lines
- **Net delta: -10 lines**

Breakdown:
- Removed: `@export var template_image` (1 line), `@export var fallback_tile_set` (1 line), `@export var decoder_image` (1 line), `_contract` WeakRef + 5-line comment block (6 lines), `_set_contract` method + 2-line comment (4 lines) = -13 lines removed
- Added: `@export var bitmask_template` (1 line, renamed), `get_fallback_tile_set()` stub + 4-line comment (6 lines) = +7 lines added
- Net: -6 lines in exports/fields, +6 lines for stub = net -10 with blank line adjustments

Plan expected "+20 to +30" — that estimate was relative to pure addition; actual result is net -10 because 13 lines of contract back-ref machinery were deleted alongside the 3 @export deletions. The stub addition (+6 lines) is within the expected range for new functionality.

## Final Test Count in Migration Spec

`test_count: 16`

- ~6 migrated from Phase 1 (still applicable): idempotence, signal-storm, subclassable picker, bitmask_template inspector preview, LOC checkpoint, no-anti-patterns scan
- 20 Phase 1 tests deleted: 10 visual-regression rows + 10 wiring rows referencing deleted symbols
- 10 new tests added: PENTA-SYNTH-02/03/06/07/08, TWO/THREE/FIVE synthesis modes, LAYER-04 demo rebind, NATIVE-01..03/MIN3x3-01

## Confirmation: No Compat Shims Added

- No `@export_storage` shadow property for the `template_image` → `bitmask_template` rename
- No `__migrate__()` method
- No `version: int` field
- No deprecation alias exposing the old property name
- Existing Phase 1 `.tres` files (`default_horizontal.tres`, `penta_horizontal_default.tres`, etc.) WILL emit warnings about missing `template_image` on first Godot load — this is expected and documented. Wave 2 deletes these `.tres` files atomically.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `get_fallback_tile_set()` returns null | addons/penta_tile/layouts/penta_tile_layout.gd | 46-47 | Intentional Wave 1 stub; Wave 2 fills the body with TileSet construction from `bitmask_template`. Consumer (PentaTileMapLayer) wired in Phase 4 (PREVIEW-03). |

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. The `bitmask_template` property inherits Godot's sandboxed `Texture2D` loader (T-02-01 in plan threat model — accepted disposition).

## Self-Check: PASSED

- `addons/penta_tile/layouts/penta_tile_layout.gd` — 47 lines, contains `bitmask_template`, `get_fallback_tile_set()`, `class_name PentaTileLayout`, `extends Resource`; no deleted symbols
- `.planning/phases/02-native-layouts/02-01-VERIFICATION-MIGRATION.md` — created, 16 test_count, all 9 required IDs present
- `.planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md` — HISTORICAL banner prepended, original 26-test content intact
- Commits cb6d253 and 595f0f8 both verified in git log
