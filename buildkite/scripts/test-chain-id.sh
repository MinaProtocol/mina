#!/bin/bash

set -eo pipefail

MINA_DEBIAN_NETWORK=$1
EXPECTED_CHAIN_ID=$2

echo "--- Testing chain_id command for ${MINA_DEBIAN_NETWORK}"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

# Codename of the build whose artifacts we consume. The ChainIdTest jobs depend
# on the Bullseye build, but honour an override if one is set in the env.
CODENAME="${MINA_DEB_CODENAME:-bullseye}"

# In-repo runtime config carrying the precomputed ledger/epoch hashes. This is
# all `chain-id --from-config-hashes-only` needs; it never materialises the
# genesis ledger tarball.
CONFIG_FILE="genesis_ledgers/${MINA_DEBIAN_NETWORK}.json"

# Signature variant of the daemon binary for this network. Mirrors
# signature_of_network() in scripts/debian/builder-helpers.sh.
case "$MINA_DEBIAN_NETWORK" in
  mainnet) SIGNATURE=mainnet ;;
  devnet | mesa) SIGNATURE=testnet ;;
  *)
    echo "Unknown network name provided: ${MINA_DEBIAN_NETWORK}" >&2
    exit 1
    ;;
esac

# Try to set up the bare-binary path: restore the freshly-built daemon binary
# from the apps/<codename> CI cache (populated by
# buildkite/scripts/apps/write_to_cache.sh) and confirm it supports the
# hashes-only chain-id mode. Returns non-zero if the binary is unavailable or
# too old, so the caller can fall back to the .deb.
BARE_EXE=""
prepare_bare() {
  local exe_name="mina_${SIGNATURE}_signatures.exe"
  local dest="./_chain_id_bare"
  mkdir -p "$dest"

  if ! ./buildkite/scripts/cache/manager.sh read "apps/${CODENAME}/${exe_name}" "$dest"; then
    echo "..bare binary apps/${CODENAME}/${exe_name} not found in CI cache" >&2
    return 1
  fi

  local exe="${dest}/${exe_name}"
  chmod +x "$exe" 2>/dev/null || true

  # --from-config-hashes-only lets us compute chain_id without unpacking the
  # genesis ledger. It is not present on every release branch yet, so probe for
  # it and fall back to the .deb path when absent.
  if ! "$exe" internal chain-id --help 2>&1 | grep -q -- '--from-config-hashes-only'; then
    echo "..binary lacks --from-config-hashes-only; falling back to debian package" >&2
    return 1
  fi

  BARE_EXE="$exe"
}

if [[ -v BUILDKITE_BUILD_ID ]] && prepare_bare; then
  echo "--- Running mina chain-id command (bare binary, no debian package)"
  ACTUAL_CHAIN_ID=$("$BARE_EXE" internal chain-id \
    --config-file "$CONFIG_FILE" \
    --from-config-hashes-only | tail -n1)
else
  echo "--- Running mina chain-id command (debian package fallback)"
  source buildkite/scripts/debian/update.sh --verbose
  source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1

  MINA_CONFIG_FILE="${MINA_CONFIG_FILE:-/var/lib/coda/${MINA_DEBIAN_NETWORK}.json}"
  ACTUAL_CHAIN_ID=$(mina internal chain-id --config-file "${MINA_CONFIG_FILE}" | tail -n1)
fi

echo "Expected Chain ID: ${EXPECTED_CHAIN_ID}"
echo "Actual Chain ID: ${ACTUAL_CHAIN_ID}"

if [[ "$ACTUAL_CHAIN_ID" == "$EXPECTED_CHAIN_ID" ]]; then
    echo "SUCCESS: Chain ID matches expected value"
else
    echo "ERROR: Chain ID mismatch"
    echo "  Expected: ${EXPECTED_CHAIN_ID}"
    echo "  Actual:   ${ACTUAL_CHAIN_ID}"
    exit 1
fi
