"""ITN (Incentivized Testnet) preflight, key generation, and daemon‑argv injection.

The main entry point is :func:`prepare_itn_injection`.
"""

from __future__ import annotations

import base64
import os
import re
import subprocess
from typing import Dict, List, Optional

from mln.errors import ErrorCode, KeyError_, SpawnError
from mln.models import ItnMaxCostWorkload, WorkloadConfig, WorkloadStart
from mln.spawn.types import DaemonEntry, ItnAuthKeyMaterial, ItnInjectionResult


def openssl_ed25519_supported() -> bool:
    """Preflight: verify openssl supports Ed25519 key generation."""
    try:
        result = subprocess.run(
            ["openssl", "genpkey", "-algorithm", "ed25519"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return False
        return True
    except (OSError, subprocess.SubprocessError):
        return False


def generate_itn_ed25519_key(out_dir: str, key_basename: str) -> tuple[str, str]:
    """Generate an Ed25519 private key PEM and extract the base64 raw public key.

    Returns (privkey_path, b64_raw_pubkey).
    """
    priv_path: str = os.path.join(out_dir, key_basename)

    gen_result = subprocess.run(
        ["openssl", "genpkey", "-algorithm", "ed25519", "-out", priv_path],
        capture_output=True,
        text=True,
    )
    if gen_result.returncode != 0:
        raise KeyError_(
            ErrorCode.KEY_GENERATION_FAILED,
            message=f"openssl genpkey failed: {gen_result.stderr.strip()}",
        )
    os.chmod(priv_path, 0o600)

    der_result = subprocess.run(
        ["openssl", "pkey", "-in", priv_path, "-pubout", "-outform", "DER"],
        capture_output=True,
    )
    if der_result.returncode != 0:
        raise KeyError_(
            ErrorCode.KEY_GENERATION_FAILED,
            message=f"openssl pkey -pubout failed: {der_result.stderr.decode(errors='replace').strip()}",
        )
    der_bytes: bytes = der_result.stdout
    if len(der_bytes) < 32:
        raise KeyError_(
            ErrorCode.KEY_GENERATION_FAILED,
            message=f"openssl produced DER output too short ({len(der_bytes)} bytes); "
            "expected at least 32 bytes (raw Ed25519 pubkey).",
        )
    raw_pubkey: bytes = der_bytes[-32:]
    b64_pubkey: str = base64.b64encode(raw_pubkey).decode("ascii")
    return priv_path, b64_pubkey


def safe_workload_dir_name(name: str) -> str:
    """Return a filesystem-safe directory name for *name*."""
    safe_name = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    return safe_name or "workload"


def prepare_itn_injection(
    workloads: List[WorkloadConfig],
    daemon_entries: List[DaemonEntry],
    state_root: str,
) -> ItnInjectionResult:
    """Preflight ITN Ed25519 support, generate per‑workload auth keys,
    inject pubkeys into daemon argv, and return typed key material.

    **Side effect**: mutates ``DaemonEntry.argv`` in‑place on the entry
    whose argv contains ``--itn-graphql-port``.
    """
    auto_itn_wls: List[ItnMaxCostWorkload] = [
        w
        for w in workloads
        if isinstance(w, ItnMaxCostWorkload) and w.start != WorkloadStart.MANUAL
    ]

    if not auto_itn_wls:
        return ItnInjectionResult(auth_keys={}, itn_workloads=[])

    if not openssl_ed25519_supported():
        raise SpawnError(
            ErrorCode.ED25519_UNSUPPORTED,
            message="One or more itn_max_cost workloads require Ed25519 key "
            "generation via openssl, but 'openssl genpkey -algorithm ed25519' "
            "failed.  Install openssl >= 1.1.1 or set ITN workloads to "
            "start='manual'.",
        )

    _itn_key_root: str = os.path.join(state_root, "itn_keys")
    os.makedirs(_itn_key_root, mode=0o700, exist_ok=True)
    os.chmod(_itn_key_root, 0o700)

    auth_keys: Dict[str, ItnAuthKeyMaterial] = {}
    for _iwl in auto_itn_wls:
        _wl_name = _iwl.name
        _itn_key_dir = os.path.join(_itn_key_root, safe_workload_dir_name(_wl_name))
        os.makedirs(_itn_key_dir, mode=0o700, exist_ok=True)
        os.chmod(_itn_key_dir, 0o700)
        _priv_path, _b64_pubkey = generate_itn_ed25519_key(_itn_key_dir, "itn-key")
        auth_keys[_wl_name] = ItnAuthKeyMaterial(
            workload_name=_wl_name,
            priv_path=_priv_path,
            b64_pubkey=_b64_pubkey,
        )

    _itn_pubkeys: str = ",".join(_mat.b64_pubkey for _mat in auth_keys.values())
    _itn_daemon: Optional[DaemonEntry] = None
    for de in daemon_entries:
        if "--itn-graphql-port" in de.argv:
            _itn_daemon = de
            break
    if _itn_daemon is None:
        raise SpawnError(
            ErrorCode.NODE_CONFIG,
            message="One or more itn_max_cost workloads require ITN GraphQL, "
            "but no daemon argv contains --itn-graphql-port. Ensure "
            "the topology includes itn_graphql capability on a node.",
        )
    _itn_dargv: List[str] = _itn_daemon.argv
    if "--itn-keys" in _itn_dargv:
        _itn_idx: int = _itn_dargv.index("--itn-keys")
        if _itn_idx + 1 < len(_itn_dargv):
            _itn_dargv[_itn_idx + 1] = _itn_pubkeys
        else:
            _itn_dargv.append(_itn_pubkeys)
    else:
        try:
            _gql_port_idx: int = _itn_dargv.index("--itn-graphql-port")
            _itn_dargv.insert(_gql_port_idx + 2, "--itn-keys")
            _itn_dargv.insert(_gql_port_idx + 3, _itn_pubkeys)
        except ValueError:
            _itn_dargv.extend(["--itn-keys", _itn_pubkeys])

    return ItnInjectionResult(
        auth_keys=auth_keys,
        itn_workloads=auto_itn_wls,
    )
