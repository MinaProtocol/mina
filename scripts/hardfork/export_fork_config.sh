#!/bin/bash

MINA_V1_DAEMON=${MINA_V1_DAEMON:=_build/default/src/app/cli/src/mina.exe}
FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}

$MINA_V1_DAEMON daemon --config-file genesis_ledgers/mainnet.json --peer-list-url https://storage.googleapis.com/seed-lists/mainnet_seeds.txt &


function isNotSynced() {
    status=$(curl --silent --show-error --header "Content-Type:application/json" -d'{ "query": "query { syncStatus } " }' localhost:3085/graphql | jq '.data.syncStatus')
    if [ "${status}" == '"SYNCED"' ]; then
        return 1
    else
        return 0
    fi
}

while isNotSynced; do
    sleep 10s
done

echo "Node synced"

curl --silent --show-error --header "Content-Type:application/json" -d'{ "query": "query { fork_config } " }' localhost:3085/graphql | jq '.data.fork_config' > $FORK_CONFIG_JSON

$MINA_V1_DAEMON client stop-daemon
