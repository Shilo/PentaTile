# LLM-Friendly Docs

Phase 7 evaluated two approaches:

- Point agents at MkDocs source plus GDScript `##` comments.
- Generate a flat text artifact from docs and code comments.

The current recommendation is to use the direct source approach. The repo is
small, the docs are plain Markdown, and the runtime API is already documented in
GDScript comments. A generated flat file would add drift risk and maintenance
surface before there is evidence that agents struggle with the direct sources.

Recommended context for agents:

- `AGENTS.md` for project rules and pitfalls.
- `docs/` for task-facing docs.
- `addons/penta_tile/**/*.gd` for authoritative API and implementation comments.
- `tests/` for rendered-output regression methodology.

The detailed tradeoff is recorded in
`.planning/phases/07-repo-restructure-extract-tests-mkdocs-site-llm-friendly-docs/07-LLM-DOCS-DECISION.md`.
