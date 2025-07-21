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

# Build the mock coordinator binary if it doesn't exist
if [ ! -f "_build/default/src/test/mock_snark_work_coordinator/mock_snark_work_coordinator.exe" ]; then
  echo "Building mock coordinator binary..."
  dune build src/test/mock_snark_work_coordinator/mock_snark_work_coordinator.exe --profile=devnet
fi

# Set environment variables for the test script
export DUMPED_SPEC_PATH="/tmp/mock-coordinator-test/specs"
export PROOF_OUTPUT_PATH="/tmp/mock-coordinator-test/proofs"

./scripts/tests/mock_coordinator.sh