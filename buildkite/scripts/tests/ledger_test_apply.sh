#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl python3 python3-pip wget

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-devnet-instrumented" 1

echo "removing magic config files"
sudo rm -f /var/lib/coda/config_*

./scripts/tests/ledger_test_apply.sh \
    --mina-app mina \
    --runtime-ledger-app mina-create-genesis