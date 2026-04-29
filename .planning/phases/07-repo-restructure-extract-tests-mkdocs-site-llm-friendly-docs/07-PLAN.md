# Phase 7 Plan: Repo Restructure + MkDocs + LLM-Friendly Docs

**Phase:** 7
**Status:** Executed inline under autonomous request
**Created:** 2026-04-29

## Goal

Ship three post-v0.2.0 repository hygiene deliverables without changing
runtime addon behavior:

1. Move tests out of the addon package to root `tests/`.
2. Add a minimal MkDocs documentation site.
3. Decide whether LLM agents need a generated flat docs artifact.

## Requirements

- **REPO-01:** `addons/penta_tile/tests/` is moved to root `tests/`.
- **REPO-02:** test runners, sample image imports, release CI, README, AGENTS,
  CLAUDE, and current planning docs point at root `tests/`.
- **REPO-03:** release packaging still archives only `addons/penta_tile/`.
- **DOCS-06:** MkDocs config and source pages cover quickstart,
  installation, layouts overview, one page per shipped layout, Penta definition,
  and custom layout authoring.
- **DOCS-07:** docs theme defaults to dark mode and exposes a manual light/dark
  toggle.
- **DOCS-08:** LLM docs decision artifact records direct-source vs flat-artifact
  tradeoff and recommendation.

## Execution Tasks

1. Audit path references.
   - Inspect release workflow, runners, test assets, README, AGENTS/CLAUDE, and
     current planning docs.
   - Keep archived historical phase artifacts mostly intact except where broad
     path rewrites are harmless.

2. Move tests.
   - Move every tracked file from `addons/penta_tile/tests/` to `tests/`.
   - Update PowerShell and bash runners so `--path` remains repo root and
     `--script` uses `tests/<name>.gd`.
   - Update PixelLab fixture paths to `res://tests/...`.

3. Add MkDocs.
   - Use `mkdocs-material==9.*`.
   - Configure dark-first `slate` palette and manual toggle to `default`.
   - Add plain Markdown pages only; no custom CSS, JS, or generated API layer.

4. Decide LLM docs pipeline.
   - Compare direct source (`docs/` + GDScript `##` comments + tests) against a
     generated flat text file.
   - Implement no generator unless the flat artifact clearly wins.

5. Verify.
   - Run `git diff --check`.
   - Run Godot test suite if Godot is available.
   - Run `mkdocs build` if MkDocs can be installed safely.
   - Inspect release workflow archive command and repository status.

## Non-Goals

- No Phase 6 editor-preview implementation.
- No Phase 8 multi-terrain or v0.3 research implementation.
- No runtime `PentaTileMapLayer` or layout behavior changes.
- No compatibility shims, version fields, or speculative docs generation.
