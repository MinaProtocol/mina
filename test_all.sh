#!/bin/bash

set -eo pipefail

eval `opam config env`

# FIXME: Linux specific
myprocs=`nproc --all`
date
dune runtest --verbose -j${myprocs}

for consensus_mechanism in proof_of_signature proof_of_stake; do
  export CODA_CONSENSUS_MECHANISM="$consensus_mechanism"
  for test_args in full-test coda-peers-test coda-block-production-test 'coda-shared-prefix-test -who-proposes 0' 'coda-shared-prefix-test -who-proposes 1' coda-shared-state-test 'transaction-snark-profiler -check-only'; do
>>>>>>> add multiple transaction test
    date
    dune exec cli -- $test_args
  done
done

date
