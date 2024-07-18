#!/bin/bash

set -eo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

profile=$1
path=$2

source ~/.profile

export MINA_LIBP2P_PASS="naughty blue worm"
export NO_JS_BUILD=1 # skip some JS targets which have extra implicit dependencies
export USE_LAGRANGE_CACHE=true
echo "The value of USE_LAGRANGE_CACHE is in the dev unit test script is $USE_LAGRANGE_CACHE"

echo "--- Make build"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go
time make build

echo "--- Build all targets"
dune build "${path}" --profile="${profile}" -j16

echo "--- Check for changes to verification keys"
time dune runtest "src/app/print_blockchain_snark_vk" --profile="${profile}" -j16

# Turn on the proof-cache assertion, so that CI will fail if the proofs need to
# be updated.
export ERROR_ON_PROOF=true


# Note: By attempting a re-run on failure here, we can avoid rebuilding and
# skip running all of the tests that have already succeeded, since dune will
# only retry those tests that failed.
echo "--- Run unit tests"
time dune runtest "${path}" --profile="${profile}" -j16 || \
(./scripts/link-coredumps.sh && \
 echo "--- Retrying failed unit tests" && \
 time dune runtest "${path}" --profile="${profile}" -j16 || \
 (./scripts/link-coredumps.sh && false))
