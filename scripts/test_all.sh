#!/bin/bash

set -exo pipefail

eval `opam config env`

run_dune() {
  if [ "${DUNE_PROFILE}" = "" ]; then
    DUNE_PROFILE=test_posig
  fi
  dune $1 --profile="${DUNE_PROFILE}" ${@:2}
}

run_unit_tests() {
  date
  MYPROCS=${MYPROCS:-$(nproc --all)} # Linux-specific
  run_dune runtest --verbose -j${MYPROCS}
}

run_ppx_tests() {
  date
  make test-ppx
}

run_unit_tests_with_coverage() {
  date
  MYPROCS=${MYPROCS:-$(nproc --all)} # Linux-specific
  # force to make sure all coverage files generated
  BISECT_ENABLE=YES run_dune runtest --force -j${MYPROCS}
}

run_integration_test() {
  echo "------------------------------------------------------------------------------------------"

  date
  SECONDS=0
  echo "TESTING ${1}"
  set +e

  # ugly hack to clean up dead processes
  pkill -9 exe
  pkill -9 kademlia
  pkill -9 coda
  sleep 1

  run_dune exec coda -- integration-tests ${1} 2>&1 | tee test.log | ../scripts/jqproc.sh -f '.level=="Error" or .level=="Warning" or .level=="Faulty_peer" or .level=="Fatal"'
  OUT=${PIPESTATUS[0]}
  echo "------------------------------------------------------------------------------------------" >> test.log
  echo "${1}" >> test.log

  echo "TESTING ${1} took ${SECONDS} seconds"

  if [ $OUT -eq 0 ];then
    echo "PASSED"
  else
    echo "FAILED"
    echo "------------------------------------------------------------------------------------------"
    echo "RECENT OUTPUT:"
    cat test.log | run_dune exec logproc
    echo "------------------------------------------------------------------------------------------"
    echo "FAILURE ON: ${1}"
    exit 2
  fi

  set -e
}

run_all_integration_tests() {
  # disabled (fails all the time) 'coda-restart-node-test'
  for test in full-test coda-peers-test coda-transitive-peers-test coda-block-production-test 'coda-shared-prefix-test -who-proposes 0' 'coda-shared-prefix-test -who-proposes 1' 'coda-shared-state-test' 'transaction-snark-profiler -check-only'; do
    run_integration_test "${test}"
  done
}

run_all_sig_integration_tests() {
    DUNE_PROFILE=test_posig \
    CODA_BLOCK_DURATION=1000 \
    run_all_integration_tests
}

run_all_stake_integration_tests() {
    DUNE_PROFILE=test_postake \
    CODA_BLOCK_DURATION=1000 \
    CODA_K=24 \
    CODA_C=8 \
    run_all_integration_tests
}

run_epoch_stake_integration_test() {
    DUNE_PROFILE=test_postake \
    CODA_BLOCK_DURATION=1000 \
    CODA_K=2 \
    CODA_C=2 \
    run_integration_test full-test
}

main() {
  run_dune build
  run_unit_tests
  run_ppx_tests
  run_all_sig_integration_tests
  run_all_stake_integration_tests
  # run_epoch_stake_integration_test
}

# Only run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
