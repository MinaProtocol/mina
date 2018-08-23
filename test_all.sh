#!/bin/bash

set -eo pipefail

eval `opam config env`
dune runtest --verbose -j8

for consensus_mechanism in proof_of_signature proof_of_stake; do
  export CONSENSUS_MECHANISM="$consensus_mechanism"
  for test_args in full-test coda-peers-test coda-block-production-test 'transaction-snark-profiler -check-only'; do
    dune exec cli -- $test_args
  done
done
