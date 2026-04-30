# Spike 004: VirtuMap Integration — Gap Analysis Script
# Quantifies the gap between VirtuMap's terrain API and PentaTile's layout dispatch.

import json
import sys
from typing import Dict, List, Optional, Tuple

# ── VirtuMap terrain constants (from virtumap_render_constants.gd) ──────────

TERRAIN_SETS = {
    0: {"name": "FLOOR", "role": "structure", "cells_type": "atlas_cells"},
    1: {"name": "WALL", "role": "structure", "cells_type": "terrain_cells"},
    2: {"name": "HULL", "role": "structure", "cells_type": "terrain_cells"},
    3: {"name": "SLOPE", "role": "structure", "cells_type": "terrain_cells"},
    4: {"name": "PLATFORM", "role": "structure", "cells_type": "terrain_cells"},
    5: {"name": "BEAM", "role": "structure", "cells_type": "terrain_cells"},
}

CANONICAL_LAYERS = [
    {"id": "BackgroundLayer", "role": "background"},
    {"id": "StructureLayer", "role": "structure"},
    {"id": "FixtureLayer", "role": "fixture"},
    {"id": "OverlayLayer", "role": "overlay"},
]

# ── PentaTile capability matrix ─────────────────────────────────────────────

PENTATILE_CAPABILITIES = {
    "multi_strip": {
        "v0_2_0": "AUTO_STRIP per-strip detection in PentaTileLayoutPenta. Per-strip independent dispatch via resolve_display_strip().",
        "gap": "No terrain-ID injection mechanism. Strips detected from atlas content, not from set_cell() input.",
        "needed": "Parameterize strip_index from the logic cell's atlas_coords.y (terrain index).",
    },
    "slope_autotiling": {
        "v0_2_0": "No slope support. Existing mask systems: 4-bit corner, 4-bit edge, 8-bit Moore.",
        "gap": "No slope-aware mask computation. Slopes need diagonal-mask (6,9) awareness + triangular tile rendering.",
        "needed": "PentaTileLayoutSlope subclass. See spike 005.",
    },
    "atlas_passthrough": {
        "v0_2_0": "_update_cells() processes ALL painted cells through layout dispatch.",
        "gap": "Fixture/overlay cells painted with non-layout source_ids still go through autotiling.",
        "needed": "Source-ID gating: cells with source_id != layout_source skip layout dispatch. Paint to offset=Vector2.ZERO passthrough layer.",
    },
    "precedence_groups": {
        "v0_2_0": "Single _PentaTileVisual child layer.",
        "gap": "No mechanism for overlapping terrain cells with precedence ordering.",
        "needed": "Multiple visual child layers, one per precedence group. Per-cell routing based on terrain group membership.",
    },
    "bulk_paint_api": {
        "v0_2_0": "Per-cell set_cell() only. Each call triggers _update_cells() per affected coords.",
        "gap": "Batch generation (VirtuMap paints hundreds of cells) pays per-cell overhead.",
        "needed": "set_cells(positions, source_id, atlas_coord) → single _update_cells() for union of affected rects.",
    },
    "multi_source_output": {
        "v0_2_0": "Global _resolve_source_id() for all generated output. AtlasSlot has no source_id field.",
        "gap": "VirtuMap uses multiple atlas sources per ship (one tileset, multiple sources).",
        "needed": "source_id field on AtlasSlot; _paint_with_slot routes to correct source.",
    },
}

# ── Gap scoring ──────────────────────────────────────────────────────────────

def score_gaps() -> Dict[str, Dict]:
    """Score each gap on feasibility, complexity, and VirtuMap necessity."""
    
    gaps = {}
    
    gaps["terrain_strip_dispatch"] = {
        "description": "Multi-terrain strip dispatch via atlas_coords.y encoding",
        "feasibility": "HIGH",
        "complexity": 4,
        "virtumap_must": True,
        "penta_loc_delta": 60,
        "breaking": False,
        "blocks": [],
        "blocked_by": [],
        "verdict": "Extend existing AUTO_STRIP pattern. Add strip_index param to compute_mask().",
        "detail": (
            "PentaTileLayoutPenta already dispatches per-strip via AUTO_STRIP mode. "
            "The visual rendering is already per-strip. What's missing: conveying WHICH "
            "strip a logic cell belongs to. VirtuMap would encode terrain as atlas_coords.y "
            "(e.g., FLOOR=(0,0), WALL=(0,1), HULL=(0,2)). PentaTile reads this at compute time."
        ),
    }
    
    gaps["slope_layout"] = {
        "description": "PentaTileLayoutSlope subclass for 45-degree slopes",
        "feasibility": "HIGH",
        "complexity": 5,
        "virtumap_must": True,
        "penta_loc_delta": 120,
        "breaking": False,
        "blocks": [],
        "blocked_by": ["spike_005_findings"],
        "verdict": "New single-grid layout subclass. Synthesize or author slope triangles.",
        "detail": (
            "Slopes are the only terrain type that requires a DIFFERENT layout than the "
            "surrounding terrain. A wall cell uses the WALL strip; a slope cell uses the "
            "SLOPE strip. The slope layout must handle 4-bit corner masks where one corner "
            "is 'slope-occupied' vs 'empty'. The existing single-grid pipeline handles "
            "this — slope just becomes another layout subclass in that pipeline."
        ),
    }
    
    gaps["atlas_passthrough"] = {
        "description": "Source-ID gating for fixture/overlay cells",
        "feasibility": "HIGH",
        "complexity": 3,
        "virtumap_must": True,
        "penta_loc_delta": 90,
        "breaking": False,
        "blocks": [],
        "blocked_by": [],
        "verdict": "Add _PentaTilePassthrough child layer. Gate on source_id in _update_cells.",
        "detail": (
            "The simplest solution: second visual child layer at Vector2.ZERO offset. "
            "_update_cells skips layout dispatch for cells whose source_id != layout_source. "
            "These cells paint directly to the passthrough layer at the display coord. "
            "This means virtumap fixture tiles render at their exact logic coordinates "
            "without dual-grid half-tile offsets."
        ),
    }
    
    gaps["precedence_groups"] = {
        "description": "Overlapping terrain rendering with priority ordering",
        "feasibility": "MEDIUM",
        "complexity": 7,
        "virtumap_must": False,
        "penta_loc_delta": 150,
        "breaking": True,
        "blocks": [],
        "blocked_by": ["terrain_strip_dispatch"],
        "verdict": "v2 target. Multiple visual child layers per precedence tier.",
        "detail": (
            "When HULL (hull) overlaps WALL (wall) at the same cell, hull should render "
            "above wall. This requires multiple visual child layers with z-ordering. "
            "Each precedence group gets its own _PentaTileVisual_N child. At paint time, "
            "the cell's terrain group determines which child receives the tile. ",
            "This is architecturally significant: the single-visual-layer assumption "
            "permeates _sync_visual_layers, _ensure_synthesized_tile_set, and the "
            "paint pipeline. v1 approach: use one PentaTileMapLayer per terrain type "
            "(what VirtuMap already does with TileMapLayer per terrain)."
        ),
    }
    
    gaps["bulk_paint_api"] = {
        "description": "set_cells() batch method for procedural generation",
        "feasibility": "HIGH",
        "complexity": 6,
        "virtumap_must": False,
        "penta_loc_delta": 80,
        "breaking": False,
        "blocks": [],
        "blocked_by": [],
        "verdict": "Add public set_cells() that batches then calls _update_cells once.",
        "detail": (
            "VirtuMap generates hundreds of cells per ship (48x24 grid → 1152 cells, "
            "about 60% painted → ~700 cells). Calling set_cell() 700 times triggers "
            "700 _update_cells() callbacks (one per painted coord). A batch method "
            "that calls set_cell in a loop then triggers _update_cells for the union "
            "of affected rects would amortize the callback cost."
        ),
    }
    
    gaps["multi_source_output"] = {
        "description": "source_id field on PentaTileAtlasSlot for multi-source TileSets",
        "feasibility": "HIGH",
        "complexity": 5,
        "virtumap_must": False,
        "penta_loc_delta": 50,
        "breaking": False,
        "blocks": [],
        "blocked_by": [],
        "verdict": "Add source_id field with default=-1 (use global). Route in _paint_with_slot.",
        "detail": (
            "PentaTileAtlasSlot currently has no source_id — it assumes all output goes "
            "to _resolve_source_id(). Some layouts (PixelLab with per-variation sources, "
            "VirtuMap with per-terrain sources) need per-slot source routing. "
            "Add optional source_id: int = -1 to AtlasSlot. When >= 0, _paint_with_slot "
            "uses it; when -1, falls back to _resolve_source_id()."
        ),
    }
    
    return gaps


def generate_integration_path() -> List[Dict]:
    """Generate the recommended integration path with phases and milestones."""
    
    return [
        {
            "phase": "0 — Schema Changes (PentaTile v0.3)",
            "items": [
                "source_id on PentaTileAtlasSlot",
                "strip_index param on compute_mask()",
            ],
            "rationale": "Non-breaking schema additions that unblock all downstream features.",
        },
        {
            "phase": "1 — Passthrough + Terrain Dispatch (PentaTile v0.3)",
            "items": [
                "Atlas passthrough (source-ID gating + _PentaTilePassthrough layer)",
                "Multi-strip terrain dispatch (atlas_coords.y → strip_index)",
            ],
            "rationale": "Minimum viable VirtuMap integration: WALL/PLATFORM/BEAM become Penta strips, FLOOR/fixtures become passthrough cells.",
        },
        {
            "phase": "2 — Slope Layout (PentaTile v0.3)",
            "items": [
                "PentaTileLayoutSlope subclass",
                "Slope synthesis or authored slope quadrant slots",
            ],
            "rationale": "SLOPE terrain set needs its own layout. Can ship independently.",
        },
        {
            "phase": "3 — VirtuMap Adapter Rewrite (VirtuMap v1.3?)",
            "items": [
                "Replace set_cells_terrain_connect calls with set_cell",
                "Encode terrain as atlas_coords.y",
                "Remove terrain peering bit authoring from tileset",
                "Replace Phase 17 backfill with PentaTile deterministic fallback",
            ],
            "rationale": "VirtuMap side of the integration. Removes 6 terrain sets, 940 clicks of peering bit authoring.",
        },
        {
            "phase": "4 — Advanced Features (PentaTile v0.4+ / VirtuMap v2)",
            "items": [
                "Precedence groups (multi-layer visual output)",
                "Bulk paint API (set_cells batch)",
                "Multi-source output routing",
                "Variation-bank wiring for terrain variation",
            ],
            "rationale": "Quality-of-life and performance features. Not blocking VirtuMap integration.",
        },
    ]


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    gaps = score_gaps()
    path = generate_integration_path()
    
    report = {
        "spike": "004",
        "title": "VirtuMap Integration Requirements",
        "verdict": "VALIDATED",
        "summary": (
            "All six VirtuMap needs are technically feasible within PentaTile's existing "
            "architecture. Phase 0-2 (schema changes, passthrough, terrain dispatch, "
            "slopes) can ship in v0.3. Phase 3 (VirtuMap adapter rewrite) is the "
            "consumer-side work. Phase 4 (precedence, batch API, multi-source) targets v0.4+."
        ),
        "gaps": {k: {kk: vv for kk, vv in v.items() if kk != "detail"} for k, v in gaps.items()},
        "integration_path": path,
        "recommendations": {
            "immediate": [
                "Add spike 005 (slope layout feasibility) findings as prerequisite",
                "Include terrain-strip-dispatch in Phase 9 terrain+variation spike scope",
                "Add todo: source_id on AtlasSlot (schema change, non-breaking)",
            ],
            "v0_3_scope": [
                "source_id on AtlasSlot",
                "Atlas passthrough",
                "Multi-strip terrain dispatch via atlas_coords.y",
                "PentaTileLayoutSlope",
            ],
            "defer_v0_4": [
                "Precedence groups (alternative: one PentaTileMapLayer per terrain type)",
                "Bulk set_cells() API (demo-scale is fine with per-cell)",
                "Multi-source output routing",
            ],
        },
    }
    
    print(json.dumps(report, indent=2))
    
    # Write report file
    with open("out/gap_analysis_report.json", "w") as f:
        json.dump(report, f, indent=2)
    
    print("\nReport written to out/gap_analysis_report.json")


if __name__ == "__main__":
    main()
