#!/usr/bin/env bash
# Shared verification checks for the mina daemon package.
# Assumes mina binary and config files are already installed.
#
# Checks:
#   1. mina binary runs (--version, --help)
#   2. The commit hash baked into the mina binary matches the commit hash
#      embedded in the genesis config filename (config_<hash>.json)
set -euo pipefail

echo "Running mina --version and --help ..."
mina --version
mina --help

# --- Extract commit hash from the mina binary ---
MINA_VERSION_OUTPUT=$(mina --version 2>&1)
MINA_COMMIT=$(echo "$MINA_VERSION_OUTPUT" | grep -oP '(?:commit_hash": "|Commit )\K[a-f0-9]+' | head -c 8)
echo "Mina binary commit hash: $MINA_COMMIT"

# --- Compare with the genesis config file commit hash ---
# The daemon package ships a config file at /var/lib/coda/config_<hash>.json
# where <hash> must match the binary's commit hash.
CONFIG_FILE=$(ls /var/lib/coda/config_*.json 2>/dev/null | head -1 || true)

if [ -z "$CONFIG_FILE" ]; then
  echo "No genesis config file found in /var/lib/coda/ — skipping hash check"
  exit 0
fi

echo "Found genesis config: $CONFIG_FILE"

# Extract the commit hash from the config filename (config_<hash>.json).
# The filename hash is produced by `git rev-parse --short=8`, which is a
# MINIMUM width: git widens it (to 9+) when the 8-char prefix is ambiguous
# across any object in the repo. The binary hash above is truncated to a
# fixed 8 chars, so normalize the config hash to the same 8-char prefix
# before comparing — otherwise an ambiguous commit fails a valid package.
CONFIG_COMMIT=$(basename "$CONFIG_FILE" | grep -oP 'config_\K[a-f0-9]+' | head -c 8)
echo "Config file commit hash: $CONFIG_COMMIT"

if [ "$MINA_COMMIT" = "$CONFIG_COMMIT" ]; then
  echo "OK: mina binary commit ($MINA_COMMIT) matches genesis config commit ($CONFIG_COMMIT)"
else
  echo "FAIL: mina binary commit ($MINA_COMMIT) does not match genesis config commit ($CONFIG_COMMIT)"
  exit 1
fi
