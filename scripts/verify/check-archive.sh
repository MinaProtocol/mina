#!/usr/bin/env bash
# Shared verification checks for the mina-archive package.
# Assumes mina-archive binary is already installed.
set -euo pipefail

echo "Verifying mina-archive..."
mina-archive --version
mina-archive --help
