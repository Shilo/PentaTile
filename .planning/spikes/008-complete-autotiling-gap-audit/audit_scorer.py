"""Spike 008: Complete Autotiling Gap Audit — Scoring Engine

Usage:
  python audit_scorer.py          # prints scored matrix
  python audit_scorer.py --json   # outputs JSON report
"""

import json
import sys

# ── Feature Definition ───────────────────────────────────────────────────────

FEATURES = [
    # (id, name, completeness, demand, risk, scope, note)
    ("multiterrain", "Multi-terrain dispatch", 0, 5, 3, "v0.3", "Spike 006 design; atlas_coords.y encoding"),
    ("variation", "Deterministic variation", 0, 5, 2, "v0.3", "PITFALLS §2 recipe; TileData.probability"),
    ("editorpreview", "Editor tool preview (line/rect)", 0, 4, 3, "v0.3", "Ghost material approach; ~30 LOC"),
    ("passthrough", "Atlas passthrough", 0, 3, 1, "v0.3", "Source-ID gating; spike 004"),
    ("slope", "Slope layout", 0, 3, 3, "v0.3", "Spike 005 design; 8-tile atlas"),
    ("decoder", "Mask decoder (template→slot)", 0, 3, 2, "v0.3", "GDScript port of spikes 001-003"),
    ("sourceid", "source_id on AtlasSlot", 0, 3, 1, "v0.3", "Schema addition; non-breaking"),
    ("terrainmode", "terrain_mode() virtual", 0, 3, 3, "v0.3", "Layout→Godot TerrainMode mapping; spike 007"),
    ("stripindex", "compute_mask(strip_index)", 0, 3, 2, "v0.3", "Multi-terrain mask compute; spike 006"),
    ("batchapi", "set_cells() batch method", 0, 2, 2, "v0.4", "Procedural gen optimization"),
    ("tilesetter", "Tilesetter Wang15 + Blob47", 0, 3, 3, "v0.4", "Deferred D-86; primary source TBD"),
    ("precedence", "Precedence groups", 0, 3, 4, "v0.4", "Multi-layer visual output; spike 004"),
    ("toptiles", "Top-tile support", 0, 4, 3, "v2", "Explicit per-mask; platformer caps"),
    ("rpgmaker", "RPG Maker A2/A4 subtile compositor", 0, 2, 5, "v2", "Quarter-tile pipeline; v0.3+ importer"),
    ("perfshader", "Shader fallback (diagonal compositing)", 0, 1, 4, "v2", "Premature without benchmarks"),
    ("collisiontool", "Collision authoring tools", 0, 1, 4, "v2", "TileSet physics is sufficient"),
]


ANTI_FEATURES = [
    ("terrain_solver", "Godot terrain solver delegation", "Non-deterministic; breaks mask contract; MULTITERR-07"),
    ("coord_cache", "Persistent coordinate cache", "Demo-scale doesn't need it; adds lifecycle bugs"),
    ("signal_fanout", "Watcher/signal-fanout systems", "Signal storm risk; identity guardrail"),
    ("custom_paint", "Custom paint API (parallel to set_cell)", "Defeats native-API win"),
    ("inspector_plugin", "EditorInspectorPlugin polish", "3800 LOC for TileBitTools; identity guardrail"),
    ("hex_iso", "Hex/iso grid support", "Identity expansion beyond scope"),
]


SHIPPED = [
    ("DualGrid16", "16-tile dual-grid corner mask"),
    ("Wang2Edge", "16-tile single-grid edge mask"),
    ("Wang2Corner", "16-tile single-grid corner-diagonal mask"),
    ("Min3x3", "9-tile open-side collapse edge mask"),
    ("Penta (ONE→FIVE)", "5-mode load-time synthesis"),
    ("Blob47Godot", "47-tile 8-bit Moore collapse"),
    ("PixelLabTopDown", "8×8 atlas corner mask"),
    ("PixelLabSideScroller", "8×8 atlas corner mask (side variant)"),
    ("Fallback TileSet", "Auto-generated from bitmask_template"),
    ("AUTO/AUTO_STRIP", "Dimension-only + per-strip detection"),
    ("Synthesis caching", "Signature-based idempotent rebuild"),
    ("Configuration warnings", "Inspector feedback on atlas issues"),
]


def score(completeness: int, demand: int, risk: int) -> float:
    """Priority score: higher = more urgent.
    completeness_gap = 5 - completeness (lower completeness = higher priority)
    risk_penalty = risk (higher risk = lower priority)
    """
    gap = 5 - completeness
    return (gap * 0.3) + (demand * 0.4) + ((5 - risk) * 0.3)


def generate_matrix():
    """Generate the full scored feature matrix."""
    rows = []
    for fid, name, completeness, demand, risk, scope, note in FEATURES:
        priority = score(completeness, demand, risk)
        rows.append({
            "id": fid,
            "name": name,
            "completeness": completeness,
            "demand": demand,
            "risk": risk,
            "scope": scope,
            "priority": round(priority, 1),
            "note": note,
        })
    
    # Sort by priority descending
    rows.sort(key=lambda r: r["priority"], reverse=True)
    
    return rows


def generate_phase_recommendations(rows):
    """Group recommendations by phase."""
    phases = {}
    for r in rows:
        scope = r["scope"]
        phases.setdefault(scope, []).append(r)
    return phases


def main():
    rows = generate_matrix()
    phases = generate_phase_recommendations(rows)
    
    print("=" * 80)
    print("  PentaTile Complete Autotiling Gap Audit")
    print("=" * 80)
    
    print("\n── SHIPPED (v0.2.0) ──")
    for name, desc in SHIPPED:
        print(f"  ✓ {name}: {desc}")
    
    print("\n── GAPS (ordered by priority) ──")
    print(f"  {'ID':<20} {'Prio':>5} {'Comp':>5} {'Dem':>4} {'Risk':>4}  {'Scope':<8}")
    print(f"  {'─'*20} {'─'*5} {'─'*5} {'─'*4} {'─'*4}  {'─'*8}")
    
    for r in rows:
        bar = "█" * int(r["priority"]) + "░" * (10 - int(r["priority"]))
        print(f"  {r['id']:<20} {r['priority']:>4.1f}  {bar:<10} {r['completeness']:>4} {r['demand']:>4} {r['risk']:>4}  {r['scope']:<8}")
    
    print("\n── PHASE RECOMMENDATIONS ──")
    for phase in ["v0.3", "v0.4", "v2"]:
        if phase in phases:
            loc_total = 0
            print(f"\n  {phase}:")
            for r in phases[phase]:
                loce = {  # rough LOC estimates
                    "multiterrain": 80, "variation": 120, "editorpreview": 30,
                    "passthrough": 90, "slope": 55, "decoder": 200,
                    "sourceid": 50, "terrainmode": 30, "stripindex": 40,
                    "batchapi": 80, "tilesetter": 300, "precedence": 150,
                    "toptiles": 200, "rpgmaker": 400, "perfshader": 200,
                    "collisiontool": 150,
                }.get(r["id"], 100)
                loc_total += loce
                print(f"    {r['id']:<20} +{loce:>4} LOC  prio={r['priority']}")
            
            print(f"    {'─'*37}")
            print(f"    {'Total':<20} +{loc_total:>4} LOC")
    
    print("\n── ANTI-FEATURES (deliberately excluded) ──")
    for fid, name, reason in ANTI_FEATURES:
        print(f"  ✗ {fid}: {name}")
        print(f"      {reason}")
    
    print("\n── RECOMMENDED /gsd COMMANDS ──")
    print("  /gsd-add-phase \"Multi-Terrain + Variation Implementation\"   # v0.3")
    print("  /gsd-add-phase \"VirtuMap Integration Bridge\"               # v0.3")
    print("  /gsd-add-todo \"source_id on PentaTileAtlasSlot (Phase 10 schema)\"")
    print("  /gsd-add-todo \"terrain_mode() virtual on PentaTileLayout base\"")
    print("  /gsd-add-todo \"compute_mask(strip_index) signature extension\"")
    print("  /gsd-add-todo \"GDScript port of spike 001-003 mask decoder (v0.4)\"")
    print("  /gsd-plan-phase 9  # incorporate spike 006+007 findings")
    
    if "--json" in sys.argv:
        import os
        os.makedirs("out", exist_ok=True)
        report = {
            "spike": "008",
            "verdict": "VALIDATED",
            "shipped_count": len(SHIPPED),
            "gaps_count": len(FEATURES),
            "anti_features_count": len(ANTI_FEATURES),
            "v0_3_loc_total": sum(
                0 for r in rows if r["scope"] == "v0.3"
            ),
            "features": rows,
            "shipped": [{"name": n, "desc": d} for n, d in SHIPPED],
            "anti_features": [{"id": fid, "name": n, "reason": r} for fid, n, r in ANTI_FEATURES],
        }
        with open("out/audit_report.json", "w") as f:
            json.dump(report, f, indent=2)
        print("\n  Report written to out/audit_report.json")


if __name__ == "__main__":
    main()
