from __future__ import annotations

import copy
import json
from typing import Dict, List

import click

from mln.schema import resolve_topology_source, validate_topology
from mln.topology import normalize_topology, resolve_topology
from mln.constants import VALID_LOG_LEVELS, VALID_PROOF_LEVELS
from mln.errors import CompatError, ErrorCode
from mln.models import CompatOverrides, NormalizedTopology

# ── Supported legacy flags & their mapping ───────────────────────────────

# Flags that the compact compat converter accepts.  Each entry describes
# how to mutate the topology dict.  Functions receive (topology, value) and
# must mutate topology in place.

_SUPPORTED_FLAGS: Dict[str, str] = {
    "-w": "whales",
    "--whales": "whales",
    "-f": "fish",
    "--fish": "fish",
    "-swc": "snark_workers_count",
    "--snark-workers-count": "snark_workers_count",
    "--fast": "fast",
    "-st": "override_slot_time",
    "--override-slot-time": "override_slot_time",
    "-pl": "proof_level",
    "--proof-level": "proof_level",
    "-wd": "work_delay",
    "--work-delay": "work_delay",
    "-tc": "transaction_capacity_log2",
    "--transaction-capacity-log2": "transaction_capacity_log2",
    "-c": "config_mode",
    "--config": "config_mode",
    "-u": "update_genesis_timestamp",
    "--update-genesis-timestamp": "update_genesis_timestamp",
    "-d": "demo",
    "--demo": "demo",
    "-vt": "value_transfer",
    "--value-transfer-txns": "value_transfer",
    "-zt": "zkapp_transactions",
    "--zkapp-transactions": "zkapp_transactions",
    "-ti": "transaction_interval",
    "--transaction-interval": "transaction_interval",
    "-sf": "snark_worker_fee",
    "--snark-worker-fee": "snark_worker_fee",
    "-ll": "log_level",
    "--log-level": "log_level",
    "-fll": "file_log_level",
    "--file-log-level": "file_log_level",
    "-wll": "worker_log_level",
    "--worker-log-level": "worker_log_level",
    "--snark-worker-nap-sec": "snark_worker_nap_sec",
    "-r": "root",
    "--root": "root",
    "--mina-exe": "mina_exe",
    "--archive-exe": "archive_exe",
    "--zkapp-exe": "zkapp_exe",
}


# Flags that take a value (vs boolean flags).
_VALUE_FLAGS: frozenset = frozenset(
    {
        "-w",
        "--whales",
        "-f",
        "--fish",
        "-swc",
        "--snark-workers-count",
        "-st",
        "--override-slot-time",
        "-pl",
        "--proof-level",
        "-wd",
        "--work-delay",
        "-tc",
        "--transaction-capacity-log2",
        "-c",
        "--config",
        "-u",
        "--update-genesis-timestamp",
        "-sf",
        "--snark-worker-fee",
        "-ll",
        "--log-level",
        "-fll",
        "--file-log-level",
        "-wll",
        "--worker-log-level",
        "--snark-worker-nap-sec",
        "-r",
        "--root",
        "--mina-exe",
        "--archive-exe",
        "--zkapp-exe",
        "-ti",
        "--transaction-interval",
    }
)

# Boolean flags (presence = truthy, no value consumed).
_BOOL_FLAGS: frozenset = frozenset(
    {
        "--fast",
        "-d",
        "--demo",
        "-vt",
        "--value-transfer-txns",
        "-zt",
        "--zkapp-transactions",
    }
)


def _assert_valid_log_level(label: str, value: str) -> None:
    """Raise CompatError if *value* is not a recognised log level."""
    if value not in VALID_LOG_LEVELS:
        raise CompatError(
            ErrorCode.INVALID_FLAG_VALUE,
            message=f"{label}: invalid log level {value!r}. "
            f"Valid levels: {', '.join(sorted(VALID_LOG_LEVELS))}",
        )


def _parse_compat_args(args: List[str]) -> Dict[str, object]:
    """Parse legacy CLI args into a flat dict of key → value (or True for bool).

    Rejects any flag not in *_SUPPORTED_FLAGS*.
    """
    result: Dict[str, object] = {}
    i: int = 0
    while i < len(args):
        arg: str = args[i]
        # Consume a flat arg token (not a flag)
        if not arg.startswith("-"):
            raise CompatError(
                ErrorCode.INVALID_FLAG_VALUE,
                message=f"Unexpected positional argument: {arg!r}. "
                "All arguments must be flags (e.g. --whales 2, -vt).",
            )

        if arg not in _SUPPORTED_FLAGS:
            raise CompatError(
                ErrorCode.UNSUPPORTED_FLAG,
                message=f"Unsupported legacy flag: {arg!r}. "
                "This compact compat translator supports a subset of legacy flags. "
                "Use 'convert compat --help' for details.",
            )

        key: str = _SUPPORTED_FLAGS[arg]
        if arg in _BOOL_FLAGS:
            result[key] = True
            i += 1
        elif arg in _VALUE_FLAGS:
            i += 1
            if i >= len(args):
                raise CompatError(
                    ErrorCode.INVALID_FLAG_VALUE,
                    message=f"Flag {arg!r} expects a value but none was provided.",
                )
            result[key] = args[i]
            i += 1
        else:
            raise CompatError(
                ErrorCode.INVALID_FLAG_VALUE,
                message=f"Internal: no value category for {arg!r}",
            )
    return result


def _build_compat_overrides(parsed: Dict[str, object]) -> CompatOverrides:
    """Build typed ``CompatOverrides`` from raw parsed legacy flag dict.

    Only fields present in *parsed* are forwarded; defaults from
    ``CompatOverrides`` fill the rest.  Pydantic validation errors
    (e.g. non‑integer strings for integer fields) are caught and
    re‑raised as ``CompatError`` with old‑style messages.
    """
    known_fields = set(CompatOverrides.model_fields.keys())
    filtered = {k: v for k, v in parsed.items() if k in known_fields}
    try:
        return CompatOverrides.model_validate(filtered)
    except Exception as exc:
        # Catch Pydantic ValidationError (and any other validation failure)
        # and rewrap as CompatError so the CLI never dumps a raw traceback.
        _err_msg: str
        try:
            from pydantic import ValidationError as _PydanticValidationError

            if isinstance(exc, _PydanticValidationError):
                for _e in exc.errors():
                    _field = ".".join(str(p) for p in _e["loc"])
                    _etype = _e.get("type", "")
                    # Integer / float parsing failures → old‑style message
                    if _etype in ("int_parsing", "int_type", "float_parsing"):
                        raise CompatError(
                            ErrorCode.INVALID_FLAG_VALUE,
                            message=f"{_field} must be an integer, got "
                            f"{filtered.get(_field, '?')!r}",
                        )
                # General Pydantic error
                _err_msg = str(exc)
            else:
                _err_msg = str(exc)
        except CompatError:
            raise  # already wrapped, propagate
        except Exception:
            _err_msg = str(exc)
        raise CompatError(
            ErrorCode.INVALID_FLAG_VALUE,
            message=f"Invalid flag value: {_err_msg}",
        ) from exc


def _apply_compat(topology: dict, parsed: Dict[str, object]) -> dict:
    """Mutate a topology dict (deep-copied from single-node preset) with
    the legacy flag values, using typed ``CompatOverrides``.  Returns the
    modified topology dict."""
    co: CompatOverrides = _build_compat_overrides(parsed)
    t: dict = copy.deepcopy(topology)

    _strip_unused_itn_graphql(t)

    requested_whales: int = co.whales
    requested_fish: int = co.fish

    if co.zkapp_transactions and requested_whales < 2:
        requested_whales = 2

    _set_tier_count(t, "whale", requested_whales)
    _set_tier_count(t, "fish", requested_fish)
    _expand_block_producer_nodes(
        t, whale_count=requested_whales, fish_count=requested_fish
    )

    # ── snark workers count ──────────────────────────────────────────
    if co.snark_workers_count is not None:
        _ensure_seed_node(t)
        _sc: dict = _ensure_snark_coordinator(t)
        _sc.setdefault("worker_pools", {}).setdefault("default", {})["count"] = (
            co.snark_workers_count
        )

    # ── fast mode ────────────────────────────────────────────────────
    if "fast" in parsed:
        raise CompatError(
            ErrorCode.COMPAT_NOT_SUPPORTED,
            message="--fast is not yet supported in compact compat mode because the "
            "Python topology does not currently materialize slot-time overrides "
            "into daemon.json. Use --snark-workers-count 7 explicitly if only "
            "the worker-count part is desired.",
        )

    if "override_slot_time" in parsed:
        raise CompatError(
            ErrorCode.COMPAT_NOT_SUPPORTED,
            message="--override-slot-time is not yet supported in compact compat mode "
            "because the Python topology does not currently materialize "
            "slot-time overrides into daemon.json.",
        )

    # ── proof level ──────────────────────────────────────────────────
    if co.proof_level is not None:
        if co.proof_level not in VALID_PROOF_LEVELS:
            raise CompatError(
                ErrorCode.INVALID_FLAG_VALUE,
                message=f"--proof-level: invalid value {co.proof_level!r}. "
                f"Valid: {', '.join(sorted(VALID_PROOF_LEVELS))}",
            )
        _ensure_runtime_config_proof(t)["level"] = co.proof_level

    # ── work delay ───────────────────────────────────────────────────
    if co.work_delay is not None:
        _ensure_runtime_config_proof(t)["work_delay"] = co.work_delay

    # ── transaction capacity log2 ────────────────────────────────────
    if co.transaction_capacity_log2 is not None:
        _ensure_runtime_config_proof(t).setdefault("transaction_capacity", {})[
            "2_to_the"
        ] = co.transaction_capacity_log2

    # ── config mode ──────────────────────────────────────────────────
    if co.config_mode is not None:
        if co.config_mode not in ("reset", "inherit"):
            raise CompatError(
                ErrorCode.INVALID_FLAG_VALUE,
                message=f"--config must be 'reset' or 'inherit', got {co.config_mode!r}",
            )
        _mode = "reset" if co.config_mode == "reset" else "keep"
        t.setdefault("state", {})["mode"] = _mode

    # ── update genesis timestamp ─────────────────────────────────────
    if "update_genesis_timestamp" in parsed:
        _v = _str_val(parsed["update_genesis_timestamp"], "--update-genesis-timestamp")
        _st = t.setdefault("state", {})
        if _v == "no":
            _st.pop("genesis_timestamp", None)
            _st["genesis_timestamp"] = {"delay": "PT120S"}
        elif _v.startswith("delay_sec:"):
            _secs = _v[len("delay_sec:") :]
            try:
                _s: int = int(_secs)
            except ValueError:
                raise CompatError(
                    ErrorCode.INVALID_FLAG_VALUE,
                    message=f"--update-genesis-timestamp delay_sec:N requires an integer N, "
                    f"got {_secs!r}",
                )
            _st["genesis_timestamp"] = {"delay": f"PT{_s}S"}
        elif _v.startswith("fixed:"):
            _fixed_ts = _v[len("fixed:") :]
            if not _fixed_ts:
                raise CompatError(
                    ErrorCode.INVALID_FLAG_VALUE,
                    message="--update-genesis-timestamp fixed:T requires a non-empty timestamp",
                )
            raise CompatError(
                ErrorCode.COMPAT_NOT_SUPPORTED,
                message="--update-genesis-timestamp fixed:T is not supported by the "
                "current topology schema (only 'delay' is allowed on "
                "genesis_timestamp). Use 'delay_sec:N' instead.",
            )
        else:
            raise CompatError(
                ErrorCode.INVALID_FLAG_VALUE,
                message=f"--update-genesis-timestamp: unrecognised mode {_v!r}. "
                "Use 'no', 'delay_sec:N', or 'fixed:T'.",
            )

    # ── demo mode ────────────────────────────────────────────────────
    if co.demo:
        _ensure_seed_node(t)["demo_mode"] = True

    # ── transaction interval ─────────────────────────────────────────
    _trans_interval: int = co.transaction_interval

    # ── value_transfer workload ──────────────────────────────────────
    if co.value_transfer:
        _wl = t.setdefault("workloads", {})
        _wl["value-transfer-compat"] = {
            "type": "value_transfer",
            "config": {
                "sender": "whale-0",
                "amount": "1",
                "interval_seconds": _trans_interval,
            },
        }

    # ── zkapp_transactions workload ──────────────────────────────────
    if co.zkapp_transactions:
        _wl = t.setdefault("workloads", {})
        _wl["zkapp-compat"] = {
            "type": "zkapp",
            "config": {
                "fee_payer_account": "whale-0",
                "sender_account": "whale-1",
                "interval_seconds": _trans_interval,
            },
        }

    # ── snark worker fee ─────────────────────────────────────────────
    if co.snark_worker_fee is not None:
        _ensure_snark_coordinator(t)["fee"] = co.snark_worker_fee

    # ── log level ────────────────────────────────────────────────────
    if co.log_level is not None:
        _assert_valid_log_level("--log-level", co.log_level)
        t.setdefault("logging", {}).setdefault("console", {})["node"] = co.log_level

    # ── file log level ───────────────────────────────────────────────
    if co.file_log_level is not None:
        _assert_valid_log_level("--file-log-level", co.file_log_level)
        t.setdefault("logging", {}).setdefault("file", {})["node"] = co.file_log_level

    # ── worker log level ─────────────────────────────────────────────
    if co.worker_log_level is not None:
        _assert_valid_log_level("--worker-log-level", co.worker_log_level)
        _lg = t.setdefault("logging", {})
        _lg.setdefault("console", {})["snark_worker"] = co.worker_log_level
        _lg.setdefault("file", {})["snark_worker"] = co.worker_log_level

    # ── snark worker nap ─────────────────────────────────────────────
    if co.snark_worker_nap_sec is not None:
        _sc = _ensure_snark_coordinator(t)
        _sc.setdefault("worker_pools", {}).setdefault("default", {})["nap"] = (
            f"PT{co.snark_worker_nap_sec}S"
        )

    # ── root ─────────────────────────────────────────────────────────
    if co.root is not None:
        t.setdefault("state", {})["root"] = co.root

    # ── binary paths ─────────────────────────────────────────────────
    if co.mina_exe is not None:
        t.setdefault("binaries", {})["mina"] = co.mina_exe
    if co.archive_exe is not None:
        t.setdefault("binaries", {})["archive"] = co.archive_exe
    if co.zkapp_exe is not None:
        t.setdefault("binaries", {})["zkapp"] = co.zkapp_exe

    return t


# ── Helpers ────────────────────────────────────────────────────────────────


def _str_val(value: object, flag_name: str) -> str:
    """Coerce a parsed value to str; used for values that must be strings."""
    if isinstance(value, bool):
        raise CompatError(
            ErrorCode.INVALID_FLAG_VALUE,
            message=f"{flag_name} requires a value; got bare flag (boolean)",
        )
    return str(value)


def _int_val(value: object, flag_name: str, *, minimum: int) -> int:
    """Parse an integer compat flag value and enforce a lower bound."""
    raw: str = _str_val(value, flag_name)
    try:
        parsed: int = int(raw)
    except ValueError:
        raise CompatError(
            ErrorCode.INVALID_FLAG_VALUE,
            message=f"{flag_name} must be an integer, got {raw!r}",
        )
    if parsed < minimum:
        raise CompatError(
            ErrorCode.INVALID_FLAG_VALUE,
            message=f"{flag_name} must be >= {minimum}, got {parsed}",
        )
    return parsed


def _ensure_seed_node(topology: dict) -> dict:
    """Return the seed node dict, creating with p2p_seed capability if needed."""
    nodes: dict = topology.setdefault("nodes", {})
    if "seed" not in nodes:
        nodes["seed"] = {"capabilities": {"p2p_seed": {}}}
    return nodes["seed"]


def _strip_unused_itn_graphql(topology: dict) -> None:
    """Remove ITN GraphQL inherited from the single-node preset for compat.

    Legacy compat value-transfer/zkApp flows do not need ITN GraphQL.  Keeping
    the preset's placeholder ``itn_keys`` makes Mina try to decode a non-key and
    crash during daemon boot.
    """
    seed: dict = _ensure_seed_node(topology)
    caps: dict = seed.setdefault("capabilities", {})
    caps.pop("itn_graphql", None)
    seed.pop("itn_keys", None)


def _ensure_snark_coordinator(topology: dict) -> dict:
    """Return the snark_coordinator capability dict, creating if needed."""
    seed: dict = _ensure_seed_node(topology)
    caps: dict = seed.setdefault("capabilities", {})
    if "snark_coordinator" not in caps:
        caps["snark_coordinator"] = {
            "work_selection": "seq",
            "worker_pools": {"default": {"count": 2, "nap": "PT1S"}},
        }
    return caps["snark_coordinator"]


def _ensure_tier(topology: dict, tier_name: str) -> dict:
    """Return the tier dict, creating with defaults if needed."""
    tiers: dict = topology.setdefault("ledger_generation", {}).setdefault("tiers", {})
    if tier_name not in tiers:
        _defaults: dict = {"count": 1}
        if tier_name == "whale":
            _defaults["offline_balance"] = "11550000mina"
            _defaults["online_balance"] = "499mina"
        elif tier_name == "fish":
            _defaults["offline_balance"] = "65500mina"
            _defaults["online_balance"] = "500mina"
        tiers[tier_name] = _defaults
    return tiers[tier_name]


def _set_tier_count(topology: dict, tier_name: str, count: int) -> None:
    """Set the generated ledger count for a tier, removing zero-count tiers."""
    tiers: dict = topology.setdefault("ledger_generation", {}).setdefault("tiers", {})
    if count == 0:
        tiers.pop(tier_name, None)
        return
    tier: dict = _ensure_tier(topology, tier_name)
    tier["count"] = count


def _compat_block_producer_node(account: str) -> dict:
    """Return a node definition for an extra compat block producer."""
    return {
        "capabilities": {
            "block_producer": {
                "account": account,
            }
        },
        "demo_mode": False,
    }


def _expand_block_producer_nodes(
    topology: dict, *, whale_count: int, fish_count: int
) -> None:
    """Expand legacy --whales/--fish cardinalities into BP daemon nodes.

    The single-node preset's seed daemon remains whale-0 and keeps its seed,
    snark coordinator, and ITN GraphQL capabilities.  Extra whales/fish become
    non-seed block producers that peer with the seed during plan resolution.
    """
    nodes: dict = topology.setdefault("nodes", {})
    seed: dict = _ensure_seed_node(topology)
    seed_caps: dict = seed.setdefault("capabilities", {})
    seed_caps.setdefault("block_producer", {})["account"] = "whale-0"

    for node_name in [name for name in nodes if name.startswith("whale_")]:
        nodes.pop(node_name, None)
    for node_name in [name for name in nodes if name.startswith("fish_")]:
        nodes.pop(node_name, None)

    for whale_idx in range(1, whale_count):
        nodes[f"whale_{whale_idx}"] = _compat_block_producer_node(f"whale-{whale_idx}")
    for fish_idx in range(fish_count):
        nodes[f"fish_{fish_idx}"] = _compat_block_producer_node(f"fish-{fish_idx}")


def _ensure_runtime_config_proof(topology: dict) -> dict:
    """Return the runtime_config.proof dict, creating defaults if needed."""
    rc: dict = topology.setdefault("runtime_config", {})
    proof: dict = rc.setdefault("proof", {})
    proof.setdefault("level", "full")
    proof.setdefault("work_delay", 1)
    proof.setdefault("transaction_capacity", {"2_to_the": 2})
    return proof


# ── Public API: used by CLI ────────────────────────────────────────────────


def translate_compat(args: List[str]) -> dict:
    """Translate legacy Bash flags to a validated topology dict.

    Args are the positional strings (excluding the subcommand name).
    Raises ``CompatError`` on any error.
    """
    parsed: Dict[str, object] = _parse_compat_args(args)
    raw: dict = resolve_topology_source("single-node")
    topology: dict = _apply_compat(raw, parsed)

    errors: List[str] = validate_topology(topology)
    if errors:
        raise CompatError(
            ErrorCode.TOPOLOGY_VALIDATION,
            message="Compat translation produced an invalid topology:\n"
            + "\n".join(f"  - {e}" for e in errors),
        )

    return topology


def compat_to_plan_and_spawn(args: List[str]) -> None:
    """Full pipeline: translate flags → validate → normalise → resolve →
    write plan → materialise → spawn.

    This is the equivalent of ``spawn compat <flags>``.
    """
    import json
    from pathlib import Path

    topology: dict = translate_compat(args)

    # Normalise & resolve (same logic as _do_plan_topology)
    from mln.plan import (
        derive_plan_root,
        plan_path,
        validate_manifest_matches_plan,
    )
    from mln.materialize import do_materialize
    from mln.spawn import spawn_instance_from_plan

    normalized: dict = normalize_topology(topology)

    norm_errors = validate_topology(normalized)
    if norm_errors:
        raise CompatError(
            ErrorCode.TOPOLOGY_VALIDATION,
            message="Compat translation produced an invalid normalised topology:\n"
            + "\n".join(f"  - {e}" for e in norm_errors),
        )

    preset_name: str = topology.get("name", "single-node")
    state_root: str = derive_plan_root(topology, preset_name)
    _plan: Path = plan_path(state_root)

    normalized.setdefault("state", {})["root"] = state_root
    nt = NormalizedTopology.model_validate(normalized)
    typed_plan = resolve_topology(nt)

    # Always overwrite in compat mode
    _plan.parent.mkdir(parents=True, exist_ok=True)
    _plan.write_text(
        json.dumps(
            typed_plan.model_dump(mode="json", exclude_none=True),
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    click.echo(f"Plan written to {_plan}", err=True)

    # Materialise with force — typed plan already in hand
    mresult = do_materialize(typed_plan, force=True, dry_run=False)
    assert mresult.mode == "materialized", (
        "do_materialize with dry_run=False must return materialized result"
    )
    assert mresult.manifest is not None
    manifest_model = mresult.manifest
    click.echo(f"Materialised at {state_root}", err=True)

    # Spawn
    validate_manifest_matches_plan(typed_plan, manifest_model)
    spawn_instance_from_plan(typed_plan, manifest_model)


# ── Click commands ─────────────────────────────────────────────────────────


_HELP_TEXT = """Translate legacy mina-local-network.sh flags to a v1 topology.

This compact compat translator accepts a subset of legacy flags and maps them
directly to topology fields.  The result is a valid, validated topology JSON
that can be used with 'plan topology', 'materialize', and 'spawn instance'.

SUPPORTED FLAGS:
  -w, --whales <N>             Whale BP count; seed is whale-0, extras are BP nodes
  -f, --fish <N>               Fish BP count; each fish becomes a BP node
  -swc, --snark-workers-count <N>  Snark workers (preset default 3)
  --fast                       Rejected: slot-time override not materialized yet
  -st, --override-slot-time <ms>  Rejected: slot-time override not materialized yet
  -pl, --proof-level <level>   full|check|none
  -wd, --work-delay <N>        Scan state work delay
  -tc, --transaction-capacity-log2 <N>  Log2 tx capacity
  -c, --config <reset|inherit> Config mode
  -u, --update-genesis-timestamp <mode>  no|delay_sec:N|fixed:T
  -d, --demo                   Enable demo mode
  -vt, --value-transfer-txns   Enable value-transfer workload
  -zt, --zkapp-transactions    Enable zkApp workload; auto-bumps whales to 2
                               if needed for whale-1 sender
  -ti, --transaction-interval <N>  Interval between txs in seconds (default 10)
  -sf, --snark-worker-fee <fee>  SNARK worker fee
  -ll, --log-level <level>     Console log level for daemon
  -fll, --file-log-level <level>  File log level for daemon
  -wll, --worker-log-level <level>  Console+file log level for snark workers
  --snark-worker-nap-sec <N>   Worker nap seconds
  -r, --root <path>            State root directory
  --mina-exe <path>            Path to mina executable
  --archive-exe <path>         Path to archive executable
  --zkapp-exe <path>           Path to zkApp test transaction executable

EXAMPLES:
  convert compat --snark-workers-count 7 --value-transfer-txns
  spawn compat --whales 2 --zkapp-transactions --proof-level none --demo
"""


@click.group()
def convert():
    """Convert between formats (legacy compat, topology inspection)."""


@convert.command(
    "compat",
    help="Translate legacy Bash flags to topology JSON.",
    context_settings={
        "ignore_unknown_options": True,
        "allow_extra_args": True,
    },
)
@click.argument("args", nargs=-1, type=click.UNPROCESSED)
@click.option(
    "--help",
    "show_help",
    is_flag=True,
    default=False,
    is_eager=True,
    help="Show detailed help for compat translation.",
)
def convert_compat(args: tuple[str, ...], show_help: bool):
    """Translate legacy mina-local-network.sh flags to v1 topology JSON.

    ARGS are legacy flags (e.g. --whales 2 --fast -vt).
    The translated topology is emitted as JSON to stdout.
    """
    if show_help:
        click.echo(_HELP_TEXT)
        return
    arg_list: List[str] = list(args)
    topology: dict = translate_compat(arg_list)
    click.echo(json.dumps(topology, indent=2))


@click.command(
    "compat",
    help="Translate legacy flags, plan, materialize, and spawn in one shot.",
    context_settings={
        "ignore_unknown_options": True,
        "allow_extra_args": True,
    },
)
@click.argument("args", nargs=-1, type=click.UNPROCESSED)
def spawn_compat(args: tuple[str, ...]):
    """Legacy-style one-shot network: translate flags, plan, materialize, spawn.

    Accepts the same subset of legacy flags as 'convert compat'.
    """
    arg_list: List[str] = list(args)
    compat_to_plan_and_spawn(arg_list)
