# TetraTile

## What This Is

TetraTile is a lightweight dual-grid autotiling addon for Godot 4.6 that exposes a single public node, `TetraTileMapLayer`, on top of the engine's native `TileMapLayer` API. It is built for game developers (initially the author's own projects) who want a small, lean autotiler they can drop into a Godot project and drive with the standard painting and runtime APIs.

## Core Value

Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

## Requirements

### Validated

<!-- Shipped in v0.1.0 and confirmed working in the demo. -->

- ✓ Single public `TetraTileMapLayer` node extending `TileMapLayer` — v0.1.0
- ✓ Native painting API support (`set_cell()`, `erase_cell()`, editor tools) — v0.1.0
- ✓ 4-tile binary atlas contract (Fill, Inner Corner, Border, Outer Corner) — v0.1.0
- ✓ Horizontal (4×1) and vertical (1×4) atlas layouts — v0.1.0
- ✓ 16-state mask-driven tile selection with transform rotations — v0.1.0
- ✓ Two-layer composition for disconnected diagonal masks (6 and 9) — v0.1.0
- ✓ Hidden logic layer via `self_modulate.a` (avoids Godot cleanup behavior) — v0.1.0
- ✓ Generated visual-layer collisions sourced from TileSet physics polygons — v0.1.0
- ✓ Public `rebuild()` helper for full visual regeneration — v0.1.0
- ✓ Demo scene with platformer player and runtime drag-paint — v0.1.0
- ✓ Codebase mapped in `.planning/codebase/` — v0.1.0

### Active

<!-- This milestone: expand the contract. -->

- [ ] Atlas contract redesign — drop the strict 4-tile core; declare-what-you-have model
- [ ] Per-tile configurability knobs baked into the contract (rotation lock, variation rules)
- [ ] Y-axis variation support, riding Godot's built-in TileSet alternate-tile probability
- [ ] Top-tile support — designated top-edge visuals for platformer-style caps
- [ ] Non-rotating tileset support — per-direction tile authoring (T/B/L/R not interchangeable)
- [ ] Updated demo scene showcasing all new features in one place
- [ ] GitHub release tagged with the next simple semver number (0.2.0)

### Out of Scope

<!-- Explicitly deferred for this milestone. -->

- TetraBake (procedural 5th edge/diagonal connector tile generation) — Parking-lot idea; not needed to unblock author's own games
- Tileset converter (Wang/blob → TetraTile atlas) — Authoring tooling, deferred until contract design is settled
- Outer transition tile support (grass→dirt, multi-terrain) — Distinct R&D track; not a top pain in current games
- Shader fallback for diagonal compositing — Performance optimization; demo-scale targets don't require it
- Collision authoring tools / auto-collision generation — Existing TileSet-physics path is enough for now
- MkDocs documentation site — GitHub README is sufficient for the private audience
- Godot Asset Library distribution — GitHub releases only this milestone
- Formal automated test suite (GUT or similar) — Quality bar is "works in my game"
- Large-map performance benchmarking (>10k cells) — Demo-scale (~100–1k cells) is the target
- Backwards compatibility for v0.1.0 atlases / API — Pre-1.0; breaking changes accepted

## Context

- Existing implementation is ~261 LOC of GDScript in a single class plus a working demo scene with a `CharacterBody2D` player and runtime drag-paint script. No external dependencies beyond Godot 4.6.
- Architecture is intentionally lean: no persistent coordinate cache, no signal fanout, no watchers — `_update_cells()` recomputes affected masks on demand and writes directly to two internal `TileMapLayer`s.
- Codebase analysis (`.planning/codebase/CONCERNS.md`) flagged no critical bugs or security issues. The main concerns are absence of tests, undocumented map-size limits, and the fixed 4-tile atlas constraint — the last of which this milestone is explicitly tackling.
- The user is comparing TetraTile against TileMapDual; TetraTile's selling point has been minimalism and the 4-tile contract. Expanding the contract risks blurring that distinction, so the redesign should preserve "smaller and leaner than TileMapDual" as a guiding constraint even as new modes appear.
- Top-tile and non-rotating-tileset support are intertwined: top tiles are a specific case of breaking the rotational symmetry assumption baked into the current 16-state table. The user explicitly flagged this pair as needing heavy research before implementation.
- Variation should reuse Godot's existing `TileSetAtlasSource` alternate-tile probability mechanism rather than introducing custom RNG, to stay aligned with the engine and let users tune variation in the existing TileSet inspector.

## Constraints

- **Tech stack**: Godot 4.6+ stable. Pure GDScript. No C#, no GDExtension, no third-party dependencies.
- **Engine API**: Implementation must continue to ride `TileMapLayer._update_cells()`. No persistent coordinate cache, signal fanout, or watcher systems (per the existing architecture's "lean" stance).
- **Distribution**: GitHub releases with plain semver tags (no `-pre`, `-alpha`, `-dev` suffixes). No Asset Library submission this milestone.
- **Audience**: The author's own games. No public-API SLA; breaking changes accepted with migration notes in commits/release notes.
- **Performance**: Demo-scale target (~100–1k cells). Interactive painting and runtime drag-paint must remain fluid; large-map perf is not a milestone gate.
- **Identity**: TetraTile must remain visibly smaller and simpler than TileMapDual; expansions should not pull in terrain metadata, tile caches, or watcher infrastructure.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Milestone goal is "expand the contract", not "ship 1.0 / harden v0.1" | Author's own games are blocked on visual repetition and platformer-top friction, not on the contract being unstable | — Pending |
| Y-axis variation rides Godot's built-in `TileSetAtlasSource` alternate-tile probability | Avoid reinventing RNG; users author variation in the existing TileSet inspector | — Pending |
| Drop the strict 4-tile atlas core; move to a "declare what you have" contract with per-tile knobs | User wants atlas-level configurability (rotation lock, variation rules); current fixed contract blocks top-tile and non-rotating support | — Pending |
| Top tiles + non-rotating tilesets treated as one R&D track | Top tiles are a specific case of breaking rotational symmetry — same underlying redesign | — Pending |
| Breaking changes allowed; v0.1 atlases may require migration | Pre-1.0 and audience is the author's own games; demo can be updated alongside | — Pending |
| GitHub release only; no Asset Library, no MkDocs | Audience is private; discoverability and full docs site are not goals this milestone | — Pending |
| Quality bar is "works in my game" — no formal test suite, no perf benchmarks | Keeps milestone scope tight on the contract redesign and three feature pillars | — Pending |
| One expanded demo scene over multiple per-feature demos | Simpler maintenance; surface area stays small as features land | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-25 after initialization*
