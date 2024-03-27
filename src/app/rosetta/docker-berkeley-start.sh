#!/bin/bash

set -eou pipefail

export MINA_NETWORK=berkeley
export MINA_SUFFIX="-dev"
export MINA_COMMIT="${MINA_COMMIT:=05c2f73d0f6e4f1341286843814ce02dcb3919e0}"   #https://github.com/MinaProtocol/mina/discussions/12421
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json

# Configuration
echo "=========================== DOWNLOADING CONFIGURATION FOR ${MINA_NETWORK} ==========================="
curl -s -o "${MINA_CONFIG_FILE}" "https://raw.githubusercontent.com/MinaProtocol/mina/${MINA_COMMIT}/genesis_ledgers/${MINA_NETWORK}.json"

./docker-start.sh $@
