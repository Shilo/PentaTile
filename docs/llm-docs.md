# LLM-Friendly Docs

PentaTile publishes auto-generated, single-file documentation surfaces for LLMs
and agents on every docs build, following the
[llms.txt standard](https://llmstxt.org/).

## Stable URLs

- **<https://shilo.github.io/PentaTile/llms.txt>** — table of contents per the
  llmstxt.org spec. Small, links to every doc page in nav order.
- **<https://shilo.github.io/PentaTile/llms-full.txt>** — full content
  concatenation. One file with quickstart, layout pages, the Penta-tileset
  definition, custom-layout authoring guide, and the complete GDScript API
  reference inline.

Both are regenerated from the MkDocs source on every push to `main` that
touches `docs/`, `mkdocs.yml`, or `addons/penta_tile/**/*.gd`. They are
served by GitHub Pages alongside the rendered HTML site.

## What feeds the LLM artifacts

1. **MkDocs source** — every page in `docs/` (rendered as Markdown, not HTML).
2. **GDScript `##` doc-comments** — extracted from `addons/penta_tile/**/*.gd`
   into a virtual `api-reference.md` page at build time via
   `tools/mkdocs_hooks.py`. Documented public methods (no leading underscore)
   and documented `@export` properties are included; undocumented members are
   intentionally omitted (add a `##` block above the member to surface it).
3. **`mkdocs-llmstxt` plugin** — concatenates the above into `llms.txt` and
   `llms-full.txt` per the llmstxt.org spec.

The pipeline lives in `.github/workflows/docs.yml` and is unconditional —
there is no separate "generate LLM artifact" step to remember to run.

## Recommended agent context

For agents working **in the repo** (Claude Code, Cursor, etc.):

- `AGENTS.md` — project rules, pitfalls, identity guardrails.
- `docs/` — task-facing prose (Markdown source, no rendering required).
- `addons/penta_tile/**/*.gd` — authoritative API and implementation comments.
- `tests/` — rendered-output regression methodology.

For agents fetching **over the network** (no repo checkout):

- Fetch <https://shilo.github.io/PentaTile/llms-full.txt> for everything in one
  request.
- Fetch <https://shilo.github.io/PentaTile/llms.txt> first if you need a
  lightweight index before drilling into specific pages.

## History

Phase 7 originally rejected an auto-generated LLM artifact in favor of
direct-source consumption. That decision was reversed on 2026-04-29 once the
project goal widened from "the author's own games" to "readable and widely
usable library," and an over-the-network single-file surface became necessary.

The reversal and rationale are recorded in
`.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION-REVISION.md`.
