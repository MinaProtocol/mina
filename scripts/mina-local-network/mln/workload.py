"""The workload handle: what mln actually needs from a workload.

A workload is *not* a process.  mln does not need an exit code or signal
semantics from one — it needs to know whether it is still going, whether it
succeeded, and how to stop it.  That is the whole of :class:`Workload`.

Two implementations back it:

* :class:`ThreadWorkload` — our own Python workers (value-transfer, zkApp,
  ITN).  These are thin loops over external commands, so they run in-process
  on a thread and receive their input as one typed payload, no serialization.
  Stopping is cooperative (see :class:`WorkerContext`).
* :class:`SubprocessWorkload` — echo workloads, which run an arbitrary
  user-supplied command and so are genuinely external processes.

Contrast with :class:`~mln.process_types.WatchedProcess`, the honest
``Popen``-shaped protocol for real external apps (daemons, archive, rosetta,
snark workers) whose argv/exit-code/signal interface is genuine.
"""

from __future__ import annotations

import datetime
import os
import subprocess
import sys
import threading
from typing import Dict, List, Optional, Sequence

from mln.models import WorkloadPayload
from mln.process import spawn_tagged_process, teardown_process

# The protocols and Outcome live in the dependency-light mln.workload_types so
# mln.models can also import RunHandle without a cycle; re-exported here for
# existing importers of mln.workload.
from mln.workload_types import Outcome, RunHandle, Workload, WorkloadStopped

__all__ = [
    "Outcome",
    "Workload",
    "RunHandle",
    "WorkloadStopped",
    "SubprocessWorkload",
    "ThreadWorkload",
    "WorkerContext",
]


class SubprocessWorkload:
    """A :class:`Workload` carried by a tagged, session-leader subprocess.

    Reuses the same launch primitive as real external processes
    (:func:`~mln.spawn.lifecycle.spawn_tagged_process`) so the load-bearing
    session/PGID/output-tagging semantics cannot drift, and the same
    group-signalling teardown (:func:`~mln.process.teardown_process`) so any
    grandchildren the workload shells out to are reaped.
    """

    def __init__(self, name: str, argv: List[str], env: Dict[str, str]) -> None:
        self.name = name
        self.argv = list(argv)
        self.env = dict(env)
        self._proc: Optional["subprocess.Popen[str]"] = None  # noqa: F821
        self.pid: Optional[int] = None
        self.pgid: Optional[int] = None
        self.started_at: Optional[str] = None

    def start(self) -> None:
        proc = spawn_tagged_process(self.argv, self.env, self.name)
        self._proc = proc
        self.pid = proc.pid
        # start_new_session=True makes the child its own session leader, so its
        # PGID equals its PID.  Using proc.pid directly avoids a getpgid() race.
        self.pgid = proc.pid
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()

    def is_running(self) -> bool:
        return self._proc is not None and self._proc.poll() is None

    def stop(self) -> None:
        teardown_process(self._proc, self.pgid)

    def outcome(self) -> Optional[Outcome]:
        if self._proc is None:
            return None
        code = self._proc.poll()
        if code is None:
            return None
        return Outcome.COMPLETED if code == 0 else Outcome.FAILED

    @property
    def returncode(self) -> Optional[int]:
        """The subprocess exit code, or ``None`` if unstarted / still running.

        Not part of :class:`Workload` — a workload's result is its
        :class:`Outcome`.  This exists only so the spawn supervisor can bubble
        a genuine process exit code up as *its own* exit status.
        """
        if self._proc is None:
            return None
        return self._proc.poll()


class WorkerContext:
    """Cancellation and environment for an in-process (threaded) worker.

    A thread cannot be killed from outside, so stopping is cooperative: worker
    code runs external commands through :meth:`run` and waits through
    :meth:`sleep`, both of which observe a stop request promptly — a running
    child is killed and :class:`WorkloadStopped` raised to unwind the worker.
    A worker that loops without hitting any of these (a bug) cannot be forced
    to stop; that is the accepted cost of running it in-process rather than as
    a killable process group.

    ``env`` overlays the process environment for the commands a worker shells
    out to (e.g. ``MINA_PRIVKEY_PASS``).  A subprocess worker received this at
    launch; a thread shares the supervisor's environment, so it must be
    supplied here instead.  ``log`` tags the worker's own output with its name,
    the job the parent's drain threads did for a subprocess.
    """

    _POLL_SECONDS = 0.2

    def __init__(self, name: str, env: Dict[str, str]) -> None:
        self.name = name
        self._stop = threading.Event()
        self._base_env = {**os.environ, **env}

    def request_stop(self) -> None:
        """Signal the worker to stop (called from the supervisor thread)."""
        self._stop.set()

    def checkpoint(self) -> None:
        """Raise :class:`WorkloadStopped` if a stop has been requested."""
        if self._stop.is_set():
            raise WorkloadStopped()

    def sleep(self, seconds: float) -> None:
        """Sleep, but wake and raise immediately if a stop arrives."""
        if seconds > 0 and self._stop.wait(seconds):
            raise WorkloadStopped()
        self.checkpoint()

    def log(self, message: str) -> None:
        """Emit a worker log line tagged with the workload name."""
        print(f"[{self.name}] {message}", file=sys.stderr)

    def run(
        self, argv: Sequence[str], *, text: bool = True
    ) -> "subprocess.CompletedProcess":
        """Run *argv* to completion, killing it promptly if a stop arrives.

        Output is captured (as the workers expect).  Returns a
        ``CompletedProcess`` like ``subprocess.run(capture_output=True)``.
        """
        self.checkpoint()
        proc = subprocess.Popen(
            list(argv),
            env=self._base_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=text,
        )
        while True:
            try:
                out, err = proc.communicate(timeout=self._POLL_SECONDS)
                return subprocess.CompletedProcess(
                    list(argv), proc.returncode, out, err
                )
            except subprocess.TimeoutExpired:
                if self._stop.is_set():
                    proc.kill()
                    proc.communicate()
                    raise WorkloadStopped()


class ThreadWorkload:
    """A :class:`Workload` run in-process on a daemon thread.

    Our Python workers are thin loops over external commands; running them here
    (rather than in a re-exec'd child) means the input crosses as one typed
    payload with no serialization, and the worker is directly unit-testable.
    The trade is that stopping is cooperative — see :class:`WorkerContext`.
    """

    def __init__(
        self, name: str, payload: WorkloadPayload, env: Dict[str, str]
    ) -> None:
        self.name = name
        self._payload = payload
        self._ctx = WorkerContext(name, env)
        self._thread: Optional[threading.Thread] = None
        self._outcome: Optional[Outcome] = None
        self._returncode: Optional[int] = None
        self.started_at: Optional[str] = None
        # A thread has no OS identity of its own.
        self.pid: Optional[int] = None
        self.pgid: Optional[int] = None

    def start(self) -> None:
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self._thread = threading.Thread(
            target=self._body, name=f"workload-{self.name}", daemon=True
        )
        self._thread.start()

    def _body(self) -> None:
        # Local import breaks the module cycle (workers imports models; the
        # supervisor imports this module).
        from mln.workers import dispatch_workload

        try:
            dispatch_workload(self._payload, self._ctx)
            self._outcome, self._returncode = Outcome.COMPLETED, 0
        except WorkloadStopped:
            # Asked to stop; that is not a failure.
            self._outcome, self._returncode = Outcome.COMPLETED, 0
        except SystemExit as exc:
            code = exc.code if isinstance(exc.code, int) else (0 if exc.code is None else 1)
            self._outcome = Outcome.COMPLETED if code == 0 else Outcome.FAILED
            self._returncode = code
        except BaseException as exc:  # noqa: BLE001 — a worker fault is a failed
            # outcome, never a supervisor crash.
            self._ctx.log(f"workload error: {exc}")
            self._outcome, self._returncode = Outcome.FAILED, 1

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def stop(self) -> None:
        self._ctx.request_stop()
        if self._thread is not None:
            # Best-effort: a cooperative worker unwinds well within this; a
            # wedged one cannot be forced, and is_running() will stay True.
            self._thread.join(timeout=5)

    def outcome(self) -> Optional[Outcome]:
        if self.is_running():
            return None
        return self._outcome

    @property
    def returncode(self) -> Optional[int]:
        """Synthesized exit status for the supervisor to bubble up.

        Not part of :class:`Workload`; parallels ``SubprocessWorkload`` so the
        supervisor can read one attribute for both.
        """
        if self.is_running():
            return None
        return self._returncode
