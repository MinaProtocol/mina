"""
Typed Pydantic models for Mina local-network domain data.

Models represent immutable data boundaries.  Raw ``dict[str, Any]`` should
not propagate beyond JSON/HTTP/file decode edges — use these models
wherever practical.
"""

from __future__ import annotations

import subprocess
from enum import Enum
from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field, field_validator

from mln.workload_types import RunHandle

# ── Workload dispatch ───────────────────────────────────────────────────


class WorkloadType(str, Enum):
    """Supported workload types for match/case dispatch."""

    ECHO = "echo"
    VALUE_TRANSFER = "value_transfer"
    ZKAPP = "zkapp"
    ITN_MAX_COST = "itn_max_cost"


class WorkloadStart(str, Enum):
    """When a workload should begin after process spawn."""

    IMMEDIATE = "immediate"
    AFTER_GRAPHQL_READY = "after_graphql_ready"
    AFTER_GENESIS = "after_genesis"
    MANUAL = "manual"


class ProcessKind(str, Enum):
    """Kind of a tracked process in the process table."""

    DAEMON = "daemon"
    ARCHIVE = "archive"
    ROSETTA = "rosetta"
    SNARK_WORKER = "snark_worker"
    WORKLOAD = "workload"


class ServiceKind(str, Enum):
    """Kind of a resolved service — distinct from ProcessKind.

    ``ServiceKind`` is the domain for topology / resolved-plan service
    dispatch (archive, rosetta).  Conversely, ``ProcessKind`` is the
    domain for tracked runtime processes in the process table.
    """

    ARCHIVE = "archive"
    ROSETTA = "rosetta"


# ── GraphQL ─────────────────────────────────────────────────────────────


class GraphQLResponse(BaseModel):
    """Validated GraphQL response body with non-null object data."""

    model_config = ConfigDict(frozen=True, extra="allow")

    data: Dict[str, Any]


class SyncStatusPayload(BaseModel):
    """Typed payload for the ``syncStatus`` GraphQL query.

    Used as the structural output of ``parse_sync_status`` — callers never
    receive a raw ``dict`` from this query.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    syncStatus: str


class ITNAuthResult(BaseModel):
    """Typed result of an ITN ``auth`` GraphQL query.

    Accepts both snake_case (Python attribute access) and camelCase
    (GraphQL response) keys — the aliases map GraphQL field names
    ``serverUuid`` / ``signerSequenceNumber`` to the typed Python
    attributes.
    """

    model_config = ConfigDict(frozen=True)

    server_uuid: str = Field(
        min_length=1, alias="serverUuid", validation_alias="serverUuid"
    )
    signer_sequence_number: int = Field(
        alias="signerSequenceNumber", validation_alias="signerSequenceNumber"
    )


# ── Nonce tracking ──────────────────────────────────────────────────────


class NonceClaim(BaseModel):
    """A workload role that advances an account nonce."""

    model_config = ConfigDict(frozen=True)

    workload_name: str
    role: str


# ── Endpoints ───────────────────────────────────────────────────────────


class Endpoint(BaseModel):
    """A single network endpoint with host and port."""

    model_config = ConfigDict(frozen=True)

    port: int
    host: str = "127.0.0.1"


class NodeEndpoints(BaseModel):
    """Resolved endpoints for a single daemon node."""

    model_config = ConfigDict(frozen=True)

    client: Endpoint
    rest: Endpoint
    external: Endpoint
    metrics: Endpoint
    libp2p_metrics: Endpoint
    itn_graphql: Optional[Endpoint] = None


# ── Plan models ─────────────────────────────────────────────────────────


class BinariesConfig(BaseModel):
    """Resolved binary paths from topology.binaries."""

    model_config = ConfigDict(frozen=True, extra="allow")

    mina: str = "_build/default/src/app/cli/src/mina.exe"
    archive: str = "_build/default/src/app/archive/archive.exe"
    rosetta: str = "_build/default/src/app/rosetta/rosetta.exe"
    zkapp: str = (
        "_build/default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe"
    )


class GenesisTimestamp(BaseModel):
    """Genesis timestamp configuration — time delay from now or absolute value."""

    model_config = ConfigDict(frozen=True)

    delay: str = "PT120S"
    value: Optional[str] = None


class PlanState(BaseModel):
    """Top-level state metadata for a resolved plan."""

    model_config = ConfigDict(frozen=True)

    root: str
    genesis_timestamp: GenesisTimestamp = Field(default_factory=GenesisTimestamp)
    config_file: str = ""
    extra_files_root: str = ""


class SnarkCoordinatorInfo(BaseModel):
    """Typed per-node snark-coordinator metadata in the resolved plan.

    Preserves JSON shape exactly — all fields are optional because the
    coordinator may or may not be present on any given node.

    ``worker_pools`` remains ``Dict[str, Any]``: each pool value carries
    ``count`` and ``nap`` fields, but the pool name is open‑ended so
    a fully‑typed sub‑model offers no practical gain.
    """

    model_config = ConfigDict(frozen=True)

    fee: Optional[str] = None
    fee_receiver: Optional[str] = None
    work_selection: Optional[str] = None
    worker_pools: Dict[str, Any] = Field(default_factory=dict)


class ResolvedNode(BaseModel):
    """A single resolved daemon node in the plan."""

    model_config = ConfigDict(frozen=True)

    name: str
    endpoints: Dict[str, Endpoint]
    peer_id: Optional[str] = None
    capabilities: List[str] = Field(default_factory=list)
    daemon_argv: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    config_dir: str = ""
    config_file: str = ""
    block_producer_key_path: Optional[str] = None
    snark_coordinator: Optional[SnarkCoordinatorInfo] = None


class ResolvedWorker(BaseModel):
    """A single resolved external snark worker in the plan."""

    model_config = ConfigDict(frozen=True)

    name: str
    coordinator_node: str
    coordinator_port: int
    daemon_address: str
    worker_argv: List[str] = Field(default_factory=list)
    config_dir: str = ""
    env: Dict[str, str] = Field(default_factory=dict)


class ResolvedService(BaseModel):
    """A single resolved service (archive, rosetta) in the plan."""

    model_config = ConfigDict(frozen=True)

    name: str
    kind: ServiceKind
    binary: str = ""
    port: Optional[int] = None
    argv: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    postgres_uri: Optional[str] = None
    graphql_uri: Optional[str] = None
    config_dir: str = ""


class EchoWorkload(BaseModel):
    """An echo workload that runs an arbitrary external command."""

    model_config = ConfigDict(frozen=True)

    name: str
    type: Literal["echo"] = "echo"
    start: WorkloadStart = WorkloadStart.IMMEDIATE
    argv: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    success_exits_keep_network: bool = True
    graphql_uri: Optional[str] = None


class ValueTransferWorkload(BaseModel):
    """A value-transfer workload sending random payments across the account pool.

    Sender and receiver are drawn at random each transfer from the eligible
    online-tier accounts (not configured), the amount is drawn from
    ``[amount_min, amount_max]``, and each account submits to its own stable
    home node — so traffic enters the network everywhere and must gossip to
    producers.  With probability ``replay_probability`` a sent payment is
    resubmitted identically (replay noise the network's nonce/dedup path rejects).
    """

    model_config = ConfigDict(frozen=True)

    name: str
    type: Literal["value_transfer"] = "value_transfer"
    start: WorkloadStart = WorkloadStart.AFTER_GENESIS
    amount_min: str = "1mina"
    amount_max: str = "10mina"
    # Fee DSL (like the amounts) paid on every send. Explicit because payments go
    # through the daemon's GraphQL, which — unlike the CLI — takes no default.
    fee: str = "0.25mina"
    interval_seconds: float = 10.0
    count: Optional[int] = None
    # Ledger nonce every pool account starts from. 0 is right for a fresh
    # network; one that inherits accounts must say what they inherited. The
    # worker tracks each account's nonce from here and pins every send.
    first_nonce: int = 0
    # Expected inherited ledger nonce per pool account ref (e.g. {"whale-0": 67}).
    # Set only on a network that inherited a ledger (the fork side of a hardfork):
    # before its first send the worker reads each listed account's live nonce and
    # asserts it equals this, verifying the fork carried the account structure
    # across intact. Empty means "fresh network, nothing to carry over".
    assert_carryover_nonces: Dict[str, int] = {}
    # Probability that a successful send is replayed (resubmitted identically),
    # cascading: p for one replay, p^2 for two, … 0 disables replay noise.
    replay_probability: float = 0.0
    success_exits_keep_network: bool = True
    graphql_uri: Optional[str] = None


class ZkappWorkload(BaseModel):
    """A zkApp workload that deploys and updates zkApps."""

    model_config = ConfigDict(frozen=True)

    name: str
    type: Literal["zkapp"] = "zkapp"
    start: WorkloadStart = WorkloadStart.AFTER_GENESIS
    fee_payer_account: str = "whale-0"
    sender_account: str = "whale-1"
    transfer_amount: str = "1"
    receiver_amount: str = "1000"
    fee: str = "5"
    interval_seconds: float = 10.0
    count: Optional[int] = None
    create_account: bool = True
    success_exits_keep_network: bool = True
    graphql_uri: Optional[str] = None


class ItnMaxCostWorkload(BaseModel):
    """An ITN max-cost workload that schedules heavy zkApp traffic."""

    model_config = ConfigDict(frozen=True)

    name: str
    type: Literal["itn_max_cost"] = "itn_max_cost"
    start: WorkloadStart = WorkloadStart.AFTER_GENESIS
    fee_payer_account: str = "whale-0"
    duration_min: int = 1
    tps: Optional[float] = None  # None means auto-computed
    num_zkapps_to_deploy: int = 2
    max_cost_num_updates: int = 7
    num_new_accounts: int = 0
    account_queue_size: int = 0
    memo_prefix: str = "maxcost"
    no_precondition: bool = False
    min_balance_change: str = "0"
    max_balance_change: str = "1000000000"
    min_new_zkapp_balance: str = "1000000000"
    max_new_zkapp_balance: str = "2000000000"
    init_balance: str = "5000000000"
    min_fee: str = "1000000000"
    max_fee: str = "2000000000"
    deployment_fee: str = "1000000000"
    success_exits_keep_network: bool = True
    graphql_uri: Optional[str] = None
    itn_graphql_uri: Optional[str] = None


# Union type for dispatch — use match/case
WorkloadConfig = (
    EchoWorkload | ValueTransferWorkload | ZkappWorkload | ItnMaxCostWorkload
)


# ── Workload run payloads ────────────────────────────────────────────────
#
# One typed, named payload per Python worker, replacing the old hand-ordered
# argv list decoded by position.  A worker runs in-process on a thread, so the
# payload is passed as a plain object — no serialization.  Contrast with echo
# workloads, which are genuine external commands and keep an ``argv``.


class TransferAccount(BaseModel):
    """One account in the value-transfer pool: its keys and assigned home node.

    ``home_rest_uri`` is the REST GraphQL endpoint this account always submits
    to (assigned once, spread across eligible nodes), so its nonce sequence
    stays contiguous on one daemon.
    """

    model_config = ConfigDict(frozen=True)

    name: str
    pubkey: str
    privkey_path: str
    home_rest_uri: str


class ValueTransferPayload(BaseModel):
    """Resolved inputs for the randomized value-transfer worker."""

    model_config = ConfigDict(frozen=True)

    mina_exe: str
    # Eligible sender/receiver pool (online-tier accounts with privkeys), each
    # carrying its stable home node.
    accounts: List[TransferAccount]
    amount_min_nanomina: int
    amount_max_nanomina: int
    fee_nanomina: int
    interval_secs: float
    count: Optional[int] = None
    first_nonce: int = 0
    # Expected inherited ledger nonce keyed by pool account name (the online key
    # name, e.g. "online_whale_account_0"), resolved from the workload's
    # ref-keyed assert_carryover_nonces. The worker asserts each before its first
    # send. Empty means no carry-over to verify.
    assert_carryover_nonces: Dict[str, int] = {}
    replay_probability: float = 0.0


class ZkappPayload(BaseModel):
    """Resolved inputs for the zkApp worker."""

    model_config = ConfigDict(frozen=True)

    zkapp_exe: str
    graphql_uri: str
    fee_payer_privkey_path: str
    fee_payer_pubkey: str
    sender_privkey_path: str
    sender_pubkey: str
    zkapp_privkey_path: str
    zkapp_pubkey: str
    transfer_amount: str
    receiver_amount: str
    fee: str
    interval_secs: float
    create_account: bool = False
    count: Optional[int] = None


class ItnMaxCostPayload(BaseModel):
    """Resolved inputs for the ITN max-cost worker."""

    model_config = ConfigDict(frozen=True)

    mina_exe: str
    itn_graphql_uri: str
    fee_payer_privkey_path: str
    itn_privkey_path: str
    itn_pubkey: str
    duration_min: int
    tps: float
    num_zkapps_to_deploy: int
    max_cost_num_updates: int
    num_new_accounts: int
    account_queue_size: int
    memo_prefix: str
    no_precondition: bool
    min_balance_change: str
    max_balance_change: str
    min_new_zkapp_balance: str
    max_new_zkapp_balance: str
    init_balance: str
    min_fee: str
    max_fee: str
    deployment_fee: str


# Dispatch union — matched by isinstance in dispatch_workload.
WorkloadPayload = Union[ValueTransferPayload, ZkappPayload, ItnMaxCostPayload]


# ── Topology workload normalization ──────────────────────────────────────


class NormalizedWorkloadEntry(BaseModel):
    """A single workload entry after normalization with defaults applied.

    This is the intermediate data shape between ``normalize_topology()``
    and ``resolve_topology()``.  It captures the ``type`` / ``start`` /
    ``config`` structure that the authored topology and JSON Schema use,
    after normalization has filled in per-type defaults.

    ``extra="allow"`` preserves forward-compat with any additional
    workload-level keys that may appear in authored topologies.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    type: str
    start: WorkloadStart = WorkloadStart.IMMEDIATE
    config: Dict[str, Any] = Field(default_factory=dict)


# ── Per-type normalized workload config sub-models ───────────────────────
#
# These describe the post-normalization ``config`` sub-dict inside a
# ``NormalizedWorkloadEntry``.  ``resolve_topology()`` validates the
# config dict against the correct model (based on ``wl.type``) and then
# uses typed attribute access instead of ``.get(...)`` chains.
#
# All models are ``frozen`` and ``extra="allow"`` — additional fields that
# the authored topology may carry are preserved but do not affect the
# typed attribute surface.


class NormalizedEchoWorkloadConfig(BaseModel):
    """Post-normalization echo workload config."""

    model_config = ConfigDict(frozen=True, extra="allow")

    argv: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    success_exits_keep_network: bool = True


class NormalizedValueTransferWorkloadConfig(BaseModel):
    """Post-normalization value_transfer workload config.

    Sender/receiver are no longer configured — the worker draws them at random
    from the eligible account pool each transfer, and the amount is a range.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    amount_min: str = "1mina"
    amount_max: str = "10mina"
    fee: str = "0.25mina"
    interval_seconds: float = 10.0
    count: Optional[int] = None
    first_nonce: int = 0
    # Expected inherited ledger nonce per pool account ref; see
    # ValueTransferWorkload.assert_carryover_nonces.
    assert_carryover_nonces: Dict[str, int] = {}
    replay_probability: float = 0.0
    success_exits_keep_network: bool = True


class NormalizedZkappWorkloadConfig(BaseModel):
    """Post-normalization zkapp workload config."""

    model_config = ConfigDict(frozen=True, extra="allow")

    fee_payer_account: str = "whale-0"
    sender_account: str = "whale-1"
    transfer_amount: str = "1"
    receiver_amount: str = "1000"
    fee: str = "5"
    interval_seconds: float = 10.0
    count: Optional[int] = None
    create_account: bool = True
    success_exits_keep_network: bool = True


class NormalizedItnMaxCostWorkloadConfig(BaseModel):
    """Post-normalization itn_max_cost workload config.

    ``duration_min`` is **required** (no default) — matching the raw
    ``wl_config["duration_min"]`` direct-key-access pattern in the
    original code.  Every itn_max_cost workload must supply this field.

    ``tps`` is intentionally **omitted** from this model: it has
    dynamic auto-resolution semantics (string ``"auto"`` → computed
    float, ``None`` → auto, etc.) that are handled directly in
    ``resolve_topology()`` before the ``ItnMaxCostWorkload``
    constructor.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    fee_payer_account: str = "whale-0"
    duration_min: int
    num_zkapps_to_deploy: int = 2
    max_cost_num_updates: int = 7
    num_new_accounts: int = 0
    account_queue_size: int = 0
    memo_prefix: str = "maxcost"
    no_precondition: bool = False
    min_balance_change: str = "0"
    max_balance_change: str = "1000000000"
    min_new_zkapp_balance: str = "1000000000"
    max_new_zkapp_balance: str = "2000000000"
    init_balance: str = "5000000000"
    min_fee: str = "1000000000"
    max_fee: str = "2000000000"
    deployment_fee: str = "1000000000"
    success_exits_keep_network: bool = True

    @field_validator(
        "min_balance_change",
        "max_balance_change",
        "min_new_zkapp_balance",
        "max_new_zkapp_balance",
        "init_balance",
        "min_fee",
        "max_fee",
        "deployment_fee",
        mode="before",
    )
    @classmethod
    def _coerce_int_to_str(cls, v: Any) -> str:
        """Normalize integer inputs to strings, matching the old ``str()``
        wrapping in ``resolve_topology()`` for itn_max_cost balance/fee fields.

        YAML numbers (int, float) are implicitly accepted by the topology
        schema; the normalized config stored them as-is.  This validator
        preserves that leniency.
        """
        if not isinstance(v, str):
            return str(v)
        return v


class TierDefinition(BaseModel):
    """Definition of a single account tier in the ledger plan.

    Common fields are typed; ``extra="allow"`` preserves forward‑compat
    with any additional tier‑specific fields from the topology.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    count: int = 0
    offline_balance: str = "0mina"
    online_balance: str = "0mina"


class GenesisLedgerConfig(BaseModel):
    """Genesis‑block parameters used in daemon.json construction."""

    model_config = ConfigDict(frozen=True, extra="allow")

    slots_per_epoch: int = 48
    k: int = 10
    grace_period_slots: int = 3
    genesis_state_timestamp: str = "<generated>"


class ProofLedgerConfig(BaseModel):
    """Proof‑level parameters used in daemon.json construction."""

    model_config = ConfigDict(frozen=True, extra="allow")

    work_delay: int = 1
    level: str = "full"
    transaction_capacity: Dict[str, Any] = Field(
        default_factory=lambda: {"2_to_the": 2}
    )
    block_window_duration_ms: Optional[int] = None


class DaemonRuntimeConfig(BaseModel):
    """Daemon-specific runtime config fields written as top-level ``daemon``
    in daemon.json.

    All fields are optional — only non-None values produce a ``daemon``
    section in the materialized config.
    """

    model_config = ConfigDict(frozen=True)

    slot_tx_end: Optional[int] = None
    slot_chain_end: Optional[int] = None
    hard_fork_genesis_slot_delta: Optional[int] = None


class LedgerConfig(BaseModel):
    """Typed ledger configuration grouping genesis and proof parameters."""

    model_config = ConfigDict(frozen=True, extra="allow")

    genesis: GenesisLedgerConfig = Field(default_factory=GenesisLedgerConfig)
    proof: ProofLedgerConfig = Field(default_factory=ProofLedgerConfig)
    daemon: DaemonRuntimeConfig = Field(default_factory=DaemonRuntimeConfig)


class LedgerPlan(BaseModel):
    """Ledger account and key directory plan."""

    model_config = ConfigDict(frozen=True)

    tiers: Dict[str, TierDefinition] = Field(default_factory=dict)
    accounts: Dict[str, Any] = Field(default_factory=dict)
    genesis_state_timestamp: str = ""
    config: LedgerConfig = Field(default_factory=LedgerConfig)
    key_dirs: Dict[str, str] = Field(default_factory=dict)
    extra_accounts_file: str = ""


class ResolvedPlan(BaseModel):
    """Top-level resolved plan produced by topology resolution."""

    model_config = ConfigDict(frozen=True)

    state: PlanState
    binaries: BinariesConfig = Field(default_factory=BinariesConfig)
    nodes: List[ResolvedNode] = Field(default_factory=list)
    workers: List[ResolvedWorker] = Field(default_factory=list)
    services: List[ResolvedService] = Field(default_factory=list)
    workloads: List[WorkloadConfig] = Field(default_factory=list)
    ledger: LedgerPlan


# ── Manifest models ─────────────────────────────────────────────────────


class KeyRecord(BaseModel):
    """A single generated keypair record in the materialized manifest."""

    model_config = ConfigDict(frozen=True)

    privkey_path: str
    pubkey_path: str
    pubkey_content: str


class MaterializedManifest(BaseModel):
    """A materialized-manifest.json representation."""

    model_config = ConfigDict(frozen=True)

    schema_version: int = 1
    materialized_at: str = ""
    plan_path: str = ""
    state_root: str = ""
    daemon_config: str = ""
    genesis_ledger: str = ""
    generated_files: List[str] = Field(default_factory=list)
    keys: Dict[str, KeyRecord] = Field(default_factory=dict)
    node_logs: Dict[str, str] = Field(default_factory=dict)
    plan_fingerprint: Optional[str] = None
    plan_fingerprint_algorithm: Optional[str] = None


class MaterializeResult(BaseModel):
    """Structural result of a materialize operation — never a raw dict.

    ``do_materialize`` always returns this model.  The ``mode`` discriminator
    tells whether artefacts were actually written to disk::

        result = do_materialize(resolved_plan, force=False, dry_run=True)
        if result.mode == "dry_run":
            print(result.planned_dirs)
        else:
            assert result.manifest is not None
            print(result.manifest.generated_files)
    """

    model_config = ConfigDict(frozen=True)

    mode: Literal["dry_run", "materialized"]
    materialized_at: str
    state_root: str
    schema_version: int = 1
    manifest: Optional[MaterializedManifest] = None
    planned_dirs: List[str] = Field(default_factory=list)


# ── Process table models ────────────────────────────────────────────────


class ProcessesFileEntry(BaseModel):
    """A single entry in processes.json."""

    model_config = ConfigDict()

    pid: Optional[int] = None
    pgid: Optional[int] = None
    kind: ProcessKind
    argv: List[str] = Field(default_factory=list)
    started_at: Optional[str] = None
    state: str = "pending"


# ── In-flight process tracking (spawn lifecycle) ────────────────────────


class _ProcessEntryBase(BaseModel):
    """Runtime bookkeeping shared by both spawn-table entry variants.

    Mutable in-memory state used inside ``spawn_instance_from_plan`` — NOT the
    persisted ``processes.json`` format (see ``ProcessesFileEntry``).
    """

    # mutable + holds live handles (Popen / RunHandle) that pydantic must not
    # try to validate structurally beyond isinstance.
    model_config = ConfigDict(arbitrary_types_allowed=True)

    name: str
    env: Dict[str, str] = Field(default_factory=dict)

    # Mutable runtime bookkeeping
    pid: Optional[int] = None
    pgid: Optional[int] = None
    started_at: Optional[str] = None
    state: str = "pending"


class CoreProcessEntry(_ProcessEntryBase):
    """A real external process: daemon, archive, rosetta, or snark worker.

    Its argv is a genuine interface and ``proc`` a real ``Popen`` with an exit
    code and signal semantics.  Contrast :class:`WorkloadEntry`.
    """

    kind: ProcessKind
    argv: List[str] = Field(default_factory=list)
    proc: Optional[subprocess.Popen] = Field(default=None, exclude=True)

    client_port: Optional[int] = None  # daemon
    # daemon: auto-fork migrate-exit expected to exit cleanly
    expected_exit: bool = False

    def to_processes_json_entry(self) -> ProcessesFileEntry:
        """Project this process into a persisted JSON entry."""
        return ProcessesFileEntry(
            pid=self.pid,
            pgid=self.pgid,
            kind=self.kind,
            argv=self.argv,
            started_at=self.started_at,
            state=self.state,
        )


class WorkloadEntry(_ProcessEntryBase):
    """A workload: echo (an external command, via ``argv``) or a Python worker
    (via a typed ``payload``).

    Carried by a :class:`~mln.workload_types.RunHandle`, not a bare process —
    a workload is not a process to the supervisor.  Has no ``proc`` field at
    all, so the "core process" shape is unrepresentable here.
    """

    type: WorkloadType
    start: WorkloadStart
    argv: List[str] = Field(default_factory=list)  # echo only
    payload: Optional[WorkloadPayload] = None  # Python workers only
    workload: Optional[RunHandle] = Field(default=None, exclude=True)

    success_exits_keep_network: bool = True
    graphql_uri: Optional[str] = None

    def to_processes_json_entry(self) -> ProcessesFileEntry:
        """Project this workload into a persisted JSON entry."""
        return ProcessesFileEntry(
            pid=self.pid,
            pgid=self.pgid,
            kind=ProcessKind.WORKLOAD,
            argv=self.argv,
            started_at=self.started_at,
            state=self.state,
        )


# A spawn-table entry is exactly one of these; dispatch with ``match``.
ProcessEntry = CoreProcessEntry | WorkloadEntry


# ── Topology models ─────────────────────────────────────────────────────


class LoggingConfig(BaseModel):
    """Grouped logging configuration from topology.logging."""

    model_config = ConfigDict(frozen=True)

    console: Dict[str, str] = Field(default_factory=dict)
    file: Dict[str, str] = Field(default_factory=dict)


class RuntimeConfig(BaseModel):
    """Runtime configuration from topology.runtime_config."""

    model_config = ConfigDict(frozen=True)

    genesis: Dict[str, Any] = Field(default_factory=dict)
    proof: Dict[str, Any] = Field(default_factory=dict)
    daemon: Dict[str, Any] = Field(default_factory=dict)


class NormalizedTopology(BaseModel):
    """Normalized topology after defaults are applied."""

    model_config = ConfigDict(frozen=True, extra="allow")

    schema_version: int
    name: Optional[str] = None
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    runtime_config: RuntimeConfig = Field(default_factory=RuntimeConfig)
    ledger_generation: Dict[str, Any] = Field(default_factory=dict)
    state: Dict[str, Any] = Field(default_factory=dict)
    binaries: Dict[str, str] = Field(default_factory=dict)
    nodes: Dict[str, dict] = Field(default_factory=dict)
    services: Dict[str, dict] = Field(default_factory=dict)
    workloads: Dict[str, NormalizedWorkloadEntry] = Field(default_factory=dict)


# Rebuild forward references
GraphQLResponse.model_rebuild()
NonceClaim.model_rebuild()
