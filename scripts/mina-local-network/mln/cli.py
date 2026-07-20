from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Annotated, Optional

from cyclopts import App, Parameter

from mln.errors import (
    ErrorCode,
    ManifestError,
    MLNError,
    PlanError,
    TopologyError,
    WorkloadError,
)
from mln.constraints import requirements_json_schema
from mln.graphql import account_ledger_nonce
from mln.materialize import do_materialize, required_key_file_paths
from mln.paths import REQUIREMENTS_SCHEMA_PATH
from mln.models import MaterializedManifest, NormalizedTopology, ResolvedPlan
from mln.plan import (
    FINGERPRINT_ALGORITHM,
    derive_plan_root,
    load_plan,
    plan_fingerprint,
    plan_path,
    resolve_plan_path,
    validate_manifest_matches_plan,
)
from mln.schema import (
    list_preset_names,
    load_topology_schema,
    resolve_topology_source,
    validate_topology,
)
from mln.spawn import (
    spawn_instance_from_plan,
)
from mln.spawn.workloads import (
    resolve_account_ref_to_online_key,
    value_transfer_pool_refs,
)
from mln.topology import (
    normalize_topology,
    resolve_topology,
    to_resolved_plan,
)

# ═══════════════════════════════════════════════════════════════════════════
# App + error boundary
#
# cyclopts derives every command from its function signature (one source of
# truth — no decorator/parameter drift).  ``@app.meta.default`` is the single
# place a domain ``MLNError`` is rendered, replacing the old custom Click group.
# ═══════════════════════════════════════════════════════════════════════════


app = App(
    name="mina-local-network",
    version="0.1.0",
    help=(
        "Mina local-network v1 topology tool (Python).\n\n"
        "Inspect, validate, resolve, and spawn Mina local network topologies."
    ),
)


@app.meta.default
def _main(
    *tokens: Annotated[str, Parameter(show=False, allow_leading_hyphen=True)],
) -> None:
    """Render a domain ``MLNError`` cleanly instead of dumping a traceback."""
    try:
        app(tokens)
    except MLNError as err:
        print(str(err), file=sys.stderr)
        raise SystemExit(1) from err


# ═══════════════════════════════════════════════════════════════════════════
# presets
# ═══════════════════════════════════════════════════════════════════════════


presets = App(name="presets", help="Inspect topology presets.")
app.command(presets)


@presets.command(name="list")
def presets_list() -> None:
    """List available preset names."""
    print(json.dumps({"presets": list_preset_names()}))


@presets.command(name="show")
def presets_show(path: Path, /) -> None:
    """Display a topology file as strict JSON."""
    normalized = normalize_topology(resolve_topology_source(path))
    print(json.dumps(normalized, indent=2))


# ═══════════════════════════════════════════════════════════════════════════
# schema
# ═══════════════════════════════════════════════════════════════════════════


schema = App(name="schema", help="JSON Schema operations.")
app.command(schema)


@schema.command(name="print")
def schema_print() -> None:
    """Print the checked-in topology schema as strict JSON."""
    print(json.dumps(load_topology_schema(), indent=2))


@schema.command(name="validate")
def schema_validate(path: Path, /) -> None:
    """Validate a topology file against the schema."""
    raw = resolve_topology_source(path)

    # Validate raw authored topology before normalization injects defaults
    raw_errors = validate_topology(raw)
    if raw_errors:
        print(f"Validation FAILED ({len(raw_errors)} error(s)):")
        for e in raw_errors:
            print(f"  - {e}")
        raise SystemExit(1)

    # Self-check: normalize and validate again
    normalized = normalize_topology(raw)
    norm_errors = validate_topology(normalized)
    if norm_errors:
        print(f"Normalized validation FAILED ({len(norm_errors)} error(s)):")
        for e in norm_errors:
            print(f"  - {e}")
        raise SystemExit(1)

    print("Validation PASSED")


@schema.command(name="regen")
def schema_regen() -> None:
    """Regenerate the derived JSON Schema files from the pydantic models.

    The pydantic models are the single source of truth; the checked-in schema is
    projected from them.  Run this after changing the models, then commit the
    result.  A drift test asserts the checked-in file matches this output.
    """
    schemas = {REQUIREMENTS_SCHEMA_PATH: requirements_json_schema()}
    for path, doc in schemas.items():
        path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path}")


# ═══════════════════════════════════════════════════════════════════════════
# plan
# ═══════════════════════════════════════════════════════════════════════════


def _resolve_topology_to_plan(path: Path) -> tuple[ResolvedPlan, Path]:
    """Resolve and validate a topology into a typed plan and its plan path.

    Writes nothing — callers decide whether and when to persist, so that a
    caller with further preconditions to check (see ``do_patch_topology``)
    can fail without having already clobbered an existing plan on disk.
    """
    raw = resolve_topology_source(path)

    # Validate raw topology before normalization
    raw_errors = validate_topology(raw)
    if raw_errors:
        raise TopologyError(
            ErrorCode.TOPOLOGY_VALIDATION,
            message=f"Topology validation failed with {len(raw_errors)} error(s):\n"
            + "\n".join(f"  - {e}" for e in raw_errors),
        )

    normalized = normalize_topology(raw)

    norm_errors = validate_topology(normalized)
    if norm_errors:
        raise TopologyError(
            ErrorCode.TOPOLOGY_VALIDATION,
            message=f"Normalized topology validation failed with {len(norm_errors)} error(s):\n"
            + "\n".join(f"  - {e}" for e in norm_errors),
        )

    # Determine state root and plan path.  The root name comes from the
    # topology's own ``name``; the file stem is only the fallback.
    state_root = derive_plan_root(raw, path.stem)

    # Inject resolved root into normalized topology for resolve_topology
    normalized.setdefault("state", {})["root"] = state_root

    # Validate into typed model and resolve
    nt = NormalizedTopology.model_validate(normalized)
    return resolve_topology(nt), plan_path(state_root)


def _write_plan(typed_plan: ResolvedPlan, _plan: Path) -> None:
    """Persist *typed_plan* to *_plan*.

    Excludes None / unset optional fields so omitted workload count and
    other optionals are absent rather than "null" in JSON.
    """
    _plan.parent.mkdir(parents=True, exist_ok=True)
    _plan.write_text(
        json.dumps(
            typed_plan.model_dump(mode="json", exclude_none=True),
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    print(f"Plan written to {_plan}")


def do_plan_topology(path: Path, overwrite: bool) -> str:
    """Core plan topology logic shared by CLI commands.

    Returns the path of the written plan file.
    """
    typed_plan, _plan = _resolve_topology_to_plan(path)

    # Check for overwrite
    if _plan.exists() and not overwrite:
        raise PlanError(
            ErrorCode.PLAN_ALREADY_EXISTS,
            message=f"Plan already exists at {_plan}\nUse --overwrite to replace it.",
            path=str(_plan),
        )

    _write_plan(typed_plan, _plan)
    return str(_plan)


plan = App(name="plan", help="Resolve and persist topology plans (no process spawning).")
app.command(plan)


@plan.command(name="topology")
def plan_topology(path: Path, /, *, overwrite: bool = False) -> None:
    """Resolve a topology and write the persisted runtime plan to disk.

    Writes <state.root>/network-plan.json.  Refuses to overwrite an
    existing plan unless --overwrite is passed.

    This command does NOT generate keys, ledger files, daemon configs,
    or spawn any processes.
    """
    do_plan_topology(path, overwrite)


@plan.command(name="lower")
def plan_lower(path: Path, /) -> None:
    """Print the explicit-nodes (v1) form of a topology as strict JSON.

    A constraint (v2) topology is lowered to concrete nodes by the sampler; a v1
    topology passes through unchanged. Consumers that need the resolved node set
    without a full plan — e.g. the hardfork harness building its daemon list from
    the sampled nodes — read this. Placement is random unless requirements.seed is
    pinned, so re-running an unpinned v2 topology lowers to a fresh layout; a
    consumer that needs one layout lowers once and reuses the result.
    """
    print(json.dumps(resolve_topology_source(path)))


# ═══════════════════════════════════════════════════════════════════════════
# patch
# ═══════════════════════════════════════════════════════════════════════════


def do_patch_topology(path: Path) -> str:
    """Core patch logic: replan in place while preserving materialized keys.

    Every precondition is checked before anything is written, so a rejected
    patch leaves the existing plan and manifest exactly as they were and the
    state root stays spawnable.

    Only key material is verified — daemon.json and genesis_ledger.json are
    deliberately left untouched and are NOT regenerated from the patched
    plan.  Callers that change ledger-affecting config (balances, proof
    level, ...) are responsible for those files themselves; see
    ``patch_topology`` for the rationale.

    Returns the path of the written plan file.
    """
    # ── resolve + validate everything before touching disk ───────────
    typed_plan, _plan = _resolve_topology_to_plan(path)
    state_root = typed_plan.state.root

    manifest_path = Path(state_root) / "materialized-manifest.json"
    if not manifest_path.exists():
        raise PlanError(
            ErrorCode.PLAN_NOT_FOUND,
            message="No materialized-manifest.json found.\n\n"
            f"'patch topology' requires an existing materialized manifest at {state_root}.\n"
            f"Run 'materialize {state_root}' first, then patch.",
            path=str(manifest_path),
        )
    manifest = _load_manifest(manifest_path)

    missing = [p for p in required_key_file_paths(typed_plan) if not Path(p).exists()]
    if missing:
        sample = missing[:5]
        msg_lines = [
            "The new topology requires key material that has not been "
            "materialized yet.",
            "Missing key files include:",
        ]
        msg_lines += [f"  - {p}" for p in sample]
        if len(missing) > 5:
            msg_lines.append(f"  ... and {len(missing) - 5} more")
        msg_lines.append("")
        msg_lines.append(
            "'patch topology' only reuses existing key material — it never "
            f"generates new keys. Run 'materialize {state_root}' to generate "
            "the missing keys (existing keys are reused), then patch again."
        )
        raise ManifestError(
            ErrorCode.PATCH_REQUIRES_NEW_KEYS,
            message="\n".join(msg_lines),
            path=state_root,
        )

    # ── all preconditions met — commit the plan, then the manifest ───
    _write_plan(typed_plan, _plan)

    # Fingerprint the plan as 'spawn instance' will read it back, so the
    # stamped value can never disagree with the consumer's own computation.
    persisted_plan = to_resolved_plan(load_plan(_plan))
    patched_manifest = manifest.model_copy(
        update={
            "plan_fingerprint": plan_fingerprint(persisted_plan),
            "plan_fingerprint_algorithm": FINGERPRINT_ALGORITHM,
        }
    )
    manifest_path.write_text(
        json.dumps(patched_manifest.model_dump(mode="json"), indent=2, sort_keys=True),
        encoding="utf-8",
    )
    print(f"Patched plan at {_plan}; manifest fingerprint refreshed")
    return str(_plan)


patch = App(
    name="patch",
    help="Replan an already-materialized state root in place, reusing keys.",
)
app.command(patch)


@patch.command(name="topology")
def patch_topology(path: Path, /) -> None:
    """Resolve a new topology and apply it over an existing materialized plan.

    Requires materialized-manifest.json to already exist at the topology's
    state root (run 'materialize' first).  Refuses if the new topology would
    need any key that hasn't been generated yet — patch never creates keys,
    it only lets a plan's non-key surface (binary paths, runtime config,
    workloads, node args, ...) change in place while reusing the same
    materialized keys.

    Intended for transitions like a hard-fork test's main → fork network
    swap, where the topology legitimately changes but accounts must not.

    CAVEAT: only keys are carried over and verified.  daemon.json and
    genesis_ledger.json are NOT regenerated, so a patched plan that changes
    ledger-affecting config (account balances, proof level, slot timings)
    will spawn against the *previously materialized* values of those files.
    That is deliberate — the hard-fork flow installs its own migrated
    daemon.json before patching, and re-materializing would clobber it.  If
    you need those files rebuilt, run 'materialize <root> --force' instead
    (it reuses existing keys and regenerates the config from the plan).
    """
    do_patch_topology(path)


# ═══════════════════════════════════════════════════════════════════════════
# query
# ═══════════════════════════════════════════════════════════════════════════


query = App(name="query", help="Ask a running network about its current state.")
app.command(query)


@query.command(name="account-nonce")
def query_account_nonce(
    target: str,
    /,
    *,
    account_ref: str,
    node: str,
) -> None:
    """Print the ledger nonce of ACCOUNT_REF as NODE sees it.

    TARGET can be a state-root directory containing network-plan.json, or a
    direct path to a network-plan.json file.  The network must be running.

    --account-ref is an account ref, e.g. 'whale-1' — a tier and index, as
    workloads and ledger generation name accounts.  --node picks whose view
    to ask (nodes can differ).

    Resolves the account ref through the materialized manifest, so callers name
    accounts the way the topology does and never need to know how refs map onto
    generated keys.
    """
    plan_path_ = resolve_plan_path(target)
    typed_plan = to_resolved_plan(load_plan(plan_path_))

    node_entry = next((n for n in typed_plan.nodes if n.name == node), None)
    if node_entry is None:
        raise PlanError(
            ErrorCode.PLAN_NOT_FOUND,
            message=f"The plan declares no node '{node}'. It has: "
            f"{', '.join(sorted(n.name for n in typed_plan.nodes))}.",
            path=str(plan_path_),
        )
    rest_ep = node_entry.endpoints.get("rest")
    if rest_ep is None:
        raise PlanError(
            ErrorCode.PLAN_NOT_FOUND,
            message=f"Node '{node}' has no REST endpoint, so it cannot be asked anything.",
            path=str(plan_path_),
        )

    manifest = _load_manifest(Path(typed_plan.state.root) / "materialized-manifest.json")
    key_name = resolve_account_ref_to_online_key(account_ref)
    record = manifest.keys.get(key_name)
    if record is None or not record.pubkey_content:
        raise ManifestError(
            ErrorCode.WORKLOAD_KEY_NOT_FOUND,
            message=f"Account ref '{account_ref}' resolves to manifest key '{key_name}', "
            f"which the materialized manifest does not have. Check the topology declares "
            f"that tier with enough accounts.",
        )

    uri = f"http://127.0.0.1:{rest_ep.port}/graphql"
    print(account_ledger_nonce(uri, record.pubkey_content))


@query.command(name="value-transfer-pool")
def query_value_transfer_pool(target: str, /) -> None:
    """Print the account refs the value_transfer pool draws from, as a JSON list.

    TARGET can be a state-root directory containing network-plan.json, or a
    direct path to a network-plan.json file.  Reads the materialized manifest
    only — the network need not be running.

    The value_transfer worker draws random senders from this pool, so it has no
    single sender.  A caller carrying nonces across a hardfork snapshots each
    printed ref's nonce (via 'query account-nonce') and seeds the fork network's
    value_transfer 'first_nonces' with them.  Refs are printed the way the
    topology names accounts, so the caller never maps refs onto generated keys.
    """
    plan_path_ = resolve_plan_path(target)
    typed_plan = to_resolved_plan(load_plan(plan_path_))
    manifest = _load_manifest(Path(typed_plan.state.root) / "materialized-manifest.json")
    print(json.dumps(value_transfer_pool_refs(manifest.keys)))


# ═══════════════════════════════════════════════════════════════════════════
# inspect
# ═══════════════════════════════════════════════════════════════════════════


inspect = App(
    name="inspect",
    help="Inspect persisted network plans and topologies (read-only, no spawning).",
)
app.command(inspect)


@inspect.command(name="topology")
def inspect_topology(path: Optional[Path] = None, /) -> None:
    """REMOVED.  Use 'plan topology' to resolve and persist a plan first.

    This command no longer produces transient resolved plans.  To inspect
    a topology, use:

      plan topology <file>                    # write network-plan.json
      inspect instance <state-root-or-plan>   # read the persisted plan
    """
    raise TopologyError(
        ErrorCode.INVALID_ARGUMENT,
        message="The 'inspect topology' command has been removed.\n\n"
        "Use 'plan topology <file>' to resolve and persist a plan,\n"
        "then 'inspect instance <state-root-or-plan>' to inspect it.\n\n"
        "Example:\n"
        "  plan topology presets/single-node.jsonc\n"
        "  inspect instance .mina-local-network/single-node",
    )


@inspect.command(name="instance")
def inspect_instance(target: str, /) -> None:
    """Read and display a persisted network plan (read-only).

    TARGET can be a state-root directory containing network-plan.json,
    or a direct path to a network-plan.json file.
    """
    plan_path_ = resolve_plan_path(target)
    typed_plan = to_resolved_plan(load_plan(plan_path_))
    print(json.dumps(typed_plan.model_dump(mode="json", exclude_none=True), indent=2))


# ═══════════════════════════════════════════════════════════════════════════
# spawn
# ═══════════════════════════════════════════════════════════════════════════


def _load_manifest(manifest_path: Path) -> MaterializedManifest:
    """Load and validate a materialized-manifest.json file.

    Wraps ``json.JSONDecodeError`` and Pydantic ``ValidationError`` into
    ``ManifestError`` so the CLI never dumps a raw traceback for corrupt
    or malformed manifest files.
    """
    try:
        raw_text = manifest_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ManifestError(
            ErrorCode.FILE_NOT_FOUND,
            message=f"Cannot read manifest at {manifest_path}: {exc}",
            path=str(manifest_path),
        ) from exc
    try:
        raw_dict = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        raise ManifestError(
            ErrorCode.PLAN_PARSE_ERROR,
            message=f"Manifest at {manifest_path} is not valid JSON: {exc}",
            path=str(manifest_path),
        ) from exc
    try:
        return MaterializedManifest.model_validate(raw_dict)
    except Exception as exc:
        try:
            from pydantic import ValidationError as _PydanticValidationError

            if isinstance(exc, _PydanticValidationError):
                raise ManifestError(
                    ErrorCode.PLAN_PARSE_ERROR,
                    message=f"Manifest at {manifest_path} is malformed: {exc}",
                    path=str(manifest_path),
                ) from exc
        except ManifestError:
            raise
        except Exception:
            pass
        raise


def _reject_old_format_workloads(plan_data: dict) -> None:
    """Reject old‑format workloads (missing ``type``) with a clear message.

    Called before ``to_resolved_plan`` in spawn paths so that injected
    pre‑v1 workload shapes don't silently coerce to the wrong typed model.
    """
    raw_workloads = plan_data.get("workloads")
    if not isinstance(raw_workloads, list):
        return
    for idx, raw_wl in enumerate(raw_workloads):
        if not isinstance(raw_wl, dict):
            continue
        wl_name: str = str(raw_wl.get("name", f"#{idx}"))
        if "type" not in raw_wl:
            raise WorkloadError(
                ErrorCode.WORKLOAD_NO_ARGV,
                message=f"Workload '{wl_name}' has no argv. "
                f"Old-format workloads are not supported. "
                f"Use typed workloads with 'type' and 'config' dict "
                f"(e.g. type='echo' with config.argv).",
            )
        wl_config = raw_wl.get("config")
        if isinstance(wl_config, dict):
            if raw_wl.get("type") == "echo" and not wl_config.get("argv"):
                raise WorkloadError(
                    ErrorCode.WORKLOAD_NO_ARGV,
                    message=f"Echo workload '{wl_name}' has no argv. "
                    f"Provide config.argv for echo workloads.",
                )


spawn = App(name="spawn", help="Spawn local network processes (daemon + snark workers).")
app.command(spawn)


@spawn.command(name="topology")
def spawn_topology(path: Path, /, *, overwrite: bool = False) -> None:
    """Plan + convenience spawn from a topology.

    Resolves the topology and writes network-plan.json (delegates to
    'plan topology'), materializing first if the plan has no manifest yet,
    then spawns the instance.

    An existing manifest must match the freshly written plan, so replanning
    a topology whose materialized state was built from a different plan is
    refused rather than silently spawned against stale artifacts.  Use
    'patch topology' for deliberate in-place plan changes that must keep
    the materialized keys.
    """
    # Plan the topology first
    plan_path_str = do_plan_topology(path, overwrite=overwrite)
    plan_data = load_plan(Path(plan_path_str))

    # Reject old‑format workloads before typed validation
    _reject_old_format_workloads(plan_data)

    # Validate and construct typed plan
    typed_plan = to_resolved_plan(plan_data)
    state_root = typed_plan.state.root

    # Check for materialized manifest — auto-materialize if absent
    manifest_path = Path(state_root) / "materialized-manifest.json"
    if not manifest_path.exists():
        print("Manifest not found — materializing...")
        materialize_result = do_materialize(typed_plan, force=False, dry_run=False)
        assert materialize_result.mode == "materialized"
        assert materialize_result.manifest is not None
        manifest = materialize_result.manifest
    else:
        manifest = _load_manifest(manifest_path)
        # Validate manifest fingerprint matches the current plan
        validate_manifest_matches_plan(typed_plan, manifest)

    spawn_instance_from_plan(typed_plan, manifest)


@spawn.command(name="instance")
def spawn_instance(target: str, /) -> None:
    """Spawn a daemon with optional services (archive, rosetta) and external
    snark workers from a persisted plan and materialized manifest.

    TARGET can be a state-root directory containing network-plan.json,
    or a direct path to a network-plan.json file.

    Requires materialized-manifest.json alongside the plan.  Currently
    supports a single daemon with optional archive, rosetta, external
    snark workers, echo workloads, value_transfer workloads, zkapp workloads,
    and itn_max_cost workloads. Archive requires an external, already-initialised
    Postgres database; the preflight verifies connectivity and schema
    before any child process is spawned.

    The processes run in the foreground; SIGINT/SIGTERM tear down the
    child process groups.  Any exception after the first child is spawned
    will kill all started children before returning.
    """
    plan_path_ = resolve_plan_path(target)
    plan_data = load_plan(plan_path_)

    # Reject old‑format workloads before typed validation
    _reject_old_format_workloads(plan_data)

    # Validate and construct typed plan
    typed_plan = to_resolved_plan(plan_data)
    state_root = typed_plan.state.root

    manifest_path = Path(state_root) / "materialized-manifest.json"
    if not manifest_path.exists():
        raise PlanError(
            ErrorCode.PLAN_NOT_FOUND,
            message="No materialized-manifest.json found.\n\n"
            f"The network plan at {plan_path_} has not been materialized.\n"
            f"Run 'materialize {state_root}' first to generate "
            "keys, configs, and ledger files, then try spawn instance again.",
            path=str(manifest_path),
        )
    manifest = _load_manifest(manifest_path)

    # Validate manifest fingerprint matches the current plan
    validate_manifest_matches_plan(typed_plan, manifest)

    spawn_instance_from_plan(typed_plan, manifest)


# ═══════════════════════════════════════════════════════════════════════════
# materialize
# ═══════════════════════════════════════════════════════════════════════════


@app.command(name="materialize")
def materialize(target: str, /, *, force: bool = False, dry_run: bool = False) -> None:
    """Materialize static artifacts from a persisted network plan.

    TARGET is a state-root directory or path to network-plan.json.

    Creates key directories, configuration files, generates Mina account
    keypairs, and writes all generated artifacts along with a
    materialized-manifest.json.  Does NOT spawn any processes.

    Refuses to overwrite existing materialized artifacts unless --force
    is passed.
    """
    plan_path_ = resolve_plan_path(target)
    plan_data = load_plan(plan_path_)

    # Validate and construct typed plan
    typed_plan = to_resolved_plan(plan_data)

    result = do_materialize(typed_plan, force=force, dry_run=dry_run)

    if dry_run:
        print(json.dumps(result.model_dump(mode="json"), indent=2))
        return

    assert result.manifest is not None, "materialized result must carry a manifest"
    manifest = result.manifest

    print(
        json.dumps(
            {
                "status": "ok",
                "materialized_at": manifest.materialized_at,
                "manifest_path": manifest.state_root + "/materialized-manifest.json",
                "generated_files_count": len(manifest.generated_files),
            },
            indent=2,
        )
    )
