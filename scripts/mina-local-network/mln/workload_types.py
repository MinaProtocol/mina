"""Workload handle protocols and the outcome type — dependency-light.

These carry no ``mln`` dependencies, so both the concrete handles
(``mln.workload``) and the process-table models (``mln.models``) can import
them without an import cycle.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional, Protocol, runtime_checkable


class Outcome(Enum):
    """How a finished workload turned out — *not* an exit code.

    ``COMPLETED`` means it finished the work it was asked to do; ``FAILED``
    means it errored out.  Whether a completed workload keeps the network
    running is a separate policy decision (``success_exits_keep_network``),
    not part of the outcome.
    """

    COMPLETED = "completed"
    FAILED = "failed"


@runtime_checkable
class Workload(Protocol):
    """What the spawn supervisor needs from a workload — and nothing more."""

    name: str

    def start(self) -> None:
        """Begin the work.  Idempotence is not required; call once."""
        ...

    def is_running(self) -> bool:
        """True while the work is still in progress."""
        ...

    def stop(self) -> None:
        """Request the work stop, reaping anything it spawned."""
        ...

    def outcome(self) -> Optional[Outcome]:
        """The result once finished, or ``None`` while still running."""
        ...


@runtime_checkable
class RunHandle(Workload, Protocol):
    """A :class:`Workload` plus the process-ish bookkeeping the supervisor mirrors.

    Both ``SubprocessWorkload`` and ``ThreadWorkload`` satisfy this.  Typing the
    process table's handle as ``RunHandle`` (rather than ``Any``) lets the
    supervisor read ``returncode`` and ``launch_workload`` mirror
    ``pid``/``pgid``/``started_at`` with static checking.  ``pid``/``pgid`` are
    ``None`` for a thread, which has no OS identity of its own.
    """

    pid: Optional[int]
    pgid: Optional[int]
    started_at: Optional[str]

    @property
    def returncode(self) -> Optional[int]:
        """Synthesized exit status the supervisor bubbles up, or ``None``."""
        ...


class WorkloadStopped(Exception):
    """Raised inside a worker when a stop has been requested, to unwind it.

    Caught by :class:`~mln.workload.ThreadWorkload`; a worker sees it only
    through :class:`~mln.workload.WorkerContext` (``run``/``sleep``/
    ``checkpoint``) and should let it propagate rather than swallow it.
    """
