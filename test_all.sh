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
  for test in full-test coda-peers-test coda-transitive-peers-test coda-block-production-test 'coda-shared-prefix-test -who-proposes 0' 'coda-shared-prefix-test -who-proposes 1' coda-shared-state-test 'transaction-snark-profiler -check-only'; do
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
      tail -n 30 test.log
      exit 2
    fi
    set -e
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
