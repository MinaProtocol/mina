#!/usr/bin/env python3
"""
mina-local-network.py — v1 Python topology resolver for Mina local networks.

Thin compatibility entrypoint.  All logic lives in the ``mln`` package.
"""

from __future__ import annotations

from mln.cli import app

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    app.meta()
