"""Process‑table construction from typed plan pieces.

The main entry point is :func:`build_process_table`.
"""

from __future__ import annotations

import sys
from typing import Dict, List, Optional

from mln.errors import ErrorCode, WorkloadError
from mln.models import (
    CoreProcessEntry,
    EchoWorkload,
    ItnMaxCostWorkload,
    KeyRecord,
    ProcessEntry,
    ProcessKind,
    ResolvedService,
    ResolvedWorker,
    ValueTransferWorkload,
    WorkloadConfig,
    WorkloadEntry,
    WorkloadPayload,
    WorkloadStart,
    WorkloadType,
    ZkappWorkload,
)
from mln.spawn.types import DaemonEntry, ItnInjectionResult
from mln.spawn.workloads import (
    build_echo_argv,
    build_itn_max_cost_payload,
    build_value_transfer_payload,
    build_zkapp_payload,
    validate_workload_pubkey_conflicts,
)


def _has_hardfork_migrate_exit(argv: List[str]) -> bool:
    try:
        flag_index = argv.index("--hardfork-handling")
    except ValueError:
        return False
    return flag_index + 1 < len(argv) and argv[flag_index + 1] == "migrate-exit"


def build_process_table(
    archive_svc: Optional[ResolvedService],
    daemon_entries: List[DaemonEntry],
    workers: List[ResolvedWorker],
    rosetta_svc: Optional[ResolvedService],
    workloads: List[WorkloadConfig],
    keys: Dict[str, KeyRecord],
    rest_server: str,
    node_rest_servers: List[str],
    mina_exe: str,
    zkapp_exe: str,
    itn_result: ItnInjectionResult,
) -> List[ProcessEntry]:
    """Build the process table (ordered by spawn priority) from typed plan pieces.

    Returns a mutable ``List[ProcessEntry]`` (``CoreProcessEntry`` for real
    external processes, ``WorkloadEntry`` for workloads) suitable for the spawn
    + supervision lifecycle.  This is the functional-core half of process‑table
    construction — no subprocess launch, signal handlers, or persistence IO.
    """
    procs_table: List[ProcessEntry] = []

    # 1. Archive (if present)
    if archive_svc is not None:
        procs_table.append(
            CoreProcessEntry(
                name=archive_svc.name,
                kind=ProcessKind.ARCHIVE,
                argv=list(archive_svc.argv),
                env=dict(archive_svc.env),
            )
        )

    # 2. Daemon nodes — seed first, then non-seed (stable order within each group)
    sorted_daemons = sorted(
        daemon_entries,
        key=lambda de: not de.is_seed,
    )
    for de in sorted_daemons:
        has_hardfork_migrate_exit = _has_hardfork_migrate_exit(de.argv)
        procs_table.append(
            CoreProcessEntry(
                name=de.name,
                kind=ProcessKind.DAEMON,
                argv=list(de.argv),
                env=dict(de.env),
                client_port=de.client_port,
                expected_exit=has_hardfork_migrate_exit,
            )
        )

    # 3. Workers
    for worker in workers:
        procs_table.append(
            CoreProcessEntry(
                name=worker.name,
                kind=ProcessKind.SNARK_WORKER,
                argv=list(worker.worker_argv),
                env=dict(worker.env),
            )
        )

    # 4. Rosetta (if present)
    if rosetta_svc is not None:
        procs_table.append(
            CoreProcessEntry(
                name=rosetta_svc.name,
                kind=ProcessKind.ROSETTA,
                argv=list(rosetta_svc.argv),
                env=dict(rosetta_svc.env),
            )
        )

    # 5. Workloads (appended after core processes; spawned after readiness gates)
    # Workload client commands target the seed daemon's REST GraphQL endpoint,
    # matching topology's per-workload readiness URI resolution.
    validate_workload_pubkey_conflicts(workloads, keys)

    for wl in workloads:
        if wl.start == WorkloadStart.MANUAL:
            print(
                f"Workload '{wl.name}' has start='manual' — will not be auto-spawned.",
                file=sys.stderr,
            )
            continue
        # Echo runs an arbitrary external command → argv (a subprocess).
        # The Python workers carry a typed payload run in-process (a thread).
        wl_argv: List[str] = []
        wl_payload: Optional[WorkloadPayload] = None
        match wl:
            case EchoWorkload():
                wl_argv, wl_env = build_echo_argv(wl)
                if not wl_argv:
                    raise WorkloadError(
                        ErrorCode.WORKLOAD_NO_ARGV,
                        message=f"Workload '{wl.name}' (type='{wl.type}') has no argv. "
                        f"Provide config.argv for echo workloads.",
                    )
            case ValueTransferWorkload():
                wl_payload, wl_env = build_value_transfer_payload(
                    wl, keys, node_rest_servers, mina_exe
                )
            case ZkappWorkload():
                wl_payload, wl_env = build_zkapp_payload(
                    wl, keys, rest_server, zkapp_exe
                )
            case ItnMaxCostWorkload():
                wl_payload, wl_env = build_itn_max_cost_payload(
                    wl, keys, mina_exe, itn_result
                )
        procs_table.append(
            WorkloadEntry(
                name=wl.name,
                type=WorkloadType(wl.type),
                start=wl.start,
                argv=wl_argv,
                payload=wl_payload,
                env=wl_env,
                success_exits_keep_network=wl.success_exits_keep_network,
                graphql_uri=wl.graphql_uri,
            )
        )

    return procs_table
