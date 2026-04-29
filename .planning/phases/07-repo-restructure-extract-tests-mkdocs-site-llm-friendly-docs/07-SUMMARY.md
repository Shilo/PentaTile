# Phase 7 Summary: Repo Restructure + MkDocs + LLM Docs Decision

**Status:** Implemented
**Date:** 2026-04-29

## Delivered

- Moved the Godot regression suite from `addons/penta_tile/tests/` to root
  `tests/`.
- Updated local and CI runners to execute `tests/*.gd` while keeping Godot's
  project path at repo root.
- Updated release CI to run `tests/run_tests.sh`; release archives still use
  `git archive ... -- addons/penta_tile/`, so tests are excluded from the addon
  zip.
- Added a minimal MkDocs Material site with dark mode first and manual
  dark/light toggle.
- Added quickstart, installation, layouts overview, one page per shipped layout,
  Penta definition, custom layout authoring, and LLM docs pages.
- Recorded the LLM docs decision: direct MkDocs source + GDScript doc comments
  are better than a generated flat artifact for now.

## Verification

- `git diff --check` — PASS.
- `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -NoPause` —
  PASS, 17 / 17 tests green.
- `python -m pip install -r requirements-docs.txt --user` — dependency already
  satisfied locally.
- `python -m mkdocs build --strict` — PASS, documentation built to ignored
  `site/` directory.
- Release workflow inspection — PASS, test step calls `tests/run_tests.sh` and
  archive step remains restricted to `addons/penta_tile/`.

## 2026-04-29 Follow-Up Review

- Reviewed commits `01d46a4` and `ace016f`.
- Fixed docs deploy workflow comments to match the reversed LLM-docs decision.
- Expanded docs workflow path filters to include `addons/penta_tile/**/*.gd` and
  `tools/mkdocs_hooks.py`, so API-reference and LLM artifact changes redeploy.
- Expanded every layout page with template images, setup steps, atlas contracts,
  and authoring notes.
- Added MkDocs logo/favicon and homepage logo from the PentaTile brand assets.
- Fixed `tools/mkdocs_hooks.py` class-doc extraction and hid private
  `@export_storage` members from the generated public API reference.

## Follow-Up

None required for Phase 7. A flat LLM artifact can be reconsidered only if a
specific consumer or repeated agent failure proves the direct-source approach is
not enough.

## Revision (2026-04-29)

The "no generated LLM artifact" decision is **reversed**. PentaTile now ships
auto-generated `llms.txt` and `llms-full.txt` on every docs build via
`mkdocs-llmstxt` plus `tools/mkdocs_hooks.py`. Trigger: project audience widened
from "the author's own games" to "readable and widely usable library," which
fires Revisit Trigger (1) ("docs host needs single-page export") in the
original decision.

Full rationale, ship list, and future revisit triggers in
[07-LLM-DOCS-DECISION-REVISION.md](./07-LLM-DOCS-DECISION-REVISION.md).
