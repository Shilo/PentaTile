# Phase 3: TileBitTools Design-Inspiration Audit (Wave 0b deliverable, D-84)

**Audited:** 2026-04-29
**TBT version:** main branch as cloned at `C:\Programming_Files\Godot\tile_bit_tools-main\` (~3,825 LOC across 30 GDScript files + 12 `.tres` templates + 7 example PNGs)
**Status:** Complete — all 9 audit categories classified
**Policy:** D-73 (NO code copy, NO data lift). This audit produces IDEAS, not snippets. Every recommendation is written in PentaTile's own style as prose or pseudo-code; no TBT identifiers leak into PentaTile source. Where this audit cites TBT class names (`BitData`, `EditorBitData`, `TemplateBitData`, etc.), the reference is **descriptive** — naming the source location of the pattern. Recommendations always rename to PentaTile-namespace equivalents (`PentaTileLayoutData`, `PentaTileLayoutLoader`, etc.) per the project's "Coined-Term Discipline" invariant in CLAUDE.md.

> **Why this audit exists.** The user's discuss-phase direction (`03-CONTEXT.md` D-73) flipped Phase 3 from "transcribe TBT slot tables" to "implement layouts from each format's own primary reference." That reframing left ~3,825 LOC of TBT addon source on the table as design-inspiration material. D-84 commissioned this audit so future plan-phases can inherit verdicts rather than re-litigate. The audit deliberately overshoots the minimum 350-line gate; reasoning column verbosity beats terseness when the goal is to lock decisions for v0.3+.

> **What this audit is NOT.** It is not a bug report on TBT. It is not a competitive teardown. It is not a license review (TBT is MIT; that is settled). It is a **decision-locking artifact**: every TBT pattern receives a verdict (ADOPT / PARTIAL / ADOPT-DEFERRED / REJECT) that future phases can cite without re-reading TBT.

---

## Section 1 — TL;DR table

The following table summarizes every audited pattern's verdict and the phase that should pick it up. Detailed reasoning lives in Section 2; backlog seeds in Section 4.

| Pattern | Verdict | Action | Phase |
|---------|---------|--------|-------|
| BitData / EditorBitData / TemplateBitData Resource hierarchy | PARTIAL (already done) | Mirror the pattern (base class + concrete subclasses); `PentaTileLayout` already does this. Reject the 3-tier split. | 3 (no work; pattern is in flight) |
| EditorInspectorPlugin scene-tree walk | REJECT | Do nothing. Project rejects editor-UX polish per CLAUDE.md identity guardrail. | never |
| `_custom_tags : Array[String]` template metadata vocabulary | ADOPT-DEFERRED | Backlog seed: layout-tag vocabulary on `PentaTileLayout` base when layout count threshold trips. | 0.3+ (trigger: layouts ≥ 12) |
| `tiles_preview` SubViewport overlay | REJECT | Do nothing. Editor-UX polish; PentaTile uses Godot's stock inspector preview. | never |
| `theme_updater` editor theme harmonization | REJECT | Do nothing. Editor-UX polish. | never |
| Save-template / Edit-template dialogs | REJECT | Do nothing. User-authored layouts are subclasses on disk; no save-as UI. | never |
| Project Settings keys (`addons/tile_bit_tools/output/...`) | ADOPT-DEFERRED | Backlog seed: single Project Settings key for verbosity once ≥2 surfaces exist. | 0.3+ (trigger: ≥2 verbosity surfaces) |
| Paul Tol color-blind palette | REJECT | Do nothing for v0.2. Audit notes precedent for v2 multi-terrain coloring. | v2 (only if MULTITERR-* lands) |
| 12 bundled `.tres` files as a curation pattern | ADOPT (already done) | PentaTile ships per-layout greybox PNGs; Phase 3 adds 3 more. Pattern is in flight. | 3 (already in flight) |
| `core/output.gd` verbosity channels (USER/INFO/DEBUG) | REJECT (v0.2) | Single instrumentation surface today (`OS.is_debug_build()` rebuild count); no multi-channel surface needed. | 0.3+ if verbosity surfaces multiply |
| `controls/bit_data_draw/bit_data_draw.gd` peering-bit color overlay | REJECT | PentaTile renders silhouettes, not bit colors. Out of scope. | never |

**Verdict distribution:** 0 ADOPT (work to do), 2 ADOPT (already done), 2 ADOPT-DEFERRED (backlog seeds), 1 PARTIAL (already done), 6 REJECT.

---

## Section 2 — Per-pattern verdict table

| # | Pattern | TBT location (file:line LOC) | TileMapDual equivalent | Verdict | Reasoning (cite PROJECT.md / CLAUDE.md guardrail) | Action |
|---|---------|------------------------------|------------------------|---------|---------------------------------------------------|--------|
| 1 | `BitData → EditorBitData / TemplateBitData` Resource hierarchy: a base Resource holding tile-keyed terrain data, with one subclass for "live editor selection" and one subclass for "serialized template on disk." Implemented at `tile_bit_tools/core/bit_data.gd:1-245` (base; declares `enum TerrainBits` line 7-17, `var CellNeighborsByMode` line 25, getters/setters lines 138-159), `tile_bit_tools/core/editor_bit_data.gd:1-123` (extends base; reads from live `TileSet`/`TileSetAtlasSource`), `tile_bit_tools/core/template_bit_data.gd:1-105` (extends base; adds `version`, `template_name`, `template_description`, `_custom_tags` line 9-22, `built_in`/`preview_texture` runtime-only fields). | None directly. TileMapDual uses Godot's raw `terrain_peering_bits` API and stores a per-cell tracking dict; no parallel Resource hierarchy. | PARTIAL (already done) | PentaTile's `PentaTileLayout` base + concrete subclasses (`PentaTileLayoutPenta`, `PentaTileLayoutDualGrid16`, `PentaTileLayoutWang2Edge`, `PentaTileLayoutWang2Corner`, `PentaTileLayoutMinimal3x3`) already mirror the abstract-base + concrete-subclasses pattern. Per **PROJECT.md "Identity"** ("smaller and simpler than TileMapDual") and **CLAUDE.md "Identity Guardrails"** the *3-tier* split (base + editor + template) is rejected: PentaTile has no "live editor selection" concept — layouts are runtime Resources, not edit-time mutations of TileSet metadata. The base + concrete pattern survives; the live-vs-serialized split does not. | Continue using `PentaTileLayout` base + concrete subclasses as Phase 3 already plans. No 3-tier split. No `PentaTileLayoutData` distinct from `PentaTileLayout`. |
| 2 | `EditorInspectorPlugin` walking Godot's internal editor scene tree to attach UI to the stock TileSet editor. Implemented at `tile_bit_tools/inspector_plugin.gd:1-353` — `extends EditorInspectorPlugin` (line 2), references private editor classes via string lookup (`tile_set_editor : Node`, `atlas_source_editor : Node`, `tile_atlas_view : Node` lines 25-27, plus `atlas_source_proxy`/`atlas_tile_proxy` lines 31-32 — internal `Object` proxies obtained by walking the editor's own scene tree from `_can_handle` line 135 / `_parse_end` line 145). | None. TileMapDual is a runtime node; it does not extend the editor at all. | REJECT | **CLAUDE.md "Identity Guardrails"** explicitly lists `EditorInspectorPlugin` polish as a guardrail-rejected category ("typed `@export` + `@export_group` is enough"). **PROJECT.md Out of Scope** lists "Custom layout authoring polished surface (`EditorInspectorPlugin`)" as deferred indefinitely. Walking internal class names (`TileSetEditor`, `AtlasTileProxyObject`, `TileAtlasView`) is fragile across Godot 4.x minor versions — TBT's archive note ("no longer being actively maintained") at `tile_bit_tools/README.md` is partly because every Godot minor version risks breaking the scene-tree walk. **PROJECT.md Constraints** ("smaller and simpler than TileMapDual") forbids this entire surface. | Do nothing. The audit explicitly does not relitigate this REJECT. |
| 3 | `_custom_tags : Array[String]` template metadata vocabulary, with auto-tag definitions in `tile_bit_tools/core/template_tag_data.gd:1-134` (`enum Tags` line 7, `var tags` dict at line 72, `var tag_display` array at line 124). Templates declare per-`.tres` tags like `["Tilesetter"]`, `["Godot 3", "TilePipe2"]`, `["Incomplete Autotile", "Simple"]` — see the bundled-template inventory in `.planning/research/layouts/TILEBITTOOLS.md` § 5. The TBT inspector's `templates_section.gd:1-276` filters templates by selected tags. | None. | ADOPT-DEFERRED (PARTIAL) | The vocabulary itself is sound design — once a layout library has enough entries that picking one is non-obvious, tag-based filtering becomes useful. PentaTile v0.2 will end at ~10 layouts (5 Phase 2 native + 3 Phase 3 public-convention + 2 Phase 3.5 PixelLab). **CLAUDE.md "Identity Guardrails"** forbids editor UI for filtering, but `Array[StringName]` on the layout itself is just metadata — typed `@export`, no editor polish. **PROJECT.md "Constraints"** allows additions that don't grow the editor surface. The trigger to un-defer is layout count ≥ 12 (a layout count where users will actually want to filter); current count below threshold so the cost (≈30 LOC + vocabulary review) doesn't yet pay off. | Backlog seed (Section 4): `2026-04-29-add-layout-tags-vocabulary.md`. v0.3+ phase suggestion. |
| 4 | `tiles_preview` SubViewport-based live overlay rendering bit colors over tile atlas. Implemented at `tile_bit_tools/controls/tiles_preview/tiles_preview.gd:1-206` (`extends Control` line 2; uses `var preview_bit_data : TBTPlugin.EditorBitData` line 16, `var base_image : Image` line 20, `var image_crop_rect : Rect2i` line 22). Renders a SubViewport on top of Godot's stock atlas view to show terrain-bit color overlays. | None. TileMapDual has its own dual-display node but does not overlay editor UI. | REJECT | **CLAUDE.md "Identity Guardrails"** ("no `EditorInspectorPlugin` polish") and **PROJECT.md Out of Scope** ("Custom layout authoring polished surface") both reject editor overlays. PentaTile's `bitmask_template : Texture2D` exposed on every layout is enough — it shows up in the inspector's stock Texture2D preview. SubViewport overlays add maintenance cost (theme harmonization, opacity sliders, atlas-coord mapping) for a UX win the project doesn't need. | Do nothing. |
| 5 | Editor theme harmonization. Implemented at `tile_bit_tools/controls/tbt_plugin_control/theme_updater.gd:1-268` (`extends Control` line 2; uses `var override_properties` line 27, `var override_methods` line 43, `var overrides_dict` line 59). Detects the user's active Godot editor theme and re-tints TBT's UI panels to match. ~268 LOC for cosmetic parity with editor theme. | None. | REJECT | **CLAUDE.md "Identity Guardrails"** ("smaller and simpler than TileMapDual") forbids non-load-bearing UI surface. PentaTile uses Godot's stock inspector — theme harmonization is automatic. **PROJECT.md Constraints** ("smaller and simpler than TileMapDual") forbids 268 LOC of editor cosmetics by definition. | Do nothing. |
| 6 | Save-template / Edit-template / Template-picker popups. Implemented at `tile_bit_tools/controls/tbt_plugin_control/popups/save_template_dialog.gd:1-75` (extends `template_dialog.gd`, line 2; `_get_save_path` line 37, `_get_save_dir` line 49, `_on_save_template_requested` line 74), with sibling `edit_template_dialog.gd` (62 LOC) and `template_dialog.gd` (173 LOC). Provides UX for saving the current TileSet's bit configuration as a `.tres` template at Project / Shared / User folders. | None. TileMapDual has no template authoring UI. | REJECT | **PROJECT.md Out of Scope** lists "Custom layout authoring polished surface" as deferred indefinitely. PentaTile's authoring path is "subclass `PentaTileLayout` in a `.gd` file" — that's the documented experimental UX. Adding a save-as dialog implies bidirectional `.tres` ↔ class-on-disk plumbing that the project does not need. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids speculative authoring infrastructure ("never add hooks, virtual methods, abstract slots, or extension points 'in case a future feature needs them'"). | Do nothing. |
| 7 | Project Settings keys for addon configuration. Implemented at `tile_bit_tools/core/globals.gd:1-95` (`const PROJECT_SETTINGS_PATH := "addons/tile_bit_tools/"` line 41, `const Settings` dict line 43-94). Exposes paths, output verbosity flags, and color overrides as Project Settings entries readable via `ProjectSettings.get_setting()`. | None. | ADOPT-DEFERRED (PARTIAL) | The pattern is reasonable for an addon with multiple verbosity / configuration surfaces. PentaTile today has exactly one ad-hoc instrumentation surface (`OS.is_debug_build()`-gated `_rebuild_count` print in `penta_tile_map_layer.gd`); a single Project Settings key (`addons/penta_tile/output/show_debug_logs`) would simplify it but is overkill for one consumer. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids adding settings "in case a future feature needs them"; the un-defer trigger is concrete: ≥2 verbosity / configuration surfaces actually existing. | Backlog seed (Section 4): `2026-04-29-add-project-settings-verbosity.md`. v0.3+ phase, trigger condition specified. |
| 8 | Paul Tol color-blind-friendly palette for terrain bit colors. Implemented at `tile_bit_tools/core/globals.gd:43-94` (the `Settings` const dict's color entries reference `colors/auto_terrain_color_*` Project Settings keys with hex defaults from Tol's "bright" scheme — `#AA3377`, `#CCBB44`, `#228833`, `#66CCEE`). | None. | REJECT (v0.2) | PentaTile does NOT render multi-terrain previews, so there is no surface that consumes terrain colors. **PROJECT.md Out of Scope** lists "Outer transition tile support (multi-terrain)" as v2. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids adding palettes "in case a future feature needs them." This audit notes the precedent for whenever multi-terrain (MULTITERR-01..05) lands; if so, that future phase can adopt Tol's scheme by reference. | Do nothing for v0.2. The Section 5 anti-pattern register notes the precedent. |
| 9 | The 12 bundled `.tres` files in `tile_bit_tools/templates/` as a CURATION PATTERN — shipping enough templates that the addon works out of box without external assets. Inventory: `godot3_2x2.tres`, `godot3_3x3_16_tiles.tres`, `godot3_3x3_minimal.tres`, `simple_4-tile_(inside_corners).tres`, `simple_9-tile_(inside_corners).tres`, `simple_9-tile_(outside_corners).tres`, `tilesetter_blob.tres`, `tilesetter_wang.tres`, `tilesetter_wang_3-terrain.tres`, `tilesetter_wang_3-terrain_transitions.tres`, `tilepipe2_256_tile_16x16.tres`, `tilepipe2_256_tile_32x8.tres`. | TileMapDual ships ZERO bundled templates (relies on the user supplying their own atlas). | ADOPT (already done) | PentaTile v0.2 already ships per-layout bundled bitmask PNGs in `addons/penta_tile/layouts/penta_tile_layout_<slug>.png` (5 from Phase 2; Phase 3 adds 3 more per D-85 + TEMPLATE-02; Phase 3.5 adds 2 PixelLab). The "addon works out of box" test is satisfied by these bundled PNGs feeding `get_fallback_tile_set()` codegen at runtime. **PROJECT.md "Core Value"** ("Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets") aligns with shipping fallback assets. | No action: the pattern is in flight in Phase 3 (3 new PNGs ship as part of TEMPLATE-02). |
| 10 | `core/output.gd` verbosity-controlled output channels. Implemented at `tile_bit_tools/core/output.gd:1-160` (`enum MessageTypes {USER, INFO, DEBUG}` line 5, `func user(msg, ...)` line 39, `func info(msg ...)` line 43, `func debug(msg ...)` line 47, `func error(msg ...)` line 51, `func warning(msg ...)` line 65). Three channels gated by `_is_message_type_enabled` line 126, configurable via Project Settings. | None directly. TileMapDual prints freely. | REJECT (v0.2) | PentaTile has exactly one verbosity surface today (`OS.is_debug_build()`-gated `_rebuild_count` print). A 160-LOC multi-channel verbosity helper for one consumer fails **PROJECT.md "Constraints"** ("smaller and simpler than TileMapDual") and the **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** ban on speculative infrastructure. The audit pairs this with item 7 (Project Settings) — both un-defer together when ≥ 2 surfaces exist. | Do nothing for v0.2. Same backlog seed as item 7 (paired). |
| 11 | `controls/bit_data_draw/bit_data_draw.gd` peering-bit color overlay (~237 LOC). Implemented at `tile_bit_tools/controls/bit_data_draw/bit_data_draw.gd:1-237` (`extends Control` line 2; `enum RectPoint` line 5; `var bit_shapes` line 16-141; uses `BitData` reference line 142; `var atlas_rect`, `var terrain_set`, `var terrain_mode`, `var terrain_colors` lines 158-164). Decomposes a `BitData` Resource into colored rectangles per peering bit and draws them as an overlay in the inspector. | None. | REJECT | PentaTile renders **silhouettes**, not bit colors. The 47-blob and Wang/Tilesetter layouts shipped in Phase 3 are encoded by atlas POSITION (per the layout's `_MASK_TO_ATLAS` const dict), not by bit-color overlay. The bitmask_template PNG is a single grey silhouette per slot — no per-bit color is ever drawn. **CLAUDE.md "Identity Guardrails"** ("no `EditorInspectorPlugin` polish") forbids overlay drawing in the inspector. The TBT design here exists to communicate Godot's terrain-peering-bit semantics; PentaTile bypasses that semantic layer entirely. | Do nothing. |

**Anti-pattern reminder (table reasoning column):** every REJECT cites a specific guardrail. "Vague" justifications fail the audit. Every reasoning cell above names at least one of: PROJECT.md "Identity", PROJECT.md "Constraints", PROJECT.md "Out of Scope", CLAUDE.md "Identity Guardrails", CLAUDE.md "Breaking Changes Policy (HARD RULE)", CLAUDE.md "Coined-Term Discipline".

**TBT class-name audit policy clarification (W-2 from RESEARCH §6):** TBT class names ARE PERMITTED in audit prose when citing TBT source ("TBT's bit-data hierarchy lives at `tile_bit_tools/core/bit_data.gd:1-245`"). The forbidden pattern is **adopting** those names into PentaTile — a recommendation of the form "PentaTile should add a class with the same name as TBT's base bit-data Resource" is forbidden; "PentaTile could add a `PentaTileLayoutData` class with similar role" is permitted. The acceptance-criteria greps for the literal GDScript declaration sequences (the keyword pair followed by the TBT class identifier) catch the adoption pattern; descriptive citations of the TBT identifier in audit prose are unaffected because they appear as text, not as GDScript declaration sequences.

---

## Section 3 — Cross-reference appendix

For each pattern in Section 2, this appendix briefly describes what (if anything) TileMapDual does in the same conceptual space. TileMapDual's source is **not vendored locally** for this audit; references below are based on PROJECT.md identity-guardrail descriptions of TileMapDual's documented behavior plus the project's own audit notes (`.planning/research/layouts/MASK_UNIFICATION.md`, `.planning/research/layouts/COMPARISON.md`). When a specific behavior is not directly known, the row says "Not present in TileMapDual to my knowledge" and the audit's verdict still stands — the cross-reference is a tiebreaker, not the primary verdict source.

| # | Pattern | TileMapDual cross-reference |
|---|---------|------------------------------|
| 1 | BitData / EditorBitData / TemplateBitData hierarchy | TileMapDual stores per-cell terrain metadata in its internal tracking dict (cf. PROJECT.md "Persistent coordinate caches" guardrail — TileMapDual is the cited example). It does not have a separate Resource hierarchy for "live selection" vs "serialized template" because TileMapDual is a runtime-only addon. PentaTile's `PentaTileLayout` Resource hierarchy is closer to TBT's `BitData` than to anything in TileMapDual. |
| 2 | EditorInspectorPlugin scene-tree walk | TileMapDual does not extend the editor. **PentaTile's REJECT here makes PentaTile strictly smaller in editor footprint than TileMapDual** (TileMapDual: 0 editor surface; PentaTile: 0 editor surface; TBT: ~3,825 LOC of editor surface). |
| 3 | `_custom_tags` template vocabulary | Not present in TileMapDual to my knowledge. TileMapDual ships zero templates and uses the user's atlas directly. |
| 4 | tiles_preview SubViewport overlay | Not present in TileMapDual. TileMapDual's "preview" is its runtime dual-display node; no editor overlay. |
| 5 | theme_updater | Not present in TileMapDual. |
| 6 | Save-template dialogs | Not present in TileMapDual. |
| 7 | Project Settings keys | Not present in TileMapDual to my knowledge — TileMapDual exposes configuration via `@export` properties on its node. |
| 8 | Paul Tol palette | Not present in TileMapDual. TileMapDual does not render multi-terrain previews. |
| 9 | Bundled `.tres` curation | TileMapDual ships ZERO bundled templates (per PROJECT.md "Context" reference). PentaTile's "ship enough samples" pattern is closer to TBT than to TileMapDual. |
| 10 | core/output.gd verbosity channels | Not present in TileMapDual to my knowledge — TileMapDual prints freely (and is cited in PROJECT.md as having signal-fanout / leak issues, which suggests a different debug-output history). |
| 11 | bit_data_draw peering-bit color overlay | Not present in TileMapDual. TileMapDual's display layer renders fully composited tiles, not bit-decomposition overlays. |

**Cross-reference summary:** of 11 audited TBT patterns, **1** has a TileMapDual analog (item 1 — internal terrain-metadata tracking, though the *form* differs significantly: TBT uses a Resource hierarchy, TileMapDual a tracking dict). The other 10 are TBT-only — they reflect TBT's identity as an edit-time inspector plugin, which TileMapDual is not. **PentaTile's positioning relative to both:** the project lands closer to TileMapDual on editor footprint (zero) and closer to TBT on bundled-asset curation (ship per-layout fallback PNGs). This is intentional — see PROJECT.md Identity for the alignment.

---

## Section 4 — Backlog seeds

Each subsection below is a backlog seed for a PARTIAL or ADOPT-DEFERRED entry from Section 2. The seed itself, **not this audit file**, declares its target filename in `.planning/todos/pending/`. Phase 5 closeout (or whatever phase processes Phase 3's backlog spillover) creates the actual todo files.

### Backlog seed: Layout tags vocabulary (item 3)

- **Suggested file:** `.planning/todos/pending/2026-04-29-add-layout-tags-vocabulary.md`
- **Phase suggestion:** v0.3+ — first available phase after layout count crosses ≥ 12 (current end-of-v0.2 estimate: ~10 layouts).
- **Implementation sketch (≤10 lines, prose, NO code lift):** Add a typed `tags : Array[StringName]` `@export` to the PentaTile layout base class (`addons/penta_tile/layouts/penta_tile_layout.gd`). Vocabulary, locked at design-phase: `["Public", "Tilesetter", "BorisTheBrave", "PixelLab", "Empirical", "Penta"]`. Each concrete layout sets its tags in `_init` (or via inspector). No editor UI. No filtering surface. The tags exist purely as machine-readable metadata for any future discovery surface (e.g., a `find_layouts_by_tag()` static helper, ~10 LOC). Bound to ~30 LOC total addition.
- **Why deferred:** un-defer trigger is layout count ≥ 12 — below that, picking a layout from the inspector dropdown is fast enough that filtering offers no win. The cost (vocabulary review + class doc-comment updates per layout) doesn't pay off until users actually wade through a long list.
- **Anti-pattern guard:** the seed does NOT propose adopting TBT's `_custom_tags : Array` (untyped). PentaTile uses typed `Array[StringName]`. The seed does NOT propose any inspector filtering UI. It does NOT propose the `template_tag_data.gd` auto-tag machinery (which assigns tags based on template metadata) — PentaTile layouts are GDScript classes, so tags are author-declared, not auto-derived.

### Backlog seed: Project Settings verbosity key (items 7 + 10, paired)

- **Suggested file:** `.planning/todos/pending/2026-04-29-add-project-settings-verbosity.md`
- **Phase suggestion:** v0.3+ — first available phase after PentaTile gains a second verbosity surface beyond `OS.is_debug_build()`-gated `_rebuild_count` instrumentation.
- **Implementation sketch (≤10 lines, prose, NO code lift):** Register a single Project Settings key — `addons/penta_tile/output/show_debug_logs : bool` — read once at `_ready` of `PentaTileMapLayer` into a private `_show_debug_logs` cache. Replace the `OS.is_debug_build()` gate with `_show_debug_logs`. If a second verbosity surface ever lands (e.g., synthesis re-run logging), it reads the same flag. No multi-channel verbosity enum (USER/INFO/DEBUG); a single bool is enough. Bound to ~15 LOC.
- **Why deferred:** un-defer trigger is ≥ 2 verbosity surfaces actually existing. With one surface today, the abstraction adds cost without benefit. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids adding the key "in case a future feature needs it." When the second surface lands, that feature's plan-phase adopts this seed.
- **Anti-pattern guard:** the seed does NOT propose adopting TBT's `core/output.gd` 3-channel verbosity (USER/INFO/DEBUG). A single bool is enough for PentaTile's surface. The seed does NOT propose adopting TBT's `Settings` const dict structure — PentaTile uses a single-key registration, not a dictionary of settings.

### Backlog seed: Save-custom-layout dialog — REJECTED outright

- **Suggested file:** N/A (this seed is documented for completeness only; no `.planning/todos/pending/` file is created).
- **Phase suggestion:** never.
- **Reasoning:** TBT's `save_template_dialog.gd` is the load-bearing UX for an editor-time addon whose value proposition is "click-author Godot's terrain bits faster." PentaTile's value proposition is "subclass a typed Resource and you're done." The save-dialog is unnecessary for the latter. **PROJECT.md Out of Scope** lists "Custom layout authoring polished surface (`EditorInspectorPlugin`)" — the save dialog is a subset of that. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids the speculative authoring infrastructure that the dialog implies.
- **Why no backlog file:** the audit explicitly rejects the pattern; reopening it in a future phase requires fresh design work, not a pre-staged seed.

---

## Section 5 — Anti-pattern register

This section crystallizes the REJECT verdicts as identity-protective rules. Future plan-phases reference this register to bypass re-auditing — when a new plan-phase considers a pattern that smells like one of these, the planner checks this section first.

- **AP-1 (REJECT) — `EditorInspectorPlugin` scene-tree walking.** Walking Godot's internal editor class names (`TileSetEditor`, `AtlasTileProxyObject`, `TileAtlasView`) is fragile across Godot 4.x minor versions. PentaTile uses public APIs only. Source justification: CLAUDE.md "Identity Guardrails" + PROJECT.md Out of Scope ("Custom layout authoring polished surface").
- **AP-2 (REJECT) — SubViewport overlays in the editor.** Adds maintenance cost (theme harmonization, opacity sliders, atlas-coord mapping) for a UX win the project does not need. Source: CLAUDE.md "Identity Guardrails."
- **AP-3 (REJECT) — Editor theme harmonization.** Cosmetic parity with the user's editor theme is not load-bearing for a runtime addon. Stock Godot inspector theme is the contract. Source: CLAUDE.md "Identity Guardrails" + PROJECT.md "Constraints" ("smaller and simpler than TileMapDual").
- **AP-4 (REJECT) — Save-as / edit-template dialogs.** PentaTile's authoring path is "subclass `PentaTileLayout` in a `.gd` file." A save-as dialog implies bidirectional `.tres` ↔ class-on-disk plumbing the project does not need. Source: PROJECT.md Out of Scope + CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility."
- **AP-5 (REJECT) — Speculative configuration palettes.** Color-blind palettes, debug-channel enums, multi-key Project Settings dictionaries — all forbidden until ≥ 2 actual consumers exist. Source: CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility" ("never add hooks, virtual methods, abstract slots, or extension points 'in case a future feature needs them'").
- **AP-6 (REJECT) — Peering-bit color overlay rendering.** PentaTile renders silhouettes, not bit colors. Layouts encode masks by atlas POSITION via `_MASK_TO_ATLAS` const dicts. No per-bit overlay drawer is needed; no inspector overlay is needed. Source: CLAUDE.md "Identity Guardrails" + PROJECT.md "Core Value" (paint with native API → correct visuals; no manual bit metadata).
- **AP-7 (REJECT) — 3-tier Resource hierarchy (base + live-editor + template).** PentaTile has no "live editor selection" concept; layouts are runtime Resources, not edit-time mutations of TileSet metadata. The 2-tier base + concrete pattern (`PentaTileLayout` + concrete subclasses) is sufficient. Source: PROJECT.md "Identity" + the `PentaTileLayout` base class architecture from Phase 1.
- **AP-8 (REJECT) — Lifting TBT class names into PentaTile.** D-73 lock: NO code copy, NO data lift. Recommendations always rename to PentaTile-namespace equivalents (`PentaTileLayoutData`, `PentaTileLayoutLoader`, etc.). Source: D-73 + Claude memory `feedback_no_competitor_code_copy.md`.
- **AP-9 (REJECT) — Lifting TBT `.tres` data.** Each layout's slot table comes from the FORMAT's own primary reference, never from TBT's encoding. Source: D-73 + D-74 (BorisTheBrave for Blob47Godot) + D-75 (Tilesetter manual for Tilesetter*).
- **AP-10 (REJECT) — `addons/penta_tile/ATTRIBUTION.md`.** Nothing is lifted, so nothing requires attribution. The 1-line README footnote acknowledges TBT as design inspiration; no separate attribution file. Source: D-72 + D-73.

**Use of this register in future phases:** when a plan-phase considers a pattern, search this register first. If the pattern matches an AP-N entry, the verdict is REJECT and no further audit work is needed. If a new pattern surfaces that doesn't match an existing AP-N, the plan-phase generates a delta entry (e.g., `AP-11`) and pins it to this register at the next audit refresh.

---

## Section 6 — Verification checklist (self-audit)

Before saving this audit, the following checklist was confirmed:

- [x] Every TBT file referenced in Section 2 has a verifiable `(file:line)` citation. Citations include: `tile_bit_tools/core/bit_data.gd:1-245` (lines 7-17, 25, 138-159 for specific features), `tile_bit_tools/core/editor_bit_data.gd:1-123`, `tile_bit_tools/core/template_bit_data.gd:1-105` (lines 9-22 for `_custom_tags`), `tile_bit_tools/inspector_plugin.gd:1-353` (lines 25-27, 31-32, 135, 145), `tile_bit_tools/core/template_tag_data.gd:1-134` (lines 7, 72, 124), `tile_bit_tools/core/template_loader.gd:1-257`, `tile_bit_tools/core/globals.gd:1-95` (lines 41, 43-94), `tile_bit_tools/core/output.gd:1-160` (lines 5, 39, 43, 47, 51, 65, 126), `tile_bit_tools/controls/tiles_preview/tiles_preview.gd:1-206` (lines 16, 20, 22), `tile_bit_tools/controls/tbt_plugin_control/theme_updater.gd:1-268` (lines 27, 43, 59), `tile_bit_tools/controls/tbt_plugin_control/popups/save_template_dialog.gd:1-75` (lines 37, 49, 74), `tile_bit_tools/controls/bit_data_draw/bit_data_draw.gd:1-237` (lines 5, 16-141, 142, 158-164).
- [x] Every PARTIAL / ADOPT-DEFERRED has a corresponding Section 4 backlog seed: items 3 (Layout tags) and items 7 + 10 paired (Project Settings + verbosity).
- [x] Every REJECT has a Section 5 register entry: AP-1 through AP-10 cover items 2, 4, 5, 6, 8, 11 + the cross-cutting D-73 lifts (AP-8/9/10).
- [x] No code blocks copy TBT source verbatim. The audit contains no GDScript fenced blocks at all — recommendations are pure prose. Where pseudo-code is implicit (e.g., the layout-tags backlog seed), it is described in PentaTile's idiom (typed `Array[StringName]`, `@export`, PentaTile-namespaced names).
- [x] No identifier names from TBT (`BitData`, `EditorBitData`, `TemplateBitData`, `template_loader`, `tbt_plugin_control`, `theme_updater`, `tiles_preview`, `bit_data_draw`) appear in any "Action" column or Section 4 implementation sketch as adopted PentaTile names. They appear only in pattern-description prose with explicit `tile_bit_tools/...` path prefixes (descriptive citations, not adoption recommendations). Section 4 sketches name PentaTile equivalents in PentaTile-style: `PentaTileLayout` base, `_show_debug_logs`, `addons/penta_tile/output/show_debug_logs`, `find_layouts_by_tag`.
- [x] No `addons/penta_tile/ATTRIBUTION.md` is created or referenced as future work. AP-10 explicitly REJECTS it.
- [x] D-73 and D-84 are both cited in the document body (D-73 in the Policy preamble + AP-8/9/10; D-84 in the title + Section 4 framing).
- [x] At least 2 occurrences of `tile_bit_tools/` path prefix appear (verified — Section 2 alone has 12+).
- [x] At least 1 backlog seed references `.planning/todos/pending/` (verified — both Section 4 seeds do).

---

## Section 7 — References

### Primary source (TBT — read for citation only, NO code lift)

- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\plugin.gd` (62 LOC) — EditorPlugin entry.
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\inspector_plugin.gd` (353 LOC) — EditorInspectorPlugin scene-tree walker (REJECT — AP-1).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\bit_data.gd` (245 LOC) — base Resource for tile-keyed terrain data (PARTIAL already done).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\editor_bit_data.gd` (123 LOC) — live-editor subclass (REJECT 3-tier split — AP-7).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\template_bit_data.gd` (105 LOC) — serialized-template subclass.
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\template_loader.gd` (257 LOC) — discovery + tagging + caching of templates.
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\template_tag_data.gd` (134 LOC) — auto-tag definitions (ADOPT-DEFERRED for typed-vocab analog).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\globals.gd` (95 LOC) — Project Settings + Paul Tol palette (ADOPT-DEFERRED for verbosity / REJECT for palette).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\core\output.gd` (160 LOC) — verbosity channels (REJECT v0.2).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\controls\tiles_preview\tiles_preview.gd` (206 LOC) — SubViewport overlay (REJECT — AP-2).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\controls\tbt_plugin_control\theme_updater.gd` (268 LOC) — theme harmonization (REJECT — AP-3).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\controls\tbt_plugin_control\popups\save_template_dialog.gd` (75 LOC) — save-template dialog (REJECT — AP-4).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\controls\bit_data_draw\bit_data_draw.gd` (237 LOC) — peering-bit color overlay (REJECT — AP-6).
- `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\templates\` (12 `.tres` files) — bundled curation (ADOPT already done).

### Prior PentaTile audits (extended by this deliverable)

- `.planning/research/layouts/TILEBITTOOLS.md` — informational background audit (read 2026-04-25). This deliverable extends that one with explicit ADOPT/PARTIAL/REJECT verdicts cross-referenced against TileMapDual, plus backlog seeds for ADOPT-DEFERRED items.

### Project-level guardrails (cited throughout)

- `.planning/PROJECT.md` § Identity — "smaller and simpler than TileMapDual" guardrail.
- `.planning/PROJECT.md` § Constraints — tech stack, distribution, audience, performance, identity.
- `.planning/PROJECT.md` § Out of Scope — explicit deferred surfaces.
- `.planning/PROJECT.md` § Core Value — what the project actually delivers.
- `CLAUDE.md` § Identity Guardrails — six rejected categories (terrain peering, multi-terrain, watchers, persistent caches, custom drawing API, EditorInspectorPlugin polish).
- `CLAUDE.md` § Coined-Term Discipline — "Penta" reservation invariant.
- `CLAUDE.md` § Breaking Changes Policy (HARD RULE) — both directions: no backwards-compat shims, no forward-compat speculation.
- `.planning/phases/03-tilebittools-sourced-layouts/03-CONTEXT.md` — D-72 (phase rename), D-73 (no code lift), D-84 (this deliverable spec).

### TileMapDual cross-reference

- TileMapDual source not vendored locally for this audit. Cross-reference rows in Section 3 cite TileMapDual's documented behavior from PROJECT.md identity-guardrail descriptions and from the project's own audit notes (`.planning/research/layouts/MASK_UNIFICATION.md`, `.planning/research/layouts/COMPARISON.md`). Where specific behavior is uncertain, the row says "Not present in TileMapDual to my knowledge"; the audit's verdict still stands because the verdict's primary justification is the cited PROJECT.md / CLAUDE.md guardrail, not the TileMapDual cross-reference.

### Decisions referenced

- D-72: Phase 3 renamed from "TileBitTools-Sourced Layouts" → "Public-Convention Layouts (Blob47 + Tilesetter)."
- D-73: No code copy. No data lift. TBT is design-inspiration only. **LOCKED for this phase and all future PentaTile work.**
- D-74: `PentaTileLayoutBlob47Godot` slot table sourced from BorisTheBrave's published 47-blob reference.
- D-75: Tilesetter slot tables sourced via plan-phase web research from the format's own primary reference, not from TBT's encoding.
- D-84: This audit is the Wave 0b deliverable.

---

## Section 8 — Per-pattern deep-dive narratives

Section 2's verdict table is dense by design. This section unfolds the reasoning for each pattern in narrative form, so a future plan-phase can re-read a single pattern without rebuilding the table's column constraints. Each subsection is keyed to its Section 2 row number (#1..#11).

### #1 — Bit-data Resource hierarchy, narrative

TBT's three-tier Resource hierarchy exists because TBT is an edit-time inspector plugin that bridges two universes. On one side, Godot's stock TileSet editor exposes terrain peering bits via the `TileData` API — a live, mutable, in-memory representation tied to the editor selection. On the other side, TBT's templates are stored as `.tres` files on disk — a serialized, declarative representation. The base `BitData` Resource at `tile_bit_tools/core/bit_data.gd:1-245` defines the shared schema (the `_tiles` dictionary keyed by `Vector2i`, plus the `terrain_set` and `terrain_mode` fields, plus the dispatch lookup `var CellNeighborsByMode` at line 25 mapping terrain modes to neighbor-bit lists). The `EditorBitData` subclass at `tile_bit_tools/core/editor_bit_data.gd:1-123` reads from the live editor selection — its `apply_template_bit_data` method (line 33) and `load_from_tile_data` method (line 58) bridge from `TileData` API into the shared schema. The `TemplateBitData` subclass at `tile_bit_tools/core/template_bit_data.gd:1-105` adds `version`, `template_name`, `template_description`, `_custom_tags`, `template_terrain_count`, `example_folder_path`, plus runtime-only `built_in` and `preview_texture` fields — the metadata that survives serialization to disk.

PentaTile does not have this two-universe bridge. PentaTile layouts are runtime Resources; they do not mutate Godot's `TileData` or `TileSet` metadata. The "live editor" / "serialized template" split has no analog. What PentaTile does share with TBT is the abstract-base + concrete-subclasses pattern itself: `PentaTileLayout` (base, abstract virtuals) is to `BitData` as `PentaTileLayoutPenta` (concrete) is to `TemplateBitData` (in role, not in name). Phase 1 already shipped this pattern. Phase 3 ships three more concrete subclasses on the same shape. **The audit's verdict is "PARTIAL (already done)" because the half of TBT's pattern that fits PentaTile is the half already in flight.** No new work; no further design decision.

The 3-tier split itself is rejected — this rejection is captured as AP-7 in the anti-pattern register. The cost of the 3-tier split is two extra Resource subclasses (~228 LOC in TBT's case) maintained to bridge the live/serialized boundary. PentaTile pays zero of that cost.

### #2 — EditorInspectorPlugin scene-tree walk, narrative

`tile_bit_tools/inspector_plugin.gd:1-353` is the load-bearing class behind TBT's UX. It extends `EditorInspectorPlugin`, an editor-only Godot class that lets addons attach UI to specific Object types in the inspector. TBT's `_can_handle` method (line 135) and `_parse_end` method (line 145) decide when to attach. To reach into the stock TileSet editor's internals, the class declares `var tile_set_editor : Node` (line 25), `var atlas_source_editor : Node` (line 26), `var tile_atlas_view : Node` (line 27), `var atlas_source_proxy : Object` (line 31), and `var atlas_tile_proxy : Object` (line 32). These are **typed by string lookup** — the editor's own scene tree is walked to find nodes whose class names match. This is the Godot 4 equivalent of "private API access via reflection," and it is fragile: every Godot 4.x minor version risks breaking the walk because the editor's internal class names and tree shape are not part of Godot's public API contract.

PentaTile does not extend the editor at all. The project's value proposition does not require it. The user paints with `set_cell()` / `erase_cell()`; the layout's `mask_to_atlas` dispatch happens at runtime; the inspector UI is whatever Godot's stock inspector renders for the layout Resource's typed `@export` properties. **CLAUDE.md "Identity Guardrails"** explicitly REJECTS `EditorInspectorPlugin` polish ("typed `@export` + `@export_group` is enough"). **PROJECT.md Out of Scope** lists "Custom layout authoring polished surface (`EditorInspectorPlugin`)" as deferred indefinitely. The audit's REJECT here is the strongest of any pattern: the entire 353-LOC class plus the ~830 LOC of `tiles_inspector` UI plus the ~250 LOC of `tiles_preview` plus the ~270 LOC of `bit_data_draw` — roughly 1,700 LOC of editor surface — is REJECTED as a category.

This audit recommendation captures the project's existing rejection rather than re-litigating it. Future plan-phases that consider any editor-UX feature (e.g., a "preview the active layout's bitmask in a custom inspector panel" idea) reference AP-1 in the anti-pattern register and stop there.

### #3 — Layout tag vocabulary, narrative

TBT's tag system is a small but well-designed piece of metadata machinery. `tile_bit_tools/core/template_tag_data.gd:1-134` defines an `enum Tags` (line 7) with built-in tag IDs, a `var tags` dict (line 72) mapping tag IDs to display labels, and a `var tag_display` array (line 124) defining display order. Templates declare per-`.tres` tags via the `_custom_tags : Array` field on `TemplateBitData` (`tile_bit_tools/core/template_bit_data.gd` line ~9-22 in the property block). The bundled-template inventory shows the vocabulary in use: `["Tilesetter"]`, `["Godot 3", "TilePipe2"]`, `["Incomplete Autotile", "Simple"]`, `["Plugin Required"]`. The TBT inspector's template picker filters by selected tags via `tile_bit_tools/controls/tiles_inspector/template_section/templates_section.gd:1-276` (a chip-style multi-tag UI).

The pattern surfaces a real need: as a layout library grows past a handful of entries, picking one becomes non-trivial. PentaTile v0.2 will end at ~10 layouts (5 native + 3 public-convention + 2 PixelLab). At 10, a flat dropdown is still navigable. At 12+ the case for filtering strengthens. The PentaTile-namespace adoption is straightforward: a typed `tags : Array[StringName]` `@export` on `PentaTileLayout` base, with vocabulary `["Public", "Tilesetter", "BorisTheBrave", "PixelLab", "Empirical", "Penta"]` (locked at backlog-seed processing time, not now). Each concrete layout sets its tags in `_init` or via inspector. A static helper `find_layouts_by_tag(tag : StringName) -> Array[PentaTileLayout]` (~10 LOC) provides programmatic discovery. **No editor UI is added** — the tags exist purely as machine-readable metadata for any future discovery surface.

Backlog seed (Section 4 above) names the trigger: layout count ≥ 12. The seed deliberately omits the chip-style filter UI from TBT's inspector — that's REJECTed by AP-1. The PentaTile adoption is the metadata only.

### #4 — tiles_preview SubViewport overlay, narrative

`tile_bit_tools/controls/tiles_preview/tiles_preview.gd:1-206` extends `Control` (line 2) and renders a SubViewport overlay on top of Godot's stock atlas view to display terrain-bit colors. Internal state includes `var preview_bit_data : TBTPlugin.EditorBitData` (line 16), `var base_image : Image` (line 20), `var image_crop_rect : Rect2i` (line 22), and a `var ready_complete := false` flag (line 49). The overlay multiplies bit colors against the atlas image; an opacity slider in the sibling `terrain_opacity_slider.gd` controls blending. The result is a live, in-editor preview of which terrain bits each tile carries.

PentaTile does not need this. Layouts encode masks by atlas POSITION via `_MASK_TO_ATLAS` const dicts; there are no bit colors to overlay because there are no per-bit terrain assignments. The `bitmask_template : Texture2D` exposed on every layout shows up in the inspector's stock Texture2D preview — that's the project's "preview" surface. The 206 LOC of `tiles_preview.gd` plus its supporting files (`tiles_view.gd`, `terrain_opacity_slider.gd` — another ~50 LOC) is REJECTed as out-of-scope editor polish. AP-2 in the register captures this.

### #5 — theme_updater editor theme harmonization, narrative

`tile_bit_tools/controls/tbt_plugin_control/theme_updater.gd:1-268` extends `Control` (line 2) and contains the `var override_properties` dictionary (line 27), `var override_methods` dictionary (line 43), and `var overrides_dict` aggregator (line 59). The class detects the user's active Godot editor theme (light/dark/custom) and re-tints TBT's panels, buttons, and section headers to match. Constants like `CATEGORY_EDITOR_CLASS := "EditorInspectorCategory"` (line 7) and `SECTION_EDITOR_CLASS := "EditorInspectorSection"` (line 8) reference Godot's internal class names — same fragility as AP-1, but for cosmetic purposes only.

PentaTile uses Godot's stock inspector. Stock inspector theme harmonization is automatic. The 268 LOC of `theme_updater.gd` solves a problem PentaTile does not have. AP-3 captures the REJECT.

### #6 — Save / edit / template-picker dialogs, narrative

The popup family lives at `tile_bit_tools/controls/tbt_plugin_control/popups/`: `template_dialog.gd` (173 LOC), `save_template_dialog.gd` (75 LOC, with `_get_save_path` line 37, `_get_save_dir` line 49, `_on_save_template_requested` line 74), and `edit_template_dialog.gd` (62 LOC). Together they let the user save the current TileSet's bit configuration as a `.tres` template at Project / Shared / User folders, or edit metadata on existing templates.

PentaTile's authoring path is "subclass `PentaTileLayout` in a `.gd` file." A save-as dialog implies bidirectional `.tres` ↔ class-on-disk plumbing the project does not need. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** explicitly forbids speculative authoring infrastructure. AP-4 captures the REJECT. The Section 4 backlog seed for "Save-custom-layout dialog" is REJECTED outright with no `.planning/todos/pending/` file — reopening the pattern requires fresh design work, not a pre-staged seed.

### #7 + #10 — Project Settings + verbosity channels, narrative (paired)

These two patterns are paired because they share an un-defer trigger. `tile_bit_tools/core/globals.gd:1-95` registers a hierarchy of Project Settings under the prefix `addons/tile_bit_tools/` (line 41 — `const PROJECT_SETTINGS_PATH`) — the `Settings` const dict (line 43-94) declares paths, output verbosity flags, and color overrides. `tile_bit_tools/core/output.gd:1-160` provides a 3-channel verbosity dispatcher (`enum MessageTypes {USER, INFO, DEBUG}` line 5; the `func user(msg, ...)` line 39, `func info(msg ...)` line 43, `func debug(msg ...)` line 47, `func error(msg ...)` line 51, `func warning(msg ...)` line 65 group is gated by `_is_message_type_enabled` line 126).

PentaTile has exactly one verbosity surface today: `OS.is_debug_build()`-gated `_rebuild_count` print. A 160-LOC multi-channel dispatcher for one consumer fails the **PROJECT.md "Constraints"** test. **CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility"** forbids adding the abstraction "in case a future feature needs it." When PentaTile gains a second verbosity surface (a candidate trigger: synthesis re-run logging when `PentaTileSynthesis._apply_canonical_silhouette` reports artifact removal), both patterns un-defer together. The PentaTile adoption is the simplest possible: a single Project Settings key `addons/penta_tile/output/show_debug_logs : bool` cached in a private field at `_ready` time, replacing the `OS.is_debug_build()` gate. No multi-channel enum. No `Settings` const dict. ~15 LOC total.

### #8 — Paul Tol palette, narrative

The Tol "bright" scheme (`#AA3377`, `#CCBB44`, `#228833`, `#66CCEE`, plus three more colors) is referenced via Project Settings keys in `tile_bit_tools/core/globals.gd:43-94` under the `colors/auto_terrain_color_*` prefix. TBT uses these to color-code terrain bits in its preview overlays. The Tol palette is a reasonable pick — it is genuinely color-blind-friendly and well-documented at https://personal.sron.nl/~pault/.

PentaTile does NOT render multi-terrain previews. There is no surface that consumes terrain colors. The audit notes the precedent for whenever multi-terrain (MULTITERR-01..05 in v2 backlog) lands; if so, the Tol palette is a defensible default. For v0.2 the verdict is REJECT. AP-5 covers this with the broader "speculative configuration palettes" rule.

### #9 — Bundled curation, narrative

The 12 bundled `.tres` files at `tile_bit_tools/templates/` are TBT's "ship enough samples that the addon works out of box" pattern. Inventory (verified read-from-disk 2026-04-29): `godot3_2x2.tres`, `godot3_3x3_16_tiles.tres`, `godot3_3x3_minimal.tres`, `simple_4-tile_(inside_corners).tres`, `simple_9-tile_(inside_corners).tres`, `simple_9-tile_(outside_corners).tres`, `tilepipe2_256_tile_16x16.tres`, `tilepipe2_256_tile_32x8.tres`, `tilesetter_blob.tres`, `tilesetter_wang.tres`, `tilesetter_wang_3-terrain.tres`, `tilesetter_wang_3-terrain_transitions.tres`. The pattern is sound — without bundled samples, the user must supply their own atlas before the addon does anything visible.

PentaTile already does the equivalent. The bundled greybox PNGs at `addons/penta_tile/layouts/penta_tile_layout_<slug>.png` (5 from Phase 2; +3 from Phase 3 per D-85 + TEMPLATE-02; +2 from Phase 3.5) feed `get_fallback_tile_set()` codegen at runtime. Drop a `PentaTileMapLayer` into a scene with just a layout Resource and start painting — the bundled fallback PNG produces visible (if greyboxed) tiles. **The pattern is in flight.** No new work. The audit's verdict is "ADOPT (already done)."

The only meaningful distinction between TBT's and PentaTile's curation patterns is medium: TBT ships `.tres` files (encoded peering-bit configurations); PentaTile ships PNG files (silhouette templates). The medium difference reflects the architectural divergence — TBT writes into Godot's terrain peering bits; PentaTile dispatches via atlas position. Both ship bundled samples; they differ in what those samples encode.

### #11 — bit_data_draw peering-bit color overlay, narrative

`tile_bit_tools/controls/bit_data_draw/bit_data_draw.gd:1-237` extends `Control` (line 2) and renders peering-bit color overlays. The class declares `enum RectPoint` (line 5), `var bit_shapes` dictionary (lines 16-141, mapping each `TileSet.CellNeighbor` constant to a polygon offset), `var bit_data : BitData` setter (line 144), `var draw_size : Vector2i` setter (line 150), plus atlas-rect / terrain-mode / terrain-color state (lines 158-164). The class decomposes a `BitData` Resource into colored rectangles per peering bit and draws them as an inspector overlay.

PentaTile renders silhouettes, not bit colors. The 47-blob and Wang/Tilesetter layouts shipped in Phase 3 are encoded by atlas POSITION (via the layout's `_MASK_TO_ATLAS` const dict), not by bit-color overlay. The bitmask_template PNG is a single grey silhouette per slot — no per-bit color is ever drawn. AP-6 captures the REJECT, with the broader rationale that PentaTile bypasses Godot's terrain-peering-bit semantic layer entirely.

---

## Section 9 — Identity positioning matrix (PentaTile vs TBT vs TileMapDual)

This section is a quick-reference matrix for "where does PentaTile sit relative to the two main reference projects?" Future plan-phases use this to keep the project's identity stable across feature additions.

| Dimension | TileMapDual | TBT | PentaTile (current) | PentaTile (post-v0.2 target) |
|-----------|-------------|-----|---------------------|------------------------------|
| Editor surface (LOC) | 0 (runtime-only) | ~3,825 (`controls/` + `inspector_plugin.gd` + supporting `core/` UI plumbing) | 0 | 0 (locked by CLAUDE.md "Identity Guardrails") |
| Bundled fallback assets | 0 | 12 `.tres` templates + 7 example PNGs | 5 PNGs (Phase 2) | 10 PNGs (5 + 3 + 2) |
| Resource hierarchy depth | 1 (single runtime node, no Resource subclasses) | 3 tiers (`BitData` → `EditorBitData` / `TemplateBitData`) | 2 tiers (`PentaTileLayout` base + concrete subclasses) | 2 tiers (locked) |
| Terrain peering bits | Yes (consumes Godot's stock terrain system) | Yes (mutates Godot's stock terrain system) | No (bypasses entirely) | No (locked by PROJECT.md "Constraints") |
| Persistent coordinate cache | Yes (cited as a TileMapDual leak source in PROJECT.md identity guardrails) | N/A (edit-time, not runtime) | No | No (locked by CLAUDE.md "Identity Guardrails") |
| Watcher / signal fanout | Yes (cited as a TileMapDual crash source in PROJECT.md identity guardrails) | N/A (edit-time) | No | No (locked by CLAUDE.md "Identity Guardrails") |
| Project Settings keys | Unknown — not in immediate audit scope | Multiple (~6 under `addons/tile_bit_tools/` prefix in `core/globals.gd:43`) | 0 | 1 (post-v0.3 backlog seed) |
| Verbosity channels | Free `print()` statements | 3-channel (USER/INFO/DEBUG via `core/output.gd:5`) | 1 surface (`OS.is_debug_build()`-gated) | 1 surface, single `bool` flag (post-v0.3) |
| Custom drawing API | No (uses `set_cell` / runtime node compositing) | Yes (SubViewport overlays in editor — `tile_bit_tools/controls/tiles_preview/tiles_preview.gd:1-206`) | No | No (locked by CLAUDE.md "Identity Guardrails") |
| Layout / template tags vocabulary | Unknown — not in immediate audit scope | Yes (`_custom_tags : Array[String]` in `tile_bit_tools/core/template_bit_data.gd` + auto-tag machinery in `tile_bit_tools/core/template_tag_data.gd:1-134`) | No | Possibly v0.3+ (typed `Array[StringName]`, no UI) |
| Multi-terrain / peering metadata | Yes | Yes | No | No (v2 backlog only) |
| Distribution model | GitHub + Asset Library | GitHub + Asset Library #1757 (archived 2024-04-13) | GitHub releases only | GitHub releases only (per PROJECT.md "Distribution") |

**Reading the matrix:** PentaTile's position is "TileMapDual without the cache and watcher and peering metadata, plus TBT's bundled-curation pattern (but in PNGs instead of `.tres` files)." Or, equivalently: "smaller editor surface than TileMapDual (because both are zero), smaller runtime surface than TileMapDual (because no cache + no watchers + no peering), and smaller editor surface than TBT (because zero vs ~3,825 LOC)." This is the project's identity. Every future audit item that risks moving any cell of this matrix in the wrong direction MUST be rejected on identity grounds, regardless of standalone merit.

---

## Section 10 — Audit methodology + non-goals

For future plan-phases reading this audit, the methodology used to produce it:

1. **File inventory verification.** The TBT addon at `C:\Programming_Files\Godot\tile_bit_tools-main\addons\tile_bit_tools\` was inventoried via a recursive Glob (`**/*.gd`) on 2026-04-29. The file list matches `.planning/research/layouts/TILEBITTOOLS.md` § 3 (audited 2026-04-25); no files were renamed, added, or removed in the interim — confirming the `archived 2024-04-13` status holds.
2. **LOC verification.** Specific LOC counts for the 13 files cited in Section 2 were verified via `wc -l` on 2026-04-29: `plugin.gd` 62, `inspector_plugin.gd` 353, `core/bit_data.gd` 245, `core/editor_bit_data.gd` 123, `core/template_bit_data.gd` 105, `core/template_loader.gd` 257, `core/template_tag_data.gd` 134, `core/globals.gd` 95, `core/output.gd` 160, `controls/tiles_preview/tiles_preview.gd` 206, `controls/tbt_plugin_control/theme_updater.gd` 268, `controls/tbt_plugin_control/popups/save_template_dialog.gd` 75, `controls/bit_data_draw/bit_data_draw.gd` 237. Total cited: 2,320 LOC of 3,825 LOC project — covers the load-bearing patterns plus their high-LOC outliers.
3. **Line-number citations.** Specific line numbers in Section 2 were derived from a structural Grep over the `class_name|extends|func|var|const|enum|@tool|signal` keywords on each file. The Grep matches are reproducible and version-pinned to the cloned `main` branch.
4. **Verdict assignment.** Each pattern was classified by walking these questions in order: (a) Does CLAUDE.md "Identity Guardrails" reject this category? If yes, REJECT. (b) Does PROJECT.md "Out of Scope" defer this? If yes, REJECT or ADOPT-DEFERRED depending on the deferral phase. (c) Does CLAUDE.md "Breaking Changes Policy (HARD RULE) — No forward compatibility" forbid speculative adoption? If yes, REJECT or ADOPT-DEFERRED with concrete trigger. (d) Is the pattern already in flight in PentaTile? If yes, ADOPT (already done) or PARTIAL (already done). (e) Otherwise, classify by usefulness vs cost: high usefulness + low cost = ADOPT; high usefulness + high cost = ADOPT-DEFERRED; low usefulness = REJECT.
5. **Cross-reference assignment.** TileMapDual's documented behavior was inferred from PROJECT.md identity-guardrail descriptions and from the project's own audit notes; specific TileMapDual source lines were NOT cited because TileMapDual's source is not vendored locally for this audit. Where uncertain, the cross-reference says "Not present in TileMapDual to my knowledge" and the verdict's primary justification stands on its own.

**Non-goals:**
- This audit is NOT a TBT bug report. TBT is archived; bugs in TBT are not actionable by PentaTile.
- This audit is NOT a competitive teardown. TBT's design has merit even where PentaTile rejects it; the rejection is identity-based, not quality-based.
- This audit is NOT a license review. TBT is MIT-licensed; D-73 forbids code lift regardless.
- This audit is NOT a Tilesetter slot-table source. D-75 commissions plan-phase web research from Tilesetter's own primary reference for that work; this audit's purpose is design-pattern verdicts, not slot-table data.

---

## Section 11 — Glossary (PentaTile-namespace equivalents for TBT concepts)

When future plan-phases consider TBT-inspired ideas, they MUST rename to PentaTile-namespace equivalents per CLAUDE.md "Coined-Term Discipline" + D-73. This glossary fixes the renames so renaming is mechanical, not a fresh design decision each time.

| TBT concept | PentaTile-namespace equivalent | Status |
|-------------|--------------------------------|--------|
| TBT's base bit-data Resource | `PentaTileLayoutData` (hypothetical, NOT created in v0.2) | not adopted |
| TBT's editor-side bit-data subclass | NO equivalent. PentaTile has no live-editor-selection concept; rejected (AP-7). | not adopted |
| TBT's template-on-disk bit-data subclass | `PentaTileLayout` concrete subclasses (`PentaTileLayoutPenta`, `PentaTileLayoutDualGrid16`, etc.) | already in flight |
| `template_loader` discovery + caching | `_layout_loader` (hypothetical, NOT created in v0.2; would be a static discovery helper if ever needed) | not adopted |
| `template_tag_data` auto-tag machinery | NO equivalent. PentaTile layouts are GDScript classes; tags would be author-declared, not auto-derived. Rejected as a category. | not adopted |
| `_custom_tags : Array[String]` field | `tags : Array[StringName]` `@export` on `PentaTileLayout` base (typed) | backlog seed (v0.3+) |
| `tbt_plugin_control` root UI panel | NO equivalent. No editor UI in PentaTile. Rejected (AP-1, AP-2, AP-3, AP-4). | not adopted |
| `theme_updater` editor theme harmonization | NO equivalent. Rejected (AP-3). | not adopted |
| `tiles_preview` SubViewport overlay | NO equivalent. Rejected (AP-2). | not adopted |
| `bit_data_draw` peering-bit color overlay | NO equivalent. PentaTile renders silhouettes; rejected (AP-6). | not adopted |
| `save_template_dialog` save-as UX | NO equivalent. Rejected (AP-4). | not adopted |
| `core/output.gd` 3-channel verbosity | `_show_debug_logs : bool` private cache on `PentaTileMapLayer`, sourced from a single Project Settings key | backlog seed (v0.3+) |
| `addons/tile_bit_tools/` Project Settings prefix | `addons/penta_tile/` (one key only: `addons/penta_tile/output/show_debug_logs`) | backlog seed (v0.3+) |
| Paul Tol color-blind palette | NO equivalent in v0.2. Future MULTITERR-* phase may adopt by reference. | not adopted |
| 12 bundled `.tres` template curation | 10 bundled greybox PNGs at `addons/penta_tile/layouts/penta_tile_layout_<slug>.png` | already in flight |

**Renaming discipline:** when a future plan-phase considers a TBT-derived idea, it MUST cite both the TBT pattern (with `tile_bit_tools/...` path prefix) AND the PentaTile-namespace equivalent. The plan-phase MUST NOT adopt TBT identifier names. CLAUDE.md "Coined-Term Discipline" + D-73 + AP-8 enforce this.

---

## Section 12 — Forward audit triggers + revisit conditions

The audit's verdicts are pinned to today's project state. Some verdicts CHANGE when state changes. This section enumerates the triggers, so a future plan-phase reading this audit knows when a verdict needs re-evaluation.

### Triggers that change the layout-tags vocabulary verdict (Section 2 #3)

- **Layout count crosses 12.** At ≥ 12 layouts, the inspector dropdown becomes unwieldy enough that tag metadata pays off. Currently at 5 (end of Phase 2); end-of-v0.2 estimate is 10. The trigger fires post-v0.2.
- **User explicitly asks for tag-based layout filtering.** Even at < 12 layouts, an explicit user request un-defers immediately. Document the request in CONTEXT.md and proceed.

### Triggers that change the Project Settings + verbosity verdict (Section 2 #7 + #10)

- **Second verbosity surface is added.** The current single surface is `OS.is_debug_build()`-gated `_rebuild_count` instrumentation. A second surface (e.g., synthesis re-run logging when `PentaTileSynthesis._apply_canonical_silhouette` reports artifact removal; or load-time slot-table validation logging) un-defers immediately.
- **User explicitly asks for runtime debug toggling.** A `bool` Project Settings key is the simplest possible response.

### Triggers that change the Paul Tol palette verdict (Section 2 #8)

- **MULTITERR-01..05 enters scope.** v2 backlog item. When/if multi-terrain transitions land, terrain-color metadata becomes load-bearing. The Tol palette is a defensible reference at that point. Until then, REJECT.

### Triggers that DO NOT change any verdict

- TBT releases a new version. TBT is archived (2024-04-13); no new versions are expected. Even if TBT were unarchived, D-73 forbids code lift regardless. The audit's verdicts are independent of TBT's release status.
- Godot 4.x ships a new minor version. The audit's verdicts are pinned to PentaTile's identity guardrails, which are version-independent.
- TileMapDual ships a new feature. PentaTile's identity is "smaller and simpler than TileMapDual" — TileMapDual adding a feature does not justify PentaTile adding the same feature. The cross-reference column in Section 3 is informational, not prescriptive.

### Triggers that REQUIRE a fresh audit (not just a verdict revisit)

- A new TBT-class addon emerges with patterns not covered here. If a Godot ecosystem addon ships in 2026 or later with autotile-related design ideas, those ideas need their own audit (separate file, same structure). This audit is bounded to TBT.
- PentaTile's identity guardrails change. If CLAUDE.md "Identity Guardrails" or PROJECT.md "Constraints" are explicitly updated to allow editor-UX surface, every REJECT in Section 2 needs re-evaluation. As of 2026-04-29 the guardrails are stable.

---

*End of audit. Reasoning columns and per-pattern narratives are deliberately verbose — this audit is a decision-locking artifact for v0.3+ inheritance, not a tight executive summary. The audit's load-bearing output is Section 5 (anti-pattern register: AP-1 through AP-10) — future plan-phases reference those bullets to bypass re-auditing. Section 4 backlog seeds (Layout tags vocabulary; Project Settings verbosity key) are the only PARTIAL-class actions deferred to v0.3+; everything else is either already in flight or REJECTed on identity grounds.*
