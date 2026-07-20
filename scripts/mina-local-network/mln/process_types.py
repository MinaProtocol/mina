"""Process-related type aliases and protocols shared across mln modules."""

from __future__ import annotations

from typing import Callable, Protocol

# ── Simple type alias ────────────────────────────────────────────────────

StopChecker = Callable[[], bool]
"""A zero-argument callable that returns True when a stop is requested.

Used by readiness-poll loops (GraphQL / TCP / daemon status) to check
whether a supervising signal (e.g. SIGINT) has arrived.
"""


# ── Process protocol ─────────────────────────────────────────────────────


class WatchedProcess(Protocol):
    """Minimal protocol for a :class:`subprocess.Popen`-like process handle.

    Covers the surface used across mln readiness-wait and teardown helpers:
    ``poll()``, ``wait()``, ``terminate()``, ``kill()``, and
    ``returncode``.  Implementations (e.g. ``Popen``, ``TrackedProcess``,
    or test doubles) only need to satisfy the subset actually called.

    This protocol avoids the need for a direct concrete import of
    ``subprocess.Popen`` across module boundaries.
    """

    returncode: int

    def poll(self) -> int | None:
        """Check if the process has terminated."""
        ...

    def terminate(self) -> None:
        """Send SIGTERM to the process."""
        ...

    def kill(self) -> None:
        """Send SIGKILL to the process."""
        ...

    def wait(self, timeout: float | None = None) -> int:
        """Wait for the process to terminate, optionally with a timeout."""
        ...
