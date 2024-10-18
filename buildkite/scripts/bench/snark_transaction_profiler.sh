#!/bin/bash

set -eo pipefail

source buildkite/scripts/bench/install.sh

K=1
MAX_NUM_UPDATES=4
MIN_NUM_UPDATES=2   

echo "-- Run Snark Transaction Profiler with parameters: --k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
python3 ./scripts/benchmarks run --benchmark snark --k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES} --outfile snark.out
