# Pitfalls Research

**Domain:** Godot 4.6 dual-grid autotiling addon — contract expansion (TetraTile v0.2)
**Researched:** 2026-04-25
**Confidence:** HIGH (Godot mechanics verified via Context7 + 4.6 docs); MEDIUM (project-specific predictions)

> Scope reminder: v0.1 issues (e.g., logic-layer `visible=false` cleanup, missing tests, undocumented map-size limits) are catalogued in `.planning/codebase/CONCERNS.md`. This file focuses on **what the v0.2 expansion specifically introduces or aggravates**.

---

## Critical Pitfalls

### Pitfall 1: `_update_cells()` re-entrancy from probability-driven repaints

**What goes wrong:**
The new variation feature reads `TileSetAtlasSource` alternates and writes a chosen alternate ID via `set_cell()` on `_primary_layer`/`_overlay_layer`. If a future change accidentally writes back to `self` (the logic layer) — e.g., to "store" the picked alternate — Godot will re-enter `_update_cells()` for the same coords and the override fires recursively. Even without re-entrancy, calling `set_cell()` on the visual layers from inside `_update_cells()` is fine *today* because those layers are separate `TileMapLayer` instances, but adding any "remember the chosen variation in custom data" path on the logic layer breaks that.

Compounding: Godot 4.6 `_update_cells()` is also called when `enabled=false`, `visible=false`, `tile_set=null`, on free, or on tree removal — all with `forced_cleanup=true`. The current code handles `forced_cleanup` correctly, but any new "if I have variation data, preserve it" branch must NOT fight cleanup. Variation state must live in the visual layers (or a transient cache), never on the logic layer where the user paints.

**Why it happens:**
A natural design instinct says "store the picked alternate in a custom data layer on the logic tile so reloads don't reshimmer." That couples user input (logic layer) with derived state (variation pick), making cleanup ambiguous and inviting recursive `_update_cells()` calls.

**How to avoid:**
- Variation pick lives only in the visual layers' `set_cell(coords, source, atlas_coords, alternative_tile)` calls. The visual `alternative_tile` is the only place "what variant did we pick" is recorded. No custom data layers on the logic layer.
- For determinism, pick from a pure function `pick_alternate(display_cell, source, atlas_coords) -> int` — no shared mutable state (see Pitfall 3).
- Add a unit-style smoke test that asserts: after `set_cell()` on the logic layer triggers `_update_cells()`, no further `_update_cells()` call fires within the same frame for that coord.

**Warning signs:**
- Stack frames showing `_update_cells → _paint_display_cell → ... → _update_cells` in a profiler.
- Editor stutter that scales with map size on a single edit.
- Variation choices that drift between editor reloads (smell of a stored-value dependency).

**Phase to address:**
Variation feature phase. Lock the rule "variation never writes to the logic layer" in the contract design before any code lands.

---

### Pitfall 2: Variation shimmers on every `rebuild()` because `randi()` is global RNG

**What goes wrong:**
Naive implementation: in `_paint_display_cell()`, when a tile has alternates with `TileData.probability > 0`, call `randi()` to pick one. Result: every `rebuild()` (which fires on `_ready()`, on `atlas_layout` change, on `atlas_source_id` change, on `tile_set` change, AND any `_queue_rebuild()`) reshuffles every cell. Reload the scene → different visuals. Drag-paint → cells you didn't touch may shimmer if `_update_cells()` is invoked with empty `coords` (the existing code falls through to `rebuild()` when `coords.is_empty()`, line 75).

Godot's terrain peering tools (`set_cells_terrain_connect`) have the same problem, "fixed" by users calling `seed(...)` first — but that's a stateful global seed, fragile in multi-tilemap scenes.

**Why it happens:**
- `randi()` is the obvious API and matches Godot's docs ("pick_random uses global random seed").
- `TileData.probability` is documented as "relative probability" but the engine does NOT auto-pick at `set_cell()` time — the user must implement weighted selection. This is a sharp surprise: the property exists in the inspector and looks like it works, but Godot 4.6 only honors it inside the *terrain peering / scattering* paths, not on direct `set_cell()` calls. The addon is on the direct path.
- The "easy fix" of seeding once at `_ready()` breaks again the moment any other system calls `randi()` between rebuilds.

**How to avoid:**
- Use a **per-cell deterministic hash** as the seed, not global RNG. Concrete recipe:
  ```gdscript
  func _pick_alternate(display_cell: Vector2i, atlas_coords: Vector2i, alternates: PackedInt32Array, weights: PackedFloat32Array) -> int:
      # Stable hash: cell coords + atlas coords + per-instance salt.
      var h := hash(Vector4i(display_cell.x, display_cell.y, atlas_coords.x, atlas_coords.y) + Vector4i(_variation_salt, 0, 0, 0))
      var rng := RandomNumberGenerator.new()
      rng.seed = h
      var roll := rng.randf() * _sum(weights)
      var acc := 0.0
      for i in alternates.size():
          acc += weights[i]
          if roll <= acc:
              return alternates[i]
      return alternates[-1]
  ```
- Expose `@export var variation_salt: int = 0` so users can perturb the whole map's pattern without editing tile coords.
- Document explicitly: "Variation is deterministic per `(cell, atlas_coords, variation_salt)`. Reloading the scene produces identical visuals."

**Warning signs:**
- Demo screenshots taken at different times don't match.
- In-editor: opening the scene shows different tiles than playing the game.
- Variation pattern changes when you paint an unrelated cell across the map (proof that global RNG state is leaking in).

**Phase to address:**
Variation feature phase. Determinism contract should be written down BEFORE the picker is implemented.

---

### Pitfall 3: `alternative_tile` parameter overloaded with transform bits

**What goes wrong:**
Godot 4.6's `TileMapLayer.set_cell(coords, source_id, atlas_coords, alternative_tile)` takes a single `int` for `alternative_tile` that encodes BOTH the user-defined alternative ID (low bits) AND the transform flags `TRANSFORM_FLIP_H=4096`, `TRANSFORM_FLIP_V=8192`, `TRANSFORM_TRANSPOSE=16384` (high bits, ≥ 4096). Current TetraTile code passes the rotation constants directly as `alternative_tile`:
```gdscript
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
...
layer.set_cell(display_cell, source, _atlas_coords(tile_index), transform)  # transform IS alternative_tile
```
This works today because alt-ID is implicitly 0. The moment v0.2 picks alt-ID `N`, the call must become `transform | N`, otherwise:
- If you write only `N`, you lose the rotation.
- If you write only `transform`, you lose the variant.
- If you write `transform + N` (arithmetic add), you may collide with transform bits when `N >= 4096`.

**Why it happens:**
The Godot API design is non-obvious; the docs mention "should be used directly with TileMapLayer to flip placed tiles by altering their alternative IDs" but most readers don't internalize that "alternative_tile" really means "alternative_tile + 32-bit-packed transform flags."

**How to avoid:**
- Always combine with bitwise OR: `var packed := transform | alt_id`.
- Add an internal helper to make the contract obvious:
  ```gdscript
  func _pack_alternative(alt_id: int, transform_flags: int) -> int:
      assert(alt_id < TileSetAtlasSource.TRANSFORM_FLIP_H, "alt_id must be < 4096; collides with transform flags")
      return transform_flags | alt_id
  ```
- Document the constraint in the public contract: alternative IDs ≥ 4096 are reserved by Godot for transforms and cannot be used.
- Round-trip test: `get_cell_alternative_tile()` should return `transform | alt_id` exactly.

**Warning signs:**
- A rotated tile suddenly appears un-rotated after enabling variation.
- A rotated variant tile renders as the base atlas tile.
- `get_cell_alternative_tile()` returns a number you don't recognize.

**Phase to address:**
Variation feature phase. Add the helper and the assertion before the second `set_cell()` call in the codebase grows alternates.

---

### Pitfall 4: Non-rotating tileset mask table — transpose vs flip ordering, and the empty-mask trap

**What goes wrong:**
A non-rotating tileset means each of the four orientations of each tile shape must be authored as a distinct atlas entry instead of being generated by transforms. The current 16-state lookup at lines 116–152 implicitly multiplies by 4 transforms (rot 0/90/180/270). Drop transforms → you need a **64-entry** table mapping `(mask, orientation_slot)` → atlas coords.

Three places this typically goes wrong:

1. **Bit assignment drift.** Current code uses `TL=1, TR=2, BL=4, BR=8` (lines 21–24, 157–164). When hand-writing a 64-row table, it's easy to swap TR↔BL because the labels are visually adjacent. Off-by-one in mask ordering will produce visuals that look "almost right" — the most insidious kind of bug because they pass casual playtests but fail at convex corners.
2. **Transpose vs flip confusion.** Godot's `_ROTATE_90 = TRANSPOSE | FLIP_H` and `_ROTATE_270 = TRANSPOSE | FLIP_V`. Hand-authored corner art often uses a different rotation sense (CW vs CCW). When the artist's "rotated 90° clockwise" tile is dropped into the slot the addon expects "rotated 90° per Godot's transform encoding," the convex/concave corners swap.
3. **Mask 0 default.** Mask 0 = "no logic neighbors" = empty cell. Current code returns early (line 118). A 64-entry table that mistakenly maps mask 0 to "tile (0,0) with no transform" will paint a full grid of fill tiles on an empty map.

**Why it happens:**
Hand-written tables of this size are error-prone, especially when the entries combine quadrant-presence bits, atlas coordinates, and orientation slot indices.

**How to avoid:**
- **Generate the 64-entry table from the 16-entry rotating table.** The mapping is mechanical: for each (mask, transform) in the 16-entry table, look up which atlas coord the user supplied for that orientation. This eliminates the hand-typing step entirely.
- Keep the existing rotating mode as the default; non-rotating is a strict superset where the user supplies up to 4× the atlas entries.
- Provide a validator (editor warning via `update_configuration_warnings()`) that checks the user-declared atlas has all 64 slots filled when in non-rotating mode. Missing slots = explicit error, not silent fallback to a wrong tile.
- Unit-style coverage: paint each of the 16 "logical" mask shapes on a test scene and screenshot-diff against the rotating mode. Any pixel difference = orientation slot mis-assigned.
- Mask 0 special case must be the FIRST line of the painting function: `if mask == 0: erase; return`.

**Warning signs:**
- Convex outer corners look fine but concave inner corners look wrong (or vice versa) — classic rotation-sense bug.
- Painting an isolated single tile shows the wrong corner orientation on one of its four display cells.
- Empty cells on map load show fill tiles.

**Phase to address:**
Non-rotating tileset phase. Generate the table, don't hand-write it.

---

### Pitfall 5: Setter loops in the new Resource-backed contract

**What goes wrong:**
The "declare what you have" redesign almost certainly introduces a `Resource` subtype like `TetraTileContract` exposed as `@export var contract: TetraTileContract`. Three setter-loop traps appear simultaneously:

1. **Setter recursion via name shadowing.** Common bug:
   ```gdscript
   @export var contract: TetraTileContract:
       set(value):
           set_contract(value)  # if set_contract() does `contract = value`, infinite recursion → editor crash
   ```
   Godot 4 has no built-in protection against this and crashes hard.
2. **`@onready` race.** When the editor opens a scene, `@tool` setters fire BEFORE `_ready()`. If the setter touches `_primary_layer`, it gets `null`. Current code already checks `is_instance_valid()` at the use site, but a new `contract.changed` signal connection in the setter would fire on a half-built node. The existing pattern `_queue_rebuild()` (lines 258–260) guards with `is_inside_tree()` — preserve that pattern.
3. **Contract-resource `changed` signal storm.** Resources emit `changed` when any sub-property mutates. If TetraTile connects `contract.changed` to `_queue_rebuild`, then every keystroke in the contract sub-inspector triggers a deferred rebuild. With multiple sub-resources (per-tile knobs), that's dozens of rebuilds per inspector edit, freezing the editor.

**Why it happens:**
GDScript setters look simple but combine with `@tool`, deferred calls, and Resource signals to form sharp edges. The community is full of "external setter call → crash" reports (issue #48437, #52757, #76019).

**How to avoid:**
- Property setter rule: only assign `<property> = value` and call `_queue_rebuild()`. Never delegate to a method that might assign back.
- Connect to `contract.changed` exactly once, with a deferred handler:
  ```gdscript
  set(value):
      if contract == value: return  # idempotent: avoid setter loops
      if contract != null and contract.changed.is_connected(_on_contract_changed):
          contract.changed.disconnect(_on_contract_changed)
      contract = value
      if contract != null:
          contract.changed.connect(_on_contract_changed)
      _queue_rebuild()

  func _on_contract_changed() -> void:
      _queue_rebuild()  # already deferred; coalesces multiple emissions per frame
  ```
- Add an idempotence check (`if contract == value: return`) to break setter loops at runtime even if the contract is reassigned to itself.
- `_queue_rebuild()` already coalesces via `call_deferred()` (only the last call's effect survives) — preserve that.

**Warning signs:**
- Editor freezes/crashes on opening scenes containing `TetraTileMapLayer`.
- `Stack overflow` errors in the Godot output panel.
- Inspector lag proportional to contract complexity.
- "_primary_layer is null" errors during editor scene load.

**Phase to address:**
Contract redesign phase. Define the property setter discipline as a pattern enforced across all `@export`s.

---

### Pitfall 6: Renaming Resource properties orphans saved scenes silently

**What goes wrong:**
Pre-1.0 freedom invites renaming. Godot 4.6 has NO automatic property-rename migration. Renaming `@export var atlas_layout` → `@export var atlas_orientation` causes:
- Saved `.tscn`/`.tres` files retain the old key `atlas_layout = 0`.
- On scene load, Godot silently drops the unknown key and uses the new property's default.
- The user's painstaking demo configuration vanishes with no warning, no log line, no "[remap]" hint.

Same trap for renaming `Resource` subclass files (the file path is part of the saved scene), renaming custom data layer keys on a TileSet, and reordering enum values that are stored as integers.

Issue #92068 (renaming custom resources breaks `Array[CustomResource]` exports) is unresolved; issue #84981 documents broader scene corruption from resource renames.

**Why it happens:**
- "Pre-1.0, breaking changes are fine" is true at the API level but invisible to .tscn deserialization, which fails silently rather than loudly.
- Godot persists by property name, not stable ID. There is no `[obsolete]` or `[renamed_from]` decorator.

**How to avoid:**
- For ANY property rename in this milestone, follow the **two-step migration pattern**:
  1. Add the new property AND keep the old property with `@export_storage` (Godot 4.6's "stored but not editor-visible" annotation), plus a `__migrate__()` method that copies old → new.
  2. After running the migration EditorScript on the demo scene (and any user scenes the author has), remove the old property in a follow-up commit.
- Migration EditorScript pattern (run via Ctrl+Shift+X, walks `.tres`/`.tscn` and calls `__migrate__()` on resources that define it).
- For custom data layer keys: prefer adding new keys over renaming old ones; deprecate old keys with a comment instead of deleting them mid-milestone.
- For enum-stored-as-int: NEVER reorder enum members. Always append new members at the end.
- Add a CHANGELOG.md entry per breaking field rename, with the migration recipe inline.

**Warning signs:**
- Demo scene "loses configuration" after a refactor commit.
- The atlas tiles display correctly but settings revert to defaults.
- `git blame` on a tscn shows a property line disappeared with no replacement.

**Phase to address:**
Contract redesign phase (most exposed) and release phase (migration script lands alongside the rename commit).

---

### Pitfall 7: Top-tile authoring — over-clever automatic detection vs. explicit declaration

**What goes wrong:**
"Top tile" means the tile at the top edge of a solid platform (mask shapes 12 = top-left + top-right filled, primarily; also masks 8, 4 for the corners). Three design temptations, each with a trap:

1. **Auto-detect tops by mask alone** ("any cell with `mask & 12 == 12` and `mask & 3 == 0` is a top"). Trap: this hardcodes 2D platformer assumptions. A top-down view from above ("walking on roof tiles") wants the OPPOSITE assignment. Bakes a perspective into the addon.
2. **Auto-detect by checking if "below" is filled** in the logic layer. Trap: requires a definition of "down" — which on isometric/hex grids is ambiguous. Couples the contract to grid orientation forever.
3. **Per-cell user declaration** ("user paints a `top: true` flag on every cell"). Trap: ruins the "paint with native API" promise; doubles the user's work; demands UI for editing per-cell flags.

The over-clever path produces tickets like "my cave roofs render as floors" two months after release.

**Why it happens:**
Top tiles look like a "smart" feature; the temptation is to be clever and infer them. But the inference rule that works for the demo (platformer) fails silently for the next user (top-down dungeon, vertical slice, isometric).

**How to avoid:**
- **Explicit per-mask declaration in the contract**, not per-cell. The contract says "for mask 12, use atlas slot X if `top_mode == TOP_AS_HORIZONTAL_BORDER`." User opts in via a contract enum, never via per-cell painting.
- Default `top_mode = NONE` keeps v0.1 behavior. Two clearly-named modes is enough; resist a third "smart" mode.
- Document the "what counts as a top?" decision tree as part of the contract design doc — this prevents the next contributor from "improving" it into ambiguity.
- Reuse the rotation-lock mechanism: a "top tile" is operationally just "this mask uses a different atlas slot AND skips rotation," which is the same lever as non-rotating tileset support. Build on that primitive instead of inventing parallel machinery.

**Warning signs:**
- The PR description for top-tile support contains the word "automatically" or "infers".
- Changelog says "We figure out which cells are tops based on context."
- Issue tracker grows tickets with the words "wrong orientation" or "should be a top".

**Phase to address:**
Top-tile / non-rotating phase (treated as one R&D track per PROJECT.md).

---

### Pitfall 8: Contract scope creep into TileMapDual territory

**What goes wrong:**
"Declare what you have" is a small phrase that can swell into a metadata system rivaling Godot's terrain peering. Failure mode: the contract grows from "atlas slot table + 3 enums" into "per-tile peering bits + multi-terrain transitions + connection rules", and TetraTile's "smaller and leaner than TileMapDual" identity (PROJECT.md line 72) evaporates.

Specific scope creep vectors observed in similar addons:
- "While we're declaring what we have, let's also declare neighboring terrain compatibility..."
- "Users want to mix two contracts on one layer..."
- "Variation should be conditional on neighbor tile type..."
- "Top tiles should know about tiles above them..."
- "Contract validation needs an editor UI panel..."

Each is reasonable in isolation; collectively they reproduce TileMapDual or worse.

**Why it happens:**
Contract design is creative work; ideas accrete. Pre-1.0 freedom removes the "we shipped, can't change" backstop. The user is the audience, so there's no external "is this in scope?" check.

**How to avoid:**
- Re-read the PROJECT.md "Out of Scope" list before merging any contract-shaped commit. Outer transition tiles are explicitly out (line 47). If a PR slips toward terrain transitions, reject.
- Hard line count budget for v0.2: target stays under 500 LOC in `tetra_tile_map_layer.gd` + new contract Resource files combined. Current is ~261 LOC. If the contract redesign pushes past 500 LOC, that's a signal to defer features.
- Each new export property answers: "does my game need this in the next 6 months?" If no, defer.
- Maintain ARCHITECTURE.md's "no persistent caches, no signal fanout, no watchers" stance. New caches require an explicit decision entry in PROJECT.md.

**Warning signs:**
- New file count > 5 in `addons/tetra_tile/`.
- New `@export` properties > 8 across all classes.
- Documentation requires a "concepts" page to explain.
- README says "compared to TileMapDual" and the comparison table shrinks.
- Any commit message contains "terrain" or "peering".

**Phase to address:**
Contract redesign phase. Set the LOC budget and feature scope boundary BEFORE design.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems for v0.2.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `randi()` for variation | Two-line implementation | Visual shimmer on every rebuild; non-reproducible bug reports; unfixable without new RNG architecture | Never. Use cell-keyed deterministic hash from day one. |
| Hand-write the 64-entry non-rotating mask table | "Just type the table" | One typo = subtle wrong-corner bug that ships; hard to diff against rotating mode | Never. Generate from the 16-entry table. |
| Store variation pick in TileData custom data layer on logic layer | "Variation persists across reloads" | Couples user input to derived state; complicates `forced_cleanup`; tempts re-entrancy | Never for variation. Custom data layers are for user game data, not addon-derived state. |
| Skip `__migrate__()` for property renames in v0.2 | Faster commits | Author's own demo loses settings silently; "just-rename" becomes the team norm; eventual data loss in dependent games | Only when the property has never appeared in any saved scene. |
| Rebuild on every contract sub-property change | "Reactive UX" | Editor lock-up during contract editing; setter storms | Acceptable IF the rebuild is deferred via `call_deferred()` AND the contract emits coalesced `changed` (one emission per frame max). |
| Hard-code platformer "down is +Y" assumption in top-tile detection | Demo works | Top-down/iso users get wrong tiles; can't undo without breaking the demo | Never. Top-tile assignment must be explicit in the contract, not inferred. |
| Rename a property without `@export_storage` shadow | Cleaner code | Saved scenes silently lose values; bug surfaces weeks later | Pre-1.0, only with a migration EditorScript run on every known consumer scene. |
| Keep `coords.is_empty() → rebuild()` shortcut in `_update_cells()` (line 74–76) when variation is added | Preserves v0.1 behavior | Empty `coords` triggers full-map reshuffle of variation picks, defeating determinism per-cell | Acceptable IF the picker is deterministic per-cell hash (Pitfall 2 prevention). |

---

## Integration Gotchas

Common mistakes when integrating with Godot 4.6 APIs during this milestone.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `TileSetAtlasSource.create_alternative_tile()` | Assuming alternative IDs are sequential and stable | IDs may have gaps if the user deletes alternatives. Iterate via `get_alternative_tiles_count` + `get_alternative_tile_id`. |
| `TileData.probability` | Assuming Godot auto-picks at `set_cell()` time | Godot only honors `probability` in terrain/scattering paths. TetraTile uses direct `set_cell()` and MUST implement weighted selection itself. |
| `set_cell()` `alternative_tile` parameter | Passing alt ID and transform separately, picking last-write-wins | Pack with bitwise OR: `transform_flags \| alt_id`. Alt IDs must be < 4096 (TRANSFORM_FLIP_H bit). |
| `forced_cleanup=true` from `enabled=false` | Treating cleanup as an error path | It's a routine signal. Current code handles it correctly (line 69); preserve that when adding the contract setter. |
| `_update_cells()` invoked with empty coords | Treating as "nothing to do" | Godot signals "you don't know what changed, redo everything" — fall through to `rebuild()` (line 75 already does this). |
| Adding internal child layers via `add_child(layer, false, Node.INTERNAL_MODE_FRONT)` | Assuming internals are hidden from `get_children()` | They ARE hidden from `get_children()` by default but VISIBLE to scene serialization unless reset on save. Re-create on `_ready()` (current code does this). |
| Connecting to `Resource.changed` in a `@tool` setter | One connection per setter call → leak | Disconnect old before connecting new (see Pitfall 5 example). |
| Reading `tile_set.tile_size` during `_ready()` | Assumes `tile_set` is non-null | Current `_visual_layer_offset()` already guards (line 237). Preserve when adding tile-size-dependent contract logic. |

---

## Performance Traps

Patterns that work at small scale but fail as the demo grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Iterating all alternates per `_paint_display_cell()` call to compute weight sum | Editor lag during paint | Cache `(weight_sum, alternates)` per `(source, atlas_coords)` keyed dict. Invalidate on contract change. | When alternates per tile > 4 OR painted cells per frame > 100. |
| `Resource.changed` storms causing dozens of rebuilds per inspector edit | Inspector freezes during contract edits | Coalesce via `call_deferred()` (existing `_queue_rebuild()` does this). Idempotence guard in setters. | When contract sub-resources have > 3 fields AND user types fast. |
| Variation lookup via `Dictionary` keyed by `(coords, atlas_coords)` | OK at 100 cells; fails at 10k | Use the deterministic-hash picker (no cache needed; pure function). | At ~5k cells with rebuild-per-frame. |
| Calling `_sync_visual_layers()` on every `_update_cells()` invocation (lines 73, 217) when adding new contract-driven sync state | Editor frame budget eaten by sync | Sync only on property setter, not on every cell update. Already mostly correct; do NOT add new contract-driven state into `_sync_visual_layers()`. | When contract has > 5 properties that affect visual layers. |
| Rebuilding the 64-entry non-rotating table on every mask query | O(64) lookup per cell instead of O(1) | Pre-compute once at contract-load time, store as `PackedInt32Array`. | Always — never compute per-cell. |
| Re-reading `TileData.probability` from `tile_set.get_source(source).get_tile_data()` per cell | Repeated dictionary lookups + Variant hops | Cache the per-tile alternate weights on contract load; refresh only on `tile_set` change. | At ~500 cells per frame. |

---

## "Looks Done But Isn't" Checklist

Common in this milestone — things that pass casual playtest but fail later.

- [ ] **Variation feature:** Re-open the scene → tiles look identical. Reload → identical. Restart Godot → identical. If any varies, RNG is non-deterministic.
- [ ] **Variation feature:** Painting one cell does NOT shimmer cells across the map. If it does, `coords.is_empty() → rebuild()` is reshuffling variations.
- [ ] **Top tiles:** Demo includes BOTH a horizontal platform AND a single floating block AND a 1-tile-wide vertical pillar. Top assignment must be sensible in all three.
- [ ] **Non-rotating tileset:** Paint a single isolated tile. All four display cells render the correct corner orientation. (Easy to ship with one quadrant flipped.)
- [ ] **Contract redesign:** Saved demo scene reloads with all configuration intact after a property rename commit.
- [ ] **Contract redesign:** Open the demo scene with the addon DISABLED — does Godot crash on missing class? (Should fail gracefully or persist as raw data.)
- [ ] **Resource setters:** Open and close the demo scene 5 times in a row in the editor without crashing.
- [ ] **Resource setters:** Edit a contract sub-property rapidly; editor remains responsive.
- [ ] **`alternative_tile` packing:** `get_cell_alternative_tile()` after `set_cell()` returns exactly the value passed in (round-trip).
- [ ] **Empty mask:** Painting and then erasing a tile leaves no visual residue (mask 0 erases both layers).
- [ ] **Migration:** Run the migration EditorScript on a copy of the demo scene; verify no settings dropped.
- [ ] **CHANGELOG:** Each breaking property rename has a one-line migration note.
- [ ] **Demo regression:** Run the demo, drag-paint for 30 seconds, no shimmer or stutter.
- [ ] **`enabled=false` cleanup:** Toggle `enabled` — visuals clear, then return cleanly. (Per `forced_cleanup` semantics.)
- [ ] **`tile_set=null`:** Clearing `tile_set` clears visuals without errors.

---

## Recovery Strategies

When pitfalls occur despite prevention.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Variation shimmer shipped | LOW | Replace `randi()` call site with hash-based picker. One-function fix. Tag as v0.2.1. |
| `alternative_tile` bit collision | LOW | Add `_pack_alternative()` helper, replace direct passing. Mechanical refactor. |
| Setter recursion crash on scene open | MEDIUM | Add idempotence guard `if x == value: return`. Audit all setters. |
| 64-entry non-rotating table has wrong row | MEDIUM | If generated from 16-entry table, fix is one-row. If hand-written, audit all 64; consider regenerating from scratch. |
| Property rename dropped settings | HIGH if author's other games depend on it; LOW for demo only | Restore from git. Re-rename WITH migration script. Bump version. Apologize in CHANGELOG. |
| Resource `changed` storm freezes editor | LOW | Add deferred coalesce; disconnect-before-reconnect pattern. |
| Top tile mode added third "smart" auto-detect | MEDIUM | Deprecate the auto-detect mode in CHANGELOG; keep working until v0.3; document explicit modes as preferred. |
| Contract scope creep merged | HIGH | Revert may not be possible if author's games adopted it. Establish a "feature freeze" commit and re-design v0.3 around the bloat. |
| Variation picks stored on logic layer break cleanup | HIGH | Migrate variation state to a transient cache or visual-layer-only storage. Audit all `_update_cells(forced_cleanup=true)` paths. Run migration script. |
| `_update_cells()` re-entrancy | MEDIUM | Add a re-entrancy guard flag. Audit which path writes to logic layer from inside the override. |

---

## Pitfall-to-Phase Mapping

How v0.2 phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. `_update_cells()` re-entrancy | Variation feature phase + Contract redesign phase | Smoke test: single `set_cell()` → exactly one `_update_cells()` call per affected logic cell. |
| 2. Variation shimmers (global RNG) | Variation feature phase | Reload-the-scene determinism test; documented in user-facing API. |
| 3. `alternative_tile` bit collision | Variation feature phase | Round-trip assertion in unit-style test; `_pack_alternative()` helper checked in. |
| 4. 64-entry mask table errors | Non-rotating tileset phase | Generated table; visual diff against rotating mode for all 16 mask shapes. |
| 5. Setter loops in contract Resource | Contract redesign phase | Open/close demo scene 5× without crash; idempotence guard pattern documented. |
| 6. Property rename orphans | Contract redesign phase + release phase | Migration EditorScript runs cleanly on demo scene; CHANGELOG entry per rename. |
| 7. Top-tile authoring confusion | Top-tile / non-rotating phase | Top assignment is explicit (contract enum), not inferred; demo includes platformer + top-down test cases (or documents top-down as out-of-scope). |
| 8. Contract scope creep | Contract redesign phase (front-loaded design review) | LOC budget enforced; PROJECT.md "Out of Scope" reviewed before each design commit. |

---

## TetraTile-Specific Gotcha Recap

Things only relevant because of v0.1's existing architecture:

1. **`_queue_rebuild()` (line 258) is the existing coalescing primitive.** Every new property setter MUST use it, not a custom path. Adding a parallel "queue" path defeats the coalescing.
2. **`_visual_layer_offset()` returns `tile_size * -0.5`** (line 239). If the contract introduces non-uniform tile sizes (e.g., platformer "tall top" tiles), this offset breaks. Out-of-scope for v0.2 per PROJECT.md, but flag if it sneaks in.
3. **`self_modulate.a` for logic-layer hiding** (lines 248–251) is a workaround for `visible=false` triggering `forced_cleanup`. The new contract MUST NOT introduce a path that sets `visible=false` on the logic layer.
4. **`_overlay_layer` only renders for masks 6 and 9.** A new feature that needs a third decoration layer should not pile onto `_overlay_layer`; create a new internal layer with its own `INTERNAL_MODE_FRONT` slot.
5. **`atlas_layout` setter triggers `_queue_rebuild()` (line 33).** Same rule for new contract properties: contract change → defer rebuild → coalesce.
6. **No persistent cache by ARCHITECTURE.md edict.** The variation picker MUST be a pure function. No "remember the last pick per cell" dict — that's a cache.

---

## Sources

### Godot 4.6 Documentation (HIGH confidence)
- [TileMapLayer - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html) — `_update_cells`, `forced_cleanup` conditions, `set_cell` signature
- [TileSetAtlasSource - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_tilesetatlassource.html) — `TRANSFORM_FLIP_H/V/TRANSPOSE` constants, alternative tile API
- [TileData - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_tiledata.html) — `probability` property
- [Using TileSets - Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html) — terrain peering, autotile basics
- [Upgrading from Godot 4.5 to 4.6](https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html) — migration guidance

### GitHub Issues — known engine traps (MEDIUM-HIGH confidence)
- [Issue #48437: External setter call → stack overflow crash](https://github.com/godotengine/godot/issues/48437)
- [Issue #52757: Calling method on variable property → infinite recursion](https://github.com/godotengine/godot/issues/52757)
- [Issue #92068: Renaming custom resources breaks `Array[CustomResource]`](https://github.com/godotengine/godot/issues/92068)
- [Issue #84981: Renaming/moving causes scene corruption](https://github.com/godotengine/godot/issues/84981)
- [Issue #57677: `Place Random Tile` does not work for animations](https://github.com/godotengine/godot/issues/57677)
- [Issue #72525: Alternative Tile can't replace rotation](https://github.com/godotengine/godot/issues/72525)
- [Proposal Discussion #10948: Deterministic terrain randomization](https://github.com/godotengine/godot-proposals/discussions/10948)

### Community / Tutorial Sources (MEDIUM confidence)
- [Safely Renaming Exported Variables in Godot - Prvaak](https://prvaak.cz/blog/safely-renaming-exported-variables-in-godot/) — `__migrate__()` pattern
- [More @tool woes - Godot Forum](https://forum.godotengine.org/t/more-tool-woes/116119) — `@onready` race conditions in tool scripts
- [Using @tool in Godot 4 for real-time property updates - Godot Forum](https://forum.godotengine.org/t/using-tool-in-godot4-for-real-time-property-updates-in-editor-how/7861)
- [How to use random autotiles in Godot 4 - Godot Forum](https://forum.godotengine.org/t/how-to-use-random-autotiles-in-godot-4/4022)
- [TileMapDual repository](https://github.com/pablogila/TileMapDual) — reference for "lean vs full" comparison
- [Marching Squares - BorisTheBrave](https://www.boristhebrave.com/docs/sylves/1/articles/tutorials/marching_squares.html) — bit assignment conventions
- [Classification of Tilesets - BorisTheBrave](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) — non-rotating vs rotating tradeoff space

### Project-internal sources (HIGH confidence)
- `C:/Programming_Files/Shilocity/TetraTile/.planning/PROJECT.md` — scope, constraints, "smaller than TileMapDual" identity
- `C:/Programming_Files/Shilocity/TetraTile/.planning/codebase/CONCERNS.md` — v0.1 concerns (visibility cleanup, no tests, fixed atlas)
- `C:/Programming_Files/Shilocity/TetraTile/.planning/codebase/ARCHITECTURE.md` — "no persistent caches, no signal fanout" stance
- `C:/Programming_Files/Shilocity/TetraTile/addons/tetra_tile/tetra_tile_map_layer.gd` — current 261-LOC implementation

---
*Pitfalls research for: Godot 4.6 dual-grid autotiling addon — TetraTile v0.2 contract expansion*
*Researched: 2026-04-25*
