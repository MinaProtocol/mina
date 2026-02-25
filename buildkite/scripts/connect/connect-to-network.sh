#!/bin/bash

set -eo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 '<mina-debian-network>''<testnet-name>' '<wait-between-polling-graphql>''<wait-after-final-check>' "
    exit 1
fi

MINA_DEBIAN_NETWORK=$1
NETWORK_NAME=$2
WAIT_BETWEEN_POLLING_GRAPHQL=$3
WAIT_AFTER_FINAL_CHECK=$4

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1

# Remove lockfile if present
rm /home/opam/.mina-config/.mina-lock ||:

mkdir -p /home/opam/libp2p-keys/
# Pre-generated random password for this quick test
export MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf
mina libp2p generate-keypair --privkey-path /home/opam/libp2p-keys/key
# Set permissions on the keypair so the daemon doesn't complain
chmod -R 0700 /home/opam/libp2p-keys/

# Read PEERS_LIST_URL from mina.service
PEERS_LIST_URL=$(grep -oP 'Environment="PEERS_LIST_URL=\K[^"]+' /usr/lib/systemd/user/mina.service)

# Restart in the background
mina daemon \
  --peer-list-url "$PEERS_LIST_URL" \
  --libp2p-keypair "/home/opam/libp2p-keys/key" \
& # -background

# Attempt to connect to the GraphQL client every 10s for up to 8 minutes
num_status_retries=24
for ((i=1;i<=$num_status_retries;i++)); do
  sleep $WAIT_BETWEEN_POLLING_GRAPHQL
  set +e
  mina client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq $num_status_retries ]; then
    exit $status_exit_code
  fi
done

# Check that the daemon has connected to peers and is still up after 2 mins
sleep "$WAIT_AFTER_FINAL_CHECK"
mina client status
if [ "$(mina advanced get-peers | wc -l)" -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi

# Check network id
NETWORK_ID=$(curl 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw '{"query":"query MyQuery {\n  networkID\n}\n","variables":null,"operationName":"MyQuery"}' \
  | jq -r .data.networkID)

EXPECTED_NETWORK=mina:$NETWORK_NAME

if [[ "$NETWORK_ID" == "$EXPECTED_NETWORK" ]]; then
    echo "Network id correct ($NETWORK_ID)"
else
    echo "Network id incorrect (expected: $EXPECTED_NETWORK got: $NETWORK_ID)"
    exit 1
fi

