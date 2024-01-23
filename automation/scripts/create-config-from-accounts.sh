#!/bin/bash

TESTNET=$1
GENESIS_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ARTIFACT_PATH="terraform/testnets/${TESTNET}"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../"

# GENESIS

if [[ -s "${ARTIFACT_PATH}/genesis_ledger.json" ]] ; then
    echo "-- genesis_ledger.json already exists for this testnet, refusing to overwrite. Delete \'${ARTIFACT_PATH}/genesis_ledger.json\' to force re-creation."
  exit
fi

# Optional: add num_accounts

jq -s '{ genesis: { genesis_state_timestamp: "'${GENESIS_TIMESTAMP}'" }, ledger: { name: "'${TESTNET}'", accounts: [ .[] ] } }' ${ARTIFACT_PATH}/*.accounts.json > "${ARTIFACT_PATH}/genesis_ledger.json"
