# Phase 7 Decision Revision: LLM-Friendly Documentation Surface

**Revision date:** 2026-04-29
**Supersedes:** [07-LLM-DOCS-DECISION.md](./07-LLM-DOCS-DECISION.md)
**Status:** Implemented

## Reversal

The original Phase 7 decision rejected an auto-generated LLM-friendly artifact in
favor of direct-source consumption (mkdocs source + GDScript `##` comments +
`AGENTS.md` + `tests/`). That decision is reversed.

PentaTile **now generates `llms.txt` and `llms-full.txt` on every docs build**
via the [mkdocs-llmstxt](https://github.com/pawamoy/mkdocs-llmstxt) plugin plus a
custom `tools/mkdocs_hooks.py` step that extracts GDScript `##` doc-comments
into a virtual `api-reference.md` page.

## Why the reversal

The original decision listed three explicit "revisit triggers":

1. A docs host needs single-page export.
2. A model/tool with poor repository traversal appears as a real consumer.
3. Repeated agent failures caused by missing cross-file context.

The user's stated 2026-04-29 reframing — *"all in the goal to have readable and
widely usable library"* — fires trigger (1) by intent, even before the
empirical signal of (2) or (3): a public-facing library benefits from a stable
single-URL surface that LLM tools can fetch without filesystem access. The
original decision was correct given the original "audience is the author's own
games" framing; broadening that audience invalidates the rationale.

Identity-guardrail concerns from the original decision (drift risk, dual
sources of truth, CI maintenance surface) are addressed by:

- **No committed generated file.** `docs/api-reference.md` is gitignored and
  rebuilt on every `mkdocs build` / `mkdocs serve`. Source of truth stays in
  `addons/penta_tile/**/*.gd`.
- **Deterministic generation.** `tools/mkdocs_hooks.py` is ~150 LOC of
  pure-stdlib Python; no templating, no external state, no flaky network calls.
- **One CI surface.** The existing `docs.yml` workflow does the LLM-artifact
  generation as part of `mkdocs build` — no second workflow, no commit-back
  loop, no schedule.

## What ships

| Artifact | URL / Path | Source |
| --- | --- | --- |
| `llms.txt` | `https://shilo.github.io/PentaTile/llms.txt` | mkdocs-llmstxt plugin (TOC per spec) |
| `llms-full.txt` | `https://shilo.github.io/PentaTile/llms-full.txt` | mkdocs-llmstxt plugin with `full_output` |
| `api-reference.md` | `docs/api-reference.md` (gitignored) | `tools/mkdocs_hooks.py` `on_pre_build` hook |

The hook walks `addons/penta_tile/**/*.gd` (excluding `tests/` and `demo/`),
extracts class-level + public-method + `@export` `##` blocks, and writes a
single API reference page. The mkdocs-llmstxt plugin then includes that page
plus the rest of the nav in `llms-full.txt`.

## Backward references

- [07-LLM-DOCS-DECISION.md](./07-LLM-DOCS-DECISION.md) — original "no generator"
  decision. Kept as historical record; this file supersedes it.
- [07-SUMMARY.md](./07-SUMMARY.md) — Phase 7 implementation summary; gets a
  revision note pointing here.
- [docs/llm-docs.md](../../../docs/llm-docs.md) — user-facing page rewritten
  to describe the new pipeline.
- [.github/workflows/docs.yml](../../../.github/workflows/docs.yml) — the
  workflow that builds and deploys `llms.txt` + `llms-full.txt` to GitHub Pages.

## Future revisit triggers

Re-open this decision only if:

- The mkdocs-llmstxt plugin is abandoned and no maintained equivalent exists.
- The generated artifact balloons past a size threshold that hurts LLM ingestion
  (currently ~700 lines; concern threshold ~5000).
- A specific consumer requests a different format (JSONL, structured chunks,
  embeddings-ready) that justifies a parallel pipeline.
