from __future__ import annotations

import re
from typing import Tuple

from mln.constants import ISO_DURATION_RE
from mln.errors import ErrorCode, TopologyError

# Mina amount DSL: <integer>mina or <integer>nanomina
_AMOUNT_RE = re.compile(r"^(\d+)(mina|nanomina)$")

_NANOMINA_PER_MINA = 1_000_000_000


def parse_iso_duration(dur_str: str) -> float:
    """Parse an ISO-8601 PT...S duration string into seconds.

    >>> parse_iso_duration("PT1S")
    1.0
    >>> parse_iso_duration("PT0.5S")
    0.5
    """
    m = ISO_DURATION_RE.match(dur_str)
    if not m:
        raise TopologyError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"Cannot parse ISO duration: {dur_str!r}",
        )
    return float(m.group(1))


def convert_balance_to_decimal_mina(balance_str: str) -> str:
    """Convert a Mina amount DSL string to a 9-decimal-place mina string.

    Uses exact integer arithmetic (no floating point).  Rejects values
    that don't match ``<integer>mina`` or ``<integer>nanomina``.

    >>> convert_balance_to_decimal_mina("11550000mina")
    '11550000.000000000'
    >>> convert_balance_to_decimal_mina("499mina")
    '499.000000000'
    >>> convert_balance_to_decimal_mina("1000nanomina")
    '0.000001000'
    >>> convert_balance_to_decimal_mina("5nanomina")
    '0.000000005'
    """
    m = _AMOUNT_RE.match(balance_str)
    if not m:
        raise TopologyError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"Invalid balance: {balance_str!r}. "
            "Expected format: <integer>mina or <integer>nanomina",
        )
    value_str = m.group(1)
    unit = m.group(2)
    if unit == "mina":
        return f"{value_str}.000000000"
    # nanomina: convert to mina with 9 decimal places using integer division
    value = int(value_str)
    int_part = value // 1_000_000_000
    frac_part = value % 1_000_000_000
    return f"{int_part}.{frac_part:09d}"


def parse_account_spec(spec: str) -> Tuple[str, int]:
    """Parse a tier account specifier like 'whale-0' into (tier, index).

    >>> parse_account_spec("whale-0")
    ('whale', 0)
    >>> parse_account_spec("fish-2")
    ('fish', 2)
    """
    m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_]*)-(\d+)$", spec)
    if not m:
        raise TopologyError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"Invalid account specifier: {spec!r}. Expected format: tier-index (e.g. 'whale-0')",
        )
    return m.group(1), int(m.group(2))


def _capabilities_of(node_def: dict) -> dict:
    """Extract the capabilities dict from a raw topology node definition."""
    return node_def.get("capabilities", {})


def has_capability(node_def: dict, cap: str) -> bool:
    """Return True if *node_def* has the named capability."""
    return cap in _capabilities_of(node_def)
