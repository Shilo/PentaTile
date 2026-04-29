# Blob 47 Godot

Class: `PentaTileLayoutBlob47Godot`

Blob 47 Godot is a single-grid layout using an 8-bit Moore-neighborhood mask.
PentaTile collapses the 256 raw masks to 47 reachable blob states using the
standard rule: a corner bit matters only when both adjacent edge bits are set.

The bundled fallback atlas is packed into a 7x7 grid with two unused cells.
