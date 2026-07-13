from __future__ import annotations

import json
import re
from pathlib import Path
from typing import List

from mln.errors import ErrorCode, TopologyError

_JSONC_STRING_RE = re.compile(r'"(?:[^"\\]|\\.)*"')
_JSONC_SL_COMMENT_RE = re.compile(r"//.*?$", re.MULTILINE)
_JSONC_ML_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)

_PLACEHOLDER_MARKER = "\x00JSONC_STR_{}_\x00"


def strip_jsonc_comments(text: str) -> str:
    r"""Remove // and /* */ comments while preserving content inside strings.

    Uses a placeholder approach: extract all string literals first, then
    strip comments from the non-string regions, then restore strings.

    >>> strip_jsonc_comments('{"a": 1 /* cmt */, "b": "// not a comment"}')
    '{"a": 1  , "b": "// not a comment"}'
    >>> strip_jsonc_comments('// top comment\n{"a": 1}\n/* bottom */')
    '\n{"a": 1}\n'
    """
    # Phase 1: replace every string literal with a unique placeholder
    strings: List[str] = []

    def _replace_string(m: re.Match) -> str:
        idx = len(strings)
        placeholder = _PLACEHOLDER_MARKER.format(idx)
        strings.append(m.group(0))
        return placeholder

    placeholderized = _JSONC_STRING_RE.sub(_replace_string, text)

    # Phase 2: strip comments from the placeholderized text
    placeholderized = _JSONC_ML_COMMENT_RE.sub("", placeholderized)
    placeholderized = _JSONC_SL_COMMENT_RE.sub("", placeholderized)

    # Phase 3: restore string literals in reverse index order
    for idx in range(len(strings) - 1, -1, -1):
        placeholder = _PLACEHOLDER_MARKER.format(idx)
        placeholderized = placeholderized.replace(placeholder, strings[idx])

    return placeholderized


def load_jsonc(path: Path) -> dict:
    """Load a .jsonc file, strip comments, and parse as JSON."""
    raw = path.read_text(encoding="utf-8")
    stripped = strip_jsonc_comments(raw)
    try:
        return json.loads(stripped)
    except json.JSONDecodeError as exc:
        raise TopologyError(
            ErrorCode.PLAN_PARSE_ERROR,
            message=f"Failed to parse JSONC in {path}: {exc}"
            f"\nStripped content (first 500 chars): {stripped[:500]}",
            path=str(path),
        ) from exc
