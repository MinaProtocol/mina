#!/bin/bash

set -eux -o pipefail

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

# Restart in the background
mina daemon \
  --peer-list-url "https://storage.googleapis.com/seed-lists/${NETWORK_NAME}_seeds.txt" \
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
NETWORK_ID=$(curl -f --show-error 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw '{"query":"query MyQuery {\n  networkID\n}\n","variables":null,"operationName":"MyQuery"}' \
  | jq -r '.data.networkID')

if [ $? -ne 0 ]; then
    echo "GraphQL query 'networkID' failed!" >&2
    exit 1
fi

EXPECTED_NETWORK=mina:$NETWORK_NAME

if [[ "$NETWORK_ID" == "$EXPECTED_NETWORK" ]]; then
    echo "Network id correct ($NETWORK_ID)"
else
    echo "Network id incorrect (expected: $EXPECTED_NETWORK got: $NETWORK_ID)"
    exit 1
fi

# Check bestTip 
BEST_TIP_STATE_HASH=$(curl -f --show-error 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw '{"query":"query MyQuery {\n bestChain(maxLength: 1) {\n stateHash \n}\n}\n","variables":null,"operationName":"MyQuery"}' \
  | jq -r '.data.bestChain[0].stateHash')

if [ $? -ne 0 ]; then
    echo "GraphQL query 'bestChain' failed!" >&2
    exit 1
fi

echo "Found best tip state hash ${BEST_TIP_STATE_HASH}"

SNARKED_LEDGER_HASH=$(curl -f --show-error 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw '{
     "query": "query MyBlock($stateHash: String!) { block(stateHash: $stateHash) { protocolState { blockchainState { snarkedLedgerHash } } } }",
     "variables": { "stateHash": "'"${BEST_TIP_STATE_HASH}"'" },
     "operationName": "MyBlock"
   }' \
  | jq -r '.data.block.protocolState.blockchainState.snarkedLedgerHash')

if [ $? -ne 0 ]; then
    echo "GraphQL query 'block' failed!" >&2
    exit 1
fi

echo "Best tip's Snarked Ledger Hash: ${SNARKED_LEDGER_HASH}"

ANCIENT_STATE_HASH_DEVNET="3NL5hv4ysELXF2Tg5UZDMgBFcQLTM1tGtRRzMhgyLa5EzvbeDQhq"
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw '{
     "query": "query MyBlock($stateHash: String!) { block(stateHash: $stateHash) { protocolState { blockchainState { snarkedLedgerHash } } } }",
     "variables": { "stateHash": "'"${ANCIENT_STATE_HASH_DEVNET}"'" },
     "operationName": "MyBlock"
     }' || true)
  

if [[ "$HTTP_CODE" == "500" ]]; then
    echo "OK: Querying ancient state hash on node, got HTTP CODE 500"
else
    echo "FAIL: Querying ancient state hash on node, got HTTP CODE ${HTTP_CODE}, expected 500"
    exit 1
fi
