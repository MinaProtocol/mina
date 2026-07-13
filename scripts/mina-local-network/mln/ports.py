from __future__ import annotations

import socket
from typing import Optional

from mln.errors import ErrorCode, TopologyError


def _probe_free_port(host: str = "127.0.0.1") -> int:
    """Return a single free TCP port on *host*."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


class PortAllocator:
    """Deterministic-ish port allocation for the no-spawn resolver.

    Allocates consecutive port ranges starting from a free base port.
    Tracks allocations so duplicate pinned ports can be detected.
    """

    def __init__(self, start_base: Optional[int] = None):
        self._base = start_base or _probe_free_port()
        self._next = self._base
        self._allocated: set[int] = set()

    def allocate_single(self, pinned: Optional[int] = None, label: str = "") -> int:
        if pinned is not None:
            if pinned in self._allocated:
                raise TopologyError(
                    ErrorCode.NODE_CONFIG,
                    message=f"Pinned port {pinned} for '{label}' is already allocated.",
                    entity=label,
                )
            self._allocated.add(pinned)
            return pinned
        while self._next in self._allocated:
            self._next += 1
        port = self._next
        self._allocated.add(port)
        self._next += 1
        return port
