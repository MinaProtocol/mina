#!/bin/bash

set -eo pipefail

TESTNET_NAME="testnet-generic"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-test-suite,mina-$TESTNET_NAME" 1

pip3 install -r scripts/benchmarks/requirements.txt