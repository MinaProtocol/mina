#!/bin/bash

set -eo pipefail

if [ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" = "develop" ]; then
  echo "Not pulling against develop, not running the connect test"
  exit 0
fi

apt-get update
apt-get install -y git

DUNE_PROFILE=testnet_postake_medium_curves

source buildkite/scripts/export-git-env-vars.sh

apt-get install -y apt-transport-https ca-certificates
echo "deb [trusted=yes] http://packages.o1test.net unstable main" | tee /etc/apt/sources.list.d/coda.list
apt-get update
apt-get install --allow-downgrades -y curl ${PROJECT}_${VERSION}

TESTNET_NAME="turbo-pickles"

# Generate genesis proof and then crash due to no peers
coda daemon \
  -config-file ./coda-automation/terraform/testnets/$TESTNET_NAME/genesis_ledger.txt \
  -generate-genesis-proof true \
|| true

# Restart in the background
coda daemon \
  -peer-list-file coda-automation/terraform/testnets/$TESTNET_NAME/peers.txt \
  -config-file ./coda-automation/terraform/testnets/$TESTNET_NAME/genesis_ledger.txt \
  -generate-genesis-proof true \
  -background

# Check that the GraphQL client is up within 30s
sleep 30s
coda client status

# Check that the daemon has connected to peers and is still up after 2 mins
sleep 2m
coda client status
if [ $(coda client get-peers | wc -l) -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi
