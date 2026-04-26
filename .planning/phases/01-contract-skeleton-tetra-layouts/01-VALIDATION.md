---
phase: 1
slug: contract-skeleton-tetra-layouts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (no GUT, no GdUnit4) — per `PROJECT.md` "works in my game" quality bar |
| **Config file** | none |
| **Quick run command** | `"C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe" --headless --check-only --path . addons/tetra_tile/tetra_tile_map_layer.gd` (parse-only sanity) |
| **Full suite command** | Manual: open `addons/tetra_tile/demo/tetra_tile_demo.tscn` in editor, drag-paint 5 reference patterns, pixel-diff against `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-*.png` |
| **Estimated runtime** | ~3 s (parse-only) / ~2 min (manual visual regression for 5 patterns) |

---

## Sampling Rate

- **After every task commit:** Run `Godot --headless --check-only --path . <changed-or-new-file.gd>` (parse + class_name resolution sanity)
- **After every plan wave:** Open demo scene in editor; verify load without errors; spot-check 1 of 5 mask configurations against v0.1 baseline (pixel-diff = 0)
- **Before `/gsd-verify-work`:** All 5 reference-pattern visual regressions vs v0.1 baseline pixel-diff = 0; idempotence guard counter test passes; LOC checkpoint logged
- **Max feedback latency:** ~5 s for parse-only / ~2 min for full visual regression

---

## Per-Task Verification Map

> Plan IDs and Task IDs are TBD — populated during planning. The Requirement → Behavior → Test Type mapping below pre-computes the verification needed for each requirement so plans can attach them to tasks.

| Requirement | Behavior to verify | Test Type | Automated Command | File Exists | Status |
|-------------|--------------------|-----------|-------------------|-------------|--------|
| CONTRACT-01 | `@export var atlas_contract: TetraTileAtlasContract` exposes typed Resource picker | manual-editor | open scene; click `atlas_contract` slot; confirm only `TetraTileAtlasContract`-derived resources appear | ❌ W0 (live editor required) | ⬜ pending |
| CONTRACT-02 | Contract declares `version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0` | code-grep | `grep -E '@export var (version\|layout\|variation_seed)' addons/tetra_tile/tetra_tile_atlas_contract.gd` returns 3 lines | ❌ W0 (file doesn't exist yet) | ⬜ pending |
| CONTRACT-03 | `_update_cells` reads from `contract.layout` not v0.1 inline match | code-grep | `grep -c 'match _mask_at\|match mask:' addons/tetra_tile/tetra_tile_map_layer.gd` returns `0` | ✅ (file exists) | ⬜ pending |
| CONTRACT-04 | Null contract renders bit-identical to v0.1 | visual-regression | open demo with `atlas_contract = null`; paint 5 reference patterns; pixel-diff vs `baselines/v0.1-{pattern}.png` = 0 across all 5 | ❌ W0 (baselines + manual run) | ⬜ pending |
| CONTRACT-05 | Idempotence guard + Resource.changed signal-storm prevention | debug-instrumented + manual | inject `var _rebuild_count := 0` into `TetraTileMapLayer`; reassign `atlas_contract = same_value` triggers 0 increments; edit a contract sub-property triggers exactly 1 increment | ❌ W0 (debug instrumentation) | ⬜ pending |
| LAYOUT-01 | `compute_mask(coord, sample_fn)` virtual exists; subclasses override | code-grep | `grep '^func compute_mask' addons/tetra_tile/.../tetra_tile_layout.gd` returns 1 line; same in horizontal + vertical subclasses returns 1 each | ❌ W0 | ⬜ pending |
| LAYOUT-02 | `mask_to_atlas(mask)` virtual exists; base raises push_error | code-grep + manual | same pattern as LAYOUT-01; instantiating raw `TetraTileLayout` and calling `mask_to_atlas(0)` emits `push_error` | ❌ W0 | ⬜ pending |
| LAYOUT-03 | Base declares `template_image: Texture2D`, `fallback_tile_set: TileSet`, `description: String` (multiline), class-level `##` doc-comment | code-grep | `grep -E '@export var (template_image\|fallback_tile_set\|description)' addons/tetra_tile/.../tetra_tile_layout.gd` returns 3 lines; head of file contains `## ` doc-comment | ❌ W0 | ⬜ pending |
| LAYOUT-04 | `AtlasSlot` Resource has 4 properties at correct types | code-grep | `grep -E '@export var (atlas_coords\|transform_flags\|alternative_tile\|diagonal_complement_atlas_coords)' addons/tetra_tile/.../tetra_tile_atlas_slot.gd` returns 4 lines | ❌ W0 | ⬜ pending |
| LAYOUT-05 | `_pack_alternative(alt, flags)` ORs and asserts `alt_id < 4096` | code-grep + manual | `grep '_pack_alternative' addons/tetra_tile/.../tetra_tile_layout.gd` (or wherever it lives) returns ≥ 1 line; calling with `alt_id = 4096` triggers assertion failure (or push_error in non-debug) | ❌ W0 | ⬜ pending |
| TETRA-01 | TetraHorizontal output bit-identical to v0.1 horizontal | visual-regression | demo with `default_horizontal.tres` assigned; paint 5 reference patterns; pixel-diff vs v0.1 baseline = 0 across all 5 | ❌ W0 (baselines + manual run) | ⬜ pending |
| TETRA-02 | TetraVertical output bit-identical to v0.1 vertical | visual-regression | demo with `default_vertical.tres` assigned (after capturing v0.1 vertical baselines with `atlas_layout = VERTICAL`); pixel-diff = 0 | ❌ W0 (baselines + manual run) | ⬜ pending |
| TETRA-03 | Demo scene with bundled default contract = bit-identical to v0.1 | visual-regression | drag-paint a hand-painted pattern in v0.1 demo (baseline) and v0.2 demo with `default_horizontal.tres` (post-Phase-1); pixel-diff = 0 | ❌ W0 (baseline) | ⬜ pending |
| PREVIEW-01 | `template_image: Texture2D` renders inline via Godot's stock preview | manual-editor | open `default_horizontal.tres` in inspector; thumbnail of `tetra_horizontal.png` appears next to `template_image` field; no custom plugin loaded | ❌ W0 (live editor required) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **`baselines/` directory + 5 v0.1 reference screenshots** — open `addons/tetra_tile/demo/tetra_tile_demo.tscn` in editor BEFORE any Phase 1 code lands; drag-paint 5 reference patterns (single isolated tile, 2×3 rectangle, L-shape, single-row strip, 4×4 checkerboard); save to `.planning/phases/01-contract-skeleton-tetra-layouts/baselines/v0.1-{horizontal,vertical}-{pattern}.png` (10 PNGs total, 5 per atlas_layout enum value). Without these, all visual-regression tests in the table above are unverifiable.
- [ ] **Debug-build instrumentation** — add `var _rebuild_count: int = 0` field to `TetraTileMapLayer` (gated behind `if OS.is_debug_build():`), increment in `_queue_rebuild`. Reset/read by the verification recipe for CONTRACT-05.
- [ ] **`addons/tetra_tile/contracts/` directory** — created during Phase 1, holds 4 bundled `.tres` files (2 contracts + 2 layout instances). No directory pre-creation needed by Wave 0.
- [ ] **Pre-Phase-1 LOC snapshot** — `wc -l addons/tetra_tile/*.gd` BEFORE Phase 1 starts; saved to `.planning/phases/01-contract-skeleton-tetra-layouts/loc-baseline.txt`. End-of-Phase-1 LOC checkpoint compares against this.
- [ ] No framework install — visual regression is manual + pixel-diff in any external image-diff tool (e.g., ImageMagick `compare -metric AE a.png b.png /dev/null`); no GUT, no GdUnit4 needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inspector typed-picker shows only `TetraTileAtlasContract` subclasses | CONTRACT-01 | No headless path to verify inspector UI | Open scene; click `atlas_contract` slot in inspector; confirm dropdown lists only `TetraTileAtlasContract`-derived resources (or "<empty>") |
| Inspector typed-picker shows only `TetraTileLayout` subclasses for `contract.layout` | (success criterion 5) | Same | Open `default_horizontal.tres` in inspector; click `layout` slot; confirm dropdown lists `TetraTileLayoutTetraHorizontal`, `TetraTileLayoutTetraVertical`, and `TetraTileLayout` (base) |
| `template_image` renders thumbnail inline | PREVIEW-01 | Same — Godot's stock Texture2D preview is editor-only | Open `tetra_horizontal_default.tres` in inspector; thumbnail of `tetra_horizontal.png` visible next to `template_image` field |
| Visual regression bit-identity (5 patterns × 2 enum values × 3 contract states = 30 pixel-diffs) | CONTRACT-04, TETRA-01, TETRA-02, TETRA-03 | Renderer determinism is reproducible but rebuild trigger requires editor or game-loop run | Capture baselines (Wave 0); after each plan wave, recapture; pixel-diff every PNG; all must equal 0 |

*Inspector tests are unavoidable manual steps; no automation gain at v0.2 demo scope.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify (`code-grep` / `--check-only` parse) OR Wave 0 dependency (visual-regression baseline)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (parse-only is the floor)
- [ ] Wave 0 covers all `❌ W0` references (baselines + debug instrumentation + LOC snapshot)
- [ ] No watch-mode flags — all verification is on-demand
- [ ] Feedback latency < 5s for parse / < 2min for visual regression (acceptable per "works in my game")
- [ ] `nyquist_compliant: true` set in frontmatter once all tasks attach to this map

**Approval:** pending
