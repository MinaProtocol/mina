from __future__ import annotations

import re
from typing import Tuple

from mln.constants import ISO_DURATION_RE
from mln.errors import ErrorCode, TopologyError

# Mina amount DSL: a mina amount, which may be fractional (groups: integer part,
# optional fractional part), or a nanomina amount, which must be a whole number —
# nanomina is the base unit. The grammar enforces that: only the mina branch has a
# fractional part.
_AMOUNT_RE = re.compile(r"^(\d+)(?:\.(\d+))?mina$|^(\d+)nanomina$")

_NANOMINA_PER_MINA = 1_000_000_000
_NANOMINA_DECIMALS = 9  # a mina is 10^9 nanomina, so 9 fractional digits is exact


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


def amount_dsl_to_nanomina(amount_str: str) -> int:
    """Parse a Mina amount DSL string to an integer number of nanomina.

    Accepts ``<int>mina``, a fractional ``<int>.<frac>mina`` (e.g. ``0.25mina``),
    or ``<int>nanomina``. Fractional mina is converted exactly via integer
    arithmetic; more than 9 fractional digits is sub-nanomina and rejected, since
    nanomina is the smallest representable unit.

    >>> amount_dsl_to_nanomina("1mina")
    1000000000
    >>> amount_dsl_to_nanomina("0.25mina")
    250000000
    >>> amount_dsl_to_nanomina("5nanomina")
    5
    """
    m = _AMOUNT_RE.match(amount_str)
    if not m:
        raise TopologyError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"Invalid amount: {amount_str!r}. Expected format: "
            "<number>mina (may be fractional) or <integer>nanomina",
        )
    nanomina_part = m.group(3)
    if nanomina_part is not None:
        return int(nanomina_part)

    int_part = int(m.group(1))
    frac_str = m.group(2)
    if frac_str is not None and len(frac_str) > _NANOMINA_DECIMALS:
        raise TopologyError(
            ErrorCode.INVALID_ARGUMENT,
            message=f"Amount {amount_str!r} has sub-nanomina precision: mina "
            f"supports at most {_NANOMINA_DECIMALS} fractional digits.",
        )
    frac_nanomina = int(frac_str.ljust(_NANOMINA_DECIMALS, "0")) if frac_str else 0
    return int_part * _NANOMINA_PER_MINA + frac_nanomina


def convert_balance_to_decimal_mina(balance_str: str) -> str:
    """Convert a Mina amount DSL string to a 9-decimal-place mina string.

    Uses exact integer arithmetic (no floating point).

    >>> convert_balance_to_decimal_mina("11550000mina")
    '11550000.000000000'
    >>> convert_balance_to_decimal_mina("0.25mina")
    '0.250000000'
    >>> convert_balance_to_decimal_mina("1000nanomina")
    '0.000001000'
    >>> convert_balance_to_decimal_mina("5nanomina")
    '0.000000005'
    """
    return nanomina_to_decimal_mina(amount_dsl_to_nanomina(balance_str))


def nanomina_to_decimal_mina(nanomina: int) -> str:
    """Format an integer nanomina amount as a 9-decimal mina string (for -amount)."""
    int_part = nanomina // _NANOMINA_PER_MINA
    frac_part = nanomina % _NANOMINA_PER_MINA
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
