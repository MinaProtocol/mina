from __future__ import annotations

import re
from typing import Dict

# Number of consecutive ports a daemon node consumes (client, rest, external,
# metrics, libp2p-metrics).  ITN GraphQL port, if enabled, is the 6th.
DAEMON_PORT_COUNT = 5

VALID_LOG_LEVELS = frozenset(
    {"Spam", "Trace", "Debug", "Info", "Warn", "Error", "Faulty_peer", "Fatal"}
)
VALID_PROOF_LEVELS = frozenset({"full", "check", "none"})

# --- v1 grouped logging defaults ---
DEFAULT_CONSOLE_LOG_LEVELS: Dict[str, str] = {
    "node": "Warn",
    "snark_worker": "Error",
    "archive": "Warn",
    "rosetta": "Warn",
}
DEFAULT_FILE_LOG_LEVELS: Dict[str, str] = {
    "node": "Info",
    "snark_worker": "Info",
    "archive": "Info",
    "rosetta": "Info",
}

DEFAULT_PROOF_LEVEL = "full"
DEFAULT_SNARK_WORKER_NAP_SEC = 1
DEFAULT_STATE_ROOT = ".mina-local-network/default"
DEFAULT_STATE_MODE = "reset"
DEFAULT_GENESIS_DELAY = "PT120S"

# Re-use well-known seed peer id / key from the current Bash script
SEED_PEER_KEY = (
    "CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIek"
    "BmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,"
    "CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,"
    "12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
)
SEED_PEER_ID = (
    "/ip4/127.0.0.1/tcp/{external_port}/p2p/"
    "12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
)

# ISO-8601 duration regex: PT{seconds}S
ISO_DURATION_RE = re.compile(r"^PT(\d+(?:\.\d+)?)S$")

# Minimal privkey passphrase matching the Bash script default
DEFAULT_PRIVKEY_PASS = "naughty blue worm"
