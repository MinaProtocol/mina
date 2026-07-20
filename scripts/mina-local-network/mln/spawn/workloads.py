"""Workload launch construction and cross-workload validation.

Echo workloads resolve to an ``argv`` (they run an arbitrary external
command); the Python workers resolve to a typed payload consumed in-process.
"""

from __future__ import annotations

import os
import re
from typing import Dict, List, Optional, Tuple

from mln.amounts import amount_dsl_to_nanomina, parse_account_spec
from mln.constants import DEFAULT_PRIVKEY_PASS
from mln.errors import ErrorCode, SpawnError, WorkloadError
from mln.models import (
    EchoWorkload,
    ItnMaxCostPayload,
    ItnMaxCostWorkload,
    KeyRecord,
    NonceClaim,
    TransferAccount,
    ValueTransferPayload,
    ValueTransferWorkload,
    WorkloadConfig,
    WorkloadStart,
    ZkappPayload,
    ZkappWorkload,
)
from mln.process import resolve_existing_executable
from mln.spawn.types import ItnInjectionResult

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


def online_key_name_to_account_ref(key_name: str) -> str:
    """Inverse of :func:`resolve_account_ref_to_online_key`.

    ``online_whale_account_1`` → ``whale-1``. Only valid for online-tier key
    names (as produced by :func:`_online_account_pool`).
    """
    body = key_name[len("online_") :]  # 'whale_account_1'
    tier, _sep, index = body.rpartition("_account_")
    return f"{tier}-{index}"


# ── Per-workload argv builders ──────────────────────────────────────


def build_echo_argv(wl: EchoWorkload) -> Tuple[List[str], Dict[str, str]]:
    """Resolve an echo workload's argv/env — a thin passthrough.

    Returns ``(argv, env)`` to match the shape of the payload builders below.
    """
    return list(wl.argv), dict(wl.env)


def _online_account_pool(keys: Dict[str, KeyRecord]) -> List[Tuple[str, KeyRecord]]:
    """Eligible value-transfer accounts: online-tier keys with a usable privkey.

    Online-tier keys (``online_<tier>_account_<i>``) are the ones that can sign
    payments; sorted for a deterministic pool order (home-node assignment keys
    off it).
    """
    pool: List[Tuple[str, KeyRecord]] = []
    for name in sorted(keys):
        if not (name.startswith("online_") and "_account_" in name):
            continue
        rec = keys[name]
        if rec.privkey_path and os.path.isfile(rec.privkey_path) and rec.pubkey_content:
            pool.append((name, rec))
    return pool


def value_transfer_pool_refs(keys: Dict[str, KeyRecord]) -> List[str]:
    """Account refs (e.g. ``whale-1``) the value_transfer worker's pool draws from.

    The pool is derived here (see :func:`_online_account_pool`); this exposes it
    as refs so a caller — the hardfork harness snapshotting per-account nonces to
    carry across the fork — need not reimplement the ref→key mapping that
    mina-local-network owns. Order matches the pool's (sorted, deterministic).
    """
    return [online_key_name_to_account_ref(name) for name, _rec in _online_account_pool(keys)]


def build_value_transfer_payload(
    wl: ValueTransferWorkload,
    keys: Dict[str, KeyRecord],
    node_rest_uris: List[str],
    mina_exe: str,
) -> Tuple[ValueTransferPayload, Dict[str, str]]:
    """Resolve the eligible account pool + home nodes into a typed payload.

    Sender/receiver are chosen at runtime from ``accounts``; each account is
    assigned a stable home node round-robin across ``node_rest_uris`` so its
    nonce sequence stays on one daemon.
    """
    if not node_rest_uris:
        raise WorkloadError(
            ErrorCode.SERVICE_MISSING_DEPENDENCY,
            message=f"value_transfer workload '{wl.name}': "
            f"no daemon REST endpoints available for client commands.",
            entity=wl.name,
        )

    pool = _online_account_pool(keys)
    if len(pool) < 2:
        raise WorkloadError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"value_transfer workload '{wl.name}': needs ≥2 online-tier "
            f"accounts to pick distinct sender/receiver, found {len(pool)}. "
            f"Ensure the topology defines enough accounts and re-materialize.",
            entity=wl.name,
        )

    accounts = [
        TransferAccount(
            name=name,
            pubkey=rec.pubkey_content,
            privkey_path=rec.privkey_path,
            home_rest_uri=node_rest_uris[i % len(node_rest_uris)],
        )
        for i, (name, rec) in enumerate(pool)
    ]

    # Re-key the ref-addressed carry-over expectations (e.g. {"whale-0": 67}) onto
    # the pool's key names (e.g. "online_whale_account_0"), which is how the worker
    # names its accounts. Only refs present in the pool are carried; a ref outside
    # it has no account to check.
    pool_names = {name for name, _rec in pool}
    carryover_by_name: Dict[str, int] = {}
    for ref, nonce in wl.assert_carryover_nonces.items():
        key_name = resolve_account_ref_to_online_key(ref)
        if key_name in pool_names:
            carryover_by_name[key_name] = nonce

    amount_min = amount_dsl_to_nanomina(wl.amount_min)
    amount_max = amount_dsl_to_nanomina(wl.amount_max)
    fee_nanomina = amount_dsl_to_nanomina(wl.fee)
    if amount_min > amount_max:
        raise WorkloadError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"value_transfer workload '{wl.name}': amount_min "
            f"({wl.amount_min}) exceeds amount_max ({wl.amount_max}).",
            entity=wl.name,
        )

    payload = ValueTransferPayload(
        mina_exe=mina_exe,
        accounts=accounts,
        amount_min_nanomina=amount_min,
        amount_max_nanomina=amount_max,
        fee_nanomina=fee_nanomina,
        interval_secs=wl.interval_seconds,
        count=wl.count,
        first_nonce=wl.first_nonce,
        assert_carryover_nonces=carryover_by_name,
        replay_probability=wl.replay_probability,
    )
    return payload, {"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS}


def build_zkapp_payload(
    wl: ZkappWorkload,
    keys: Dict[str, KeyRecord],
    rest_server: str,
    zkapp_exe: str,
) -> Tuple[ZkappPayload, Dict[str, str]]:
    """Resolve keys/paths into a typed zkApp payload and its env."""
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
            ErrorCode.SERVICE_MISSING_DEPENDENCY,
            message=f"zkapp workload '{wl.name}': "
            f"no GraphQL URI available for client commands.",
            entity=wl.name,
        )

    resolved_zkapp_exe: str = resolve_existing_executable(
        zkapp_exe,
        label="zkApp binary",
    )

    payload = ZkappPayload(
        zkapp_exe=resolved_zkapp_exe,
        graphql_uri=rest_server,
        fee_payer_privkey_path=fee_payer_privkey,
        fee_payer_pubkey=fee_payer_pubkey,
        sender_privkey_path=sender_privkey,
        sender_pubkey=sender_pubkey,
        zkapp_privkey_path=zkapp_privkey,
        zkapp_pubkey=zkapp_pubkey,
        transfer_amount=wl.transfer_amount,
        receiver_amount=wl.receiver_amount,
        fee=wl.fee,
        interval_secs=wl.interval_seconds,
        create_account=wl.create_account,
        count=wl.count,
    )
    return payload, {"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS}


def build_itn_max_cost_payload(
    wl: ItnMaxCostWorkload,
    keys: Dict[str, KeyRecord],
    mina_exe: str,
    itn_result: ItnInjectionResult,
) -> Tuple[ItnMaxCostPayload, Dict[str, str]]:
    """Resolve keys/paths into a typed itn_max_cost payload and its env."""
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

    payload = ItnMaxCostPayload(
        mina_exe=mina_exe,
        itn_graphql_uri=itn_graphql_uri,
        fee_payer_privkey_path=fee_payer_privkey,
        itn_privkey_path=itn_privkey_path,
        itn_pubkey=itn_b64_pubkey,
        duration_min=wl.duration_min,
        tps=wl.tps,
        num_zkapps_to_deploy=wl.num_zkapps_to_deploy,
        max_cost_num_updates=wl.max_cost_num_updates,
        num_new_accounts=wl.num_new_accounts,
        account_queue_size=wl.account_queue_size,
        memo_prefix=wl.memo_prefix,
        no_precondition=wl.no_precondition,
        min_balance_change=wl.min_balance_change,
        max_balance_change=wl.max_balance_change,
        min_new_zkapp_balance=wl.min_new_zkapp_balance,
        max_new_zkapp_balance=wl.max_new_zkapp_balance,
        init_balance=wl.init_balance,
        min_fee=wl.min_fee,
        max_fee=wl.max_fee,
        deployment_fee=wl.deployment_fee,
    )
    return payload, {"MINA_PRIVKEY_PASS": DEFAULT_PRIVKEY_PASS}


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
            case ValueTransferWorkload():
                # value_transfer draws senders at random from the whole online
                # pool, so it claims no single account. Its per-account nonce is
                # owned by the worker (which pins every send), not contended here.
                # (Online pool vs the offline keys zkapp/itn use → no overlap.)
                pass
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
