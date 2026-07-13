from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

import click

from mln.errors import (
    MLNError,
    ErrorCode,
    ManifestError,
    PlanError,
    TopologyError,
    WorkloadError,
)
from mln.schema import (
    list_preset_names,
    load_topology_schema,
    resolve_topology_source,
    validate_topology,
)
from mln.topology import (
    normalize_topology,
    resolve_topology,
    to_resolved_plan,
)
from mln.plan import (
    derive_plan_root,
    load_plan,
    plan_path,
    resolve_plan_path,
    validate_manifest_matches_plan,
)
from mln.materialize import do_materialize
from mln.models import MaterializedManifest, NormalizedTopology
from mln.spawn import (
    spawn_instance_from_plan,
)
from mln.workers import vt_worker_body, zkapp_worker_body, itn_max_cost_worker_body
from mln.convert import convert
from mln.convert import spawn_compat as spawn_compat_command


# ═══════════════════════════════════════════════════════════════════════════
# Custom Click group — converts MLNError to Click-friendly output
# ═══════════════════════════════════════════════════════════════════════════


class MLNCliGroup(click.Group):
    """Click group that intercepts MLNError and renders it cleanly."""

    def invoke(self, ctx: click.Context) -> object:
        try:
            return super().invoke(ctx)
        except MLNError as err:
            click.echo(str(err), err=True)
            raise SystemExit(1) from err


# ═══════════════════════════════════════════════════════════════════════════
# Click group
# ═══════════════════════════════════════════════════════════════════════════


@click.group(cls=MLNCliGroup)
@click.version_option(version="0.1.0", prog_name="mina-local-network")
def cli():
    """Mina local-network v1 topology tool (Python).

    Inspect, validate, resolve, and spawn Mina local network topologies.
    """


# ═══════════════════════════════════════════════════════════════════════════
# presets
# ═══════════════════════════════════════════════════════════════════════════


@cli.group()
def presets():
    """Manage topology presets."""


@presets.command("list")
def presets_list():
    """List available preset names."""
    names = list_preset_names()
    if not names:
        click.echo(json.dumps({"presets": []}))
        return
    click.echo(json.dumps({"presets": names}))


@presets.command("show")
@click.argument("name_or_path")
def presets_show(name_or_path: str):
    """Display a preset as strict JSON."""
    topology = resolve_topology_source(name_or_path)
    normalized = normalize_topology(topology)
    click.echo(json.dumps(normalized, indent=2))


# ═══════════════════════════════════════════════════════════════════════════
# schema
# ═══════════════════════════════════════════════════════════════════════════


@cli.group()
def schema():
    """JSON Schema operations."""


@schema.command("print")
def schema_print():
    """Print the checked-in topology schema as strict JSON."""
    schema_data = load_topology_schema()
    click.echo(json.dumps(schema_data, indent=2))


@schema.command("validate")
@click.argument("file_or_preset")
def schema_validate(file_or_preset: str):
    """Validate a topology file or preset against the schema."""
    raw = resolve_topology_source(file_or_preset)

    # Validate raw authored topology before normalization injects defaults
    raw_errors = validate_topology(raw)
    if raw_errors:
        click.echo(f"Validation FAILED ({len(raw_errors)} error(s)):")
        for e in raw_errors:
            click.echo(f"  - {e}")
        raise SystemExit(1)

    # Self-check: normalize and validate again
    normalized = normalize_topology(raw)
    norm_errors = validate_topology(normalized)
    if norm_errors:
        click.echo(f"Normalized validation FAILED ({len(norm_errors)} error(s)):")
        for e in norm_errors:
            click.echo(f"  - {e}")
        raise SystemExit(1)

    click.echo("Validation PASSED")


# ═══════════════════════════════════════════════════════════════════════════
# plan
# ═══════════════════════════════════════════════════════════════════════════


def do_plan_topology(file_or_preset: str, overwrite: bool) -> str:
    """Core plan topology logic shared by CLI commands.

    Returns the path of the written plan file.
    """
    raw = resolve_topology_source(file_or_preset)

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

    # Determine state root and plan path
    state_root = derive_plan_root(raw, file_or_preset)
    _plan = plan_path(state_root)

    # Inject resolved root into normalized topology for resolve_topology
    normalized.setdefault("state", {})["root"] = state_root

    # Validate into typed model and resolve
    nt = NormalizedTopology.model_validate(normalized)
    typed_plan = resolve_topology(nt)

    # Check for overwrite
    if _plan.exists() and not overwrite:
        raise PlanError(
            ErrorCode.PLAN_ALREADY_EXISTS,
            message=f"Plan already exists at {_plan}\nUse --overwrite to replace it.",
            path=str(_plan),
        )

    # Write — exclude None / unset optional fields so omitted workload
    # count and other optionals are absent rather than "null" in JSON.
    _plan.parent.mkdir(parents=True, exist_ok=True)
    _plan.write_text(
        json.dumps(
            typed_plan.model_dump(mode="json", exclude_none=True),
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    click.echo(f"Plan written to {_plan}")
    return str(_plan)


@cli.group()
def plan():
    """Resolve and persist topology plans (no process spawning)."""


@plan.command("topology")
@click.argument("file_or_preset")
@click.option(
    "--overwrite",
    is_flag=True,
    default=False,
    help="Overwrite an existing network-plan.json",
)
def plan_topology(file_or_preset: str, overwrite: bool):
    """Resolve a topology and write the persisted runtime plan to disk.

    Writes <state.root>/network-plan.json.  Refuses to overwrite an
    existing plan unless --overwrite is passed.

    This command does NOT generate keys, ledger files, daemon configs,
    or spawn any processes.
    """
    do_plan_topology(file_or_preset, overwrite)


# ═══════════════════════════════════════════════════════════════════════════
# inspect
# ═══════════════════════════════════════════════════════════════════════════


@cli.group()
def inspect():
    """Inspect persisted network plans and topologies (read-only, no spawning)."""


@inspect.command("topology")
@click.argument("file_or_preset", required=False)
def inspect_topology(file_or_preset: Optional[str] = None):
    """REMOVED.  Use 'plan topology' to resolve and persist a plan first.

    This command no longer produces transient resolved plans.  To inspect
    a topology, use:

      plan topology <file-or-preset>          # write network-plan.json
      inspect instance <state-root-or-plan>   # read the persisted plan
    """
    raise TopologyError(
        ErrorCode.INVALID_ARGUMENT,
        message="The 'inspect topology' command has been removed.\n\n"
        "Use 'plan topology <file-or-preset>' to resolve and persist a plan,\n"
        "then 'inspect instance <state-root-or-plan>' to inspect it.\n\n"
        "Example:\n"
        "  plan topology single-node\n"
        "  inspect instance .mina-local-network/single-node",
    )


@inspect.command("instance")
@click.argument("target")
def inspect_instance(target: str):
    """Read and display a persisted network plan (read-only).

    TARGET can be a state-root directory containing network-plan.json,
    or a direct path to a network-plan.json file.
    """
    plan_path = resolve_plan_path(target)
    plan_data = load_plan(plan_path)

    # Validate and construct typed plan, then dump for display
    typed_plan = to_resolved_plan(plan_data)
    click.echo(
        json.dumps(typed_plan.model_dump(mode="json", exclude_none=True), indent=2)
    )


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


@cli.group()
def spawn():
    """Spawn local network processes (daemon + snark workers)."""


@spawn.command("topology")
@click.argument("file_or_preset")
@click.option(
    "--overwrite",
    is_flag=True,
    default=False,
    help="Overwrite an existing network-plan.json before spawning",
)
def spawn_topology(file_or_preset: str, overwrite: bool):
    """Plan + convenience spawn from a topology.

    Resolves the topology and writes network-plan.json (delegates to
    'plan topology'), then spawns the instance if the plan has been
    materialized.  If not materialized, prints a clear error.
    """
    # Plan the topology first
    plan_path_str = do_plan_topology(file_or_preset, overwrite=overwrite)
    plan_data = load_plan(Path(plan_path_str))

    # Reject old‑format workloads before typed validation
    _reject_old_format_workloads(plan_data)

    # Validate and construct typed plan
    typed_plan = to_resolved_plan(plan_data)
    state_root = typed_plan.state.root

    # Check for materialized manifest — auto-materialize if absent
    manifest_path = Path(state_root) / "materialized-manifest.json"
    if not manifest_path.exists():
        click.echo("Manifest not found — materializing...")
        materialize_result = do_materialize(typed_plan, force=False, dry_run=False)
        assert materialize_result.mode == "materialized"
        assert materialize_result.manifest is not None
        manifest = materialize_result.manifest
    else:
        manifest = _load_manifest(manifest_path)
        # Validate manifest fingerprint matches the current plan
        validate_manifest_matches_plan(typed_plan, manifest)

    spawn_instance_from_plan(typed_plan, manifest)


@spawn.command("instance")
@click.argument("target")
def spawn_instance(target: str):
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
    plan_path = resolve_plan_path(target)
    plan_data = load_plan(plan_path)

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
            f"The network plan at {plan_path} has not been materialized.\n"
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


@cli.command("materialize")
@click.argument("target")
@click.option(
    "--force",
    is_flag=True,
    default=False,
    help="Overwrite existing materialized artifacts",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Print what would be done without writing any files",
)
def materialize(target: str, force: bool, dry_run: bool):
    """Materialize static artifacts from a persisted network plan.

    TARGET is a state-root directory or path to network-plan.json.

    Creates key directories, configuration files, generates Mina account
    keypairs, and writes all generated artifacts along with a
    materialized-manifest.json.  Does NOT spawn any processes.

    Refuses to overwrite existing materialized artifacts unless --force
    is passed.
    """
    plan_path = resolve_plan_path(target)
    plan_data = load_plan(plan_path)

    # Validate and construct typed plan
    typed_plan = to_resolved_plan(plan_data)

    result = do_materialize(typed_plan, force=force, dry_run=dry_run)

    if dry_run:
        click.echo(json.dumps(result.model_dump(mode="json"), indent=2))
        return

    assert result.manifest is not None, "materialized result must carry a manifest"
    manifest = result.manifest

    click.echo(
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


# ═══════════════════════════════════════════════════════════════════════════
# convert
# ═══════════════════════════════════════════════════════════════════════════

cli.add_command(convert)

# Register spawn compat on the spawn group
spawn.add_command(spawn_compat_command)

# ═══════════════════════════════════════════════════════════════════════════
# hidden workers — registered on cli so the shim/hyphenated script can invoke
# them via subprocess.
# ═══════════════════════════════════════════════════════════════════════════

cli.command("_vt_worker", hidden=True)(vt_worker_body)
cli.command("_zkapp_worker", hidden=True)(zkapp_worker_body)
cli.command("_itn_max_cost_worker", hidden=True)(itn_max_cost_worker_body)
