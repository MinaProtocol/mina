#!/bin/bash

set -eo pipefail

echo "Disabled for now as we don't have a testnet online yet"
exit 0

if [ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" = "compatible" ]; then
  echo "Not pulling against compatible, not running the connect test"
  exit 0
fi

apt-get update
apt-get install -y git

export DUNE_PROFILE=testnet_postake_medium_curves

source buildkite/scripts/export-git-env-vars.sh

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get install -y apt-transport-https ca-certificates
echo "deb [trusted=yes] http://packages.o1test.net unstable main" | tee /etc/apt/sources.list.d/coda.list
apt-get update
apt-get install --allow-downgrades -y curl ${PROJECT}=${VERSION}

TESTNET_NAME="testworld"


# Generate genesis proof and then crash due to no peers
coda daemon \
  -config-file ./automation/terraform/testnets/$TESTNET_NAME/genesis_ledger.json \
  -generate-genesis-proof true \
|| true

# Remove lockfile if present
rm ~/.coda-config/.mina-lock ||:

# Restart in the background
coda daemon \
  -peer-list-file automation/terraform/testnets/$TESTNET_NAME/peers.txt \
  -config-file ./automation/terraform/testnets/$TESTNET_NAME/genesis_ledger.json \
  -generate-genesis-proof true \
  & # -background

# Attempt to connect to the GraphQL client every 10s for up to 4 minutes
num_status_retries=24
for ((i=1;i<=$num_status_retries;i++)); do
  sleep 10s
  set +e
  coda client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq $num_status_retries ]; then
    exit $status_exit_code
  fi
done

# Check that the daemon has connected to peers and is still up after 2 mins
sleep 2m
coda client status
if [ $(coda advanced get-peers | wc -l) -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi
