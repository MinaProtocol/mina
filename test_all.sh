#!/bin/bash

set -eo pipefail

eval `opam config env`

run_unit_tests() {
  date
  myprocs=`nproc --all`  # Linux specific
  dune runtest --verbose -j${myprocs}
}


run_integration_tests() {
  for test in full-test coda-peers-test coda-transitive-peers-test coda-block-production-test 'coda-shared-state-test' 'coda-shared-prefix-test -who-proposes 0' 'coda-shared-prefix-test -who-proposes 1' 'transaction-snark-profiler -check-only'; do
    echo "------------------------------------------------------------------------------------------"

    date
    SECONDS=0
    echo "TESTING ${test} USING ${CODA_CONSENSUS_MECHANISM}"
    set +e
    # ugly hack to clean up dead processes
    pkill -9 exe
    pkill -9 kademlia
    pkill -9 cli
    sleep 1
    dune exec cli -- $test 2>&1 >> test.log
    OUT=$?
    echo "TESTING ${test} took ${SECONDS} seconds"
    if [ $OUT -eq 0 ];then
      echo "PASSED"
    else
      echo "FAILED"
      echo "------------------------------------------------------------------------------------------"
      echo "RECENT OUTPUT:"
      tail -n 50 test.log | dune exec logproc
      echo "------------------------------------------------------------------------------------------"
      echo "See above for stack trace..."
      exit 2
    fi
    set -e
  done
}

main() {
  export CODA_PROPOSAL_INTERVAL=1000
  export CODA_SLOT_INTERVAL=1000
  export CODA_UNFORKABLE_TRANSITION_COUNT=4
  export CODA_PROBABLE_SLOTS_PER_TRANSITION_COUNT=1

  run_unit_tests

  CODA_CONSENSUS_MECHANISM=proof_of_signature \
    run_integration_tests
  CODA_CONSENSUS_MECHANISM=proof_of_stake \
    run_integration_tests
}

# Only run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
