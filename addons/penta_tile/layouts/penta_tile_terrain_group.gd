@tool
## Groups multiple [PentaTileLayout] instances (one per terrain) into a
## terrain set that supports automatic cross-terrain transitions.
class_name PentaTileTerrainGroup
extends Resource

## Per-terrain layouts. Index = terrain_id (0-based). Layout at index 0
## is the default terrain used when terrain identity is unresolved.
@export var layouts: Array[PentaTileLayout] = []

## Optional human-readable names for each terrain (editor labels).
@export var terrain_names: Array[String] = []

## Transition override table. Key = Vector2i(terrain_a, terrain_b).
## Value = per-mask atlas slot overrides for boundary cells.
## Empty by default — terrain boundary transitions auto-compute.
@export var transition_overrides: Dictionary = {}

## If true, missing transition tiles fall back to terrain_a's border tile.
## If false, missing transition tiles leave the cell unpainted.
@export var auto_fallback_transitions: bool = true

## Terrain paint precedence. Index = terrain_id, value = precedence weight.
## Higher value = paints later (on top). Separate from layouts array ordering.
## When empty (default), paint order follows layouts array index (0 first).
@export var terrain_precedence: Array[int] = []
