#!/bin/bash

set -euox pipefail


# Script for running mock coordinator tests.
# It requires to be executed in buildkite context.
# e.g (BUILDKITE_BUILD_ID env var to be defined) 
mkdir -p /tmp/mock-coordinator-test
mkdir -p /tmp/mock-coordinator-test/proofs
mkdir -p /tmp/mock-coordinator-test/specs

./buildkite/scripts/cache/manager.sh read --root test_data mock_coordinator_test_specs.tar.gz /tmp/mock-coordinator-test/specs

tar -xzf /tmp/mock-coordinator-test/specs/mock_coordinator_test_specs.tar.gz -C /tmp/mock-coordinator-test/specs

rm /tmp/mock-coordinator-test/specs/mock_coordinator_test_specs.tar.gz

keep_only_n_json_files() {
    local dir="/tmp/mock-coordinator-test/specs"
    local n="$1"
    find "$dir" -maxdepth 1 -type f -name '*.json' | sort | head -n "-$n" | xargs -r rm --
}

ls /tmp/mock-coordinator-test/specs

# Keep only the latest 30 .json files (adjust N as needed)
keep_only_n_json_files 30

ls /tmp/mock-coordinator-test/specs

# Set environment variables for the test script
export DUMPED_SPEC_PATH="/tmp/mock-coordinator-test/specs"
export PROOF_OUTPUT_PATH="/tmp/mock-coordinator-test/proofs"

MINA_APP=mina MOCK_SNARK_WORKER_COORDINATOR=mina-mock-snark-work-coordinator ./scripts/tests/mock_coordinator.sh