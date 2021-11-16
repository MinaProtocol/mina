#!/bin/bash

NETWORK=${1:=mainnet}

cat genesis_ledgers/${NETWORK}.json | jq '.ledger.accounts[] | { "account_identifier": { "address": .pk }, "currency": {"symbol":"MINA", "decimals":9 }, "value": ((.balance | tonumber) * 1000000000 | tostring) }' > ${NETWORK}_balances.json

cat ${NETWORK}_balances.json | jq -s '.' > src/app/rosetta/${NETWORK}_balances.json

rm ${NETWORK}_balances.json


echo "Conversion is complete, first 15 lines of the result:"
head -n 15 src/app/rosetta/${NETWORK}_balances.json
