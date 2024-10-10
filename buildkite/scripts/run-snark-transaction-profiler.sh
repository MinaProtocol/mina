#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl python3

TESTNET_NAME="devnet"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1

K=1
MAX_NUM_UPDATES=4
MIN_NUM_UPDATES=2   

echo "-- Run Snark Transaction Profiler with parameters: --zkapps --k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
python3 ./scripts/snark_transaction_profiler.py ${K} ${MAX_NUM_UPDATES} ${MIN_NUM_UPDATES}
