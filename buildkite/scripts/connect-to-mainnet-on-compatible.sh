#!/bin/bash

set -eo pipefail

if [ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" = "compatible" ]; then
  echo "Not pulling against compatible, not running the connect test"
  exit 0
fi

TESTNET_NAME="mainnet"

# Remove lockfile if present
rm ~/.mina-config/.mina-lock ||:

# Restart in the background
mina daemon \
  --peer-list-url "https://storage.googleapis.com/seed-lists/${TESTNET_NAME}_seeds.txt" \
& # -background

# Attempt to connect to the GraphQL client every 10s for up to 4 minutes
for i in {0..24}; do
  sleep 10s
  set +e
  mina client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq 24 ]; then
    exit $status_exit_code
  fi
done

# Check that the daemon has connected to peers and is still up after 2 mins
sleep 2m
mina client status
if [ $(mina advanced get-peers | wc -l) -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi
