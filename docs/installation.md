# Installation

## From a GitHub release

Download the release zip and copy its `addons/penta_tile/` folder into your
Godot project. The release zip intentionally contains only the addon package;
repo tests, planning files, and docs-site sources are not included.

## From this repository

Copy or symlink `addons/penta_tile/` into a Godot 4.6 project, then enable the
plugin. The root `tests/` directory is for repository verification and does not
need to be copied into a game project.

## Build these docs

Install the docs dependency in your Python environment:

```bash
python -m pip install -r requirements-docs.txt
mkdocs serve
```

To check the static site:

```bash
mkdocs build --strict
```
