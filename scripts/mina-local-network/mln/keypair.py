from __future__ import annotations

import datetime
import os
import subprocess
from pathlib import Path
from typing import Optional

from mln.constants import DEFAULT_PRIVKEY_PASS
from mln.amounts import parse_iso_duration
from mln.models import KeyRecord


def generate_keypair(
    mina_exe: str, privkey_path: str, env: Optional[dict[str, str]] = None
) -> KeyRecord:
    """Run ``mina advanced generate-keypair`` to create a privkey + .pub file.

    Returns a typed :class:`KeyRecord` with ``privkey_path``, ``pubkey_path``,
    and ``pubkey_content``.
    """
    pp = Path(privkey_path)
    pubkey_path = str(pp) + ".pub"

    call_env = os.environ.copy()
    call_env.setdefault("MINA_PRIVKEY_PASS", DEFAULT_PRIVKEY_PASS)
    if env:
        call_env.update(env)

    subprocess.run(
        [mina_exe, "advanced", "generate-keypair", "-privkey-path", str(pp)],
        env=call_env,
        check=True,
        capture_output=True,
        text=True,
    )

    pubkey_content = ""
    pubkey_file = Path(pubkey_path)
    if pubkey_file.exists():
        pubkey_content = pubkey_file.read_text(encoding="utf-8").strip()

    return KeyRecord(
        privkey_path=str(pp),
        pubkey_path=pubkey_path,
        pubkey_content=pubkey_content,
    )


def compute_genesis_timestamp_utc(delay_iso: str) -> str:
    """Compute an absolute UTC timestamp from an ISO duration delay.

    ``PT120S`` → now + 120 seconds, formatted as ``YYYY-MM-DD HH:MM:SS+00:00``.
    """
    secs = parse_iso_duration(delay_iso)
    ts = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=secs)
    return ts.strftime("%Y-%m-%d %H:%M:%S+00:00")
