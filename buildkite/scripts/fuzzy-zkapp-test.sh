#!/bin/bash

set -eo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests> <timeout> <individual-test-timeout>"
    exit 1
fi

profile=$1
path=$2
timeout=$3
individual_test_timeout=$4

source ~/.profile

echo "--- Make build"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go

# Note: By attempting a re-run on failure here, we can avoid rebuilding and
# skip running all of the tests that have already succeeded, since dune will
# only retry those tests that failed.
echo "--- Run fuzzy zkapp tests"
time dune exec "${path}" --profile="${profile}" -j16 -- --timeout "${timeout}" --individual-test-timeout "${individual_test_timeout}" --seed "${RANDOM}"
STATUS=$?
if [ "$STATUS" -ne 0 ]; then
  ./scripts/link-coredumps.sh && exit "$STATUS"
fi
