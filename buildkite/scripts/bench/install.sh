#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl python3

TESTNET_NAME="devnet"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-test-suite,mina-$TESTNET_NAME" 1

pip3 install -r scripts/benchmarks/requirements.txt