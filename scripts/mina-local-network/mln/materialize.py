from __future__ import annotations

import datetime
import json
import re
import shutil
import stat
from pathlib import Path
from typing import Any, Dict, List, Optional

from mln.amounts import convert_balance_to_decimal_mina
from mln.errors import ErrorCode, ManifestError, MaterializeError
from mln.keypair import compute_genesis_timestamp_utc, generate_keypair
from mln.models import (
    KeyRecord,
    MaterializedManifest,
    MaterializeResult,
    ResolvedPlan,
    ZkappWorkload,
)
from mln.plan import FINGERPRINT_ALGORITHM, plan_fingerprint


def do_materialize(plan: ResolvedPlan, force: bool, dry_run: bool) -> MaterializeResult:
    """Materialize static artifacts (keys, config, ledger) from a typed plan.

    Returns a structural ``MaterializeResult`` — never a raw dict.
    """
    state_root = plan.state.root
    sr_path = Path(state_root)
    manifest_path = sr_path / "materialized-manifest.json"

    mina_exe = plan.binaries.mina

    # --- Preflight: detect existing owned artifacts ---
    if not dry_run:
        # Build the set of artifact paths materialize will generate
        _preflight_artifacts: List[str] = []

        # Core config artifacts
        _preflight_artifacts.append(str(sr_path / "materialized-manifest.json"))
        _preflight_artifacts.append(str(sr_path / "daemon.json"))
        _preflight_artifacts.append(str(sr_path / "genesis_ledger.json"))

        # Key files that will be generated
        _pf_tiers = plan.ledger.tiers
        _pf_key_dirs = plan.ledger.key_dirs

        for _pf_tier_name, _pf_tier_def in _pf_tiers.items():
            count = _pf_tier_def.count
            for idx in range(count):
                for prefix in ("offline", "online"):
                    key_dir_key = f"{prefix}_{_pf_tier_name}"
                    if key_dir_key not in _pf_key_dirs:
                        continue
                    kd = _pf_key_dirs[key_dir_key]
                    key_base = f"{prefix}_{_pf_tier_name}_account_{idx}"
                    privkey_path = str(Path(kd) / key_base)
                    _preflight_artifacts.append(privkey_path)
                    _preflight_artifacts.append(privkey_path + ".pub")

        # Snark coordinator key
        _pf_sc_key_dir = _pf_key_dirs.get("snark_coordinator")
        if _pf_sc_key_dir:
            sc_key_base = "snark_coordinator_account"
            sc_privkey_path = str(Path(_pf_sc_key_dir) / sc_key_base)
            _preflight_artifacts.append(sc_privkey_path)
            _preflight_artifacts.append(sc_privkey_path + ".pub")

        # zkApp per-workload keys
        for _wl in plan.workloads:
            match _wl:
                case ZkappWorkload(name=wl_name):
                    _safe_name = re.sub(r"[^a-zA-Z0-9_]", "_", wl_name)
                    _zkapp_key_dir = f"{state_root}/zkapp_keys"
                    _zkapp_key_base = f"zkapp_account_{_safe_name}"
                    _zkapp_privkey = str(Path(_zkapp_key_dir) / _zkapp_key_base)
                    _preflight_artifacts.append(_zkapp_privkey)
                    _preflight_artifacts.append(_zkapp_privkey + ".pub")
                case _:
                    pass

        _existing = [p for p in _preflight_artifacts if Path(p).exists()]
        if _existing and not force:
            sample = _existing[:5]
            msg_lines = [
                "Materialized artifacts already exist. To overwrite, pass --force.",
                "Existing files include:",
            ]
            msg_lines += [f"  - {p}" for p in sample]
            if len(_existing) > 5:
                msg_lines.append(f"  ... and {len(_existing) - 5} more")
            raise ManifestError(
                ErrorCode.MATERIALIZED_EXISTS,
                message="\n".join(msg_lines),
                path=state_root,
            )

    generated_files: List[str] = []
    key_results: Dict[str, KeyRecord] = {}

    def _mkdir(path: Path, mode: Optional[int] = None):
        """Create directory if missing; record if created."""
        if not path.exists():
            if not dry_run:
                path.mkdir(parents=True, exist_ok=True)
                if mode is not None:
                    path.chmod(mode)
            generated_files.append(str(path))

    # --- Create state root ---
    _mkdir(sr_path)

    # --- Create key directories (0700) ---
    key_dirs = plan.ledger.key_dirs
    for _name, kd in sorted(key_dirs.items()):
        _mkdir(Path(kd), mode=stat.S_IRWXU)

    # --- Create node config directories ---
    for node in plan.nodes:
        cd = node.config_dir
        if cd:
            _mkdir(Path(cd))

    # --- Create worker config directories ---
    for worker in plan.workers:
        cd = worker.config_dir
        if cd:
            _mkdir(Path(cd))

    # --- Create service config directories ---
    for svc in plan.services:
        cd = svc.config_dir
        if cd:
            _mkdir(Path(cd))

    if dry_run:
        # Return a structured result — no raw dict.
        return MaterializeResult(
            schema_version=1,
            materialized_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            mode="dry_run",
            state_root=state_root,
            planned_dirs=sorted(generated_files),
        )

    # --- Generate keypairs ---
    tiers = plan.ledger.tiers

    # Determine keys to generate from plan data
    key_dirs_map = key_dirs
    # offline keys: tier.account_index
    for tier_name, tier_def in tiers.items():
        count = tier_def.count
        for idx in range(count):
            for prefix in ("offline", "online"):
                key_dir_key = f"{prefix}_{tier_name}"
                if key_dir_key not in key_dirs_map:
                    continue
                kd = key_dirs_map[key_dir_key]
                key_base = f"{prefix}_{tier_name}_account_{idx}"
                privkey_path = str(Path(kd) / key_base)
                if Path(privkey_path).exists() and Path(privkey_path + ".pub").exists():
                    pub_content = (
                        Path(privkey_path + ".pub").read_text(encoding="utf-8").strip()
                    )
                    key_results[key_base] = KeyRecord(
                        privkey_path=privkey_path,
                        pubkey_path=privkey_path + ".pub",
                        pubkey_content=pub_content,
                    )
                    generated_files.append(privkey_path)
                    generated_files.append(privkey_path + ".pub")
                    continue
                result = generate_keypair(mina_exe, privkey_path)
                key_results[key_base] = result
                generated_files.append(privkey_path)
                generated_files.append(privkey_path + ".pub")

    # Snark coordinator key
    sc_key_dir = key_dirs_map.get("snark_coordinator")
    if sc_key_dir:
        sc_key_base = "snark_coordinator_account"
        privkey_path = str(Path(sc_key_dir) / sc_key_base)
        if Path(privkey_path).exists() and Path(privkey_path + ".pub").exists():
            pub_content = (
                Path(privkey_path + ".pub").read_text(encoding="utf-8").strip()
            )
            key_results[sc_key_base] = KeyRecord(
                privkey_path=privkey_path,
                pubkey_path=privkey_path + ".pub",
                pubkey_content=pub_content,
            )
            generated_files.append(privkey_path)
            generated_files.append(privkey_path + ".pub")
        else:
            result = generate_keypair(mina_exe, privkey_path)
            key_results[sc_key_base] = result
            generated_files.append(privkey_path)
            generated_files.append(privkey_path + ".pub")

    # zkApp per-workload keypairs (NOT added to genesis ledger)
    for wl in plan.workloads:
        match wl:
            case ZkappWorkload(name=wl_name):
                safe_name = re.sub(r"[^a-zA-Z0-9_]", "_", wl_name)
                zkapp_key_dir = str(sr_path / "zkapp_keys")
                _mkdir(Path(zkapp_key_dir), mode=stat.S_IRWXU)
                zkapp_key_base = f"zkapp_account_{safe_name}"
                zkapp_privkey_path = str(Path(zkapp_key_dir) / zkapp_key_base)
                manifest_key = f"zkapp_account_{safe_name}"
                if (
                    Path(zkapp_privkey_path).exists()
                    and Path(zkapp_privkey_path + ".pub").exists()
                ):
                    pub_content = (
                        Path(zkapp_privkey_path + ".pub")
                        .read_text(encoding="utf-8")
                        .strip()
                    )
                    key_results[manifest_key] = KeyRecord(
                        privkey_path=zkapp_privkey_path,
                        pubkey_path=zkapp_privkey_path + ".pub",
                        pubkey_content=pub_content,
                    )
                    generated_files.append(zkapp_privkey_path)
                    generated_files.append(zkapp_privkey_path + ".pub")
                else:
                    result = generate_keypair(mina_exe, zkapp_privkey_path)
                    key_results[manifest_key] = result
                    generated_files.append(zkapp_privkey_path)
                    generated_files.append(zkapp_privkey_path + ".pub")
            case _:
                pass

    # --- Write daemon.json ---
    gen_ts_value = plan.state.genesis_timestamp.value
    if gen_ts_value is not None:
        gen_ts_utc = gen_ts_value
    else:
        gen_ts_delay = plan.state.genesis_timestamp.delay
        gen_ts_utc = compute_genesis_timestamp_utc(gen_ts_delay)

    ledger_config = plan.ledger.config
    genesis_cfg = ledger_config.genesis
    proof_cfg = ledger_config.proof

    proof_block: Dict[str, Any] = {
        "level": proof_cfg.level,
        "work_delay": proof_cfg.work_delay,
        "transaction_capacity": proof_cfg.transaction_capacity,
    }
    if proof_cfg.block_window_duration_ms is not None:
        proof_block["block_window_duration_ms"] = proof_cfg.block_window_duration_ms

    daemon_json = {
        "genesis": {
            "slots_per_epoch": genesis_cfg.slots_per_epoch,
            "k": genesis_cfg.k,
            "grace_period_slots": genesis_cfg.grace_period_slots,
            "genesis_state_timestamp": gen_ts_utc,
        },
        "proof": proof_block,
        "ledger": {
            "name": "mina-local-network",
            "accounts": [],
        },
    }

    # Build ledger accounts from generated keys
    # Online entries are built first so offline entries can delegate to their
    # corresponding online pubkey.
    for tier_name, tier_def in tiers.items():
        count = tier_def.count
        offline_bal_raw = tier_def.offline_balance
        online_bal_raw = tier_def.online_balance
        offline_bal = (
            convert_balance_to_decimal_mina(offline_bal_raw) if offline_bal_raw else ""
        )
        online_bal = (
            convert_balance_to_decimal_mina(online_bal_raw) if online_bal_raw else ""
        )
        for idx in range(count):
            # online account (appears first in the ledger)
            online_key_name = f"online_{tier_name}_account_{idx}"
            online_delegate_pubkey: Optional[str] = None
            if online_bal and online_key_name in key_results:
                online_delegate_pubkey = key_results[online_key_name].pubkey_content
                daemon_json["ledger"]["accounts"].append(
                    {
                        "pk": online_delegate_pubkey,
                        "balance": online_bal,
                        "sk": None,
                        "delegate": None,
                    }
                )
            # offline account — delegates to online pubkey of the same pair
            offline_key_name = f"offline_{tier_name}_account_{idx}"
            if offline_bal and offline_key_name in key_results:
                daemon_json["ledger"]["accounts"].append(
                    {
                        "pk": key_results[offline_key_name].pubkey_content,
                        "balance": offline_bal,
                        "sk": None,
                        "delegate": online_delegate_pubkey,
                    }
                )

    # Add snark coordinator account if generated
    sc_key_name = "snark_coordinator_account"
    if sc_key_name in key_results:
        sc_tier = tiers.get("snark_coordinator")
        sc_balance_raw = sc_tier.offline_balance if sc_tier else "5mina"
        sc_balance = convert_balance_to_decimal_mina(sc_balance_raw)
        daemon_json["ledger"]["accounts"].append(
            {
                "pk": key_results[sc_key_name].pubkey_content,
                "balance": sc_balance,
                "sk": None,
                "delegate": None,
            }
        )

    # --- Merge extra genesis accounts file if configured ---
    extra_acct_file_path = plan.ledger.extra_accounts_file
    if extra_acct_file_path:
        extra_path = Path(extra_acct_file_path)
        if not extra_path.is_file():
            raise MaterializeError(
                ErrorCode.FILE_NOT_FOUND,
                message=f"Extra genesis accounts file not found: {extra_acct_file_path}",
                path=extra_acct_file_path,
            )
        try:
            extra_accounts_data = json.loads(extra_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise MaterializeError(
                ErrorCode.INVALID_ARGUMENT,
                message=f"Extra genesis accounts file is not valid JSON: {exc}",
                path=extra_acct_file_path,
            ) from exc
        if not isinstance(extra_accounts_data, list):
            raise MaterializeError(
                ErrorCode.INVALID_ARGUMENT,
                message="Extra genesis accounts file must contain a JSON array of account objects. "
                f"Got {type(extra_accounts_data).__name__}.",
                path=extra_acct_file_path,
            )
        for idx, acct in enumerate(extra_accounts_data):
            if not isinstance(acct, dict):
                raise MaterializeError(
                    ErrorCode.INVALID_ARGUMENT,
                    message=f"Extra genesis accounts file entry #{idx} is not an object. "
                    f"Got {type(acct).__name__}.",
                    path=extra_acct_file_path,
                )
            if "pk" not in acct or "balance" not in acct:
                raise MaterializeError(
                    ErrorCode.INVALID_ARGUMENT,
                    message=f"Extra genesis accounts file entry #{idx} must have 'pk' and 'balance' keys. "
                    f"Got keys: {list(acct.keys())}.",
                    path=extra_acct_file_path,
                )
        daemon_json["ledger"]["accounts"].extend(extra_accounts_data)

    # --- Build canonical ledger object (matches legacy generator shape) ---
    ledger_obj = {
        "name": "mina-local-network",
        "num_accounts": len(daemon_json["ledger"]["accounts"]),
        "accounts": daemon_json["ledger"]["accounts"],
    }
    daemon_json["ledger"] = ledger_obj

    # --- Add daemon section if non-empty ---
    daemon_cfg = ledger_config.daemon
    daemon_section: Dict[str, Any] = {}
    if daemon_cfg.slot_tx_end is not None:
        daemon_section["slot_tx_end"] = daemon_cfg.slot_tx_end
    if daemon_cfg.slot_chain_end is not None:
        daemon_section["slot_chain_end"] = daemon_cfg.slot_chain_end
    if daemon_cfg.hard_fork_genesis_slot_delta is not None:
        daemon_section["hard_fork_genesis_slot_delta"] = (
            daemon_cfg.hard_fork_genesis_slot_delta
        )
    if daemon_section:
        daemon_json["daemon"] = daemon_section

    daemon_path = sr_path / "daemon.json"
    daemon_path.write_text(json.dumps(daemon_json, indent=2), encoding="utf-8")
    generated_files.append(str(daemon_path))

    # --- Write genesis_ledger.json (top-level ledger object, no wrapper) ---
    genesis_ledger_path = sr_path / "genesis_ledger.json"
    genesis_ledger_path.write_text(json.dumps(ledger_obj, indent=2), encoding="utf-8")
    generated_files.append(str(genesis_ledger_path))

    # --- Overlay extra files root if configured ---
    extra_root = plan.state.extra_files_root
    if extra_root:
        extra_root_path = Path(extra_root)
        if not extra_root_path.is_dir():
            raise MaterializeError(
                ErrorCode.FILE_NOT_FOUND,
                message=f"Extra files root is not an existing directory: {extra_root}",
                path=extra_root,
            )
        for src_path in extra_root_path.rglob("*"):
            if src_path.is_file():
                rel_path = src_path.relative_to(extra_root_path)
                dst_path = sr_path / rel_path
                dst_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_path, dst_path)
                generated_files.append(str(dst_path))

    # --- Write materialized-manifest.json ---
    # Build node_logs map
    node_logs_map: Dict[str, str] = {}
    for node in plan.nodes:
        node_logs_map[node.name] = f"{node.config_dir}/mina.log"

    manifest = MaterializedManifest(
        schema_version=1,
        materialized_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        plan_path=str(sr_path / "network-plan.json"),
        state_root=state_root,
        daemon_config=str(daemon_path),
        genesis_ledger=str(genesis_ledger_path),
        generated_files=sorted(set(generated_files)),
        keys=key_results,
        node_logs=node_logs_map,
        plan_fingerprint=plan_fingerprint(plan),
        plan_fingerprint_algorithm=FINGERPRINT_ALGORITHM,
    )

    manifest_path.write_text(
        json.dumps(manifest.model_dump(mode="json"), indent=2, sort_keys=True),
        encoding="utf-8",
    )
    generated_files.append(str(manifest_path))

    return MaterializeResult(
        schema_version=manifest.schema_version,
        materialized_at=manifest.materialized_at,
        mode="materialized",
        state_root=state_root,
        manifest=manifest,
        planned_dirs=[],
    )
