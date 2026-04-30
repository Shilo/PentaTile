---
created: 2026-04-30T17:40:03.705Z
title: source_id on PentaTileAtlasSlot (Phase 10 schema)
area: general
files:
  - addons/penta_tile/penta_tile_atlas_slot.gd
  - addons/penta_tile/penta_tile_map_layer.gd
---

## Problem

PentaTileAtlasSlot currently has no per-slot source ID. When a TileSet has multiple atlas sources (e.g., VirtuMap multi-terrain banks), _paint_with_slot must resolve the source via _resolve_source_id() which only handles a single global source. This blocks multi-source TileSet support needed for terrain features.

## Solution

Add optional `source_id: int = -1` field to PentaTileAtlasSlot Resource. When >= 0, _paint_with_slot uses it directly instead of calling _resolve_source_id(). Non-breaking schema change — default -1 preserves existing behavior. ~50 LOC.
