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

## Follow-Up

None required for Phase 7. A flat LLM artifact can be reconsidered only if a
specific consumer or repeated agent failure proves the direct-source approach is
not enough.
