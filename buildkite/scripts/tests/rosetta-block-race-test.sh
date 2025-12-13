#!/usr/bin/env bash

# Main purpose of this is script is to wrap around  rosetta-block-race.sh
# So env vars from docker buildkite step are passed down to the script

LEDGER_URL="https://storage.googleapis.com/o1labs-ci-test-data/ledgers/single-bp-ledger.tar"
LEDGER_DIR="ledger"

echo "Downloading&extracting ledger archive from $LEDGER_URL ..."
curl -L "$LEDGER_URL" | tar -x -C "$LEDGER_DIR"

chmod 700 "$LEDGER_DIR"

sudo apt-get update
sudo apt-get install -y python3

./scripts/rosetta/test-block-race.sh \
                      --mina-exe /usr/local/bin/mina \
                      --archive-exe /usr/local/bin/mina-archive \
                      --rosetta-exe /usr/local/bin/mina-rosetta \
                      --postgres-uri ${PG_CONN} \
                      --ledger /workdir/${LEDGER_DIR}
