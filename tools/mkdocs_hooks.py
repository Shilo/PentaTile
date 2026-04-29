"""MkDocs hooks for PentaTile.

Generates ``docs/api-reference.md`` at build time by extracting Godot ``##``
doc comments from ``addons/penta_tile/**/*.gd``. The generated file is
gitignored — it is rebuilt on every ``mkdocs build`` / ``mkdocs serve``.

This file is referenced from ``mkdocs.yml`` via the ``hooks:`` key. The
``on_pre_build`` callback runs before the file collector scans ``docs/``,
which means the generated file is picked up as a regular Markdown page.

Phase 7 reversal context: ``07-LLM-DOCS-DECISION-REVISION.md`` records the
decision to auto-generate LLM-friendly docs after the original "direct
source only" stance proved insufficient for "widely usable library" goals.
The mkdocs-llmstxt plugin then concatenates this page (plus the rest of
the nav) into ``site/llms.txt`` and ``site/llms-full.txt``.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable


_PROJECT_ROOT = Path(__file__).resolve().parents[1]
_ADDON_ROOT = _PROJECT_ROOT / "addons" / "penta_tile"
_OUTPUT = _PROJECT_ROOT / "docs" / "api-reference.md"

# Match ``func name(...) -> ReturnType:`` (public funcs only — no leading ``_``).
_FUNC_RE = re.compile(r"^func\s+([a-z][a-z0-9_]*)\s*\((.*?)\)\s*(?:->\s*([^:]+?))?\s*:\s*$")

# Match ``@export[_anything] var name: Type[ = default]``.
_EXPORT_RE = re.compile(
    # Trailing ``:`` (setter-attached form ``@export var x: int = 3:``) is consumed
    # but excluded from captured groups so it doesn't leak into the rendered signature.
    r"^@export(?:_\w+)?(?:\([^)]*\))?\s+var\s+([a-z_][a-z0-9_]*)\s*:\s*([^=\n:]+?)(?:\s*=\s*([^:\n]+?))?\s*:?\s*$"
)

_CLASS_NAME_RE = re.compile(r"^class_name\s+(\w+)")
_EXTENDS_RE = re.compile(r"^extends\s+(\w+)")


def _gd_files() -> Iterable[Path]:
    """Return ``.gd`` source files in deterministic order, excluding tests + demo."""
    skip = ("demo", "tests")
    files = sorted(_ADDON_ROOT.rglob("*.gd"))
    return [f for f in files if not any(part in skip for part in f.relative_to(_PROJECT_ROOT).parts)]


def _read_doc_block(lines: list[str], end_index: int) -> str:
    """Walk backwards from ``end_index`` collecting consecutive ``## `` lines."""
    block: list[str] = []
    i = end_index - 1
    while i >= 0:
        stripped = lines[i].lstrip()
        if stripped.startswith("##"):
            block.append(stripped[2:].lstrip() if stripped.startswith("## ") else stripped[2:])
            i -= 1
        elif stripped == "":
            # Blank line breaks the block.
            break
        else:
            break
    return "\n".join(reversed(block)).strip()


def _extract_class(path: Path) -> dict | None:
    """Return ``{name, extends, doc, methods, exports}`` or ``None`` if no ``class_name``."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    class_name: str | None = None
    extends: str | None = None
    class_doc = ""
    methods: list[dict] = []
    exports: list[dict] = []

    for i, raw in enumerate(lines):
        line = raw.rstrip()

        if class_name is None:
            m = _CLASS_NAME_RE.match(line)
            if m:
                class_name = m.group(1)
                # Class doc: walk forward (Godot convention) skipping ``extends`` + ``@icon`` etc.
                j = i + 1
                while j < len(lines) and lines[j].strip().startswith(("extends ", "@", "")):
                    if lines[j].strip().startswith("##"):
                        break
                    j += 1
                # Now collect contiguous ``## `` block.
                block = []
                while j < len(lines) and lines[j].strip().startswith("##"):
                    s = lines[j].strip()
                    block.append(s[2:].lstrip() if s.startswith("## ") else s[2:])
                    j += 1
                class_doc = "\n".join(block).strip()
                continue

        if extends is None:
            m = _EXTENDS_RE.match(line)
            if m:
                extends = m.group(1)
                continue

        m_func = _FUNC_RE.match(line)
        if m_func:
            doc = _read_doc_block(lines, i)
            if not doc:
                continue  # Undocumented public method: skip from API reference.
            args = m_func.group(2).strip()
            ret = (m_func.group(3) or "void").strip()
            methods.append({
                "name": m_func.group(1),
                "signature": f"func {m_func.group(1)}({args}) -> {ret}",
                "doc": doc,
            })
            continue

        m_exp = _EXPORT_RE.match(line)
        if m_exp:
            doc = _read_doc_block(lines, i)
            if not doc:
                continue  # Undocumented export: skip.
            type_name = m_exp.group(2).strip()
            default = m_exp.group(3)
            sig = f"@export var {m_exp.group(1)}: {type_name}"
            if default:
                sig += f" = {default.strip()}"
            exports.append({"name": m_exp.group(1), "signature": sig, "doc": doc})

    if class_name is None:
        return None
    return {
        "name": class_name,
        "extends": extends or "",
        "path": path.relative_to(_PROJECT_ROOT).as_posix(),
        "doc": class_doc,
        "methods": methods,
        "exports": exports,
    }


def _bbcode_to_markdown(text: str) -> str:
    """Best-effort Godot BBCode → Markdown for LLM/HTML readability."""
    # ``[code]X[/code]``  → `` `X` ``
    text = re.sub(r"\[code\](.+?)\[/code\]", r"`\1`", text, flags=re.DOTALL)
    # ``[b]X[/b]``        → ``**X**``
    text = re.sub(r"\[b\](.+?)\[/b\]", r"**\1**", text, flags=re.DOTALL)
    # ``[i]X[/i]``        → ``*X*``
    text = re.sub(r"\[i\](.+?)\[/i\]", r"*\1*", text, flags=re.DOTALL)
    # ``[Class X]`` / ``[method X]`` / ``[member X]`` / ``[param X]`` → `` `X` ``
    text = re.sub(r"\[(?:Class|method|member|param|enum|signal|constant)\s+([^\]]+)\]", r"`\1`", text)
    # Bare class reference ``[ClassName]`` (Godot shorthand) → `` `ClassName` ``.
    text = re.sub(r"\[([A-Z][A-Za-z0-9_]*)\]", r"`\1`", text)
    # Drop unhandled tags.
    text = re.sub(r"\[/?\w+(?:\s[^\]]*)?\]", "", text)
    return text


def _format_class(cls: dict) -> str:
    out: list[str] = []
    header = f"## `{cls['name']}`"
    if cls["extends"]:
        header += f" extends `{cls['extends']}`"
    out.append(header)
    out.append("")
    out.append(f"*Source: [`{cls['path']}`]({{{{repo}}}}/{cls['path']})*"
               .replace("{{repo}}", "https://github.com/Shilo/PentaTile/blob/main"))
    out.append("")
    if cls["doc"]:
        out.append(_bbcode_to_markdown(cls["doc"]))
        out.append("")

    if cls["exports"]:
        out.append("### Exports")
        out.append("")
        for exp in cls["exports"]:
            out.append(f"#### `{exp['name']}`")
            out.append("")
            out.append("```gdscript")
            out.append(exp["signature"])
            out.append("```")
            out.append("")
            out.append(_bbcode_to_markdown(exp["doc"]))
            out.append("")

    if cls["methods"]:
        out.append("### Methods")
        out.append("")
        for m in cls["methods"]:
            out.append(f"#### `{m['name']}()`")
            out.append("")
            out.append("```gdscript")
            out.append(m["signature"])
            out.append("```")
            out.append("")
            out.append(_bbcode_to_markdown(m["doc"]))
            out.append("")

    return "\n".join(out)


def _build_api_reference() -> str:
    parts = [
        "# API Reference",
        "",
        "Auto-generated from Godot `##` doc-comments in `addons/penta_tile/**/*.gd`. "
        "Do not edit by hand — modify the source comments and rebuild docs. "
        "Regeneration is wired via `tools/mkdocs_hooks.py` (`on_pre_build`).",
        "",
        "Only documented public methods (no leading underscore) and documented "
        "`@export` properties are included. Undocumented members are intentionally "
        "omitted — add a `##` block above the member to surface it here.",
        "",
    ]
    classes = [c for c in (_extract_class(p) for p in _gd_files()) if c]
    # Stable ordering: PentaTileMapLayer first (entry point), then alphabetical.
    classes.sort(key=lambda c: (0 if c["name"] == "PentaTileMapLayer" else 1, c["name"]))
    for cls in classes:
        parts.append(_format_class(cls))
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def on_pre_build(config) -> None:
    """MkDocs hook: regenerate ``docs/api-reference.md`` before each build."""
    _OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    _OUTPUT.write_text(_build_api_reference(), encoding="utf-8")


if __name__ == "__main__":
    on_pre_build(None)
    print(f"Wrote {_OUTPUT}")
