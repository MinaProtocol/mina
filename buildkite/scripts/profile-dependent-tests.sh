#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <dune-profile>"
    exit 1
fi

export DUNE_PROFILE=$1

# shellcheck disable=SC1090
source ~/.profile

echo "--- Rebuild node_config with profile ${DUNE_PROFILE}"
# Force rebuild of node_config to ensure correct profile is used.
# This avoids full recompilation - only node_config and its dependents
# are rebuilt.
time dune build --force src/lib/node_config

echo "--- Run profile-dependent tests"
# Tests that have expected values varying by profile (dev, devnet, lightnet, mainnet).
# NOTE: Only running specific test directories because some tests in src/lib
# still need to be updated for profile-based expected values.
# Tests are ordered alphabetically.
time dune runtest \
    src/lib/blockchain_snark/tests \
    src/lib/transaction_snark/test/constraint_count
