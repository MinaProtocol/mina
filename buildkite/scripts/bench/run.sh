#!/bin/bash

set -eox pipefail

# Don't prompt for answers during apt-get install

YELLOW_THRESHOLD="0.1"
RED_THRESHOLD="0.3"
EXTRA_ARGS=""

source buildkite/scripts/bench/install.sh

MAINLINE_BRANCHES="-m develop -m compatible -m master -m dkijania/enhance_benchmarks"
while [[ "$#" -gt 0 ]]; do case $1 in
  heap-usage) BENCHMARK="heap-usage"; ;;
  mina-base) BENCHMARK="mina-base"; ;;
  ledger-export) 
    BENCHMARK="ledger-export"
    EXTRA_ARGS="--genesis-ledger-path ./genesis_ledgers/devnet.json"
  ;;
  snark) 
    BENCHMARK="snark";
    K=1
    MAX_NUM_UPDATES=4
    MIN_NUM_UPDATES=2
    EXTRA_ARGS="--k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
  ;;
  zkapp) BENCHMARK="zkapp"; ;;
  --yellow-threshold) YELLOW_THRESHOLD="$2"; shift;;
  --red-threshold) RED_THRESHOLD="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

python3 ./scripts/benchmarks test --benchmark ${BENCHMARK}  --branch ${BUILDKITE_BRANCH} --tmpfile ${BENCHMARK}.csv --yellow-threshold $YELLOW_THRESHOLD --red-threshold $RED_THRESHOLD $MAINLINE_BRANCHES $EXTRA_ARGS