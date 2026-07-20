"""Spawn orchestrator for Mina local networks.

The sole public entry point is :func:`spawn_instance_from_plan`.  All
supporting types, ITN helpers, workload builders, process‑table
construction, and lifecycle helpers live in sibling modules of this
package:

* ``.types``           — ``DaemonEntry``, ``ItnInjectionResult``, etc.
* ``.itn``             — ``prepare_itn_injection``
* ``.workloads``       — workload argv builders and pubkey validation
* ``.process_table``   — ``build_process_table``
* ``.lifecycle``       — ``launch_process``, ``build_daemon_env``,
                          ``run_readiness_gate``, ``supervise_processes``

This module retains only the imperative shell: validation, daemon‑entry
construction, signal‑handler installation, the spawn loop, and teardown.
"""

from __future__ import annotations

import json
import os
import signal
import sys
from datetime import datetime, timezone
from typing import Dict, List, Optional

from mln.errors import (
    ErrorCode,
    SpawnError,
)
from mln.graphql import (
    daemon_genesis_timestamp,
    wait_for_genesis,
    wait_for_graphql_ready,
)
from mln.models import (
    CoreProcessEntry,
    MaterializedManifest,
    ProcessEntry,
    ProcessesFileEntry,
    ProcessKind,
    ResolvedNode,
    ResolvedPlan,
    ResolvedService,
    ResolvedWorker,
    ServiceKind,
    WorkloadConfig,
    WorkloadEntry,
    WorkloadPayload,
    WorkloadStart,
    WorkloadType,
)
from mln.optionals import option_map
from mln.plan import materialize_daemon_argv
from mln.postgres import check_external_postgres
from mln.process import (
    pid_is_running,
    processes_path,
    read_processes_json,
    resolve_existing_executable,
    teardown_process,
    wait_for_daemon_ready,
    wait_for_tcp_ready,
    write_processes_json,
)
from mln.process_types import StopChecker
from mln.spawn.itn import prepare_itn_injection
from mln.spawn.lifecycle import (
    build_daemon_env,
    launch_process,
    launch_workload,
    run_readiness_gate,
    supervise_processes,
)
from mln.spawn.process_table import build_process_table
from mln.spawn.types import DaemonEntry

AFTER_GENESIS_WORKLOAD_TIMEOUT_SEC: int = 30 * 60

# How long a daemon may take to answer GraphQL before the genesis gate gives up.
# Generous: a daemon rebuilding a large genesis ledger on a cold cache takes
# minutes, and this bounds start-up cost, not the thing being checked.
GENESIS_GATE_READY_TIMEOUT_SEC: int = 15 * 60
GENESIS_GATE_POLL_INTERVAL_SEC: float = 0.1


# ── Genesis gate ─────────────────────────────────────────────────────


def assert_daemons_ready_before_genesis(
    entries: List[DaemonEntry],
    *,
    procs: Dict[str, CoreProcessEntry],
    should_stop: Optional[StopChecker] = None,
) -> None:
    """Fail unless every daemon is up while genesis is still ahead of it.

    A daemon that comes up after genesis does not complain.  It produces nothing
    for the slots it slept through and says nothing about why, because from its
    own point of view nothing went wrong; the run fails later looking like
    something else — a chain shorter than expected, or occupancy that never
    recovers.  Caught here, the report names the network's own deadline.

    A daemon that exits BEFORE it is ready fails here too, and deliberately: it
    never started, which is not the same as a network that ran and stopped.  Once
    a daemon is ready, its exit is the supervisor's business and no concern of
    this gate's.

    Waits for each daemon's GraphQL before asking it, so this is also what
    establishes that every daemon came up at all — the spawn loop gates only the
    seed.

    Genesis is read from each daemon rather than from the plan or from
    ``daemon.json``; see :func:`mln.graphql.daemon_genesis_timestamp` for why
    there is no static fallback.
    """
    for entry in entries:
        if entry.rest_port is None:
            raise SpawnError(
                ErrorCode.SPAWN_GENESIS_ALREADY_PASSED,
                message=f"Daemon '{entry.name}' has no REST endpoint, so it cannot be "
                f"asked when its genesis is.",
            )
        uri = f"http://127.0.0.1:{entry.rest_port}/graphql"
        tracked = procs.get(entry.name)

        wait_for_graphql_ready(
            graphql_uri=uri,
            timeout_sec=GENESIS_GATE_READY_TIMEOUT_SEC,
            # Polled tightly because this sits on the startup path of every spawn:
            # a daemon that is already up should not be waited on for a whole
            # second just to notice.
            interval_sec=GENESIS_GATE_POLL_INTERVAL_SEC,
            should_stop=should_stop,
            watched_proc=tracked.proc if tracked is not None else None,
            label=f"GraphQL ({entry.name})",
        )

        genesis = daemon_genesis_timestamp(uri)
        remaining = (genesis - datetime.now(timezone.utc)).total_seconds()
        if remaining <= 0:
            raise SpawnError(
                ErrorCode.SPAWN_GENESIS_ALREADY_PASSED,
                message=f"Daemon '{entry.name}' became ready {-remaining:.0f}s after its "
                f"genesis ({genesis.isoformat()}), so it has already missed the start of "
                f"the chain and will produce nothing for the slots it slept through.\n\n"
                f"The network needs longer between being spawned and the genesis it was "
                f"given: either move genesis further out, or spawn sooner.",
            )
        print(
            f"Daemon '{entry.name}' ready, genesis in {remaining:.0f}s "
            f"({genesis.isoformat()})",
            file=sys.stderr,
        )


# ── Topology reporting ───────────────────────────────────────────────


def emit_topology(plan: ResolvedPlan) -> None:
    """Print the resolved topology as JSON on stdout.

    Emitted before any process starts, so the intended network is visible
    even when a later readiness gate fails and nothing comes up.  The
    spawn loop otherwise reports only per‑process lines, which never show
    the network as a whole — a wrong node or worker count stays invisible.

    Goes to stdout (progress lines go to stderr) so it stays pipeable to
    jq, matching how ``plan topology`` emits the same structure.
    """
    print(json.dumps(plan.model_dump(mode="json", exclude_none=True), indent=2))


# ── Path absolutization ──────────────────────────────────────────────


def _absolutize_argv(argv: List[str], rel_root: str, abs_root: str) -> List[str]:
    """Replace relative state‑root paths in *argv* with absolute versions.

    All paths in the persisted plan are relative to the repo root
    (e.g. ``.mina-local-network/single/node/nodes/seed``).  Mina
    child processes may run from a different CWD, so every filesystem
    path that reaches a subprocess must be absolute.

    The helper finds any argv element whose value starts with
    *rel_root* and substitutes *abs_root* as the prefix.  The binary
    at ``argv[0]`` is also absolutised if it is a relative path.
    """
    result: List[str] = []
    for arg in argv:
        if arg.startswith(rel_root):
            result.append(abs_root + arg[len(rel_root) :])
        else:
            result.append(arg)
    # Absolutise the executable (argv[0]) when it is a relative path.
    if result and os.path.sep in result[0] and not os.path.isabs(result[0]):
        result[0] = os.path.abspath(result[0])
    return result


def _absolutize_payload(
    payload: WorkloadPayload, rel_root: str, abs_root: str
) -> WorkloadPayload:
    """Absolutise state-root-relative path fields in a workload payload.

    The same prefix substitution as :func:`_absolutize_argv`, applied to a
    payload's string fields — worker key/binary paths formerly rode in argv
    and were absolutised there.  The ``rel_root`` prefix (``.mina-local-network
    /...``) never matches a pubkey, URL, or amount, so this only touches paths.
    """
    updates = {
        name: abs_root + value[len(rel_root):]
        for name, value in payload
        if isinstance(value, str) and value.startswith(rel_root)
    }
    return payload.model_copy(update=updates) if updates else payload


# ── Orchestrator ────────────────────────────────────────────────────


def spawn_instance_from_plan(
    plan: ResolvedPlan, manifest: MaterializedManifest
) -> None:
    """Core spawn logic: validate plan, build process table, spawn, supervise, teardown.

    Exits via ``raise SystemExit(exit_code)``.  Callers must ensure
    *manifest* contains the ``keys`` section needed for token substitution.
    """
    emit_topology(plan)

    state_root = plan.state.root
    # Resolve the absolute state root so subprocess paths are safe (Mina
    # child processes may run from a different CWD than the spawner).
    abs_root: str = os.path.abspath(state_root)

    # ── Validate plan shape for this lifecycle slice ──────────────────
    nodes: List[ResolvedNode] = plan.nodes
    workers: List[ResolvedWorker] = plan.workers
    services: List[ResolvedService] = plan.services
    workloads: List[WorkloadConfig] = plan.workloads

    if len(nodes) < 1:
        raise SpawnError(
            ErrorCode.SPAWN_NO_NODES,
            message="spawn instance requires at least 1 daemon node, but the plan has 0 nodes.",
        )
    # ── Identify service entries ─────────────────────────────────────
    archive_svc: Optional[ResolvedService] = None
    rosetta_svc: Optional[ResolvedService] = None
    for svc in services:
        if svc.kind == ServiceKind.ARCHIVE:
            archive_svc = svc
        elif svc.kind == ServiceKind.ROSETTA:
            rosetta_svc = svc

    # Rosetta requires archive
    if rosetta_svc is not None and archive_svc is None:
        raise SpawnError(
            ErrorCode.SERVICE_MISSING_DEPENDENCY,
            message="The 'rosetta' service requires an 'archive' service in the plan. "
            "Add an archive service to the topology.",
        )
    # Rosetta requires a non-empty graphql URI
    if rosetta_svc is not None:
        rosetta_argv = rosetta_svc.argv
        try:
            gql_idx = rosetta_argv.index("--graphql-uri")
        except ValueError:
            raise SpawnError(
                ErrorCode.SERVICE_MISSING_DEPENDENCY,
                message="The rosetta service is missing a --graphql-uri argument.",
            )
        if gql_idx + 1 >= len(rosetta_argv) or not rosetta_argv[gql_idx + 1]:
            raise SpawnError(
                ErrorCode.SERVICE_MISSING_DEPENDENCY,
                message="The rosetta service --graphql-uri is empty. "
                "A daemon node with a REST/GraphQL endpoint is required.",
            )

    # ── External Postgres preflight (before any Popen) ───────────────
    if archive_svc is not None:
        pg_uri = archive_svc.postgres_uri
        if not pg_uri:
            raise SpawnError(
                ErrorCode.SERVICE_MISSING_DEPENDENCY,
                message="Archive service is missing postgres_uri in the resolved plan.",
            )
        check_external_postgres(pg_uri)

    # ── Refuse if processes.json indicates still-running children ──────
    existing_procs = read_processes_json(state_root)
    if existing_procs:
        for _pname, pinfo in existing_procs.items():
            pid = pinfo.pid
            if pid and pid_is_running(pid):
                raise SpawnError(
                    ErrorCode.PROCESSES_RUNNING,
                    message=f"Process '{_pname}' (pid {pid}) appears to still be running.\n"
                    f"Stop existing processes first, or remove {processes_path(state_root)}.",
                    entity=_pname,
                )
        # All tracked pids are stale — will be overwritten

    # ── Materialize argv for all daemon nodes ─────────────────────────
    _daemon_entries: List[DaemonEntry] = []
    for node in nodes:
        _dargv = materialize_daemon_argv(node.daemon_argv, manifest)
        _denv = build_daemon_env(node.env)
        _dname = node.name
        _endpoints = node.endpoints
        _client_ep = _endpoints.get("client")
        _rest_ep = _endpoints.get("rest")
        _itn_gql_ep = _endpoints.get("itn_graphql")
        _external_ep = _endpoints.get("external")
        _daemon_entries.append(
            DaemonEntry(
                name=_dname,
                argv=_dargv,
                env=_denv,
                client_port=option_map(_client_ep, lambda ep: ep.port),
                rest_port=option_map(_rest_ep, lambda ep: ep.port),
                itn_graphql_port=option_map(_itn_gql_ep, lambda ep: ep.port),
                external_port=option_map(_external_ep, lambda ep: ep.port),
                is_seed="--seed" in _dargv,
            )
        )

    # Identify seed daemon (first with --seed, or first overall as fallback)
    _seed_entry: Optional[DaemonEntry] = None
    for de in _daemon_entries:
        if de.is_seed:
            _seed_entry = de
            break
    if _seed_entry is None and _daemon_entries:
        _seed_entry = _daemon_entries[0]

    # Resolve seed REST GraphQL URI (zkapp/itn workloads target this)
    _seed_rest_port = option_map(_seed_entry, lambda se: se.rest_port)
    _rest_server = (
        f"http://127.0.0.1:{_seed_rest_port}/graphql" if _seed_rest_port else ""
    )
    # All daemon REST endpoints — value_transfer spreads its senders across these
    # so txns enter the network everywhere instead of only at the seed.
    _node_rest_uris = [
        f"http://127.0.0.1:{de.rest_port}/graphql"
        for de in _daemon_entries
        if de.rest_port
    ]

    # ── ITN max-cost preflight & key generation ────────────────────
    # Must happen before the process table is built (and before any
    # Popen) so the generated ITN public key is injected into daemon argv.
    # prepare_itn_injection mutates DaemonEntry.argv in‑place on the
    # entry carrying --itn-graphql-port.
    _itn_result = prepare_itn_injection(workloads, _daemon_entries, state_root)

    # Validate ITN GraphQL endpoint exists for any itn_max_cost workloads
    for _iwl in _itn_result.itn_workloads:
        if not _iwl.itn_graphql_uri:
            raise SpawnError(
                ErrorCode.SERVICE_MISSING_DEPENDENCY,
                message=f"Workload '{_iwl.name}' is itn_max_cost but the plan has no "
                "itn_graphql_uri for its target node. Ensure the node has "
                "itn_graphql capability in the topology.",
            )

    # ── Build the process table (list, ordered by spawn) ──────────────
    procs_table: List[ProcessEntry] = build_process_table(
        archive_svc=archive_svc,
        daemon_entries=_daemon_entries,
        workers=workers,
        rosetta_svc=rosetta_svc,
        workloads=workloads,
        keys=manifest.keys,
        rest_server=_rest_server,
        node_rest_servers=_node_rest_uris,
        mina_exe=plan.binaries.mina,
        zkapp_exe=plan.binaries.zkapp,
        itn_result=_itn_result,
    )

    # ── Absolutise filesystem paths for all subprocess argv ───────────
    # Persisted plans carry relative state‑root paths; Mina child
    # processes must receive absolute paths so they work regardless of
    # the child's CWD.
    for entry in procs_table:
        entry.argv = _absolutize_argv(entry.argv, state_root, abs_root)
        if isinstance(entry, WorkloadEntry) and entry.payload is not None:
            entry.payload = _absolutize_payload(entry.payload, state_root, abs_root)

    # ── Precheck ALL binaries before any Popen ───────────────────────
    # Python workers run in-thread from a payload and have no argv[0] binary of
    # their own; the binaries they shell out to (mina, zkApp) are prechecked
    # via the daemon entries and the explicit zkApp check below.
    for entry in procs_table:
        if not entry.argv:
            continue
        binary = entry.argv[0]
        if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
            kind_label = (
                entry.kind.value if isinstance(entry, CoreProcessEntry) else "workload"
            )
            raise SpawnError(
                ErrorCode.BINARY_NOT_FOUND,
                message=f"Binary for {kind_label} '{entry.name}' not found "
                f"or not executable: {binary}\n"
                f"Build the required binary first or set the appropriate "
                f"'binaries' or per-service 'binary' field in the topology.",
                path=binary,
                entity=entry.name,
            )

    # ── Explicit zkApp binary precheck (worker argv[0] is python, not the exe) ──
    _has_zkapp_workloads = any(
        isinstance(e, WorkloadEntry) and e.type == WorkloadType.ZKAPP
        for e in procs_table
    )
    if _has_zkapp_workloads:
        resolve_existing_executable(plan.binaries.zkapp, label="zkApp binary")

    # ── Install signal handlers BEFORE first Popen ───────────────────
    _shutdown_requested = False

    def _signal_handler(signum: int, _frame):
        nonlocal _shutdown_requested
        _shutdown_requested = True

    prev_sigint = signal.signal(signal.SIGINT, _signal_handler)
    prev_sigterm = signal.signal(signal.SIGTERM, _signal_handler)

    # ── Reusable teardown helpers ────────────────────────────────────
    def _teardown_all():
        for entry in reversed(procs_table):
            if entry.state == "stopped":
                continue
            match entry:
                case WorkloadEntry():
                    if entry.workload is not None:
                        # Workloads stop through their handle (group-signalling
                        # under the hood, so grandchildren are reaped).
                        entry.workload.stop()
                        if not entry.workload.is_running():
                            entry.state = "stopped"
                case CoreProcessEntry():
                    if entry.proc is not None:
                        dead = teardown_process(entry.proc, entry.pgid, timeout=3)
                        if dead:
                            entry.state = "stopped"

    def _cleanup_persisted_state():
        pp = processes_path(state_root)
        if pp.exists():
            pp.unlink()
        signal.signal(signal.SIGINT, prev_sigint)
        signal.signal(signal.SIGTERM, prev_sigterm)

    def _persist_processes_json():
        processes: Dict[str, ProcessesFileEntry] = {}
        for pe in procs_table:
            processes[pe.name] = pe.to_processes_json_entry()
        write_processes_json(state_root, processes)

    # ── Resolve readiness ports ──────────────────────────────────────
    _archive_port = option_map(archive_svc, lambda s: s.port)
    _rosetta_port = option_map(rosetta_svc, lambda s: s.port)
    # ── Spawn processes ──────────────────────────────────────────────
    exit_code = 0
    _coordinator_ports_gated: set[int] = set()

    try:

        def _should_stop() -> bool:
            return _shutdown_requested

        for entry in procs_table:
            # Workloads are appended to the same process table so they can be
            # supervised and torn down uniformly, but they must not be spawned
            # in the core process phase.  Their start policy/readiness gates
            # are handled below in Phase 2.5.
            if isinstance(entry, WorkloadEntry):
                continue

            # ── Coordinator readiness gate (before first snark worker) ──
            if entry.kind == ProcessKind.SNARK_WORKER and workers:
                for _w in workers:
                    _cport = _w.coordinator_port
                    if _cport in _coordinator_ports_gated:
                        continue
                    _coordinator_ports_gated.add(_cport)
                    _coord_de = next(
                        (de for de in _daemon_entries if de.client_port == _cport),
                        None,
                    )
                    if _coord_de is None:
                        continue
                    _coord_tp = next(
                        (
                            tp
                            for tp in procs_table
                            if isinstance(tp, CoreProcessEntry)
                            and tp.kind == ProcessKind.DAEMON
                            and tp.client_port == _cport
                        ),
                        None,
                    )
                    result = run_readiness_gate(
                        lambda cport=_cport, de=_coord_de, tp=_coord_tp: (
                            wait_for_daemon_ready(
                                mina_exe=de.argv[0],
                                client_port=cport,
                                env={**os.environ, **de.env},
                                timeout_sec=float("inf"),
                                interval_sec=10,
                                should_stop=_should_stop,
                                watched_proc=tp.proc if tp is not None else None,
                            )
                        ),
                        _teardown_all,
                    )
                    if result is not None:
                        exit_code = result
                        break
                if exit_code:
                    break

            # .value, not the enum itself: ProcessKind is a (str, Enum), and
            # from Python 3.11 on those format via __str__ ("ProcessKind.DAEMON")
            # rather than their value ("daemon").
            print(f"Starting {entry.kind.value} '{entry.name}'...", file=sys.stderr)
            launch_process(entry)
            print(f"{entry.kind.value} '{entry.name}' PID: {entry.pid}", file=sys.stderr)

            # ── Readiness gate: archive TCP port ──
            if entry.kind == ProcessKind.ARCHIVE and _archive_port is not None:
                result = run_readiness_gate(
                    lambda: wait_for_tcp_ready(
                        host="127.0.0.1",
                        port=_archive_port,
                        timeout_sec=30,
                        interval_sec=1,
                        should_stop=_should_stop,
                        watched_proc=entry.proc,
                        label="Archive",
                    ),
                    _teardown_all,
                )
                if result is not None:
                    exit_code = result
                    break

            # ── Readiness gate: seed daemon client status ──
            if (
                entry.kind == ProcessKind.DAEMON
                and _seed_entry is not None
                and entry.name == _seed_entry.name
            ):
                _daemon_client_port: Optional[int] = entry.client_port
                if _daemon_client_port is not None:
                    _dcp: int = _daemon_client_port  # narrowed for lambda
                    result = run_readiness_gate(
                        lambda: wait_for_daemon_ready(
                            mina_exe=entry.argv[0],
                            client_port=_dcp,
                            env={**os.environ, **entry.env},
                            timeout_sec=float("inf"),
                            interval_sec=10,
                            should_stop=_should_stop,
                            watched_proc=entry.proc,
                        ),
                        _teardown_all,
                    )
                    if result is not None:
                        exit_code = result
                        break

            # ── Readiness gate: GraphQL endpoint (before rosetta, seed only) ──
            if (
                entry.kind == ProcessKind.DAEMON
                and rosetta_svc is not None
                and _seed_entry is not None
                and entry.name == _seed_entry.name
            ):
                graphql_uri = rosetta_svc.graphql_uri or ""
                if graphql_uri:
                    result = run_readiness_gate(
                        lambda: wait_for_graphql_ready(
                            graphql_uri=graphql_uri,
                            timeout_sec=60,
                            interval_sec=1,
                            should_stop=_should_stop,
                            watched_proc=entry.proc,
                            label="GraphQL",
                        ),
                        _teardown_all,
                    )
                    if result is not None:
                        exit_code = result
                        break

            # ── Readiness gate: rosetta TCP port ──
            if entry.kind == ProcessKind.ROSETTA and _rosetta_port is not None:
                result = run_readiness_gate(
                    lambda: wait_for_tcp_ready(
                        host="127.0.0.1",
                        port=_rosetta_port,
                        timeout_sec=30,
                        interval_sec=1,
                        should_stop=_should_stop,
                        watched_proc=entry.proc,
                        label="Rosetta",
                    ),
                    _teardown_all,
                )
                if result is not None:
                    exit_code = result
                    break

        # Phase 2/2.5/3: only proceed when core startup succeeded (exit_code == 0).
        # If a readiness gate or shutdown already set a nonzero exit_code, skip
        # persistence, workload spawn, and the supervisor loop — teardown will
        # run via the finally block.
        if exit_code == 0:
            # Phase 2: persist core process tracking
            _persist_processes_json()

        # ── Genesis gate: every daemon up while genesis is still ahead ──
        #
        # Checked once here rather than per-entry in the loop above: the property
        # is about the network, and it is the LAST daemon up that decides whether
        # it holds.
        #
        # After process tracking is written, not before: this waits on daemons,
        # and while it waits the pids it is waiting on should already be on record
        # — for anything watching the network, and for a teardown that has to find
        # them.
        if exit_code == 0 and _daemon_entries:
            _daemon_procs: Dict[str, CoreProcessEntry] = {
                e.name: e
                for e in procs_table
                if isinstance(e, CoreProcessEntry) and e.kind == ProcessKind.DAEMON
            }
            result = run_readiness_gate(
                lambda: assert_daemons_ready_before_genesis(
                    _daemon_entries,
                    procs=_daemon_procs,
                    should_stop=_should_stop,
                ),
                _teardown_all,
            )
            if result is not None:
                exit_code = result

        if exit_code == 0:

            # Phase 2.5: spawn workloads after core readiness gates
            _seed_daemon_name = option_map(_seed_entry, lambda e: e.name)
            _daemon_proc = next(
                (
                    e.proc
                    for e in procs_table
                    if isinstance(e, CoreProcessEntry)
                    and e.kind == ProcessKind.DAEMON
                    and e.name == _seed_daemon_name
                ),
                None,
            )
            if _daemon_proc is None:
                _daemon_proc = next(
                    (
                        e.proc
                        for e in procs_table
                        if isinstance(e, CoreProcessEntry)
                        and e.kind == ProcessKind.DAEMON
                    ),
                    None,
                )
            for e in procs_table:
                if not isinstance(e, WorkloadEntry) or e.state == "running":
                    continue
                wl_start = e.start or WorkloadStart.IMMEDIATE
                wl_graphql_uri = e.graphql_uri or ""

                # ── Readiness gate for workload ──
                if wl_start == WorkloadStart.AFTER_GRAPHQL_READY:
                    if not wl_graphql_uri:
                        print(
                            f"WARNING: workload '{e.name}' wants "
                            f"after_graphql_ready but no GraphQL URI is "
                            f"available; skipping readiness gate.",
                            file=sys.stderr,
                        )
                    else:
                        _wl_uri: str = wl_graphql_uri  # narrowed for lambda
                        result = run_readiness_gate(
                            lambda: wait_for_graphql_ready(
                                graphql_uri=_wl_uri,
                                timeout_sec=60,
                                interval_sec=1,
                                should_stop=_should_stop,
                                watched_proc=_daemon_proc,
                                label=f"GraphQL (workload {e.name})",
                            ),
                            _teardown_all,
                        )
                        if result is not None:
                            exit_code = result
                            break

                elif wl_start == WorkloadStart.AFTER_GENESIS:
                    if not wl_graphql_uri:
                        print(
                            f"WARNING: workload '{e.name}' wants "
                            f"after_genesis but no GraphQL URI is "
                            f"available; skipping readiness gate.",
                            file=sys.stderr,
                        )
                    else:
                        _wl_uri_gen: str = wl_graphql_uri  # narrowed for lambda
                        result = run_readiness_gate(
                            lambda: wait_for_genesis(
                                graphql_uri=_wl_uri_gen,
                                timeout_sec=AFTER_GENESIS_WORKLOAD_TIMEOUT_SEC,
                                interval_sec=2,
                                should_stop=_should_stop,
                                watched_proc=_daemon_proc,
                                label=f"genesis (workload {e.name})",
                            ),
                            _teardown_all,
                        )
                        if result is not None:
                            exit_code = result
                            break

                # ── Spawn the workload ──
                print(
                    f"Starting workload '{e.name}'"
                    f" (type={e.type.value if e.type else '?'},"
                    f" start={wl_start.value})...",
                    file=sys.stderr,
                )
                launch_workload(e)
                print(f"workload '{e.name}' PID: {e.pid}", file=sys.stderr)

                # Refresh processes.json after each workload spawn
                _persist_processes_json()

            # Phase 3: supervisor loop  (only when start-up + workload gates
            # succeeded — exit_code is still 0 here)
            if exit_code == 0:
                exit_code = supervise_processes(
                    procs_table,
                    _teardown_all,
                    _persist_processes_json,
                    lambda: _shutdown_requested,
                )

        print(f"All processes exited with code {exit_code}", file=sys.stderr)

    finally:
        try:
            try:
                _teardown_all()
            except Exception as exc:
                print(f"Warning: teardown failed: {exc}", file=sys.stderr)
        finally:
            _cleanup_persisted_state()

    raise SystemExit(exit_code)
