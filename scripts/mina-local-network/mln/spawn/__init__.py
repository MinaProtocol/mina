"""Spawn orchestrator package for Mina local networks.

The sole public entry point is :func:`spawn_instance_from_plan`.
Internal modules (``.types``, ``.itn``, ``.workloads``,
``.process_table``, ``.lifecycle``) are package‑private.
"""

from __future__ import annotations

from mln.spawn.main import spawn_instance_from_plan  # noqa: F401 — public API
