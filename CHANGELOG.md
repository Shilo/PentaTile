# Changelog

All notable changes to **PentaTile** (formerly TetraTile) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased] — v0.2 in progress

### BREAKING — Project rename: TetraTile → PentaTile

The entire project has been renamed from **TetraTile** to **PentaTile**.
This is a breaking change with no backwards-compatibility shims, per the project's no-backwards-compat policy.

Renamed surface:

- Addon folder: `addons/tetra_tile/` → `addons/penta_tile/`
- Plugin id: `tetra_tile` → `penta_tile`
- Core class: `TetraTileMapLayer` → `PentaTileMapLayer`
- Contract class: `TetraTileAtlasContract` → `PentaTileAtlasContract`
- Layout base: `TetraTileLayout` → `PentaTileLayout`
- Layout subclasses: `PentaTileLayoutPentaHorizontal`, `PentaTileLayoutPentaVertical`
- All GDScript files: `tetra_tile_*.gd` → `penta_tile_*.gd`
- All `.tres` / `.tscn` assets: `tetra_*` → `penta_*`
- Custom data layer keys: `tetra_role` → `penta_role`, `tetra_lock_rotation` → `penta_lock_rotation`
- Requirement IDs: `TETRA-01..03` → `PENTA-01..03`, `TETRA-SYNTH-01..12` → `PENTA-SYNTH-01..12`
- `project.godot` config name: `"TetraTile"` → `"PentaTile"`

### Added — Penta codename anchors

- `README.md` § **What is a Penta tileset?** — canonical labeled-diagram section defining the 5 archetypes (IsolatedCell, Fill, Border, InnerCorner, OppositeCorners) and "Penta" as a coined term alongside Wang and Blob.
- `CLAUDE.md` § **Coined-Term Discipline** — project invariant reserving "Penta" exclusively for the 5-archetype format; prohibits `PentaCache`, `PentaDecoder`, or any unrelated "Penta" prefix.

### Migration notes for v0.1.x consumers

1. Replace all references to `TetraTileMapLayer` with `PentaTileMapLayer` in your scenes and scripts.
2. Move your `addons/tetra_tile/` folder to `addons/penta_tile/` and re-enable the plugin in Project Settings → Plugins.
3. If you stored the addon path in any tool scripts or CI configs (`res://addons/tetra_tile/`), update those to `res://addons/penta_tile/`.

---

## [0.1.0] — 2025-04-26

Initial release as **TetraTile**.

- Dual-grid autotiling via `TileMapLayer` subclass.
- 4-tile binary atlas: Fill, Inner Corner, Border, Outer Corner.
- 16-state marching-squares mask with transform-based rotations.
- Overlay layer composition for disconnected-diagonal masks (6 and 9).
- `PentaTileAtlasContract` resource + `PentaTileLayout` base (shipped as TetraTile v0.1).
- Horizontal and Vertical atlas layout support.
- Demo scene with platformer player and runtime painter.
