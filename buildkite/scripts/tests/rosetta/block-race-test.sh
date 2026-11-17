#!/usr/bin/env bash

# Main purpose of this is script is to wrap around  rosetta-block-race.sh
# So env vars from docker buildkite step are passed down to the script

if [[ "$(cat MINA_CODEBASE_NETWORK)" != "$(cat MINA_MAINNET_NETWORK)" ]]; then
  echo "Skipping: this codebase targets $(cat MINA_CODEBASE_NETWORK), not $(cat MINA_MAINNET_NETWORK)"
  exit 0
fi

LEDGER_URL="https://storage.googleapis.com/o1labs-ci-test-data/ledgers/single-bp-ledger-mesa.tar"
LEDGER_DIR="ledger"

mkdir -p "$LEDGER_DIR"

echo "Downloading&extracting ledger archive from $LEDGER_URL ..."
curl -L "$LEDGER_URL" | tar -x -C "$LEDGER_DIR"

chmod 700 "$LEDGER_DIR"

./buildkite/scripts/debian/update.sh

sudo apt-get install -y python3

./scripts/rosetta/test-block-race.sh \
                      --mina-exe /usr/local/bin/mina \
                      --archive-exe /usr/local/bin/mina-archive \
                      --rosetta-exe /usr/local/bin/mina-rosetta \
                      --postgres-uri ${PG_CONN} \
                      --ledger /workdir/${LEDGER_DIR}
