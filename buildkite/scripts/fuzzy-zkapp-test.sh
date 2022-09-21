#!/bin/bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests> <number-of-trials>"
    exit 1
fi

profile=$1
path=$2
trials=$3

if [ "$NIGHTLY" != true ]
then
  source ~/.profile

  echo "--- Make build"
  export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go

  # Note: By attempting a re-run on failure here, we can avoid rebuilding and
  # skip running all of the tests that have already succeeded, since dune will
  # only retry those tests that failed.
  echo "--- Run fuzzy zkapp tests"
  time dune exec "${path}" --profile="${profile}" -j16 -- --trials "${trials}" || \
  (./scripts/link-coredumps.sh && \
   echo "--- Retrying failed unit tests" && \
   time dune exec "${path}" --profile="${profile}" -j16 -- --trials "${trials}" || \
   (./scripts/link-coredumps.sh && false))
fi
