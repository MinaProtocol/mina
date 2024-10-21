#!/bin/bash

set -eo pipefail

source buildkite/scripts/bench/install.sh

python3 ./scripts/benchmarks run --benchmark zkapp --outfile zakpp-out

python3 ./scripts/benchmarks run --benchmark heap-usage --outfile heap-usage.out