#!/bin/bash

set -eo pipefail

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-berkeley-instrumented" 1

echo "removing magic config files"
sudo rm -f /var/lib/coda/config_*

./scripts/tests/ledger_test_apply.sh \
    --mina-app mina \
    --runtime-ledger-app mina-create-genesis