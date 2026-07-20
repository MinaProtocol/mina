"""Lightweight optional-value helpers — no third-party dependencies."""

from __future__ import annotations

from typing import Callable, Optional, TypeVar

T = TypeVar("T")
R = TypeVar("R")


def option_map(opt_val: Optional[T], f: Callable[[T], R]) -> Optional[R]:
    """If *opt_val* is not ``None``, return ``f(opt_val)``; otherwise ``None``.

    Monadic ``map`` for ``Optional[T]`` — replaces inline ternaries like
    ``x.attr if x is not None else None`` with a type‑safe call::

        port = option_map(endpoint, lambda ep: ep.port)
    """
    return None if opt_val is None else f(opt_val)
