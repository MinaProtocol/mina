from __future__ import annotations

import json
from pathlib import Path
from typing import List

from mln.errors import (
    ErrorCode,
    TopologyError,
)
from mln.jsonc import load_jsonc
from mln.paths import PRESETS_DIR, TOPOLOGY_SCHEMA_PATH
from mln.sampler import lower_topology


def load_topology_schema() -> dict:
    """Load the checked-in JSON Schema file."""
    if not TOPOLOGY_SCHEMA_PATH.exists():
        raise TopologyError(
            ErrorCode.FILE_NOT_FOUND,
            message=f"Schema file not found: {TOPOLOGY_SCHEMA_PATH}",
            path=str(TOPOLOGY_SCHEMA_PATH),
        )
    return json.loads(TOPOLOGY_SCHEMA_PATH.read_text(encoding="utf-8"))


def ensure_jsonschema() -> None:
    """Check that jsonschema is importable; raise with instructions if not."""
    try:
        import jsonschema  # noqa: F401
    except ImportError:
        raise TopologyError(
            ErrorCode.DEPENDENCY_MISSING,
            message="The 'jsonschema' package is required for schema validation.\n"
            "Install it with:\n"
            "  pip install -r scripts/mina-local-network/requirements.txt\n"
            "Or via nix-shell:\n"
            "  nix-shell -p 'python3.withPackages (ps: [ ps.click ps.requests ps.jsonchema ])'",
        )


def validate_topology(topology: dict) -> List[str]:
    """Validate *topology* against the schema. Returns list of error strings."""
    ensure_jsonschema()
    import jsonschema

    schema = load_topology_schema()
    errors: List[str] = []
    try:
        jsonschema.validate(topology, schema)
    except jsonschema.ValidationError:
        for err in jsonschema.Draft7Validator(schema).iter_errors(topology):
            path = (
                ".".join(str(p) for p in err.absolute_path)
                if err.absolute_path
                else "(root)"
            )
            errors.append(f"{path}: {err.message}")
    return errors


def resolve_topology_source(path: Path) -> dict:
    """Load and parse a topology file (JSONC) into a raw dict.

    The boundary that turns a missing file into a structured
    ``TopologyError(FILE_NOT_FOUND)`` where ``load_jsonc`` alone would raise a
    bare ``OSError``.
    """
    if not path.is_file():
        raise TopologyError(
            ErrorCode.FILE_NOT_FOUND,
            message=f"No such topology file: '{path}'",
            path=str(path),
        )
    # A v2 (constraint) topology is lowered to the concrete v1 form here, so every
    # downstream stage sees the resolved node map. v1 documents pass through
    # unchanged (lower_topology is a no-op without a `requirements` block).
    return lower_topology(load_jsonc(path))


def list_preset_names() -> List[str]:
    if not PRESETS_DIR.is_dir():
        return []
    return sorted(p.stem for p in PRESETS_DIR.glob("*.jsonc"))
