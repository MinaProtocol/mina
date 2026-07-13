"""Process‑table construction from typed plan pieces.

The main entry point is :func:`build_process_table`.
"""

from __future__ import annotations

from typing import Dict, List, Optional

import click

from mln.models import (
    EchoWorkload,
    ItnMaxCostWorkload,
    KeyRecord,
    ProcessKind,
    ResolvedService,
    ResolvedWorker,
    TrackedProcess,
    ValueTransferWorkload,
    WorkloadConfig,
    WorkloadStart,
    WorkloadType,
    ZkappWorkload,
)
from mln.errors import ErrorCode, WorkloadError

from mln.spawn.types import DaemonEntry, ItnInjectionResult
from mln.spawn.workloads import (
    build_echo_argv,
    build_itn_max_cost_argv,
    build_value_transfer_argv,
    build_zkapp_argv,
    validate_workload_pubkey_conflicts,
)


def build_process_table(
    archive_svc: Optional[ResolvedService],
    daemon_entries: List[DaemonEntry],
    workers: List[ResolvedWorker],
    rosetta_svc: Optional[ResolvedService],
    workloads: List[WorkloadConfig],
    keys: Dict[str, KeyRecord],
    rest_server: str,
    mina_exe: str,
    zkapp_exe: str,
    itn_result: ItnInjectionResult,
) -> List[TrackedProcess]:
    """Build the process table (ordered by spawn priority) from typed plan pieces.

    Returns a mutable ``List[TrackedProcess]`` suitable for the spawn +
    supervision lifecycle.  This is the functional-core half of process‑table
    construction — no subprocess launch, signal handlers, or persistence IO.
    """
    procs_table: List[TrackedProcess] = []

    # 1. Archive (if present)
    if archive_svc is not None:
        procs_table.append(
            TrackedProcess(
                name=archive_svc.name,
                kind=ProcessKind.ARCHIVE,
                argv=list(archive_svc.argv),
                env=dict(archive_svc.env),
            )
        )

    # 2. Daemon nodes (in plan order — seed first as resolved by topology)
    for de in daemon_entries:
        procs_table.append(
            TrackedProcess(
                name=de.name,
                kind=ProcessKind.DAEMON,
                argv=list(de.argv),
                env=dict(de.env),
                client_port=de.client_port,
            )
        )

    # 3. Workers
    for worker in workers:
        procs_table.append(
            TrackedProcess(
                name=worker.name,
                kind=ProcessKind.SNARK_WORKER,
                argv=list(worker.worker_argv),
                env=dict(worker.env),
            )
        )

    # 4. Rosetta (if present)
    if rosetta_svc is not None:
        procs_table.append(
            TrackedProcess(
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
            click.echo(
                f"Workload '{wl.name}' has start='manual' — will not be auto-spawned.",
                err=True,
            )
            continue
        match wl:
            case EchoWorkload():
                launch = build_echo_argv(wl)
            case ValueTransferWorkload():
                launch = build_value_transfer_argv(wl, keys, rest_server, mina_exe)
            case ZkappWorkload():
                launch = build_zkapp_argv(wl, keys, rest_server, zkapp_exe)
            case ItnMaxCostWorkload():
                launch = build_itn_max_cost_argv(wl, keys, mina_exe, itn_result)
        wl_argv = launch.argv
        wl_env = launch.env
        if not wl_argv:
            raise WorkloadError(
                ErrorCode.WORKLOAD_NO_ARGV,
                message=f"Workload '{wl.name}' (type='{wl.type}') has no argv. "
                f"Provide config.argv for echo workloads.",
            )
        procs_table.append(
            TrackedProcess(
                name=wl.name,
                kind=ProcessKind.WORKLOAD,
                type=WorkloadType(wl.type),
                start=wl.start,
                argv=wl_argv,
                env=wl_env,
                success_exits_keep_network=wl.success_exits_keep_network,
                graphql_uri=wl.graphql_uri,
            )
        )

    return procs_table
