"""Shared spawn‑lifecycle types — package‑internal.

All types carry public names; no ``_`` prefix.  They were formerly
``_DaemonEntry`` / ``_ItnAuthKeyMaterial`` / ``_ItnInjectionResult`` /
``_WorkloadLaunchSpec`` inside the old monolithic ``mln/spawn.py``.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field

from mln.models import ItnMaxCostWorkload


class DaemonEntry(BaseModel):
    """Internal daemon entry for the spawn lifecycle.  Never serialized.

    Lives inside ``spawn_instance_from_plan``; replaces the previous
    ``Dict[str, Any]`` bags for ``_daemon_entries`` / ``_seed_entry``.
    """

    model_config = ConfigDict()  # mutable — argv may receive ITN key injection

    name: str
    argv: List[str] = Field(default_factory=list)
    env: Dict[str, str] = Field(default_factory=dict)
    client_port: Optional[int] = None
    rest_port: Optional[int] = None
    itn_graphql_port: Optional[int] = None
    external_port: Optional[int] = None
    is_seed: bool = False


class ItnAuthKeyMaterial(BaseModel):
    """Per-workload ITN Ed25519 auth key material.  Never serialized."""

    model_config = ConfigDict(frozen=True)

    workload_name: str
    priv_path: str
    b64_pubkey: str


class ItnInjectionResult(BaseModel):
    """Typed result of ITN preflight + key-generation + daemon-argv injection.

    *auth_keys* maps workload name → key material for the worker process launch.
    *itn_workloads* are the auto-ITN workloads processed (non‑manual
    ``ItnMaxCostWorkload`` entries), for downstream validation.

    **Side effect**: the helper mutates ``DaemonEntry.argv`` in‑place on the
    daemon whose argv contains ``--itn-graphql-port``, injecting
    ``--itn-keys <comma‑delimited pubkeys>``.  The spawn lifecycle propagates
    the mutated argv through process‑table construction.
    """

    model_config = ConfigDict(frozen=True)

    auth_keys: Dict[str, ItnAuthKeyMaterial]
    itn_workloads: List[ItnMaxCostWorkload]


class WorkloadLaunchSpec(BaseModel):
    """Typed launch spec for a single workload worker process.

    Carries resolved argv and env for a workload variant.  Never serialized.
    """

    model_config = ConfigDict(frozen=True)

    argv: List[str]
    env: Dict[str, str]
