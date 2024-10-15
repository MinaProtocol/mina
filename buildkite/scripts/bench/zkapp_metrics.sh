#!/bin/bash

set -eo pipefail

source buildkite/scripts/bench/install.sh

python3 ./scripts/benchmarks.py run --benchmark zkapp 

python3 ./scripts/benchmarks.py run --benchmark heap-usage