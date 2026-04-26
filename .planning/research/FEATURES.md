# Feature Research

**Domain:** Godot 4 dual-grid autotiling addon (TetraTile v0.2 expansion: variation, top tiles, non-rotating tilesets)
**Researched:** 2026-04-25
**Confidence:** HIGH for variation API and competitor feature inventory; MEDIUM for top-tile and non-rotating authoring UX (no canonical Godot pattern; relies on adjacent-ecosystem evidence — Tilesetter, Better Terrain, platformer asset packs).

## Audience Note

TetraTile's audience is the author's own games. Distribution is GitHub releases. Quality bar is "works in my game." Many features other addons must ship for public Asset Library polish (editor docks, custom inspector plugins, full-fat tutorials) are explicitly out of scope. The scoring below reflects that filter — a feature that's "table stakes for a public addon" but optional for a self-consumed addon is graded on the latter axis.

## Feature Landscape

### Table Stakes (Users Expect These)

Features the author (as the only user) needs for the milestone goal — variation + top tiles + non-rotating tilesets — to actually unblock the games this is built for. Missing any of these and the milestone fails its stated goal.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Y-axis variation via Godot's native `TileData.probability` | Dual-grid addons across the ecosystem (TileMapDual, Better Terrain, 5-Tile Dual-Grid) all support some form of "multiple tiles for the same logical state with weighted random pick." TetraTile already loses to TileMapDual on terrain breadth — losing on variation too would make it strictly worse than the engine's stock terrain system. PROJECT.md key decision: ride Godot's existing mechanism. | LOW–MEDIUM | The engine already does the RNG. TetraTile just needs to (a) discover all alternates that exist for a given mask slot, (b) sample one weighted by `TileData.probability` at paint time. Per-coord deterministic-vs-per-paint-random is a design choice (see Differentiators). |
| Top-tile support for platformer caps | The demo is a platformer. The author's own games are platformers. The current 4-tile contract assumes rotational symmetry, so top edges and bottom edges share visuals — which looks wrong for grass-on-dirt. Without this, the demo asset (Kenney Pico-8 Platformer) can't be used at full fidelity. | MEDIUM–HIGH | Requires breaking the rotational-symmetry assumption baked into the v0.1 16-state mask table. See "Authoring UX patterns" section below for concrete designs. |
| Non-rotating tileset support | Same root cause as top tiles — the v0.1 contract collapses T/B/L/R into one rotated source. Asymmetric art (lit-from-above shading, directional textures, beveled edges) can't be expressed at all today. PROJECT.md treats top tiles + non-rotating as one R&D track. | MEDIUM–HIGH | The atlas contract redesign that supports top tiles is 90% the same redesign that supports fully non-rotating sets. See dependency diagram. |
| "Declare what you have" atlas contract | Dropping the strict 4-tile core is the Active requirement that gates the other three. v0.1's hardcoded enum for atlas layout (HORIZONTAL / VERTICAL) and fixed slot order (Fill / InnerCorner / Border / OuterCorner) cannot express "I have a top-Border tile and a bottom-Border tile but no left-Border tile." | MEDIUM | The shape of this contract is the central design decision of the milestone. Likely a custom Resource (e.g. `TetraTileAtlasConfig`) attached as `tile_set` metadata or an exported property — see Authoring UX patterns. |
| Native `TileMapLayer` painting still works | v0.1's selling point is that native `set_cell()` / editor painting drives autotiling. Anything that breaks that contract regresses the v0.1 win. | LOW | Already validated. Just needs to keep working through the redesign. |
| Updated demo scene | PROJECT.md requirement: one expanded demo showcasing all new features. The Kenney Pico-8 platformer asset already has top-tile-style art the demo isn't using. | LOW | Asset re-arrangement, not engineering. |

### Differentiators (Competitive Advantage)

Where TetraTile can credibly compete with TileMapDual (the dominant Godot dual-grid addon) by being smaller and more native. These are the features TetraTile should consciously copy from competitors **and** the ones where TetraTile can leapfrog by making different tradeoffs.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Native alt-tile probability passthrough** (vs TileMapDual rolling its own) | TileMapDual's README explicitly states: *"It currently does not support alternative tiles."* That's a real, verified gap in the dominant competitor. If TetraTile reuses Godot's existing `TileData.probability` UX (set on each base tile in the TileSet inspector), users author variation in the place they already know — no new dock, no custom Resource for variation alone. This is the single biggest differentiator available this milestone. | LOW | Author per-base-tile probability in the standard Godot TileSet inspector → Probability field. TetraTile reads it at paint time and weighted-samples among alternates that match the same 4-bit mask slot. |
| **Per-coord deterministic variation** | Engine's stock terrain randomization is non-deterministic (proposal #10948 confirms this is a long-standing pain — users can only seed via `seed()` before `set_cells_terrain_connect`). A coord-based hash (`hash(coord) % weight_total`) gives free determinism: same map always renders the same, no save/load drift, no flicker on rebuild. Costs essentially nothing to implement. | LOW | Two-line decision: `var rng_seed = hash(coord)` instead of `randi()`. Works because TetraTile owns the paint-time tile selection. |
| **Per-tile rotation lock** (PROJECT.md Active requirement) | "Rotation lock" as a per-tile knob means: this top-tile cap is authored for the top edge only — never rotate it. The user's intuition (Active requirement) matches what Tilesetter does for asymmetric tilesets ("you can choose which Sources to use for edge orientations present in that tile"). This is the mechanism that lets non-rotating tilesets coexist with rotating ones in the same atlas. | MEDIUM | Best authored as TileSet `custom_data_layers` (named "tetra_role" / "tetra_lock_rotation") so it lives where the tile lives, no parallel Resource to maintain. Read at paint time to filter the candidate set. |
| **Single public node, native API** | TetraTile's identity from v0.1. Don't add a `CursorDual`, don't add a `BetterTerrain` autoload. Differentiator vs Better Terrain (autoload-based runtime API) and TileMapDual (multiple supporting classes per its README). | LOW | Don't add new public classes. Anything new lives as `@export` on `TetraTileMapLayer` or as TileSet metadata. |
| **Migration story baked into the redesign** | Pre-1.0, breaking changes are accepted (PROJECT.md). But the v0.1 demo and the author's existing in-progress games already use the 4-tile atlas. A migration UX of "your old atlas still works as a 'rotational-symmetric, no-variation, no-top' subset of the new contract" is much cheaper to implement than asking users to re-author atlases — and it's strictly better than competitor migration UX. TileMapDual ships zero migration documentation; the engine itself botched its 3→4 tilemap migration (Godot issue #71188). | MEDIUM | Implementation: detect a v0.1-shaped atlas (4 tiles, fixed order) and synthesize the new declarative contract from it. Document one paragraph in the README showing how a v0.1 atlas maps to the new contract. |

### Anti-Features (Deliberately NOT Built — Things TileMapDual/BetterTerrain Do That TetraTile Rejects)

These are the features competitors ship that TetraTile must consciously refuse, because each of them dilutes "smaller and leaner than TileMapDual." For each: what the competitor does, why it's appealing, why TetraTile rejects it for **this** milestone.

| Feature (competitor) | Why It's Tempting | Why TetraTile Rejects (This Milestone) | What TetraTile Does Instead |
|----------------------|-------------------|----------------------------------------|------------------------------|
| **Terrain peering metadata** (Godot stock + TileMapDual) | Standard Godot UX. Users coming from terrain workflows expect to set "this side connects to grass, that side to dirt." | TetraTile's binary occupied/empty model is the entire reason the addon is small. Adding peering bits means inheriting the engine's 5-bit-per-side complexity, deterministic-pick bugs (proposal #7670), and "all required terrain combinations" footgun. PROJECT.md explicitly puts multi-terrain transitions in Out-of-Scope. | Stay binary. If the user wants two terrains, they use two `TetraTileMapLayer` nodes (per README's TileMapDual-comparison row). |
| **Terrain rule tries / "best fit" search** (Better Terrain) | Lets the addon tolerate incomplete tilesets: missing tile? Find the nearest match. | Implies a search graph (peering bits → tile candidate set → fallback chain). Core to Better Terrain (`update_terrain_cell`, `update_terrain_cells`, `update_terrain_area` all run a matching algorithm). TetraTile's `_update_cells()` is O(1) per affected display cell — a deliberate architectural floor, per CONCERNS.md. | Strict mask → tile slot table. If a slot is unfilled, fall back to the v0.1 4-tile rotational interpretation or paint nothing. The new contract explicitly *declares* what tiles exist; missing means missing. |
| **Multi-terrain transitions** (TileMapDual, Better Terrain) | "Grass to dirt" autotiling is the prototypical autotile pitch. | Out-of-Scope per PROJECT.md. Distinct R&D track. The mask table doubles in width per added terrain pair. | Defer. Documented in README roadmap under "Outer transition tile support." |
| **Watcher / signal-fanout systems** (TileMapDual) | Auto-cascading updates when a TileSet is edited at runtime; "real-time" feel. | TileMapDual's README pitches "real-time" updates — but its issue tracker shows the cost: leaks (#75), exported-build crashes (#73, #76), HTML5 export failures (#59). TetraTile's `_update_cells()` discipline avoids all of this by never holding state across calls. CONCERNS.md re-confirms this is intentional. | Continue to recompute affected masks on demand inside `_update_cells()`. `rebuild()` is the user's escape hatch. |
| **Persistent coordinate cache** (TileMapDual `Set` and `Util` classes — to be refactored per their issue #72) | "Don't recompute" is a real perf win on huge maps. | CONCERNS.md notes the cache adds memory leak risk and complicates editor-time hot reloading. PROJECT.md target is demo-scale (~100–1k cells); a cache buys nothing here and creates lifecycle bugs. | No cache. `_mask_at()` re-reads four neighbors on every paint. |
| **Custom drawing API** (`draw_cell(cell, terrain)` / `fill_tile` / `erase_tile` per TileMapDual usage guide; Better Terrain's `BetterTerrain.set_cell(...)` autoload) | Convenience wrappers with terrain selection baked in. | Each such API is a parallel painting path that has to stay in sync with native `set_cell()`. The v0.1 tradeoff — *only* native API — is the reason the addon is 261 LOC. | Continue to expose **only** the native `TileMapLayer` API. Variation / top-tile / non-rotating selection happens inside `_update_cells()`, not in a parallel API. |
| **Editor dock** (Better Terrain dedicated dock with pen/line/rect/fill) | Discoverability, designer-friendly. | Audience is the author. PROJECT.md: "Quality bar is 'works in my game' — no formal test suite, no Asset Library polish." A dock is asset-library polish. | Native TileMap editor + standard inspector for `TetraTileMapLayer` exports. |
| **Inspector plugin / custom dock for atlas configuration** (potential future direction for the new contract) | Could make the new "declare what you have" contract clickable. | Inspector plugins are a maintenance tax (Godot inspector API is unstable across minor versions). Stick with declarative properties on a custom Resource that the standard Godot inspector can edit out of the box. | Use `@export` typed properties + a custom `Resource` with `@export` arrays. The default inspector handles it. |
| **Full MkDocs documentation site** (TileMapDual roadmap; TetraTile README roadmap originally listed this) | Looks professional. | PROJECT.md: explicitly out-of-scope. Audience is private. | README + release notes only. |
| **Asset Library submission** (TileMapDual is on Asset Library) | Discoverability. | PROJECT.md: GitHub releases only. | Skip. |
| **Formal test suite (GUT)** | Caught CONCERNS.md as gap, would catch mask-table regressions. | PROJECT.md: explicitly deferred to a future milestone. The contract is changing — tests written this milestone would mostly be thrown away. | Manual demo verification. Add tests post-1.0 once the contract stabilizes. |
| **Tileset converter** (Wang/blob → TetraTile) | Onboarding tool. | PROJECT.md: deferred until contract design is settled. The contract redesign is *this* milestone, so the converter is by definition premature. | Defer. Document the new contract; users hand-author. |

## Authoring UX Patterns (Concrete Examples)

This is the section the milestone hinges on — *how* each new feature is authored matters as much as whether it ships. The chosen patterns must be defensible against "why not native Godot UX?" and against "why not TileMapDual?"

### Variation authoring

**Recommendation: ride `TileData.probability` directly. Do not introduce a custom Resource for variation.**

The author wants a Fill tile with three visual variants (e.g. plain dirt, dirt-with-pebble, dirt-with-grass-tuft).

The Godot-native pattern (verified via Context7 against Godot 4.6 docs):

1. In the TileSet inspector, the user creates **N base tiles in the atlas, all with the same role** (e.g. all are Fill). They are distinct atlas coordinates with distinct images.
2. Each base tile has its own `probability` (`set_probability` / `get_probability`, default `1.0`) editable in the inspector's middle column.
3. TetraTile's role discovery (the new "declare what you have" contract) needs to accept *multiple* base tiles per role. At paint time, sample weighted by probability.

What `TileData.probability` does NOT cover (and TetraTile must handle itself):

- The probability field is documented as "relative probability of this tile being selected when drawing a pattern of random tiles." That language is engine-side, used by `set_cells_terrain_connect()` and the editor's "scatter" tool. TetraTile is doing its own selection inside `_update_cells()`, so it has to read the property and apply the weighting itself.
- The engine's RNG behind this is non-deterministic. That's exactly the gap that lets TetraTile differentiate via per-coord hashing (see Differentiators).

**Anti-pattern to reject:** A custom `TetraVariationRule` Resource with weights, biomes, etc. TileMapDual doesn't have one *because* it doesn't support variation at all; introducing one in TetraTile would replicate Better Terrain's complexity surface for negligible gain. The engine already has `TileData.probability` and a UI for it.

**Variation behavior at runtime:** Per-coord deterministic by default (hash the coord, pick the alternate). Optional opt-out via `@export var variation_seed_per_paint: bool = false` — when true, use `randi()` so each paint operation can yield different variants. Default is determinism because that's what the user wants 95% of the time and it's what the engine doesn't ship.

### Top-tile authoring

**Recommendation: authored as TileSet `custom_data_layers`. The atlas declares which tile is the "top" tile for each role.**

The conceptual problem: in v0.1, a Border tile is rotated to handle top, bottom, left, right edges interchangeably. A platformer top-tile breaks that — the top edge wants its own art (grass cap), the side edges share one art (dirt edge), and the bottom edge shares another or reuses the side art rotated.

Three viable patterns from the ecosystem:

| Pattern | Source | UX | TetraTile fit |
|---------|--------|----|----|
| **Per-edge "Sources" property on a tile** | Tilesetter docs: *"by selecting a border tile in the set, you can choose through the Tile Properties View which Sources to use for edge orientations present in that tile (e.g., selecting a tile containing a top-facing border will allow you to choose the image used for top edges in the tileset)"* | Inspector: per-tile `top_source`, `bottom_source`, `left_source`, `right_source` slots | Closest match to TetraTile's contract redesign. TileSet `custom_data_layers` can hold "edge_role" = top/bottom/left/right. |
| **Extra atlas row with a "top mask" flag** | Godot stock terrain peering pattern — extra terrain combination tiles | Inspector: tile has terrain peering bits set such that it only matches when there's empty space above | Mismatch — requires peering bits, which the Anti-Features list rejects. |
| **Metadata flag per tile** | Better Terrain's "Decoration" type uses a metadata-marker pattern: *"treats its tiles equivalent to empty cells, and is used to add supplementary tiles around the edge of other terrains"* | Inspector: TileSet `custom_data_layer` named `tetra_role` with values like `top_border`, `border`, `outer_corner_top_left`, etc. | Best fit. Native Godot UX (TileSet custom data is a documented feature). No custom inspector plugin needed. |

**Recommended:** TileSet custom_data_layer named `tetra_role` (string or enum), with values that include directional variants:
- `fill`
- `border` (edge — generic, rotatable)
- `border_top` (top edge only — does not rotate)
- `border_bottom`, `border_left`, `border_right` (each can opt out of rotation)
- `inner_corner` (rotatable)
- `inner_corner_tl`, `inner_corner_tr`, `inner_corner_bl`, `inner_corner_br` (specific corners)
- `outer_corner` (rotatable) and the four directional variants
- Future: `top_cap`, `bottom_cap` for non-edge-state caps if needed

The mask-to-role lookup at paint time: first try the directional variant for the current mask state; fall back to the generic rotatable role if absent. This is what gives the migration story its smooth on-ramp — a v0.1 atlas has only the four generic roles, and the new contract degrades to identical-to-v0.1 behavior.

**Authoring at runtime:** No runtime authoring required. Roles are static metadata. The user assigns them once in the TileSet editor.

### Non-rotating tileset authoring

This is the same authoring UX as top tiles. "Top tile" is the prototypical asymmetric case; "non-rotating tileset" is the general case.

A user with a fully directional asset (e.g. an isometric-style 2D platformer with explicit lighting from the top-left):
1. For each role × direction (top-border, top-right-outer-corner, bottom-left-inner-corner, etc.), they create one base tile in the atlas.
2. Each tile has its `tetra_role` set to the directional variant.
3. The mask-to-tile resolver finds an exact directional match for every mask state, so no rotation is ever applied.

A user with a partially-directional asset (e.g. just wants different top vs. side caps):
1. They author the generic rotatable roles (border, inner_corner, outer_corner, fill).
2. They additionally author `border_top` (and optionally `outer_corner_tl`, `outer_corner_tr`).
3. The resolver prefers the specific role when present, falls back to rotated generic otherwise.

This is the *exact* migration story: a v0.1 atlas is the "fully generic, fully rotatable, no overrides" extreme of the new contract.

### Atlas contract redesign — the central decision

The v0.2 contract has two parts:

1. **Per-tile metadata** lives in the TileSet itself (custom data layers). This is where `tetra_role` and (optionally) `tetra_lock_rotation: bool` live. Native Godot UX. No custom Resource.

2. **Per-layer config** lives on the `TetraTileMapLayer` node (existing exports plus new ones). New exports likely needed:
   - `variation_seed_per_paint: bool = false` (default deterministic)
   - `variation_role_filter` (optional restrict-variation-to-certain-roles, if needed for performance — likely not v0.2)
   - The existing `atlas_layout` enum (HORIZONTAL/VERTICAL) becomes irrelevant once the contract is metadata-driven and can be removed. This is one of the breaking changes.

What goes away from v0.1: the strict 4-tile order, the `AtlasLayout` enum, the "first source in the TileSet" assumption (`atlas_source_id == -1`) for tile-role discovery (the resolver now scans the TileSet for tiles with `tetra_role` metadata).

### Migration UX (called out per quality gate)

**Audience-appropriate migration: README paragraph + automatic on-ramp, no migration tool.**

Pre-1.0, breaking changes are accepted (PROJECT.md). But "your old atlas just works" is cheap to implement and keeps the demo + the author's in-flight games unblocked.

**Strategy:**
1. **Detect the v0.1 shape:** if the TileSet has a single atlas source with exactly 4 tiles in the canonical order *and* no `tetra_role` custom_data_layer is defined, treat it as `[fill, inner_corner, border, outer_corner]` in the layout the user picked via the now-deprecated `atlas_layout` export.
2. **Document the upgrade path:** README adds a one-paragraph "Upgrading from 0.1.x" section showing the explicit metadata mapping. No conversion script.
3. **Deprecation, not removal:** keep `atlas_layout` as an `@export` for one minor version with a docstring "(deprecated — use TileSet `tetra_role` metadata)." Removing it in 0.3.0.
4. **No automatic migration of the demo TileSet** — re-author the demo with the new metadata. The demo doubles as the canonical worked example.

This is strictly better migration UX than:
- TileMapDual: zero documentation of breaking changes (their releases page literally has zero releases).
- Godot's stock 3→4 tilemap migration: famously broken (issue #71188 created hundreds of phantom tiles).
- Better Terrain: requires re-authoring all peering rules; no compatibility layer.

## Feature Dependencies

```
"Declare what you have" atlas contract (custom_data_layer based)
    ├─requires─> tetra_role metadata schema design
    │             └─enables─> Top-tile support
    │             └─enables─> Non-rotating tileset support
    │             └─enables─> Per-tile rotation lock
    │             └─enables─> Migration on-ramp from v0.1
    │
    ├─requires─> Mask-to-role resolver with fallback chain (specific → generic)
    │             └─enables─> Mixed atlases (some directional, some rotatable)
    │
    └─enables──> Variation (multiple base tiles per role)
                  ├─requires─> TileData.probability passthrough
                  └─enhances─> Per-coord deterministic seeding (differentiator)

Updated demo scene
    └─requires─> All four feature pillars to be functional
    └─requires─> Re-authored demo TileSet with new metadata

Migration story
    ├─requires─> v0.1-shape detection in the resolver
    └─requires─> README upgrade-paragraph
```

### Dependency Notes

- **Atlas contract redesign is the keystone:** all three feature pillars depend on the new declarative contract. The contract design itself is a single research/design exercise; once settled, the three pillars are mostly tile-resolver work.
- **Variation is independently testable:** once the resolver supports multiple tiles per role, variation is just sampling — it can ship before top tiles / non-rotating if needed for milestone slicing.
- **Top tiles and non-rotating share an implementation:** they are the same code path with different metadata. Slipping one slips the other.
- **Per-coord determinism enhances variation:** without determinism, variation is "competitor parity." With determinism, it's a leapfrog.
- **Migration on-ramp is parasitic on the resolver:** the v0.1 detection is one branch in the role resolver — practically free if added early, painful to bolt on later.

## MVP Definition

### Launch With (v0.2.0)

The minimum that makes the milestone successful per PROJECT.md.

- [ ] **Atlas contract redesign — `tetra_role` custom_data_layer** — keystone; everything else depends on it
- [ ] **Mask-to-role resolver with specific-then-generic fallback** — the engine of the redesign
- [ ] **Variation via `TileData.probability`** — competitor gap, lowest complexity new feature
- [ ] **Per-coord deterministic variation seeding** — differentiator at near-zero added cost; default ON
- [ ] **Top-tile support via directional roles** (`border_top`, `outer_corner_tl/tr`, etc.) — milestone goal
- [ ] **Non-rotating tileset support** — falls out of directional roles for free
- [ ] **Per-tile rotation lock** (`tetra_lock_rotation` custom_data_layer, optional) — finishes the per-tile configurability story
- [ ] **v0.1 atlas detection / migration on-ramp** — keeps existing games working
- [ ] **Updated demo scene using all features** — milestone gate
- [ ] **README "Upgrading from 0.1.x" paragraph** — migration UX

### Add After Validation (v0.2.x)

Bug-fix-tier follow-ups once the contract has lived in real games.

- [ ] **Per-paint random variation toggle** — only if the deterministic default proves insufficient in the author's games
- [ ] **Editor warnings for malformed metadata** — only if the author actually trips on these (e.g. printing a warning when a TileSet has `border_top` but no `border`)

### Future Consideration (v0.3+ and beyond)

Per PROJECT.md Out-of-Scope, deferred for explicit reasons.

- [ ] **TetraBake (procedural 5th tile generation)** — defer until 0.2 contract is proven
- [ ] **Tileset converter (Wang/blob → TetraTile)** — defer until 0.2 contract is proven; could be built once the new contract is stable
- [ ] **Outer transition tiles (multi-terrain)** — explicit out-of-scope; distinct R&D track
- [ ] **Shader fallback for diagonal compositing** — perf optimization; demo-scale doesn't need it
- [ ] **Auto-collision generation** — existing TileSet-physics path is enough
- [ ] **MkDocs site** — audience is private
- [ ] **Asset Library submission** — GitHub releases only this milestone
- [ ] **Formal test suite** — defer until contract stabilizes (so tests don't need rewriting)
- [ ] **Large-map perf benchmarks** — demo-scale target
- [ ] **Editor dock / inspector plugin** — competitor parity not the goal; native UX is

## Feature Prioritization Matrix

| Feature | User Value (to author's games) | Implementation Cost | Priority |
|---------|--------------------------------|---------------------|----------|
| Atlas contract redesign | HIGH (gates everything else) | MEDIUM | **P1** |
| Mask-to-role resolver with fallback | HIGH (engine of the redesign) | MEDIUM | **P1** |
| Variation via TileData.probability | HIGH (visible win, tiny cost) | LOW | **P1** |
| Per-coord deterministic variation | MEDIUM (differentiator + UX win) | LOW | **P1** |
| Top-tile support | HIGH (milestone goal, demo asset) | MEDIUM | **P1** |
| Non-rotating tileset support | HIGH (milestone goal) | MEDIUM (shares code w/ top tiles) | **P1** |
| Per-tile rotation lock metadata | MEDIUM (finishes per-tile knobs story) | LOW | **P1** |
| v0.1 atlas migration on-ramp | MEDIUM (keeps in-flight games working) | LOW (one branch in resolver) | **P1** |
| Updated demo scene | HIGH (milestone gate) | LOW | **P1** |
| README upgrade paragraph | MEDIUM (migration UX) | LOW | **P1** |
| Per-paint random variation toggle | LOW (default determinism wins 95%) | LOW | **P2** |
| Editor warnings for malformed metadata | LOW (author can debug) | MEDIUM | **P3** |
| TetraBake / converter / transitions / etc. | — | — | **Out-of-scope** (PROJECT.md) |

**Priority key:**
- P1: Must have for v0.2.0
- P2: Add when easy
- P3: Defer

## Competitor Feature Analysis

| Feature | TileMapDual (pablogila) | Better Terrain (Portponky) | Stock Godot Terrain | TetraTile v0.2 |
|---------|------------------------|----------------------------|---------------------|----------------|
| **Variation / alt tiles** | "Currently does not support alternative tiles" (quoted from README) | Inspector toolbar "option to control the level of randomization used" | Multiple tiles per peering combo + `TileData.probability`; non-deterministic RNG | **Reuse `TileData.probability`, deterministic per-coord by default** |
| **Top-tile / directional** | Not documented; relies on rotational symmetry | Not documented; relies on peering bits to encode directionality (heavyweight) | Encoded via peering bits (heavyweight) | **`tetra_role` custom_data_layer with directional values** (e.g. `border_top`) |
| **Non-rotating tilesets** | "All the different tile shapes, layouts, and offset axes" — but rotation is implicit in the dual-grid mask interpretation | Implicit in peering rules | Implicit in peering rules | **Per-tile `tetra_lock_rotation` custom_data_layer**; specific roles override generic ones |
| **Multi-terrain transitions** | Yes — *terrain peering bits and terrain rules* | Yes — *Match Tiles, Match Vertices, Category, Decoration* | Yes — *peering bits* | **No — explicit anti-feature** |
| **Drawing API** | `draw_cell(cell, terrain)`, `fill_tile`, `erase_tile` (custom helpers atop native) | `BetterTerrain.set_cell()` autoload + `update_terrain_cell()` etc. | `set_cells_terrain_connect()`, `set_cells_terrain_path()` | **Native `TileMapLayer.set_cell()` only** |
| **Persistent state / cache** | Yes (Set/Util classes; queued for refactor per their issue #72) | Implicit in autoload | Implicit in engine | **No — explicit anti-feature** |
| **Editor dock / custom inspector** | Yes (real-time terrain config feedback) | Yes (full dock with pen/line/rect/fill/select) | Engine-built TileSet editor | **No — native inspector + TileSet custom data only** |
| **Migration on breaking change** | Not documented; releases page is empty | Not documented | Engine 3→4 migration was famously broken (issue #71188) | **README paragraph + automatic v0.1-shape detection** |
| **Public node count** | `TileMapDual` plus supporting addon classes (per TetraTile README's own comparison table) | `BetterTerrain` autoload + dock | N/A | **Single `TetraTileMapLayer`** |
| **Lines of code** | Much larger; multiple classes including legacy code branches (per their issue #70) | ~few thousand LOC | engine | **261 LOC v0.1; expected modest growth** |

## Sources

### Direct competitor inventory (HIGH confidence — primary source quotes)
- [TileMapDual GitHub](https://github.com/pablogila/TileMapDual) — quoted features list
- [TileMapDual README](https://github.com/pablogila/TileMapDual/blob/main/README.md) — verified quote: "It currently does not support alternative tiles"
- [TileMapDual Releases](https://github.com/pablogila/TileMapDual/releases) — verified empty (no migration documentation)
- [TileMapDual Issues](https://github.com/pablogila/TileMapDual/issues) — verified no open feature requests for variation/top tiles/non-rotating
- [TileMapDual Usage Guide (DeepWiki)](https://deepwiki.com/pablogila/TileMapDual/3-usage-guide) — runtime API surface
- [Better Terrain GitHub](https://github.com/Portponky/better-terrain) — feature inventory, runtime API method signatures
- [Better Terrain Asset Library entry](https://godotassetlibrary.com/asset/HiwFMr/better-terrain) — confirmation of decoration / category / match-tiles / match-vertices terrain types
- [5-Tile Dual-Grid AutoTiler Asset Library](https://godotengine.org/asset-library/asset/4183) — `AutoMapLayer` + `ShuffleMapLayer` two-class design with full randomization support
- [jess-hammer dual-grid-tilemap-system-godot](https://github.com/jess-hammer/dual-grid-tilemap-system-godot) — 16-rule hardcoded reference implementation in C#

### Authoring UX patterns for non-rotating / directional tiles (MEDIUM confidence — adjacent ecosystem)
- [Tilesetter documentation: Generating Tilesets](https://www.tilesetter.org/docs/generating_tilesets) — verified quote on per-edge "Sources" property: *"by selecting a border tile in the set, you can choose through the Tile Properties View which Sources to use for edge orientations present in that tile"*
- [BorisTheBrave: Classification of Tilesets](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) — formal taxonomy for non-rotating ("R" omitted) vs rotating ("R" included) tilesets
- [Excalibur.js: Dual Tilemap Autotiling Technique](https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/) — confirms dual-grid 5-tile rotational basis; silent on asymmetric handling

### Godot native variation API (HIGH confidence — Context7 against godot-docs)
- [Godot Engine docs (Context7 `/godotengine/godot-docs`)](https://github.com/godotengine/godot-docs) — verified `TileData.probability` is `float`, default `1.0`, with `set_probability()` / `get_probability()`
- [TileSetAtlasSource class docs](https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html) — `create_alternative_tile()` semantics; alternative ID 0 = base tile
- [Using TileSets tutorial](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html) — verified quote on alternative-tile UX: *"Alternative tiles allow you to use a single tile image found only once within the atlas, but configured in different ways"*; verified that flips/transpose live on alt-tiles
- [Tiles editor progress report #4](https://godotengine.org/article/tiles-editor-progress-4/) — confirms `probability` property and "scatter" tool in editor UX

### Engine-side variation determinism (HIGH confidence)
- [Proposal #10948: deterministic terrain randomization](https://github.com/godotengine/godot-proposals/discussions/10948) — confirms engine RNG for `set_cells_terrain_connect()` is non-deterministic; community workaround is `seed()` before the call
- [Proposal #7670: Refactor Terrain Tile Matching for Accuracy and Determinism](https://github.com/godotengine/godot-proposals/issues/7670) — broader discussion of determinism gaps in terrain matching

### Migration UX prior art (HIGH confidence)
- [Godot issue #71188: Tilemap creates hundreds of tiles in Godot 4 migration](https://github.com/godotengine/godot/issues/71188) — engine's own 3→4 tilemap migration was broken; cautionary tale
- [Godot issue #75272: Atlas merging tool does not work](https://github.com/godotengine/godot/issues/75272) — engine's own conversion tooling has had reliability issues

### Platformer top-tile pattern (MEDIUM confidence — implicit in tooling rather than explicit pattern names)
- [Tilesetter documentation: Generating Tilesets](https://www.tilesetter.org/docs/generating_tilesets) — top/bottom/left/right Sources per tile (clearest existing pattern)
- [Mapledev: How to Design a Platformer Tileset](https://mapledev.tumblr.com/post/10406905135/howtotileset) — informal description of platformer tile-grid layout with top-row caps

---
*Feature research for: Godot 4 dual-grid autotiling addon (TetraTile v0.2 expansion)*
*Researched: 2026-04-25*
