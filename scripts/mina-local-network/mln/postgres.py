from __future__ import annotations

import os
import shutil as shutil_mod
import subprocess
from urllib.parse import urlparse

from pydantic import BaseModel, ConfigDict

from mln.errors import ErrorCode, PostgresError

# ── Local typed model for transitional postgres config dicts ─────────────


class _PostgresConfig(BaseModel):
    """Internal model for parsing transitional postgres config dicts.

    ``resolve_postgres_config`` constructs one of these from the raw dict
    and then materialises a ``postgresql://`` URI.  All fields carry
    sensible defaults so that the caller can pass an empty dict for a
    fully local-default connection.
    """

    model_config = ConfigDict(frozen=True)

    user: str = os.environ.get("USER", "postgres")
    password: str = os.environ.get("PG_PW", "")
    host: str = "localhost"
    port: int = 5432
    db: str = "archive"


# ── Public API ───────────────────────────────────────────────────────────


def resolve_postgres_config(postgres_def: dict) -> str:
    """Resolve Postgres connection URI from a service postgres definition.

    Returns a ``postgresql://user:pass@host:port/db`` connection string.
    The topology input *postgres_def* (a dict with keys ``host``, ``port``,
    ``user``, ``password``, ``db``) is transitional and converted here.
    The returned URI is the canonical form carried through the resolved plan.
    """
    cfg = _PostgresConfig.model_validate(postgres_def)
    return f"postgresql://{cfg.user}:{cfg.password}@{cfg.host}:{cfg.port}/{cfg.db}"


def check_external_postgres(uri: str) -> None:
    """Validate connectivity and schema for an external Postgres database.

    Parses *uri* (a ``postgresql://user:pass@host:port/db`` string)
    internally and uses **discrete flags** (``-h``, ``-p``, ``-U``, ``-d``)
    so the password is never visible in the process argument list.
    Passwords are injected via the ``PGPASSWORD`` environment variable
    when non-empty.

    ``PostgresError`` if *psql* is missing, connectivity
    fails, or the schema is not initialised.  This is a **non-destructive**
    check — no CREATE, DROP, or schema modification.
    """
    if shutil_mod.which("psql") is None:
        raise PostgresError(
            ErrorCode.PSQL_MISSING,
            message="psql is not available on PATH.  "
            "Install the PostgreSQL client tools to use the archive service.\n"
            "  Debian/Ubuntu:  sudo apt-get install postgresql-client\n"
            "  macOS:          brew install libpq && echo 'export "
            'PATH="/opt/homebrew/opt/libpq/bin:$PATH"\' >> ~/.zshrc',
        )

    parsed = urlparse(uri)
    pg_host = parsed.hostname or "localhost"
    pg_port = str(parsed.port or 5432)
    pg_user = parsed.username or os.environ.get("USER", "postgres")
    pg_passwd = parsed.password or ""
    pg_db = parsed.path.lstrip("/") or "archive"

    psql_env = os.environ.copy()
    if pg_passwd:
        psql_env["PGPASSWORD"] = pg_passwd

    psql_base = [
        "psql",
        "-h",
        pg_host,
        "-p",
        pg_port,
        "-U",
        pg_user,
        "-d",
        pg_db,
    ]

    # 1. Basic connectivity — SELECT 1
    result = subprocess.run(
        psql_base + ["-c", "SELECT 1"],
        env=psql_env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise PostgresError(
            ErrorCode.POSTGRES_UNREACHABLE,
            message=f"Could not connect to external Postgres at "
            f"{pg_host}:{pg_port}/{pg_db} as {pg_user}.\n"
            f"Ensure the database is running and credentials are correct.\n"
            f"psql stderr: {result.stderr.strip()}",
        )

    # 2. Schema existence — non-destructive: SELECT 1 FROM user_commands
    result = subprocess.run(
        psql_base + ["-c", "SELECT 1 FROM user_commands LIMIT 1"],
        env=psql_env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise PostgresError(
            ErrorCode.POSTGRES_SCHEMA_MISSING,
            message=f"External Postgres at {pg_host}:{pg_port}/{pg_db} is reachable, "
            "but the archive schema does not appear to exist.\n"
            "Run the archive initialisation tool or point to an already-"
            "initialised database.\n"
            f"psql stderr: {result.stderr.strip()}",
        )
