# Phase 5: Demo Refresh + Documentation + Release - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `05-CONTEXT.md` — this log preserves the alternatives considered and the reasoning behind each pick.

**Date:** 2026-04-29
**Phase:** 05-demo-refresh-documentation-release
**Areas discussed:** Demo refresh strategy, LOC + identity audit methodology, Release packaging mechanics
**Areas deferred to Claude's discretion:** Documentation surface + tone

---

## Demo refresh strategy

### Q1 — How should ONE demo scene showcase all 8 actually-shipped layouts?

| Option | Description | Selected |
|--------|-------------|----------|
| Side-by-side spatial grid (Recommended) | 8 PentaTileMapLayer instances arranged spatially in penta_tile_demo.tscn, labeled, drag-paint targets the hovered instance. Eyeball quality bar holds. | ✓ |
| Runtime-switch dropdown UI | Single PentaTileMapLayer with Control overlay (dropdown / number key 1-8) to swap layout at runtime. Simpler scene, one paint target, but no side-by-side comparison. | |
| Side-by-side + per-tile click-to-swap | Spatial grid AND each instance has click-to-cycle-layout affordance. Hybrid; more glue, dual interaction modes. | |

**User's choice:** Side-by-side spatial grid (Recommended).
**Notes:** Locks D-05-01.

### Q2 — What TileSet does each of the 8 instances use (proves DEMO-02)?

| Option | Description | Selected |
|--------|-------------|----------|
| All 8 use bundled fallback only (Recommended) | Every PentaTileMapLayer has tile_set = null, layout = bundled .tres. DEMO-02 satisfied 8-of-8. ground.tres + ground.png + _regen_demo_ground.py retired. | ✓ |
| Penta uses authored ground.tres + 7 others use fallback | Player has polished surface to land on; DEMO-02 satisfied 7-of-8. | |
| All 8 fallback + Penta sibling authored variant | Two Penta instances side-by-side as 'before/after authoring' comparison. | |

**User's choice:** All 8 use bundled fallback only (Recommended).
**Notes:** Locks D-05-02. Reopened later by Q5 (Penta floor) due to fallback's zero-physics-layers constraint.

### Q3 — Where does the CharacterBody2D player spawn given a side-by-side layout?

| Option | Description | Selected |
|--------|-------------|----------|
| On the Penta instance (Recommended) | Player spawns on Penta block. If Penta uses bundled fallback, generated_collision_enabled provides physics. Other instances visual-only. | ✓ (later overridden) |
| Player spawns on whichever instance is clicked first | Adaptive teleport-to-clicked-instance. More glue; teleport feels gimmicky. | |
| No player; demo is paint-only | Drop CharacterBody2D entirely. Simpler scene; loses 'platformer with autotiling ground' v0.1 feel. | |

**User's choice:** On the Penta instance (Recommended) — **OVERRIDDEN** by Q5 ("Drop the player entirely") once it became clear the bundled fallback ships zero physics layers.
**Notes:** D-05-03 in CONTEXT.md captures the FINAL state (no player), with the override traced to Q5.

### Q4 — How do we preserve the determinism baseline (BASELINE_HASH=2986698704) when refreshing the demo?

| Option | Description | Selected |
|--------|-------------|----------|
| Demo SCENE refresh is safe — baseline targets .tres only (Recommended) | determinism_test.gd / _capture_baseline.gd reference penta_layout_four_horizontal.tres via --layout-path CLI flag, NOT the demo scene. Refresh penta_tile_demo.tscn freely as long as demo/penta_layout_*.tres files keep existing. Plan-phase verifies via grep. | ✓ |
| Pin the old scene as penta_tile_baseline.tscn for tests; new demo at penta_tile_demo.tscn | Defensive split. Doubles scene count, fully insulates baseline. | |

**User's choice:** Demo SCENE refresh is safe (Recommended).
**Notes:** Locks D-05-04. Plan-phase greps test scripts to confirm the assumption holds; flips to defensive split only on hidden coupling.

### Q5 — How does the player stand on the Penta block when bundled fallback ships no collision polygons?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep penta_tile_ground.tres on Penta block; other 7 use fallback (Recommended) | DEMO-02 partial 7-of-8; Penta has polished art + collision; ground.tres + assets retained. | |
| All 8 use fallback + scene-level invisible StaticBody2D floor | Hidden full-width floor catches player; DEMO-02 satisfied 8-of-8 cleanly; loses 'autotile-generates-collision' demo. | |
| All 8 use fallback + drop the player entirely | Demo becomes paint-only. demo_player.gd retired; CharacterBody2D removed. Simplest; pure layout showcase. | ✓ |

**User's choice:** All 8 use fallback + drop the player entirely.
**Notes:** Final D-05-02 + D-05-03 lock. Surfaced after I checked `get_fallback_tile_set()` and confirmed it ships zero physics layers — Q2 + Q3 jointly produced "player falls through floor" before this question reopened the trade-off. User chose to drop the player rather than weaken DEMO-02.

---

## LOC + identity audit methodology

### Q1 — What does the audit actually measure?

| Option | Description | Selected |
|--------|-------------|----------|
| All three: LOC + public surface + hot-path complexity (Recommended) | Three axes per the framework. Identity is more than raw LOC. Each axis reports a number/observation. | ✓ |
| Pure runtime LOC only | Single-number hard pass/fail. Cleaner audit but less defensible if PentaTile loses on raw LOC but is genuinely simpler architecturally. | |
| Hot-path + qualitative anti-pattern register only — no LOC number | Skip LOC entirely. Audit = anti-pattern checklist. Concedes LOC battle. | |

**User's choice:** All three (Recommended).
**Notes:** Locks D-05-08. Rebalanced later by Q4 reframing — LOC is reported as DATA not VERDICT.

### Q2 — How is TileMapDual measured for the comparison?

| Option | Description | Selected |
|--------|-------------|----------|
| Pin a recent TileMapDual tag, clone, run identical methodology (Recommended) | git clone at latest stable tag. Run wc -l on equivalent runtime files. Document pinned tag + commit hash for reproducibility. | ✓ |
| Use TileMapDual's documented stats from their README/release notes | Trusts their claim; methodology may not match. | |
| Skip the number comparison; rely on qualitative anti-pattern checklist only | Cheaper; pairs with audit-axes option C. | |

**User's choice:** Pinned-tag clone (Recommended).
**Notes:** Locks D-05-09.

### Q3 — Where do the audit results live in the published v0.2.0?

| Option | Description | Selected |
|--------|-------------|----------|
| README "Identity & Footprint" section + release notes summary linking to it (Recommended) | Single source of truth in README; release notes summarize and link. CHANGELOG out (different concern). | ✓ |
| Standalone `addons/penta_tile/AUDIT.md` (or repo-root `IDENTITY.md`) | Separate dedicated file; one more doc to discover. | |
| Release notes only — no permanent README section | Audit is release-time concern only. README unchanged. | |
| All three: AUDIT.md + README section + release notes | Most thorough; most maintenance. | |

**User's choice:** README + release notes (Recommended).
**Notes:** Locks D-05-10.

### Q4 — What's the action if the audit verdict is FAIL?

| Option | Description | Selected |
|--------|-------------|----------|
| Decide at audit time; document the call in 05-LOC-AUDIT.md (Recommended) | Two-axis fail → trim. One-axis fail → ship with rationale. Plan-phase pre-allocates contingency 05-TRIM-PASS plan. | |
| Hard gate: trim before ship regardless | Conservative; risks cosmetic-only deletions. | |
| Soft gate: always ship; document gap, fix in v0.3+ | Pragmatic; concedes guardrail may not pass. | |

**User's choice (free text):** "I don't understand why we are auditing the LOC. only thing that absolutely matters is performance and optimization. LOC is an irrelevant number when it comes to runtime. But if LOC is large combined with non-optimization, then we should think about extracting into reusable code along with optimizing overhead"

**Reflection / lock:** This was the meaningful reframe of the entire audit. LOC is a SIGNAL, not a GOAL. Performance and optimization are what matter. Audit fail criterion = LOC large AND identifiable inefficiencies / duplications. Action = extract reusable helpers + optimize hot path; cosmetic deletion explicitly disallowed. README "Identity & Footprint" frames identity as hot-path minimalism + anti-pattern absence, not LOC delta. Planner authorized to propose PROJECT.md / ROADMAP.md SC-7 wording corrections.

**Notes:** Locks D-05-11 (the new framing) + D-05-12 (spec-correction authorization).

---

## Release packaging mechanics

### Q1 — How is the v0.2.0 release zip built?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual git archive command, documented in plan-phase artifact (Recommended) | One-time job. Plan-phase 05-RELEASE-RUNBOOK.md captures exact command. YAGNI on a build script. | |
| Scripted helper at repo root (build_release.ps1 or .sh) | Reusable; adds maintenance surface. | |
| GitHub Actions workflow that auto-builds on tag push | Most automated. Tag push → CI builds + uploads + creates Release. | ✓ (later expanded) |

**User's choice:** GitHub Actions workflow (NOT recommended).
**Notes:** First flag of the user's "automate everything" preference; locked initial direction. Later refined to "manually triggered (workflow_dispatch) instead of tag-triggered" via free-text follow-up.

### Q2 — What's the pre-flight checklist before tagging v0.2.0?

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive: tests + plugin.cfg + LOC audit + fresh-Godot smoke + manual eyeball (Recommended) | Seven items; ticked in 05-RELEASE-RUNBOOK.md. | ✓ (later trimmed) |
| Minimal: tests + plugin.cfg version + demo loads | Faster; risks shipping with stale README. | |
| Skip pre-flight; trust the green test suite + plan completion | Aggressive; risks REL-03 SC-6 unverified. | |

**User's choice:** Comprehensive (Recommended).
**Notes:** Subsequently TRIMMED by the "remove anything not automatic" follow-up: manual eyeball pass DROPPED, LOC audit moved out of CI to manual-only. Final CI checks per D-05-14: tests + headless project import + headless demo open. No LOC audit in CI; no manual eyeball.

### Q3 — How are the tag, push, and GitHub Release created?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual git CLI + gh CLI sequence, scripted as one shell session (Recommended) | git tag + git push + gh release create with --notes-file. | ✓ (later superseded) |
| Use GitHub UI for the release (manual upload + paste notes) | Browser flow; not reproducible. | |
| Custom release script (release.ps1 / .sh) wrapping git + gh CLI | Reusable wrapper; YAGNI. | |

**User's choice:** Manual git CLI + gh CLI (Recommended).
**Notes:** Superseded by Q1's later refinement (workflow_dispatch single-button release). No manual gh release create; the workflow does it.

### Q4 — What goes into the GitHub Release notes body?

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: hand-written 5-7 line highlight intro + CHANGELOG v0.2.0 paste below (Recommended) | Top: 'what shipped' + 'identity verdict' linking README. Bottom: CHANGELOG verbatim. | |
| CHANGELOG v0.2.0 paste verbatim, no intro | Cleanest single source of truth. | ✓ |
| Hand-written highlights only + link to CHANGELOG | Lightest; forces clicks for breaking-changes detail. | |

**User's choice:** CHANGELOG paste verbatim, no intro.
**Notes:** Locks D-05-18. Aligns with "no manual" framing — CHANGELOG slice extraction is mechanical.

### Q5 (clarifier) — What does the GitHub Actions workflow do, and what stays manual?

| Option | Description | Selected |
|--------|-------------|----------|
| Actions auto-builds zip + auto-creates Release; user only does git tag + push (Recommended) | softprops/action-gh-release@v2 or gh release create inside Actions. User flow: git tag + git push. | ✓ (later refined) |
| Actions only builds zip artifact; user manually runs gh release create | Two-step: Actions builds, human releases. More manual control. | |
| Actions does NOTHING; user runs build + tag + release manually | Drop the workflow; revert to Q1 manual. | |

**User's choice:** Actions auto-builds + auto-creates (Recommended) — refined further by free-text follow-up to: **manually triggered workflow that does commit + tag + release** (NOT tag-triggered).

### Q6 (clarifier) — When the manually-triggered Action commits/tags/releases, what does the COMMIT step cover?

| Option | Description | Selected |
|--------|-------------|----------|
| plugin.cfg version bump + CHANGELOG header rewrite ([Unreleased] → [0.2.0] — date) (Recommended) | User stages everything else; clicks Run Workflow with version input; workflow does plugin.cfg bump + CHANGELOG rewrite + commit + tag + push + zip + release. | |
| plugin.cfg version bump only | CHANGELOG rewrite stays manual. | |
| Just tag + release, no auto-commits | User commits everything manually. | |
| Full bump suite: plugin.cfg + CHANGELOG + README 'Identity & Footprint' summary line | Auto-stamps audit verdict line; needs machine-readable audit. | |

**User's choice (free text):** "Recommended, but it should require nothing manual. everything should be automatic. if there is something that cant be automatic, just remove it"

**Reflection / lock:** Hard rule established. Workflow handles everything programmatic; ANY step that requires manual user action other than clicking "Run workflow" is dropped. Manual eyeball pass dropped (Q2 retroactive). LOC audit stays manual but moves OUT of CI gate (Q7 follow-up). Workflow steps per D-05-17.

### Q7 (clarifier — unprompted user follow-up) — Auto-version-increment rule

**User's free-text instruction:** "and when tagging, it should increement the version with minor version +1, and if its past 9, it increment major version +1"

**Reflection / lock:** Locks D-05-16 (auto-version rule). No `workflow_dispatch.inputs.version` field. Workflow reads current plugin.cfg version, computes next: minor +1 by default; if next minor would exceed 9, bump major +1 and reset minor to 0. Patch stays 0. Examples: 0.1.0 → 0.2.0 → 0.3.0 → ... → 0.9.0 → 1.0.0. Patch-level releases not supported by the workflow per D-05-16; bypass for hand-rolled patches.

### Q8 (final clarifier) — What automated checks must pass before the workflow proceeds?

| Option | Description | Selected |
|--------|-------------|----------|
| Tests + headless demo open + LOC audit committed (Recommended) | All three checks. Aligns with 'remove anything not automatic'. | ✓ (with LOC audit dropped) |
| Tests only | Skip demo-open + LOC-audit checks. | |
| No CI checks; trust the developer | Workflow just bumps + tags + releases. | |

**User's choice (free text):** "Recommended, but I dont want a LOC audit, that should be a manual check only. LOC is not a measure of quality of code"

**Reflection / lock:** Locks D-05-13 + D-05-14. CI checks = tests + headless project import + headless demo open. NO LOC audit in CI. LOC is not a quality measure. Audit is a manual prerequisite the developer runs before clicking "Run workflow"; not a CI gate. Reinforces D-05-11 framing.

---

## Documentation surface + tone (Claude's Discretion)

This area was offered for discussion but the user did not select it. Falls to Claude's discretion in plan-phase per the deferred-ideas section of CONTEXT.md.

Default approach: extend the existing README in its current style; convert CHANGELOG `[Unreleased]` to `[<new-version>] — <date>` mechanically (the workflow handles this automatically per D-05-17 step 4); keep DOC-03 ("Authoring a Custom Layout") at API-tour depth with one minimal subclass example marked `@experimental` per the Phase 4 doc-comment sweep.

---

## Deferred Ideas (during this session)

- Patch-version releases (v0.2.1 etc.) — D-05-16 explicitly does not support; if needed, bypass workflow.
- GitHub Actions input field for explicit version override — superseded by D-05-16 auto-increment.
- Per-layout sub-scene demos / runtime layout-switching dropdown — superseded by D-05-01 spatial grid.
- Penta-uses-authored-ground.tres / scene-level-invisible-floor — superseded by D-05-03 (no player).
- Standalone AUDIT.md / IDENTITY.md — superseded by D-05-10 (README + release notes).
- Manual eyeball pass on 8 layouts in CI — DROPPED per "remove anything not automatic" rule.
- LOC audit existence check in CI — DROPPED per "LOC is not a quality measure" position.
- Hand-written release notes intro / highlight reel — superseded by D-05-18 (CHANGELOG paste verbatim).
- Build script (build_release.sh / .ps1) at repo root — superseded by GitHub Actions workflow.
