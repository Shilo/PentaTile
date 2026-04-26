# Review of `ffe876d` — "purge remaining v0.1 stale references after audit"

**Verdict:** ✅ Approved. High-quality audit, no issues found.

## What it does

Closes the gap my `0532b68` doc-sync left open. My commit only touched the 3 most-obvious live docs (STATE, ROADMAP, CHANGELOG); this audit caught **17 files** I missed:

| Category | Files | Treatment |
|----------|-------|-----------|
| **Live docs** (rewritten in place) | README.md, CLAUDE.md, .planning/PROJECT.md, .planning/REQUIREMENTS.md, .planning/STATE.md, .planning/ROADMAP.md, CHANGELOG.md, addons/penta_tile/_generate_bitmasks.py | Stale references replaced with current truth |
| **Historical snapshots** (banner-stamped) | .planning/codebase/{ARCHITECTURE,CONCERNS,CONVENTIONS,INTEGRATIONS,STACK,STRUCTURE,TESTING}.md, IMPLEMENTATION_PLAN.md, RESEARCH.md | HISTORICAL banner explaining why each is stale + pointer to canonical source |
| **Phase artifacts** (intentionally untouched) | All `.planning/phases/*` PLAN/SUMMARY/CONTEXT/VERIFICATION docs | Point-in-time records, correctly preserved |

## What I checked

### 1. Commit hash references in REQUIREMENTS.md (8 cited; all resolve)

| Cited | Resolves | What it actually shipped |
|-------|----------|--------------------------|
| `595f0f8` | ✓ | docs(02-01): migrate Phase 1 verification suite — matches LAYER-05 claim |
| `cb6d253` | ✓ | refactor(02-01): rename template_image→bitmask_template — matches LAYOUT-03/04 claim |
| `b6349fa` | ✓ | feat(02-02): atomic sweep — _DEFAULT_LAYOUT cleanup + contract delete + demo rebind — matches LAYER-02/04 claims |
| `e8e114a` | ✓ | feat(02-02): build PentaTileSynthesis — matches PENTA-SYNTH-01 claim |
| `91f69a2` | ✓ | feat(02-04): ship 4 native single-variant layouts — matches NATIVE-01..03 + MIN3x3-01 claims |
| `e17512e` | ✓ | feat(02-05): migrate template PNGs to co-located layouts/ — matches TEMPLATE-04 claim |
| `ae5d787` | ✓ | fix(02): WR-01 use canonical Sutherland-Hodgman — matches PENTA-SYNTH-07 claim |
| `673ace0` | ✓ | test(02): VERTICAL baseline — matches PENTA-03 claim |

### 2. Spot-checks on key claims

- **README.md "Why PentaTile?"** — correctly drops the "just four tiles" framing for the "1–5 progressive" framing. The comparison table row for "Tile requirement" now reads "1–5 tiles per Penta layout (or the layout's native count: 9, 16, 47…)" which is accurate across the full v0.2 layout family.
- **CLAUDE.md Layout tree** — matches actual addon shape on disk (`layouts/`, `tests/`, `penta_tile_synthesis.gd`, `penta_tile_atlas_slot.gd`, `_generate_bitmasks.py`). Verified.
- **CLAUDE.md Pitfall #4** — correctly updates `if value == _atlas_contract: return` to `if value == layout: return`. The actual setter at [penta_tile_map_layer.gd:25-31](addons/penta_tile/penta_tile_map_layer.gd#L25-L31) uses this exact pattern.
- **STATE.md Blockers reorganization** — Active vs Resolved split is the right shape. The 5 items moved to Resolved (demo rebind, P1 verification migration, ONE-mode anchoring, collision-polygon math, _DEFAULT_LAYOUT cleanup) all match work that actually shipped in Phase 2 commits.
- **ROADMAP.md Phase 4/5** — correctly retargeted from `atlas_contract.layout` / `fallback_tile_set` @export to `layout` / `get_fallback_tile_set()` codegen. Phase 5 CHANGELOG criterion now lists the actual breaking changes.
- **CHANGELOG.md v0.1.0 entry** — the line crediting `PentaTileAtlasContract` to v0.1.0 was indeed wrong (the contract was Phase 1 work toward v0.2.0; never released as TetraTile). Correctly removed.

### 3. Patterns I'd call out as well-done

- **Strike-through + "Superseded" pointer** in PROJECT.md and STATE.md is the right move — preserves audit trail vs deleting outright.
- **HISTORICAL banner pattern** for the v0.1 snapshots (`.planning/codebase/*`, `IMPLEMENTATION_PLAN.md`, `RESEARCH.md`) — each banner explains *why* it's stale AND points to the canonical current source. Avoids the trap of leaving stale docs to silently confuse future-you.
- **"(v0.1.0 baseline)" suffix on Analysis Date** — clever defense against date-misreading. The original date stamp would otherwise look like "current as of today."
- **30 REQUIREMENTS.md flips with one-line evidence** — every Pending→Complete flip is anchored to a wave number AND/OR commit hash. Future audits can verify each claim cheaply.

## Anything to fix?

**No.** Every change I checked is correct, well-motivated, and follows GSD discipline. The audit is more thorough than my initial doc-sync was — that's exactly the kind of "trust but verify" pass that catches real drift.

## Process observation

My `0532b68` reflexively touched only the docs I knew about (STATE/ROADMAP/CHANGELOG). The actual stale-reference surface was **5.7× wider** (17 files vs 3). For future post-Phase doc-sync work, the right pattern is:

```bash
git grep -lE "(PentaTileAtlasContract|atlas_contract|template_image|_overlay_layer|fallback_tile_set|_DEFAULT_LAYOUT|PentaTileLayoutPenta(Horizontal|Vertical))" \
  -- "*.md" "*.py" "*.gd" \
  | grep -v "^\.planning/phases/"
```

That grep would have surfaced all 17 files in this audit + the snapshot docs. Adding to mental checklist for the Phase 5 docs-update pass.

## Commits this thread

- `aa07ac1` — third-pass review report
- `c9a6aa9` — IN-11/12/13 fixes
- `0532b68` — initial doc-sync (incomplete; corrected by ffe876d)
- `ffe876d` — **user audit-purge of stale v0.1 references (this commit)**

## Next

No code changes recommended. Phase 2 is still gated on `/gsd-verify-work 2` for visual UAT, then "approved" to flip ROADMAP `[ ]` → `[x]`.
