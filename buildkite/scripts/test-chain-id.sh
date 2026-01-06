#!/bin/bash

set -eo pipefail

MINA_DEBIAN_NETWORK=$1
EXPECTED_CHAIN_ID=$2

echo "--- Testing chain_id command for ${MINA_DEBIAN_NETWORK}"

git config --global --add safe.directory /workdir
source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh
source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1

echo "--- Running mina chain-id command"

MINA_CONFIG_FILE="${MINA_CONFIG_FILE:-/var/lib/coda/${MINA_DEBIAN_NETWORK}.json}"

ACTUAL_CHAIN_ID=$(mina internal chain-id --config-file ${MINA_CONFIG_FILE} 2>/dev/null | tail -n1)

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
