#!/bin/bash

set -eox pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive
YELLOW_THRESHOLD="0.1"
RED_THRESHOLD="0.3"

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl python3

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-berkeley,mina-test-suite" 1

pip install parse
pip install -r ./scripts/benchmarks/requirements.txt

MAINLINE_BRANCHES="-m develop -m compatile -m master -m dkijania/build_performance_tooling_in_ci"
EXTRA_ARGS="--genesis-ledger-path ./genesis_ledgers/devnet.json"

while [[ "$#" -gt 0 ]]; do case $1 in
  heap-usage) BENCHMARK="heap-usage"; ;;
  mina-base) BENCHMARK="mina-base"; ;;
  ledger-export) BENCHMARK="ledger-export"; ;;
  snark) BENCHMARK="snark"; ;;
  zkapp) BENCHMARK="zkapp"; ;;
  --yellow-threshold) YELLOW_THRESHOLD="$2"; shift;;
  --red-threshold) RED_THRESHOLD="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

python3 ./scripts/benchmarks test --benchmark ${BENCHMARK}  --branch ${BUILDKITE_BRANCH} --tmpfile ${BENCHMARK}.csv --yellow-threshold $YELLOW_THRESHOLD --red-threshold $RED_THRESHOLD $MAINLINE_BRANCHES $EXTRA_ARGS