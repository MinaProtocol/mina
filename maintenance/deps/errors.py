"""Structural errors, shared by the core and the shell.

The core raises these; `main` is the only place that renders one. Codes are
stable so a failure can be recognised without matching on English.
"""

from __future__ import annotations

from enum import StrEnum
from pathlib import Path


class ErrorCode(StrEnum):
    ROOT_NOT_A_DIRECTORY = "ROOT_NOT_A_DIRECTORY"
    BASELINE_MISSING = "BASELINE_MISSING"
    BASELINE_NOT_WHOLE_TREE = "BASELINE_NOT_WHOLE_TREE"
    RULES_MISSING = "RULES_MISSING"
    RULES_MALFORMED = "RULES_MALFORMED"
    MALFORMED_JSON = "MALFORMED_JSON"
    DUNE_UNPARSEABLE = "DUNE_UNPARSEABLE"
    DUNE_UNREADABLE = "DUNE_UNREADABLE"
    NO_SUCH_NODE = "NO_SUCH_NODE"


class DepsError(Exception):
    """A failure the CLI can report without a traceback."""

    def __init__(self, code: ErrorCode, message: str, *, path: Path | None = None) -> None:
        self.code = code
        self.message = message
        self.path = path
        super().__init__(f"[{code.value}] {message}")
