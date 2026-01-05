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
&

graphql_query() {
  local query_string="$1"
  local jq_selector="$2"
  curl -f --show-error 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw "$query_string" \
  | jq -r "$jq_selector"
}

graphql_query_returns_failed_http_code() {
  local query_string="$1"
  curl -o /dev/null -s -w "%{http_code}" 'http://localhost:3085/graphql' \
   -H 'accept: application/json' \
   -H 'content-type: application/json' \
   --data-raw "$query_string" || true
}

num_status_retries=48
node_status=""
node_status_exit_code=1

for ((i=1; i<=num_status_retries; i++)); do
  sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"

  set +e
  node_status=$(graphql_query '{"query":"query { syncStatus }"}' '.data.syncStatus')
  node_status_exit_code=$?
  set -e

  if [[ "$node_status" == "SYNCED" ]]; then
    break
  fi
done

if [[ "$node_status" != "SYNCED" ]]; then
  exit "$node_status_exit_code"
fi

sleep "$WAIT_AFTER_FINAL_CHECK"

all_peers=$(graphql_query '{"query":"query { getPeers { peerId } }"}' '.data.getPeers[].peerId')
echo "Connected peers\n ${all_peers}"

if [[ $(printf "${all_peers}" | wc -l) == 0 ]]; then
    echo "No peers found"
fi 

ACTUAL_NETWORK_ID=$(graphql_query '{"query":"query { networkID }"}' '.data.networkID')
EXPECTED_NETWORK_ID=mina:$NETWORK_NAME

if [[ "$ACTUAL_NETWORK_ID" == "$EXPECTED_NETWORK_ID" ]]; then
    echo "Network id correct ($ACTUAL_NETWORK_ID)"
else
    echo "Network id incorrect (expected: $EXPECTED_NETWORK_ID got: $ACTUAL_NETWORK_ID)"
    exit 1
fi

# Check bestTip 
BEST_TIP_STATE_HASH=$(graphql_query '{"query":"query { bestChain(maxLength: 1) { stateHash } }"}' '.data.bestChain[0].stateHash')

echo "Found best tip state hash ${BEST_TIP_STATE_HASH}"

SNARKED_LEDGER_HASH=$(graphql_query '{
     "query": "query MyBlock($stateHash: String!) { block(stateHash: $stateHash) { protocolState { blockchainState { snarkedLedgerHash } } } }",
     "variables": { "stateHash": "'"${BEST_TIP_STATE_HASH}"'" },
     "operationName": "MyBlock"
   }' '.data.block.protocolState.blockchainState.snarkedLedgerHash')

echo "Best tip's Snarked Ledger Hash: ${SNARKED_LEDGER_HASH}"

ANCIENT_STATE_HASH_DEVNET="3NL5hv4ysELXF2Tg5UZDMgBFcQLTM1tGtRRzMhgyLa5EzvbeDQhq"
HTTP_CODE=$(graphql_query_returns_failed_http_code '{
     "query": "query MyBlock($stateHash: String!) { block(stateHash: $stateHash) }",
     "variables": { "stateHash": "'"${ANCIENT_STATE_HASH_DEVNET}"'" },
     "operationName": "MyBlock"
   }')

if [[ "$HTTP_CODE" == "500" ]]; then
    echo "OK: Querying ancient state hash on node, got HTTP CODE 500"
else
    echo "FAIL: Querying ancient state hash on node, got HTTP CODE ${HTTP_CODE}, expected 500"
    exit 1
fi
