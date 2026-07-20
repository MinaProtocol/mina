"""Spawn‑lifecycle helpers: launch, readiness gates, supervisor loop."""

from __future__ import annotations

import datetime
import sys
import time
from typing import Callable, Dict, List, Optional, Tuple

from mln.constants import DEFAULT_PRIVKEY_PASS
from mln.errors import GraphQLError, NetworkError, SpawnError
from mln.models import CoreProcessEntry, ProcessEntry, WorkloadEntry
from mln.process import spawn_tagged_process
from mln.workload import Outcome, RunHandle, SubprocessWorkload, ThreadWorkload


def launch_process(entry: CoreProcessEntry) -> CoreProcessEntry:
    """Start a tracked process via ``subprocess.Popen`` and record runtime state.

    The *entry* model is mutated in‑place with ``pid``, ``proc``, ``pgid``,
    ``started_at``, and ``state``.  Returns *entry* for fluent chaining.

    Child stdout and stderr are streamed to the parent's stdout/stderr line by
    line with a ``[{entry.name}] `` prefix, matching the legacy shell-based
    ``tag-stdout`` behaviour.
    """
    proc = spawn_tagged_process(entry.argv, entry.env, entry.name)
    entry.proc = proc
    entry.pid = proc.pid
    entry.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    # start_new_session=True makes the child its own session leader, so its
    # PGID equals its PID.  Using proc.pid directly avoids a getpgid() race.
    entry.pgid = proc.pid
    entry.state = "running"
    return entry


def launch_workload(entry: WorkloadEntry) -> WorkloadEntry:
    """Start a workload entry via a :class:`Workload` handle.

    A Python worker (carrying a typed ``payload``) runs in-process on a
    :class:`ThreadWorkload`; an echo workload (an arbitrary external command,
    carrying ``argv``) runs on a :class:`SubprocessWorkload`.  Unlike
    :func:`launch_process`, the entry gets no ``proc`` — a workload is not a
    process to the supervisor.  ``pid``/``pgid``/``started_at`` are mirrored
    from the handle (``None`` for a thread) so ``processes.json`` and the
    stale-children guard keep working.
    """
    handle: SubprocessWorkload | ThreadWorkload
    if entry.payload is not None:
        handle = ThreadWorkload(entry.name, entry.payload, entry.env)
    else:
        handle = SubprocessWorkload(entry.name, entry.argv, entry.env)
    handle.start()
    entry.workload = handle
    print(f"[{entry.name}] started", file=sys.stderr)
    entry.pid = handle.pid
    entry.pgid = handle.pgid
    entry.started_at = handle.started_at
    entry.state = "running"
    return entry


def build_daemon_env(node_env: Dict[str, str]) -> Dict[str, str]:
    """Construct daemon environment dict with ``MINA_PRIVKEY_PASS`` default."""
    env = dict(node_env)
    env.setdefault("MINA_PRIVKEY_PASS", DEFAULT_PRIVKEY_PASS)
    return env


def run_readiness_gate(
    gate_fn: Callable[[], None],
    teardown_fn: Callable[[], None],
) -> Optional[int]:
    """Run a readiness‑gate wait function with standard error‑handling.

    Returns ``None`` on success, ``143`` on ``SystemExit``.
    Re‑raises ``NetworkError``/``SpawnError``/``GraphQLError`` after teardown.
    """
    try:
        gate_fn()
    except SystemExit:
        teardown_fn()
        return 143
    except (NetworkError, SpawnError, GraphQLError):
        teardown_fn()
        raise
    return None


def supervise_processes(
    procs_table: List[ProcessEntry],
    teardown_fn: Callable[[], None],
    persist_fn: Callable[[], None],
    should_stop_fn: Callable[[], bool],
) -> int:
    """Supervise the process table, polling every 200 ms, returning exit code.

    ``CoreProcessEntry`` items are polled as real processes — ``proc.poll()``,
    exit codes honest.  ``WorkloadEntry`` items are polled as
    :class:`~mln.workload_types.RunHandle` handles — ``is_running()`` /
    ``outcome()``, *not* an exit code.  A workload's raw subprocess exit code is
    still carried alongside so a failure can bubble up as this supervisor's own
    return status, but the keep-network *decision* keys off the outcome.
    """
    while True:
        exited_core: List[Tuple[CoreProcessEntry, int]] = []
        finished_workloads: List[Tuple[WorkloadEntry, RunHandle, int]] = []
        for entry in procs_table:
            match entry:
                case CoreProcessEntry():
                    if entry.proc is not None and entry.proc.poll() is not None:
                        exited_core.append((entry, entry.proc.returncode or 0))
                case WorkloadEntry():
                    handle = entry.workload
                    if (
                        entry.state != "stopped"
                        and handle is not None
                        and not handle.is_running()
                    ):
                        finished_workloads.append(
                            (entry, handle, handle.returncode or 0)
                        )

        # ── Core-process exits take priority over workloads ───────────────
        if exited_core:
            expected_ok = [
                (entry, code)
                for entry, code in exited_core
                if entry.expected_exit and code == 0
            ]
            for entry, _code in expected_ok:
                print(
                    f"Process '{entry.name}' exited successfully as expected "
                    f"— network continues running.",
                    file=sys.stderr,
                )
                entry.state = "stopped"
                entry.proc = None
            if expected_ok:
                persist_fn()

            unexpected = [
                (entry, code)
                for entry, code in exited_core
                if not (entry.expected_exit and code == 0)
            ]
            if unexpected:
                _entry, first_exited_code = unexpected[0]
                print("A process exited — tearing down...", file=sys.stderr)
                teardown_fn()
                return first_exited_code

        # ── Then workloads: tear down on a failed outcome, or when a completed
        #    workload is marked not to keep the network. ────────────────────
        if finished_workloads:
            failing = next(
                (
                    (entry, code)
                    for entry, handle, code in finished_workloads
                    if handle.outcome() == Outcome.FAILED
                    or not entry.success_exits_keep_network
                ),
                None,
            )
            if failing is not None:
                failed_entry, first_exited_code = failing
                print(
                    f"[{failed_entry.name}] exited with code {first_exited_code} "
                    f"— tearing down...",
                    file=sys.stderr,
                )
                teardown_fn()
                return first_exited_code

            for entry, _handle, _code in finished_workloads:
                print(
                    f"[{entry.name}] completed successfully "
                    f"— network continues running.",
                    file=sys.stderr,
                )
                entry.state = "stopped"
            persist_fn()
            continue

        # Only expected core exits this tick (already handled) — keep looping.
        if exited_core:
            continue

        if should_stop_fn():
            print("Shutting down...", file=sys.stderr)
            teardown_fn()
            return 143

        time.sleep(0.2)
