#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <mina-profile>"
    exit 1
fi

export DUNE_PROFILE=$1
export MINA_PROFILE=$1

if [[ -n "${BUILDKITE+x}" && "$BUILDKITE" == "true" ]]; then
    # shellcheck disable=SC1090
    source ~/.profile
fi

echo "--- Run profile-dependent tests"
# Tests that have expected values varying by profile (dev, devnet, lightnet, mainnet).
# NOTE: Only running specific test directories because some tests in src/lib
# still need to be updated for profile-based expected values.
# Tests are ordered alphabetically.
# `-f` is needed because this script is executed in same CI environment multiple
# times.
time dune runtest -f \
    src/lib/blockchain_snark/tests \
    src/lib/transaction_snark/test/constraint_count \
    src/lib/transaction_snark/test/print_transaction_snark_vk
