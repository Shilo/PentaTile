# Architecture Research

**Domain:** Godot 4.6 dual-grid autotile addon (TetraTile v0.2.0 contract expansion)
**Researched:** 2026-04-25
**Confidence:** HIGH (Godot APIs verified via Context7 against godot-docs master + Godot 4.6 stable; design recommendations triangulated against TileMapDual precedent and v0.1 source)

## Scope of This Document

This research answers: **how should TetraTile evolve to support a "declare what you have" atlas contract, Y-axis variation, top tiles, and non-rotating tilesets — without growing larger than TileMapDual?**

It does **not** re-derive v0.1 architecture (already in `.planning/codebase/ARCHITECTURE.md`). It treats v0.1 as a fixed starting point and proposes additive deltas.

## Recommended Architecture (v0.2.0)

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          USER-FACING SURFACE                         │
├──────────────────────────────────────────────────────────────────────┤
│  TetraTileMapLayer  (extends TileMapLayer, single public class)      │
│      ├─ @export atlas_contract: TetraTileAtlasContract  ← NEW        │
│      ├─ @export atlas_source_id, logic_*, generated_collision_*      │
│      └─ rebuild(), set_cell()/erase_cell() (inherited)               │
├──────────────────────────────────────────────────────────────────────┤
│                          CONTRACT (RESOURCE)                         │
├──────────────────────────────────────────────────────────────────────┤
│  TetraTileAtlasContract  (extends Resource, .tres on disk)           │
│      ├─ @export rotation_mode: RotationMode {SYMMETRIC, NON_ROTATING}│
│      ├─ @export tile_slots: Dictionary  ← mask → AtlasSlot           │
│      ├─ @export top_overlay_slot: AtlasSlot (optional)               │
│      └─ @export variation_seed: int (deterministic alt picker)       │
├──────────────────────────────────────────────────────────────────────┤
│                          MASK + SELECTION                            │
├──────────────────────────────────────────────────────────────────────┤
│  _mask_at()                  (unchanged — 4-bit quadrant occupancy)  │
│  _resolve_slot(mask)         (NEW — dispatches via rotation_mode)    │
│  _pick_alternative(slot,xy)  (NEW — deterministic seed → alt ID)     │
├──────────────────────────────────────────────────────────────────────┤
│                          INTERNAL VISUAL LAYERS                      │
├──────────────────────────────────────────────────────────────────────┤
│  _primary_layer       (TileMapLayer, INTERNAL_MODE_FRONT)            │
│  _overlay_layer       (TileMapLayer — diagonals 6/9, unchanged)      │
│  _top_layer           (NEW, optional — only created if contract has  │
│                        a top overlay slot; rendered above primary)   │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `TetraTileMapLayer` | Public node API; owns logic cells, internal visual layers, contract | GDScript class extending `TileMapLayer` |
| `TetraTileAtlasContract` | Declares what tiles exist for which mask states; per-tile knobs | GDScript `Resource` subclass, `class_name`-registered |
| `AtlasSlot` (inner class on contract) | Pairs an atlas coord with rotation flags + variation rule | Plain object embedded in `tile_slots`; not a separate Resource |
| `_resolve_slot(mask)` | Mask → (atlas_coords, transform_flags) lookup, mode-aware | Method on `TetraTileMapLayer` |
| `_pick_alternative()` | Deterministic seed-based alt-tile picker | Method on `TetraTileMapLayer` |
| `_primary_layer` | Main visuals (15 of 16 mask states) | Internal `TileMapLayer` (unchanged from v0.1) |
| `_overlay_layer` | Disconnected diagonal composition for masks 6/9 | Internal `TileMapLayer` (unchanged from v0.1) |
| `_top_layer` | Optional top-edge overlay (e.g., grass cap on dirt) | Internal `TileMapLayer`, only spawned when contract opts in |

**"Smaller than TileMapDual" guardrails — what we're NOT introducing:**

- ❌ No persistent coordinate cache (v0.1 stance preserved)
- ❌ No watcher / signal fanout system
- ❌ No terrain set / terrain ID metadata (Godot's terrains are out of scope; TetraTile competes with that system, doesn't wrap it)
- ❌ No custom RNG: variation rides Godot's existing alternative tile + flip flag plumbing
- ❌ No multi-terrain transition support (explicitly Out of Scope per `.planning/PROJECT.md`)
- ❌ No `TileSet` editor plugin / dock UI: users author the contract via Godot's stock Inspector + .tres editing
- ❌ No GDExtension or C# escape hatch (constraint per PROJECT.md)

## Decision: Where the Atlas Contract Lives

**Recommendation: Custom `Resource` subclass (`TetraTileAtlasContract`) attached to `TetraTileMapLayer` via `@export`.**

This is option 1 from the question. Below is the evaluation of all four options, then the rationale.

### Option Evaluation Matrix

| Criterion | Custom Resource | TileSet Custom Data | Class enum + dict | Hybrid (Resource refs TileSet) |
|---|---|---|---|---|
| Editor authoring UX | High — Inspector renders Resource cleanly; saved as `.tres` | Low — custom data layers are per-tile string-keyed Variants; no schema, easy to typo | Low — users edit GDScript or set Dictionary in Inspector (stringly-typed keys) | Medium — split UX between two assets confuses authors |
| Serialization stability | High — `class_name`-registered Resources are stable across Godot versions | Medium — TileSet's per-tile metadata path notation (`x:y/alt/key`) is fragile to atlas refactors | Low — Dictionary export survives, but key/value renames break silently | Medium — coupling adds breakage surface |
| Migration ergonomics | High — old contracts can be loaded, new fields default-init from Resource | Low — schema migration requires walking every tile's metadata | Low — no version field, no migration path | Medium — must migrate both sides |
| Runtime perf cost | Low — Resource fields are typed, accessed once per repaint | Medium — `get_custom_data_by_layer_id()` per tile per repaint = N lookups | Lowest — direct dict access, but irrelevant at this scale | Medium — two reads per tile |
| Code clarity | High — contract logic lives in one Resource class with typed fields | Low — implementation logic spread between TetraTile and TileSet metadata definitions | Low — godscripted constants are not discoverable | Medium — split brain |
| "Lean" identity | High — one new file, ~40 LOC | Medium — leans into Godot's data layer system, uses no new files but couples tightly to TileSet | Low — bloats the core class | Low — adds two abstractions instead of one |

### Why Resource Wins

1. **Authoring UX is the biggest gap in v0.1.** Today's `atlas_layout` enum doesn't tell the user *which slot is what*. A Resource gives a structured Inspector view: "fill = `Vector2i(0,0)`, transform = ROTATE_0; outer_corner = `Vector2i(1,0)`; …". A user can ship a contract with **only the slots they have** — that's the entire point of "declare what you have."
2. **Serialization stability matters more than perf at 100–1k cells.** Custom data layers tie metadata to tile coordinates inside the TileSet — if the user re-arranges the atlas image, their metadata bindings break. A Resource is a separate `.tres` that can be re-targeted at a new atlas without rewriting per-tile data.
3. **Resource path notation (`x:y/alt/property`) is verbose** — using it from GDScript means string-formatted keys and `Variant` lookups. Resources give typed property access (`contract.outer_corner_slot`).
4. **Versioning is trivial.** Add a `@export var version: int = 1` field; `_load_contract()` can switch on it for forward-compat.
5. **Reusability.** A single `.tres` contract can be shared across multiple `TetraTileMapLayer` nodes (e.g., dirt on layer A and layer B with the same atlas).

**Tradeoff acknowledged:** users who only want defaults must either (a) leave the export `null` and let the layer fall back to the v0.1 behavior, or (b) ship a default `.tres` next to the addon. We recommend (a) — preserves zero-config UX.

### Resource Schema (proposal)

```gdscript
class_name TetraTileAtlasContract
extends Resource

enum RotationMode {
    SYMMETRIC,      # v0.1 behavior — 4 unique tiles + transform rotations
    NON_ROTATING,   # 16 unique tiles, no transforms applied (per-direction art)
}

@export var version: int = 1
@export var rotation_mode: RotationMode = RotationMode.SYMMETRIC

# For SYMMETRIC mode: only fill/inner/border/outer slots are read.
# For NON_ROTATING mode: tile_slots[mask] is read for each of 16 masks.

@export var fill_slot: AtlasSlot
@export var inner_corner_slot: AtlasSlot
@export var border_slot: AtlasSlot
@export var outer_corner_slot: AtlasSlot

# Used only in NON_ROTATING mode (16 explicit entries indexed by mask 0..15).
@export var mask_slots: Array[AtlasSlot] = []

# Optional. When non-null, paints an extra tile on _top_layer for any
# display cell whose mask has its top row filled but bottom row open
# (i.e., the silhouette has a top edge in this position).
@export var top_overlay_slot: AtlasSlot

# Hash-mixed with display cell coords to pick alt-tiles deterministically.
# Tweakable so users can re-roll variation without breaking the contract.
@export var variation_seed: int = 0
```

```gdscript
class_name AtlasSlot
extends Resource

@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var transform_flags: int = 0   # OR of TileSetAtlasSource.TRANSFORM_*
@export var alternative_count: int = 1 # 1 = no variation, N = pick from N alts
```

`AtlasSlot` is a separate Resource (not an inner class) because **inner classes that extend Resource cannot serialize their custom properties** (Context7-verified Godot caveat in `tutorials/scripting/resources.md`).

## Decision: Non-Rotating Tileset Support

### The Core Problem

The v0.1 mask table has 16 entries but only references 4 base tiles, reusing them under 4 transforms. The transforms exploit *rotational symmetry* of the artwork. When tiles are NOT rotationally symmetric (e.g., a top edge with grass blades drawn upward, a bottom edge with rocks), each of the 16 mask states needs its own art.

### Recommendation: Mode Flag on Contract, Not Per-Tile

**`rotation_mode` lives on `TetraTileAtlasContract`, not on individual slots.**

Rationale:
- Mixing rotated and non-rotated tiles in one atlas is a bizarre authoring story. If even one slot is non-rotating, the whole atlas is effectively non-rotating (rotated neighbors would mismatch).
- A whole-atlas flag is one boolean to migrate, not 16.
- Per-tile flags would invite combinatorial bugs ("which mask uses which mode?").

### Table Size: Stays at 16 — But Two Different Tables

The mask is still 4 bits = 16 states. The **lookup result** changes shape:

```
SYMMETRIC mode:    mask → (slot_index ∈ {fill, inner, border, outer},
                           transform ∈ {0°, 90°, 180°, 270°})
NON_ROTATING mode: mask → (atlas_coords, transform=0)  -- 16 explicit entries
```

**No 64-entry table is needed.** TileMapDual confirms the precedent: it ships 16 unique tiles for non-symmetric art, no rotation tricks.

### Diagonal Mask Composition (6 and 9) Still Works

In non-rotating mode, masks 6 and 9 still need overlay composition because the geometry is two disconnected quadrants — that's a *topology* fact, not a symmetry fact. The overlay layer paints the second outer-corner tile. With non-rotating art, the "second outer corner" is a separately-authored tile — typically slot index `mask_slots[N]` where N is a designated "diagonal complement" index (or the contract can require that `mask_slots[6]` and `mask_slots[9]` each declare two atlas coords).

**Cleanest schema:** add an optional `diagonal_complement_atlas_coords: Vector2i` field to `AtlasSlot`. Used only by entries that paint a second tile on `_overlay_layer`. In SYMMETRIC mode the engine derives this automatically (it's the outer corner under a different transform); in NON_ROTATING mode the user must author it.

### `_resolve_slot()` Pseudocode

```gdscript
func _resolve_slot(mask: int) -> Dictionary:
    if atlas_contract == null:
        return _resolve_slot_legacy(mask)  # v0.1 hardcoded behavior
    if atlas_contract.rotation_mode == TetraTileAtlasContract.RotationMode.NON_ROTATING:
        var slot: AtlasSlot = atlas_contract.mask_slots[mask]
        return { "primary": slot, "overlay": null }  # or both for masks 6/9
    return _resolve_slot_symmetric(mask)  # the v0.1 table, but reading slots from contract
```

## Decision: Top Tiles

### Composition: Third Internal Layer

**Top tiles get a dedicated `_top_layer` (a third internal `TileMapLayer`)**, not a second pass on the primary layer.

Rationale:
- Top tiles often want different `z_index` from primary (rendered above), different y-sort behavior, and possibly no collision (the cap is decorative).
- A separate layer keeps these knobs cleanly separated from `_primary_layer` properties.
- The layer is **only created when `top_overlay_slot != null`**, preserving the lean default (v0.1 atlases don't pay for top-layer infrastructure).

### When to Paint a Top Tile

The "top tile" applies wherever a display cell has logic occupancy on the bottom row but **not** the top row — i.e., the silhouette's upper edge crosses through this display cell. In mask terms:

- mask 4 (BL only) → top tile applies (bottom-left cap)
- mask 8 (BR only) → top tile applies (bottom-right cap)
- mask 12 (BL+BR, both bottom) → top tile applies (full top edge)
- All other masks: no top tile

This is a small lookup (3 of 16) added on top of the primary mask table.

### Why Not Reuse `_overlay_layer`?

The overlay layer is reserved for diagonal composition (masks 6 and 9). Top tiles need different draw rules and different visibility conditions. Reusing the overlay would muddy its semantics and force conditionals at every paint call.

### Composition Diagram

```
Logic cell (1,1) = filled
Logic cell (1,2) = empty (above the filled cell)

Display cells affected:
  (1,1) — TR/BR of (1,1) and TL/BL of neighbors
  (1,2) — top-row of the silhouette

For display cell (1,2):
  primary mask = 12 (BL+BR filled, top empty)
  → primary layer paints BORDER tile rotated 0°  (existing v0.1 behavior)
  → top layer paints top_overlay_slot at (1,2)   (NEW — caps the edge)
```

## Decision: Y-Axis Variation Plumbing

### Critical Finding: Probability Is Editor-Only for Random Brush

The Godot 4.6 docs (Context7-verified at `tutorials/2d/using_tilemaps.md`, "Painting Randomly Using Scattering") state probability applies "when drawing a pattern of random tiles" — i.e., the editor's Paint/Line/Rectangle/Bucket tools when **multiple tiles are selected** in the TileMap editor. **`set_cell()` called from code does NOT auto-pick alts based on probability** — the caller passes an explicit `alternative_tile` ID.

This means: **TetraTile must do the picking itself.**

### Recommended Approach: Deterministic Per-Coord Hash

```gdscript
func _pick_alternative(slot: AtlasSlot, display_cell: Vector2i) -> int:
    if slot.alternative_count <= 1:
        return 0
    var seed_value: int = atlas_contract.variation_seed
    var hashed: int = hash(Vector2i(
        display_cell.x ^ seed_value,
        display_cell.y * 73856093 ^ seed_value,
    ))
    return abs(hashed) % slot.alternative_count
```

The hash is computed **per display cell**, never stored. This means:
- ✅ No shimmer on rebuild — same coord → same alt every time
- ✅ No persistent cache (lean stance preserved)
- ✅ Tweakable via `variation_seed` for re-rolls

### Combining With Transform Flags

`set_cell()`'s 4th parameter is `alternative_tile`, which is **OR-ed with transform flag bits** (`TRANSFORM_FLIP_H`, `TRANSFORM_FLIP_V`, `TRANSFORM_TRANSPOSE`). The current TetraTile code passes only the rotation flags (alt-ID 0). For variation:

```gdscript
var alt_id: int = _pick_alternative(slot, display_cell)
var transform: int = slot.transform_flags
layer.set_cell(display_cell, source, slot.atlas_coords, alt_id | transform)
```

This works because alt-IDs occupy the low bits and transform flags occupy specific high bits — they don't collide. Verified in Godot docs (`class_tilesetatlassource.md`, "Apply Horizontal Flip to Godot TileMap Cell" snippet).

### Probability Tuning Stays In Godot's Inspector

Users author probability per-alt in the **stock TileSet inspector** (per Key Decision in PROJECT.md). TetraTile reads `alternative_count` from the contract and, optionally, weights via `tile_data.get_probability()`:

```gdscript
# Optional weighted variant of _pick_alternative:
var weights: Array[float] = []
for alt_id in range(slot.alternative_count):
    var tile_data := atlas_source.get_tile_data(slot.atlas_coords, alt_id)
    weights.append(tile_data.probability if tile_data else 1.0)
var rng := RandomNumberGenerator.new()
rng.seed = hash(Vector2i(display_cell.x ^ seed, display_cell.y ^ seed))
return rng.rand_weighted(weights)
```

Phase one can ship uniform picking; weighted picking is a small follow-up.

## Recommended File Structure

```
addons/tetra_tile/
├── plugin.cfg                            # unchanged
├── tetra_tile_map_layer.gd               # extended (~350 LOC est.)
├── tetra_tile_atlas_contract.gd          # NEW — Resource subclass (~60 LOC)
├── tetra_tile_atlas_slot.gd              # NEW — Resource subclass (~30 LOC)
├── tetra_tile_template.png               # unchanged (consider adding non-rotating variant)
└── demo/
    ├── tetra_tile_demo.tscn              # extended scene
    ├── demo_player.gd                    # unchanged
    ├── demo_runtime_painter.gd           # unchanged
    ├── tetra_tile_ground.png/.tres       # v0.1 atlas — kept for migration test
    ├── tetra_tile_ground_contract.tres   # NEW — minimal v0.2 wrapper for v0.1 atlas
    ├── tetra_tile_grass_top.png/.tres    # NEW — atlas with top-cap variation
    ├── tetra_tile_grass_top_contract.tres# NEW — top-overlay contract
    ├── tetra_tile_directional.png/.tres  # NEW — non-rotating atlas
    └── tetra_tile_directional_contract.tres  # NEW — non-rotating contract
```

### Structure Rationale

- **Contract Resources at addon root** — they're part of the public API (users instantiate them); demo files stay in `demo/`
- **One file per Resource class** — Godot serialization requires top-level (not inner) Resource classes
- **Demo grows linearly with features** — three contracts demonstrate three new modes side-by-side in one scene (per PROJECT.md "one expanded demo scene")

## Data Flow

### Paint Flow (v0.2.0)

```
User: tetra_tile_layer.set_cell(logic_coord, source, atlas_coords)
  ↓
TileMapLayer.set_cell() (inherited; queues internal update)
  ↓
_update_cells(coords, forced_cleanup) override
  ↓
For each affected display cell:
    ├─ mask = _mask_at(display_cell)                   [unchanged]
    ├─ slot = _resolve_slot(mask)                      [NEW dispatch on rotation_mode]
    │     ├─ SYMMETRIC: read from contract slots, compute transform
    │     └─ NON_ROTATING: read mask_slots[mask] directly, transform=0
    ├─ alt_id = _pick_alternative(slot, display_cell)  [NEW]
    ├─ _primary_layer.set_cell(display_cell, source,
    │                          slot.atlas_coords,
    │                          alt_id | slot.transform_flags)
    ├─ if mask in {6, 9} → paint overlay layer too     [unchanged]
    └─ if mask in {4, 8, 12} and contract.top_overlay_slot != null
        → _top_layer.set_cell(display_cell, source,
                              top_alt_id | top_transform)  [NEW]
```

### Rebuild Flow (v0.2.0)

Identical to v0.1 — iterate `get_used_cells()`, dispatch each through `_paint_display_cell()`. The new layers (`_top_layer` if exists) are cleared alongside primary/overlay.

### Contract Loading

```
TetraTileMapLayer._ready()
  ↓
_ensure_visual_layers()
  ├─ create _primary_layer if missing
  ├─ create _overlay_layer if missing
  └─ create _top_layer ONLY IF atlas_contract != null AND
                              atlas_contract.top_overlay_slot != null
  ↓
_apply_logic_layer_opacity(), _apply_logic_collision()
  ↓
rebuild.call_deferred()
```

The lazy creation of `_top_layer` is critical: v0.1 users with no top-overlay pay zero cost.

## Suggested Build Order

The five capabilities have a partial dependency order. **Land them in this sequence to de-risk the contract redesign:**

### Phase 1 — Contract Skeleton (de-risks everything else)

**Goal:** Introduce `TetraTileAtlasContract` and `AtlasSlot` Resources. Wire them into `TetraTileMapLayer` as an `@export`. **Behavior unchanged** — the contract Resource exists but the SYMMETRIC mode reads from the contract instead of hardcoded constants. v0.1 atlas + a default contract `.tres` reproduce v0.1 visuals exactly.

**Dependencies:** None.
**Risk if done last:** Every other feature has to retrofit the contract structure, doubling the work.
**Acceptance:** existing demo runs unchanged with a new `tetra_tile_ground_contract.tres` referenced from the demo scene.

### Phase 2 — Y-Axis Variation

**Goal:** `alternative_count` per slot + `_pick_alternative()` deterministic picker.

**Dependencies:** Phase 1 (slots must exist).
**Why second:** Variation is purely additive — it touches one method and adds one knob per slot. It also exercises Godot's alt-tile API in isolation, surfacing any surprises (e.g., transform-flag interaction) before non-rotating mode lands.
**Acceptance:** Demo atlas extended with 2 fill alternates; visual variation visible in scene; rebuilding the layer doesn't shimmer.

### Phase 3 — Non-Rotating Mode

**Goal:** `RotationMode.NON_ROTATING` + `mask_slots: Array[AtlasSlot]` of size 16.

**Dependencies:** Phase 1 (contract structure), Phase 2 (variation must work in both modes).
**Why third:** This is the largest schema change but conceptually simple once the contract is in place.
**Acceptance:** A 16-tile non-rotating atlas demo renders correctly, including masks 6 and 9 (diagonal complement field).

### Phase 4 — Top Tiles

**Goal:** Optional `top_overlay_slot` + lazy `_top_layer` + paint rule on masks 4/8/12.

**Dependencies:** Phase 1, Phase 2.
**Why fourth:** Top tiles are the smallest *new* feature but have the most ambiguous design (which masks count as "top edge"? does it apply per axis or just one?). Doing it after non-rotating means we've already shipped `_resolve_slot()` and have a place to plug top-layer painting into the existing paint pipeline.
**Acceptance:** Platformer-style demo terrain with grass cap on dirt blocks; player walks on top correctly.

### Phase 5 — Demo Scene Refresh

**Goal:** One expanded demo showcasing all four contracts (legacy 4-tile, variation, non-rotating, top tile).

**Dependencies:** Phases 1–4.
**Why last:** Demo content benefits from API stability across all features.
**Acceptance:** Switching contracts at runtime (or having three side-by-side `TetraTileMapLayer` nodes in the same scene) shows each capability without code changes.

### Build-Order Rationale Summary

```
Phase 1 (contract skeleton) ──┬──> Phase 2 (variation) ──┬──> Phase 3 (non-rotating)
                              │                         │
                              └──> Phase 4 (top tiles) ──┘
                                                         │
                                                         └──> Phase 5 (demo)
```

Phase 1 gates everything. Phases 2 and 4 are independent of each other (could parallel) but both feed Phase 3. Phase 5 is purely consuming.

## Migration Story for v0.1 Atlases

**Pre-1.0 allows breaking changes** (per PROJECT.md), so the migration bar is "rebuild from a template, not auto-upgrade."

### Concrete Migration for `tetra_tile_ground.tres`

1. Ship a **default contract `.tres`** in `addons/tetra_tile/` — `tetra_tile_default_contract.tres` — with SYMMETRIC mode and the v0.1 slot assignments (`fill = (0,0)`, `inner = (1,0)`, `border = (2,0)`, `outer = (3,0)` for HORIZONTAL layout).
2. In the demo scene, set `tetra_tile_layer.atlas_contract = preload("res://addons/tetra_tile/tetra_tile_default_contract.tres")`.
3. v0.1 `atlas_layout` enum: **deprecate, then remove**. Phase 1 reads from contract; Phase 5 deletes the legacy enum.
4. Document in CHANGELOG / release notes: "v0.2 atlases require an `atlas_contract` Resource. Use the bundled `tetra_tile_default_contract.tres` to reproduce v0.1 behavior. The `atlas_layout` property is removed."

### Fallback Path for Lazy Migration

If `atlas_contract == null` and `atlas_source_id` is set, fall back to v0.1's hardcoded behavior. This is a one-`if` branch in `_resolve_slot()`. Keep it for one minor version, then remove. Lets users upgrade the addon without touching their scenes.

## Architectural Patterns

### Pattern 1: Resource-Driven Configuration

**What:** The contract is a `Resource` subclass exported on the node. All authoring happens in the Inspector (or by editing `.tres` directly).

**When to use:** When users need to author structured data with strong types and Inspector visibility. Standard Godot pattern.

**Trade-offs:**
- ✅ Inspector renders fields automatically
- ✅ Resources can reference other Resources (Slots embedded in Contracts)
- ✅ `.tres` files version-control cleanly as text
- ❌ Inner classes can't extend Resource — each Resource needs its own file
- ❌ Adding a new export field is a non-breaking change; renaming/removing one IS breaking (text files reference field names)

### Pattern 2: Mode-Dispatched Lookup

**What:** A single mode flag (`rotation_mode`) selects between two equivalent-shape lookup tables (transform-based vs explicit). Same mask → different result computation, same return shape.

**When to use:** When two implementation strategies for the same conceptual operation share a return type. Avoids polymorphic Resource hierarchies (which have UX cost in the Inspector — users have to pick "which subclass" before authoring).

**Trade-offs:**
- ✅ Single Resource type, one Inspector page per contract
- ✅ Adding a new mode is a single enum entry + one branch in `_resolve_slot()`
- ❌ Mode-specific fields (e.g., `mask_slots` is unused in SYMMETRIC) are visible but ignored — minor UX confusion
- ❌ Resource holds union-typed data; fields not used in a given mode just take memory (negligible)

### Pattern 3: Lazy Internal Layer Creation

**What:** `_top_layer` is created on demand only when the contract opts in. v0.1 layers (primary, overlay) are always created.

**When to use:** When optional features add infrastructure that's only paid for when used. Especially when default users should pay zero overhead.

**Trade-offs:**
- ✅ Zero cost for users not using top tiles
- ✅ Symmetric with overlay layer (which is also lazy-painted, just always existing as a node)
- ❌ Adds a branch in `_ensure_visual_layers()` and `_clear_visual_layers()`
- ❌ Recreation on contract reassignment requires teardown logic

### Pattern 4: Deterministic Per-Coord Hashing for Variation

**What:** Variation index = `hash(coord ⊕ seed) mod alt_count`. Computed per paint, never stored.

**When to use:** When stochastic visual variation must be stable across rebuilds without persisting state.

**Trade-offs:**
- ✅ No cache, no persistence (matches lean stance)
- ✅ Identical rebuild output every time
- ✅ User can re-roll by changing `variation_seed`
- ❌ Same hash function across atlases means cell (5,3)'s variation in atlas A correlates with atlas B (low-impact but technically detectable)
- ❌ Modulo bias is negligible at typical alt counts (1–8)

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Contract on TileSet via Custom Data Layers

**What people might do:** Use Godot's `TileSet.add_custom_data_layer()` to attach contract metadata per-tile (e.g., "this tile is the outer corner").

**Why it's wrong:**
- Couples TetraTile's logic to TileSet authoring (any atlas refactor breaks the contract)
- Per-tile metadata is hard to inspect holistically — there's no "see the whole contract" view
- Path notation (`x:y/alt/key`) is verbose and stringly-typed
- Schema migration would require walking every tile individually

**Do this instead:** Resource subclass with explicit slot fields. The TileSet stays art-only.

### Anti-Pattern 2: Per-Tile `rotation_lock` Flag

**What people might do:** Put `is_rotating: bool` on every `AtlasSlot`, so users can mix rotated and non-rotated tiles in one atlas.

**Why it's wrong:**
- Rotation-mismatched neighbors create visual seams (a fill tile rotated 90° next to a border tile drawn for a specific orientation looks broken)
- Configuration explodes: 4 slots × 4 rotations × 16 masks = combinatorial bug surface
- Mental model is harder to explain in docs

**Do this instead:** Whole-atlas `RotationMode` flag. If a user needs mixed behavior, they ship two atlases.

### Anti-Pattern 3: Caching Selected Variants Per Coord

**What people might do:** Persist a `Dictionary[Vector2i, int]` of "this coord's chosen alt-tile" so variation survives rebuilds without recomputing the hash.

**Why it's wrong:**
- Violates the lean stance (no persistent caches)
- Cache invalidation: when does the entry expire? Never? On erase?
- Memory cost grows with map size (defeats the "demo-scale" target)
- Solves a non-problem — deterministic hashing is O(1) and adds <1µs per cell

**Do this instead:** Recompute the hash every paint. It's free.

### Anti-Pattern 4: Rebuilding On Every Contract Field Change

**What people might do:** Wire every `@export` setter on `TetraTileAtlasContract` to `tetra_tile_layer._queue_rebuild()` via signal.

**Why it's wrong:**
- Resources don't know which TetraTileMapLayer instances reference them — this requires watcher infrastructure (lean violation)
- Editing a contract while running edits user data; full rebuild on every keystroke is wasteful

**Do this instead:** Listen to `Resource.changed` signal on the contract from the layer (Godot built-in, no watcher infra needed). Debounce via existing `_queue_rebuild()`'s `call_deferred`.

```gdscript
@export var atlas_contract: TetraTileAtlasContract:
    set(value):
        if atlas_contract != null and atlas_contract.changed.is_connected(_queue_rebuild):
            atlas_contract.changed.disconnect(_queue_rebuild)
        atlas_contract = value
        if atlas_contract != null:
            atlas_contract.changed.connect(_queue_rebuild)
        _queue_rebuild()
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| ~100 cells (current demo) | None. Per-cell hash is free. |
| ~1k cells (PROJECT.md target) | None. `_update_cells` already incremental. |
| ~10k cells (Out of Scope) | Would need batched updates and possibly a coord cache; explicitly deferred per PROJECT.md |

### Scaling Priorities (if ever needed)

1. **First bottleneck:** `rebuild()` iterating `get_used_cells()` — currently O(N). Mitigation: only rebuild on contract changes, not on every property setter.
2. **Second bottleneck:** Per-cell `get_tile_data()` calls during weighted variation. Mitigation: cache the weights array per slot in the contract Resource (precomputed on `Resource.changed`).

Neither bottleneck applies at PROJECT.md's stated scale.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `TetraTileMapLayer` ↔ `TetraTileAtlasContract` | Direct property access on Resource | Resource emits `changed` for invalidation |
| `TetraTileMapLayer` ↔ Internal layers | Direct method calls (`set_cell`, `clear`, etc.) | No signals, no fanout |
| `TetraTileAtlasContract` ↔ `AtlasSlot` | Resource embedding via `@export` | Slots are sub-resources; saved inline in contract `.tres` |
| `TetraTileMapLayer` ↔ Godot `TileSet` | Read-only access via `tile_set` property | TileSet stays art-only — no contract metadata stored there |

### External Services

None — TetraTile has no external dependencies (constraint per PROJECT.md).

## Confidence Notes

- **HIGH confidence:** Resource serialization rules, alternative tile + transform flag bit interaction, `_update_cells` semantics, custom data layer mechanics — all directly verified against Godot 4.6 docs via Context7.
- **HIGH confidence:** Probability is editor-only for `set_cell` programmatic calls — verified in `tutorials/2d/using_tilemaps.md` ("Painting Randomly Using Scattering" specifies the editor's brush tools).
- **MEDIUM confidence:** TileMapDual's exact internal structure (only confirmed it ships 16 unique tiles for non-rotating mode; haven't reviewed source line-by-line). Recommendation does not depend on TileMapDual's specifics.
- **MEDIUM confidence:** Top-tile mask criteria (4/8/12). This is a designer judgment call — could also include 5/7/13 depending on whether "edge cap" applies to partial top edges. Phase 4 should validate against demo art before committing.

## Sources

- Godot 4.6 docs (Context7-verified, `/godotengine/godot-docs`):
  - `tutorials/scripting/resources.md` — Resource subclass patterns, inner class limitation
  - `tutorials/2d/using_tilesets.md` — Custom data layers, alternative tile creation, rotation/flipping
  - `tutorials/2d/using_tilemaps.md` — Painting random tiles via scattering (editor-only)
  - `classes/class_tilesetatlassource.md` — `create_alternative_tile`, transform flag application
  - `classes/class_tiledata.md` — `probability`, `flip_h`, `flip_v`, `transpose`, custom data accessors
  - `classes/class_tilemaplayer.md` — `_update_cells`, `set_cell`, `changed` signal
  - `classes/class_randomnumbergenerator.md` — `rand_weighted`, deterministic seeding
- TetraTile codebase (`.planning/codebase/ARCHITECTURE.md`, `tetra_tile_map_layer.gd`)
- TileMapDual precedent: [pablogila/TileMapDual](https://github.com/pablogila/TileMapDual), [jess-hammer/dual-grid-tilemap-system-godot](https://github.com/jess-hammer/dual-grid-tilemap-system-godot)
- Project constraints: `.planning/PROJECT.md`

---
*Architecture research for: TetraTile v0.2.0 contract expansion*
*Researched: 2026-04-25*
