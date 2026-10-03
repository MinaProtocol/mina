#!/bin/bash

set -euo pipefail

echo "--- Setting up environment"
git config --global --add safe.directory /workdir
source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh
source buildkite/scripts/debian/install.sh "mina-devnet" 1

echo "--- Generating local genesis ledger"
GENESIS_DIR=$(mktemp -d)
chmod 700 "$GENESIS_DIR"
export MINA_PRIVKEY_PASS=""

./scripts/generate-local-genesis.sh \
  --mina-binary "$(which mina)" \
  --runtime-genesis-ledger-binary "$(which mina-create-genesis)" \
  --output-dir "$GENESIS_DIR"

echo "--- Running max-cost zkapp test with --verify"
mina advanced test submit-to-archive \
  --config-file "$GENESIS_DIR/runtime_config.json" \
  --genesis-dir "$GENESIS_DIR/genesis-ledger" \
  --privkey-path "$GENESIS_DIR/faucet-key" \
  --num-blocks 1 --num-zkapp-txs 1 --num-payments 1 \
  --max-cost --verify

echo "--- SUCCESS: Max-cost zkapp test passed"
