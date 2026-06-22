#!/bin/bash

set -eo pipefail

MINA_DEBIAN_NETWORK=$1
EXPECTED_CHAIN_ID=$2

echo "--- Testing chain_id command for ${MINA_DEBIAN_NETWORK}"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

# `mina internal chain-id` reads only the daemon binary and the network's genesis
# config json. The .deb's config package does no generation -- it just copies the
# in-repo genesis_ledgers/<net>.json into /var/lib/coda -- so we reproduce the
# exact same state from the apps cache (bare `mina`) + repo (config), with no
# package. Either way `mina` is on PATH and /var/lib/coda/<net>.json exists, so
# chain-id resolves the genesis ledger identically. Fall back to the .deb on a
# cache miss (e.g. outside Buildkite).
if ./buildkite/scripts/apps/restore_binary.sh "${MINA_DEBIAN_NETWORK}" \
  && ./buildkite/scripts/apps/restore_daemon_config.sh "${MINA_DEBIAN_NETWORK}"; then
  echo "Using bare mina + replicated genesis config from apps cache"
else
  echo "Falling back to debian-installed mina-${MINA_DEBIAN_NETWORK}"
  source buildkite/scripts/debian/update.sh --verbose
  source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1
fi

echo "--- Running mina chain-id command"

MINA_CONFIG_FILE="${MINA_CONFIG_FILE:-/var/lib/coda/${MINA_DEBIAN_NETWORK}.json}"

ACTUAL_CHAIN_ID=$(mina internal chain-id --config-file ${MINA_CONFIG_FILE} | tail -n1)

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
