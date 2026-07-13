"""Workload argv construction and cross-workload validation."""

from __future__ import annotations

import os
import re
import sys
from typing import Dict, List, Optional

from mln.amounts import parse_account_spec
from mln.constants import DEFAULT_PRIVKEY_PASS
from mln.errors import ErrorCode, SpawnError, WorkloadError
from mln.models import (
    EchoWorkload,
    ItnMaxCostWorkload,
    KeyRecord,
    NonceClaim,
    ValueTransferWorkload,
    WorkloadConfig,
    WorkloadStart,
    ZkappWorkload,
)
from mln.paths import ENTRYPOINT
from mln.process import resolve_existing_executable

from mln.spawn.types import ItnInjectionResult, WorkloadLaunchSpec


def _fmt_interval(seconds: float) -> str:
    """Format a float interval as a CLI arg string, dropping ``.0`` suffix."""
    if seconds == int(seconds):
        return str(int(seconds))
    return str(seconds)


# ── Manifest key lookup helpers ──────────────────────────────────────


def _lookup_pubkey_content(keys: Dict[str, KeyRecord], key_name: str) -> Optional[str]:
    """Return the pubkey content for *key_name*, or ``None`` if missing or empty.

    This is the optional path used by ``validate_workload_pubkey_conflicts``
    — absent keys or empty pubkeys are silently skipped (no error).
    """
    record = keys.get(key_name)
    if record is None:
        return None
    content = record.pubkey_content
    return content or None


# ── Account-ref → key-name resolvers ────────────────────────────────


def resolve_account_ref_to_online_key(account_ref: str) -> str:
    """Resolve an account ref string like 'whale-0' to an online key name."""
    tier, index = parse_account_spec(account_ref)
    return f"online_{tier}_account_{index}"


def resolve_account_ref_to_offline_key(account_ref: str) -> str:
    """Resolve an account ref string like 'whale-0' to an offline key name."""
    tier, index = parse_account_spec(account_ref)
    return f"offline_{tier}_account_{index}"


# ── Per-workload argv builders ──────────────────────────────────────


def build_echo_argv(wl: EchoWorkload) -> WorkloadLaunchSpec:
    """Build argv/env for an echo workload — thin passthrough."""
    return WorkloadLaunchSpec(
        argv=list(wl.argv),
        env=dict(wl.env),
    )


def build_value_transfer_argv(
    wl: ValueTransferWorkload,
    keys: Dict[str, KeyRecord],
    rest_server: str,
    mina_exe: str,
) -> WorkloadLaunchSpec:
    """Build argv/env for a value-transfer workload."""
    sender_key_name: str = resolve_account_ref_to_online_key(wl.sender)
    receiver_key_name: str = resolve_account_ref_to_online_key(wl.receiver)

    sender_record = keys.get(sender_key_name)
    if not sender_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"sender account '{wl.sender}' → manifest key "
            f"'{sender_key_name}' not found in materialized manifest. "
            f"Ensure the topology defines the tier with enough accounts "
            f"and re-materialize.",
            entity=wl.name,
        )
    sender_privkey: Optional[str] = sender_record.privkey_path
    sender_pubkey: Optional[str] = sender_record.pubkey_content
    if not sender_privkey or not os.path.isfile(sender_privkey):
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"sender privkey path '{sender_privkey}' does not exist.",
            entity=wl.name,
        )
    if not sender_pubkey:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"sender pubkey for '{wl.sender}' is empty.",
            entity=wl.name,
        )

    receiver_record = keys.get(receiver_key_name)
    if not receiver_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"receiver account '{wl.receiver}' → manifest key "
            f"'{receiver_key_name}' not found in materialized manifest.",
            entity=wl.name,
        )
    receiver_pubkey: Optional[str] = receiver_record.pubkey_content
    if not receiver_pubkey:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"receiver pubkey for '{wl.receiver}' is empty.",
            entity=wl.name,
        )

    if not rest_server:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': "
            f"no GraphQL URI available for client commands.",
            entity=wl.name,
        )

    interval_secs: str = _fmt_interval(wl.interval_seconds)
    count: Optional[int] = wl.count

    wl_argv: List[str] = [
        sys.executable,
        str(ENTRYPOINT),
        "_vt_worker",
        mina_exe,
        rest_server,
        sender_privkey,
        sender_pubkey,
        receiver_pubkey,
        wl.amount,
        interval_secs,
    ]
    if count is not None:
        wl_argv.append(str(count))
    return WorkloadLaunchSpec(
        argv=wl_argv,
        env={"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS},
    )


def build_zkapp_argv(
    wl: ZkappWorkload,
    keys: Dict[str, KeyRecord],
    rest_server: str,
    zkapp_exe: str,
) -> WorkloadLaunchSpec:
    """Build argv/env for a zkApp workload."""
    fee_payer_key_name: str = resolve_account_ref_to_offline_key(wl.fee_payer_account)
    sender_key_name: str = resolve_account_ref_to_offline_key(wl.sender_account)
    safe_wl_name: str = re.sub(r"[^a-zA-Z0-9_]", "_", wl.name)
    zkapp_key_name: str = f"zkapp_account_{safe_wl_name}"

    fee_payer_record = keys.get(fee_payer_key_name)
    if not fee_payer_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"zkapp workload '{wl.name}': "
            f"fee payer account '{wl.fee_payer_account}' → manifest key "
            f"'{fee_payer_key_name}' not found in materialized manifest.",
            entity=wl.name,
        )
    fee_payer_privkey: Optional[str] = fee_payer_record.privkey_path
    fee_payer_pubkey: Optional[str] = fee_payer_record.pubkey_content

    sender_record = keys.get(sender_key_name)
    if not sender_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"zkapp workload '{wl.name}': "
            f"sender account '{wl.sender_account}' → manifest key "
            f"'{sender_key_name}' not found in materialized manifest.",
            entity=wl.name,
        )
    sender_privkey: Optional[str] = sender_record.privkey_path
    sender_pubkey: Optional[str] = sender_record.pubkey_content

    zkapp_record = keys.get(zkapp_key_name)
    if not zkapp_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"zkapp workload '{wl.name}': "
            f"zkApp key '{zkapp_key_name}' not found in "
            f"materialized manifest. Re-materialize to generate it.",
            entity=wl.name,
        )
    zkapp_privkey: Optional[str] = zkapp_record.privkey_path
    zkapp_pubkey: Optional[str] = zkapp_record.pubkey_content

    for label, privkey_path in [
        ("fee payer privkey", fee_payer_privkey),
        ("sender privkey", sender_privkey),
        ("zkApp privkey", zkapp_privkey),
    ]:
        if not privkey_path or not os.path.isfile(privkey_path):
            raise WorkloadError(
                ErrorCode.WORKLOAD_KEY_NOT_FOUND,
                message=f"zkapp workload '{wl.name}': "
                f"{label} path '{privkey_path}' does not exist.",
                entity=wl.name,
            )

    if not rest_server:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"zkapp workload '{wl.name}': "
            f"no GraphQL URI available for client commands.",
            entity=wl.name,
        )

    resolved_zkapp_exe: str = resolve_existing_executable(
        zkapp_exe,
        label="zkApp binary",
    )

    interval_secs: str = _fmt_interval(wl.interval_seconds)
    count: Optional[int] = wl.count
    create_account: Optional[bool] = wl.create_account

    wl_argv: List[str] = [
        sys.executable,
        str(ENTRYPOINT),
        "_zkapp_worker",
        resolved_zkapp_exe,
        rest_server,
        fee_payer_privkey,
        fee_payer_pubkey,
        sender_privkey,
        sender_pubkey,
        zkapp_privkey,
        zkapp_pubkey,
        wl.transfer_amount,
        wl.receiver_amount,
        wl.fee,
        interval_secs,
    ]
    if create_account:
        wl_argv.append("--create-account")
    if count is not None:
        wl_argv.append(str(count))
    return WorkloadLaunchSpec(
        argv=wl_argv,
        env={"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS},
    )


def build_itn_max_cost_argv(
    wl: ItnMaxCostWorkload,
    keys: Dict[str, KeyRecord],
    mina_exe: str,
    itn_result: ItnInjectionResult,
) -> WorkloadLaunchSpec:
    """Build argv/env for an itn_max_cost workload."""
    fee_payer_key_name: str = resolve_account_ref_to_offline_key(wl.fee_payer_account)
    fee_payer_record = keys.get(fee_payer_key_name)
    if not fee_payer_record:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"itn_max_cost workload '{wl.name}': "
            f"fee payer account '{wl.fee_payer_account}' → manifest key "
            f"'{fee_payer_key_name}' not found in materialized manifest.",
            entity=wl.name,
        )
    fee_payer_privkey: Optional[str] = fee_payer_record.privkey_path
    fee_payer_pubkey: Optional[str] = fee_payer_record.pubkey_content
    if not fee_payer_privkey or not os.path.isfile(fee_payer_privkey):
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"itn_max_cost workload '{wl.name}': "
            f"fee payer privkey path '{fee_payer_privkey}' does not exist.",
            entity=wl.name,
        )
    if not fee_payer_pubkey:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"itn_max_cost workload '{wl.name}': "
            f"fee payer pubkey for '{wl.fee_payer_account}' is empty.",
            entity=wl.name,
        )

    if not mina_exe or not os.path.isfile(mina_exe):
        raise SpawnError(
            ErrorCode.BINARY_NOT_FOUND,
            message=f"itn_max_cost workload '{wl.name}': "
            f"mina binary not found at '{mina_exe}'.",
            path=str(mina_exe),
        )

    itn_graphql_uri: Optional[str] = wl.itn_graphql_uri
    if not itn_graphql_uri:
        raise SpawnError(
            ErrorCode.SERVICE_MISSING_DEPENDENCY,
            message=f"itn_max_cost workload '{wl.name}': "
            f"no ITN GraphQL URI available. Ensure the node has "
            f"itn_graphql capability.",
        )

    itn_key_material = itn_result.auth_keys.get(wl.name)
    if itn_key_material is None:
        raise SpawnError(
            ErrorCode.KEY_MISSING,
            message=f"itn_max_cost workload '{wl.name}': "
            f"ITN Ed25519 key was not generated.",
        )
    itn_privkey_path: str = itn_key_material.priv_path
    itn_b64_pubkey: str = itn_key_material.b64_pubkey

    duration_min: str = str(wl.duration_min)
    tps_val: str = str(wl.tps)
    num_zkapps: str = str(wl.num_zkapps_to_deploy)
    max_cost_updates: str = str(wl.max_cost_num_updates)
    num_new_accts: str = str(wl.num_new_accounts)
    acct_queue: str = str(wl.account_queue_size)
    memo: str = str(wl.memo_prefix)
    no_precond: str = "1" if wl.no_precondition else "0"
    min_bal: str = str(wl.min_balance_change)
    max_bal: str = str(wl.max_balance_change)
    min_new_bal: str = str(wl.min_new_zkapp_balance)
    max_new_bal: str = str(wl.max_new_zkapp_balance)
    init_bal: str = str(wl.init_balance)
    min_f: str = str(wl.min_fee)
    max_f: str = str(wl.max_fee)
    deploy_f: str = str(wl.deployment_fee)

    wl_argv: List[str] = [
        sys.executable,
        str(ENTRYPOINT),
        "_itn_max_cost_worker",
        mina_exe,
        itn_graphql_uri,
        fee_payer_privkey,
        itn_privkey_path,
        itn_b64_pubkey,
        duration_min,
        tps_val,
        num_zkapps,
        max_cost_updates,
        num_new_accts,
        acct_queue,
        memo,
        no_precond,
        min_bal,
        max_bal,
        min_new_bal,
        max_new_bal,
        init_bal,
        min_f,
        max_f,
        deploy_f,
    ]
    return WorkloadLaunchSpec(
        argv=wl_argv,
        env={"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS},
    )


# ── Cross-workload pubkey conflict detection ────────────────────────


def validate_workload_pubkey_conflicts(
    workloads: List[WorkloadConfig],
    keys: Dict[str, KeyRecord],
) -> None:
    """Detect nonce-advancing pubkey conflicts across workloads."""
    nonce_pubkeys: Dict[str, NonceClaim] = {}
    for wl in workloads:
        if wl.start == WorkloadStart.MANUAL:
            continue
        match wl:
            case ValueTransferWorkload(name=wl_name):
                sender_key_name = resolve_account_ref_to_online_key(wl.sender)
                pubkey = _lookup_pubkey_content(keys, sender_key_name)
                if pubkey is not None:
                    if pubkey in nonce_pubkeys:
                        prior_claim = nonce_pubkeys[pubkey]
                        raise WorkloadError(
                            ErrorCode.WORKLOAD_PUBKEY_CONFLICT,
                            message=f"Pubkey conflict: '{wl_name}' (value_transfer sender) "
                            f"and '{prior_claim.workload_name}' "
                            f"({prior_claim.role}) share pubkey content. "
                            f"Concurrent workloads must use distinct accounts "
                            f"to avoid nonce contention.",
                        )
                    nonce_pubkeys[pubkey] = NonceClaim(
                        workload_name=wl_name,
                        role="value_transfer sender",
                    )
            case ZkappWorkload(name=wl_name):
                for account_ref, role in [
                    (wl.fee_payer_account, "zkapp fee_payer"),
                    (wl.sender_account, "zkapp sender"),
                ]:
                    key_name = resolve_account_ref_to_offline_key(account_ref)
                    pubkey = _lookup_pubkey_content(keys, key_name)
                    if pubkey is not None:
                        if pubkey in nonce_pubkeys:
                            prior_claim = nonce_pubkeys[pubkey]
                            raise WorkloadError(
                                ErrorCode.WORKLOAD_PUBKEY_CONFLICT,
                                message=f"Pubkey conflict: '{wl_name}' ({role}) "
                                f"and '{prior_claim.workload_name}' "
                                f"({prior_claim.role}) share pubkey content. "
                                f"Concurrent workloads must use distinct accounts "
                                f"to avoid nonce contention.",
                            )
                        nonce_pubkeys[pubkey] = NonceClaim(
                            workload_name=wl_name,
                            role=role,
                        )
            case ItnMaxCostWorkload(name=wl_name):
                key_name = resolve_account_ref_to_offline_key(wl.fee_payer_account)
                pubkey = _lookup_pubkey_content(keys, key_name)
                if pubkey is not None:
                    if pubkey in nonce_pubkeys:
                        prior_claim = nonce_pubkeys[pubkey]
                        raise WorkloadError(
                            ErrorCode.WORKLOAD_PUBKEY_CONFLICT,
                            message=f"Pubkey conflict: '{wl_name}' (itn_max_cost fee_payer) "
                            f"and '{prior_claim.workload_name}' "
                            f"({prior_claim.role}) share pubkey content. "
                            f"Concurrent workloads must use distinct accounts "
                            f"to avoid nonce contention.",
                        )
                    nonce_pubkeys[pubkey] = NonceClaim(
                        workload_name=wl_name,
                        role="itn_max_cost fee_payer",
                    )
            case _:
                pass  # echo workloads don't advance nonces
