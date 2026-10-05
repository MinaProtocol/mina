#!/usr/bin/env bash
# Shared verification checks for the mina daemon package.
# Assumes mina binary and config files are already installed.
#
# Checks:
#   1. A profile is available (see "Profile resolution" below)
#   2. mina binary runs (--version, --help)
#   3. The commit hash baked into the mina binary matches the commit hash
#      embedded in the genesis config filename (config_<hash>.json)
set -euo pipefail

# --- Profile resolution -----------------------------------------------------
# A profile is one of dev, devnet, lightnet, mainnet. It sets the compile-time
# constants (proof level, ledger depth, signature kind) that the node reads at
# startup.
#
# The mina binary has no default profile. node_config reads MINA_PROFILE first,
# then falls back on the file /etc/coda/build_config/PROFILE, and aborts when
# it finds neither:
#
#   (Failure "Node config: no profile set. Set MINA_PROFILE to one of dev,
#    devnet, lightnet, mainnet ...")
#
# The generic artifact (debian package mina-generic, docker tag
# "<version>-generic") has no profile on purpose: the package that installs
# that file is a layer on top of it (dockerfiles/Dockerfile-install-profile).
# So this check must give the profile itself, or every mina command below
# fails. Each profile exercises the binary in the same way. devnet is used
# because the debian install path also puts devnet on a bare mina-generic
# (buildkite/scripts/debian/install.sh).
#
# When the artifact has a profile, keep it: that is the profile the artifact
# must run with, and MINA_PROFILE is not set here so that the file stays in
# control.
PROFILE_FILE=/etc/coda/build_config/PROFILE

if [ -n "${MINA_PROFILE:-}" ]; then
  echo "Profile comes from the environment: MINA_PROFILE=$MINA_PROFILE"
elif [ -s "$PROFILE_FILE" ]; then
  echo "Profile comes from $PROFILE_FILE: $(cat "$PROFILE_FILE")"
else
  export MINA_PROFILE=devnet
  echo "This artifact has no $PROFILE_FILE (generic build)."
  echo "Running the checks with MINA_PROFILE=$MINA_PROFILE"
fi

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

# Extract the commit hash from the config filename (config_<hash>.json)
CONFIG_COMMIT=$(basename "$CONFIG_FILE" | grep -oP 'config_\K[a-f0-9]+')
echo "Config file commit hash: $CONFIG_COMMIT"

if [ "$MINA_COMMIT" = "$CONFIG_COMMIT" ]; then
  echo "OK: mina binary commit ($MINA_COMMIT) matches genesis config commit ($CONFIG_COMMIT)"
else
  echo "FAIL: mina binary commit ($MINA_COMMIT) does not match genesis config commit ($CONFIG_COMMIT)"
  exit 1
fi
