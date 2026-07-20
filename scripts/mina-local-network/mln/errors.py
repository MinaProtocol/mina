"""
Structural domain errors for the Mina local-network package.

All errors carry a stable :class:`ErrorCode` and structured fields for
programmatic consumption.  Core modules raise these errors; the CLI shell
converts them to Click-friendly representations.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional


class ErrorCode(Enum):
    """Stable error codes for programmatic matching."""

    # ── topology / schema ────────────────────────────────────
    SCHEMA_VERSION_UNSUPPORTED = "SCHEMA_VERSION_UNSUPPORTED"
    TOPOLOGY_VALIDATION = "TOPOLOGY_VALIDATION"
    REQUIREMENTS_VALIDATION = "REQUIREMENTS_VALIDATION"
    FORBIDDEN_FIELD = "FORBIDDEN_FIELD"
    MISSING_CAPABILITY = "MISSING_CAPABILITY"
    MULTIPLE_SEEDS = "MULTIPLE_SEEDS"
    NO_SEED_NODE = "NO_SEED_NODE"
    NODE_CONFIG = "NODE_CONFIG"

    # ── plan / materialize ───────────────────────────────────
    PLAN_NOT_FOUND = "PLAN_NOT_FOUND"
    PLAN_PARSE_ERROR = "PLAN_PARSE_ERROR"
    MANIFEST_MISMATCH = "MANIFEST_MISMATCH"
    MATERIALIZED_EXISTS = "MATERIALIZED_EXISTS"
    PLAN_ALREADY_EXISTS = "PLAN_ALREADY_EXISTS"
    PATCH_REQUIRES_NEW_KEYS = "PATCH_REQUIRES_NEW_KEYS"

    # ── spawn / process ──────────────────────────────────────
    PROCESSES_RUNNING = "PROCESSES_RUNNING"
    PROCESS_TRACKING_PARSE = "PROCESS_TRACKING_PARSE"
    BINARY_NOT_FOUND = "BINARY_NOT_FOUND"
    BINARY_NOT_EXECUTABLE = "BINARY_NOT_EXECUTABLE"
    SPAWN_NO_NODES = "SPAWN_NO_NODES"
    SPAWN_GENESIS_ALREADY_PASSED = "SPAWN_GENESIS_ALREADY_PASSED"
    SERVICE_MISSING_DEPENDENCY = "SERVICE_MISSING_DEPENDENCY"

    # ── workload ─────────────────────────────────────────────
    WORKLOAD_INVALID_TYPE = "WORKLOAD_INVALID_TYPE"
    WORKLOAD_KEY_NOT_FOUND = "WORKLOAD_KEY_NOT_FOUND"
    WORKLOAD_PUBKEY_CONFLICT = "WORKLOAD_PUBKEY_CONFLICT"
    WORKLOAD_NO_ARGV = "WORKLOAD_NO_ARGV"

    # ── keys / crypto ────────────────────────────────────────
    KEY_GENERATION_FAILED = "KEY_GENERATION_FAILED"
    KEY_MISSING = "KEY_MISSING"
    KEY_EXTRACTION_FAILED = "KEY_EXTRACTION_FAILED"
    ED25519_UNSUPPORTED = "ED25519_UNSUPPORTED"
    SIGNING_FAILED = "SIGNING_FAILED"

    # ── network / HTTP / GraphQL ─────────────────────────────
    HTTP_ERROR = "HTTP_ERROR"
    GRAPHQL_ERROR = "GRAPHQL_ERROR"
    GRAPHQL_RESPONSE_INVALID = "GRAPHQL_RESPONSE_INVALID"
    GRAPHQL_PARSE_ERROR = "GRAPHQL_PARSE_ERROR"
    GRAPHQL_READY_TIMEOUT = "GRAPHQL_READY_TIMEOUT"
    GRAPHQL_SYNC_TIMEOUT = "GRAPHQL_SYNC_TIMEOUT"
    TCP_READY_TIMEOUT = "TCP_READY_TIMEOUT"
    DAEMON_READY_TIMEOUT = "DAEMON_READY_TIMEOUT"

    # ── postgres ─────────────────────────────────────────────
    PSQL_MISSING = "PSQL_MISSING"
    POSTGRES_UNREACHABLE = "POSTGRES_UNREACHABLE"
    POSTGRES_SCHEMA_MISSING = "POSTGRES_SCHEMA_MISSING"

    # ── general ──────────────────────────────────────────────
    INVALID_ARGUMENT = "INVALID_ARGUMENT"
    DEPENDENCY_MISSING = "DEPENDENCY_MISSING"
    FILE_NOT_FOUND = "FILE_NOT_FOUND"


class MLNError(Exception):
    """Base error for all Mina local-network domain errors."""

    code: ErrorCode
    message: str
    hint: Optional[str]
    path: Optional[str]
    entity: Optional[str]

    def __init__(
        self,
        code: ErrorCode,
        *,
        message: str = "",
        hint: Optional[str] = None,
        path: Optional[str] = None,
        entity: Optional[str] = None,
    ) -> None:
        self.code = code
        self.message = message
        self.hint = hint
        self.path = path
        self.entity = entity
        super().__init__(self._format())

    def _format(self) -> str:
        parts = [f"[{self.code.value}] {self.message or 'unknown error'}"]
        if self.entity:
            parts.append(f"  entity: {self.entity}")
        if self.path:
            parts.append(f"  path: {self.path}")
        if self.hint:
            parts.append(f"  hint: {self.hint}")
        return "\n".join(parts)

    def __repr__(self) -> str:
        return (
            f"MLNError(code={self.code!r}, message={self.message!r}, "
            f"entity={self.entity!r}, path={self.path!r})"
        )


class TopologyError(MLNError):
    """Errors related to topology validation, normalization, or resolution."""


class PlanError(MLNError):
    """Errors related to plan persistence or loading."""


class ManifestError(MLNError):
    """Errors related to materialized manifest validation."""


class MaterializeError(MLNError):
    """Errors during materialization (keys, config, file overlay)."""


class SpawnError(MLNError):
    """Errors during process spawning or supervision."""


class WorkloadError(MLNError):
    """Errors related to workload configuration or execution."""


class KeyError_(MLNError):
    """Errors related to keypair generation or materialization."""

    # Named with trailing underscore to avoid shadowing builtin KeyError


class GraphQLError(MLNError):
    """GraphQL transport or data errors."""


class NetworkError(MLNError):
    """TCP/HTTP connectivity errors."""


class PostgresError(MLNError):
    """Postgres connectivity or schema errors."""


class ProcessTrackingError(MLNError):
    """Process tracking (processes.json) errors."""


# ── Control-flow signals (not errors) ──────────────────────────────────


class ShutdownSignal(Exception):
    """Raised when SIGINT/SIGTERM is received during process supervision.

    This is a control-flow signal, not a domain error.
    """


class WorkerExit(SystemExit):
    """Controlled exit from a worker subprocess, carrying an exit code.

    Subclasses ``SystemExit`` for backward compatibility with Click's
    expectation that hidden workers may call ``sys.exit()``.
    """
