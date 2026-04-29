# Phase 7 Decision: LLM-Friendly Documentation Surface

**Decision:** Use MkDocs source + GDScript doc comments directly. Do not add an
auto-generated flat text artifact in Phase 7.

## Options Considered

| Option | Benefit | Cost / Risk |
| --- | --- | --- |
| Direct source: `docs/`, `AGENTS.md`, `addons/penta_tile/**/*.gd`, `tests/` | Single source of truth; no generated file drift; agents can inspect implementation and tests beside narrative docs; no workflow surface added. | Agents must read multiple files, but the repo is small and paths are obvious. |
| Generated flat artifact | One file can be convenient for weaker tools or copy/paste workflows. | Adds generator code, CI maintenance, ordering decisions, and drift risk; duplicates GDScript comments and MkDocs pages before evidence of need. |

## Recommendation

Keep the direct-source approach for now:

- `AGENTS.md` remains the project contract and pitfall index.
- `docs/` provides task-facing prose.
- `addons/penta_tile/**/*.gd` contains authoritative API doc comments.
- `tests/` demonstrates rendered-output regression methodology.

This fits the project's identity guardrails: small maintained surface, no
speculative pipeline, no generated artifact that future agents might treat as
more authoritative than source.

## Revisit Trigger

Add a flat artifact later only if a concrete consumer appears, such as:

- a docs host that needs single-page export,
- a model/tool with poor repository traversal,
- or repeated agent failures caused by missing cross-file context.

If that happens, the generator should be simple and deterministic, probably
concatenating selected Markdown and `##` doc-comment blocks in a fixed order.
