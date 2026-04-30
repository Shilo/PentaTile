---
created: 2026-04-30T17:40:03.705Z
title: GDScript port of spike 001-003 mask decoder (v0.4 tooling)
area: general
files:
  - addons/penta_tile/layouts/penta_tile_layout.gd
---

## Problem

The spike 001-003 mask decoder exists only as Python+Pillow scripts that read template PNGs and compute 3x3 majority-vote bitmasks at geometric anchors. Without a GDScript port, custom layout authoring from template PNGs requires external tooling. A GDScript port running at Resource load time would make this accessible directly in the Godot editor.

## Solution

Port Python Pillow mask decoder to GDScript using Image.get_pixel()/Color. 3x3 majority vote at geometric anchors (4 corners + 4 edges). Unified background rule: transparent OR opaque-white = empty; anything else = bit set. Runs at Resource load, caches result. Enables custom layout authoring from template PNGs. ~200 LOC. v0.4 scope.
