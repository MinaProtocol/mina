#!/bin/bash

set -eo pipefail

eval `opam config env`

test_runtest() {
  date
  myprocs=`nproc --all`  # Linux specific
  dune runtest --verbose -j${myprocs}
}

test_method() {
  export CODA_CONSENSUS_MECHANISM="$1"
  for test in full-test coda-peers-test coda-block-production-test 'coda-shared-prefix-test -who-proposes 0' 'coda-shared-prefix-test -who-proposes 1' coda-shared-state-test 'transaction-snark-profiler -check-only'; do
    echo "------------------------------------------------------------------------------------------"
    date
    echo "TESTING ${test} USING ${CODA_CONSENSUS_MECHANISM}"
    sleep 1
    dune exec cli -- $test
  done
}

main() {
  test_runtest
  test_method 'proof_of_signature'
  test_method 'proof_of_stake'
}

# Only run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
