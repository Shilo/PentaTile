# Authoring Custom Layouts

Custom layouts are experimental. Prefer the built-in layouts when they match
your atlas, and subclass only for a genuinely missing convention.

A layout subclasses `PentaTileLayout` and implements three core methods:

```gdscript
@tool
class_name MyAlwaysFillLayout
extends PentaTileLayout

func is_dual_grid() -> bool:
    return false

func compute_mask(_coord: Vector2i, _sample_fn: Callable) -> int:
    return 1

func mask_to_atlas(_mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
    var slot := PentaTileAtlasSlot.new()
    slot.atlas_coords = Vector2i(0, 0)
    return slot
```

Guidelines:

- Use `_pack_alternative()` when combining alternative tile ids with Godot
  transform flags.
- For single-grid layouts, `mask=0` should usually render an atlas slot rather
  than erase the cell.
- Co-locate a `bitmask_template` PNG next to the layout script when you want
  inspector preview and fallback TileSet support.
- Keep custom layout logic small and table-driven where possible.
