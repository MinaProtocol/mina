from __future__ import annotations

from pathlib import Path

# SCRIPT_DIR is the package parent — the directory that contains
# mina-local-network.py and the mln/ package.
SCRIPT_DIR = Path(__file__).resolve().parent.parent

# REPO_ROOT matches the existing resolution semantics: SCRIPT_DIR is
# scripts/mina-local-network, so two levels up is the repository root.
REPO_ROOT = SCRIPT_DIR.parent.parent.resolve()

# The literal entrypoint script path (used as a subprocess target by
# hidden workers and by the self-invocation test).
ENTRYPOINT = SCRIPT_DIR / "mina-local-network.py"

PRESETS_DIR = SCRIPT_DIR / "presets"
SCHEMA_DIR = SCRIPT_DIR / "schema"
TOPOLOGY_SCHEMA_PATH = SCHEMA_DIR / "topology.schema.json"
# Derived from the pydantic models in mln.constraints (regenerate with
# `mina-local-network schema regen`; a drift test guards it).
REQUIREMENTS_SCHEMA_PATH = SCHEMA_DIR / "requirements.schema.json"
