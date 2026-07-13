"""Spawn‑lifecycle helpers: launch, readiness gates, supervisor loop."""

from __future__ import annotations

import datetime
import os
import subprocess
import time
from typing import Callable, Dict, List, Optional, Tuple

import click

from mln.constants import DEFAULT_PRIVKEY_PASS
from mln.errors import GraphQLError, NetworkError, SpawnError
from mln.models import ProcessKind, TrackedProcess


def launch_process(entry: TrackedProcess) -> TrackedProcess:
    """Start a tracked process via ``subprocess.Popen`` and record runtime state.

    The *entry* model is mutated in‑place with ``pid``, ``proc``, ``pgid``,
    ``started_at``, and ``state``.  Returns *entry* for fluent chaining.
    """
    full_env = os.environ.copy()
    full_env.update(entry.env)
    proc = subprocess.Popen(
        entry.argv,
        env=full_env,
        start_new_session=True,
    )
    entry.proc = proc
    entry.pid = proc.pid
    entry.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    # start_new_session=True makes the child its own session leader, so its
    # PGID equals its PID.  Using proc.pid directly avoids a getpgid() race.
    entry.pgid = proc.pid
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
    procs_table: List[TrackedProcess],
    teardown_fn: Callable[[], None],
    persist_fn: Callable[[], None],
    should_stop_fn: Callable[[], bool],
) -> int:
    """Supervise the process table, polling every 200 ms, returning exit code."""
    while True:
        exited_entries: List[Tuple[TrackedProcess, int]] = []
        for entry in procs_table:
            if entry.proc is not None and entry.proc.poll() is not None:
                exited_entries.append((entry, entry.proc.returncode or 0))

        if exited_entries:
            core_exit = next(
                (
                    (entry, _code)
                    for entry, _code in exited_entries
                    if entry.kind != ProcessKind.WORKLOAD
                ),
                None,
            )
            if core_exit is not None:
                _entry, first_exited_code = core_exit
                click.echo("A process exited — tearing down...", err=True)
                teardown_fn()
                return first_exited_code

            failing_workload = next(
                (
                    (entry, _code)
                    for entry, _code in exited_entries
                    if _code != 0 or not entry.success_exits_keep_network
                ),
                None,
            )
            if failing_workload is not None:
                _entry, first_exited_code = failing_workload
                click.echo(
                    f"Workload exited with code {first_exited_code} — tearing down...",
                    err=True,
                )
                teardown_fn()
                return first_exited_code

            for entry, _code in exited_entries:
                click.echo(
                    f"Workload '{entry.name}' completed successfully "
                    f"(exit 0) — network continues running.",
                    err=True,
                )
                entry.state = "stopped"
                entry.proc = None
            persist_fn()
            continue

        if should_stop_fn():
            click.echo("Shutting down...", err=True)
            teardown_fn()
            return 143

        time.sleep(0.2)
