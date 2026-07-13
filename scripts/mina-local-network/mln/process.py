"""Process tracking, readiness, and teardown helpers for Mina local-network."""

from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import time
from pathlib import Path
from typing import Dict, Optional

from mln.errors import (
    ErrorCode,
    NetworkError,
    ProcessTrackingError,
    SpawnError,
)
from mln.models import ProcessesFileEntry
from mln.paths import REPO_ROOT
from mln.process_types import StopChecker, WatchedProcess


def pid_is_running(pid: int) -> bool:
    """Check whether a process with the given PID is still running."""
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def processes_path(state_root: str) -> Path:
    """Return the canonical processes.json path under *state_root*."""
    return Path(state_root) / "processes.json"


def _kill_process_group(pgid: Optional[int], sig: int) -> None:
    """Best-effort kill of a process group.  No-op when pgid is None."""
    if pgid is None:
        return
    try:
        os.killpg(pgid, sig)
    except (OSError, ProcessLookupError):
        pass


def teardown_process(
    proc: Optional[WatchedProcess], pgid: Optional[int], timeout: int = 3
) -> bool:
    """Terminate a single process and wait for it to die.

    Uses process-group signalling when *pgid* is available; otherwise falls
    back to ``proc.terminate()`` / ``proc.kill()``.

    Returns True when the process is confirmed dead, False if unconfirmed.
    """
    if proc is None:
        return True
    if proc.poll() is not None:
        if pgid is not None:
            _kill_process_group(pgid, signal.SIGTERM)
        return True

    if pgid is not None:
        _kill_process_group(pgid, signal.SIGTERM)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            _kill_process_group(pgid, signal.SIGKILL)
            try:
                proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                pass
    else:
        try:
            proc.terminate()
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                proc.kill()
                proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                pass
        except (OSError, ProcessLookupError):
            pass

    return proc.poll() is not None


def wait_for_daemon_ready(
    mina_exe: str,
    client_port: int,
    env: Dict[str, str],
    timeout_sec: float = 60,
    interval_sec: float = 1,
    should_stop: Optional[StopChecker] = None,
    watched_proc: Optional[WatchedProcess] = None,
) -> None:
    """Poll the Mina daemon's client endpoint until it responds.

    Runs ``<mina_exe> client status -daemon-port <client_port>`` in a
    short-lived subprocess at each interval.

    Returns normally (``None``) when the daemon is ready.
    """
    deadline = time.time() + timeout_sec

    while time.time() < deadline:
        if should_stop is not None and should_stop():
            raise SystemExit(143)

        if watched_proc is not None and watched_proc.poll() is not None:
            code = watched_proc.returncode
            raise SpawnError(
                ErrorCode.DAEMON_READY_TIMEOUT,
                message=f"Daemon process exited with code {code} before becoming ready. "
                f"Check daemon logs for errors.",
            )

        result = subprocess.run(
            [mina_exe, "client", "status", "-daemon-port", str(client_port)],
            env=env,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return

        time.sleep(interval_sec)

    raise NetworkError(
        ErrorCode.DAEMON_READY_TIMEOUT,
        message=f"Daemon client not ready after {timeout_sec}s. Check daemon logs for errors.",
    )


def wait_for_tcp_ready(
    host: str,
    port: int,
    timeout_sec: float = 60,
    interval_sec: float = 1,
    should_stop: Optional[StopChecker] = None,
    watched_proc: Optional[WatchedProcess] = None,
    label: str = "",
) -> None:
    """Poll a TCP port until it accepts connections.

    Returns normally (``None``) when the port is reachable.
    """
    deadline = time.time() + timeout_sec

    while time.time() < deadline:
        if should_stop is not None and should_stop():
            raise SystemExit(143)

        try:
            with socket.create_connection((host, port), timeout=1.0):
                return
        except (ConnectionRefusedError, OSError, socket.timeout):
            pass

        if watched_proc is not None and watched_proc.poll() is not None:
            code = watched_proc.returncode
            raise SpawnError(
                ErrorCode.TCP_READY_TIMEOUT,
                message=f"{label} process exited with code {code} before "
                f"{host}:{port} became ready.",
            )

        time.sleep(interval_sec)

    raise NetworkError(
        ErrorCode.TCP_READY_TIMEOUT,
        message=f"{label} not ready on {host}:{port} after {timeout_sec}s.",
    )


def read_processes_json(state_root: str) -> Dict[str, ProcessesFileEntry]:
    """Read processes.json, returning empty dict if missing.

    Each entry is validated against :class:`ProcessesFileEntry` so callers
    get typed field access (``entry.pid`` rather than ``entry.get("pid")``).
    """
    pp = processes_path(state_root)
    if not pp.exists():
        return {}
    try:
        raw: dict = json.loads(pp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ProcessTrackingError(
            ErrorCode.PROCESS_TRACKING_PARSE,
            message=f"Failed to parse {pp}: {exc}\n"
            "The file may be corrupt. Remove it to continue.",
            path=str(pp),
        ) from exc
    return {k: ProcessesFileEntry.model_validate(v) for k, v in raw.items()}


def write_processes_json(
    state_root: str, processes: Dict[str, ProcessesFileEntry]
) -> None:
    """Persist process tracking to processes.json.

    Each entry is serialized via :meth:`ProcessesFileEntry.model_dump` so
    the on-disk JSON shape is unchanged from the pre-model era.
    """
    pp = processes_path(state_root)
    pp.parent.mkdir(parents=True, exist_ok=True)
    serialized = {k: v.model_dump(mode="json") for k, v in processes.items()}
    pp.write_text(json.dumps(serialized, indent=2, sort_keys=True), encoding="utf-8")


def resolve_existing_executable(path_value: str, *, label: str) -> str:
    """Resolve an executable path against the current worktree and validate it."""
    path = Path(path_value).expanduser()
    if not path.is_absolute():
        path = (REPO_ROOT / path).resolve()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise SpawnError(
            ErrorCode.BINARY_NOT_FOUND,
            message=f"{label} not found or not executable: {path}\n"
            f"Build the binary first or set the corresponding 'binaries' field "
            f"in the topology to the correct path.",
            path=str(path),
            entity=label,
        )
    return str(path)
