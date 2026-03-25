#!/usr/bin/env bash
# Shared verification checks for the mina-rosetta package.
# Assumes mina, mina-archive, and mina-rosetta binaries are already installed.
set -euo pipefail

echo "Verifying mina-rosetta..."
mina --version
mina --help
mina-archive --version
mina-archive --help
mina-rosetta --version
mina-rosetta --help
