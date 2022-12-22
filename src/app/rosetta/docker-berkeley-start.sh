#!/bin/bash

set -eou pipefail

export MINA_NETWORK=berkeley
export MINA_SUFFIX="-dev"
export MINA_COMMIT="${MINA_COMMIT:=0b63498e271575dbffe2b31f3ab8be293490b1ac}"   #https://github.com/MinaProtocol/mina/discussions/12217
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json

# Configuration
echo "=========================== DOWNLOADING CONFIGURATION FOR ${MINA_NETWORK} ==========================="
curl -s -o "${MINA_CONFIG_FILE}" "https://raw.githubusercontent.com/MinaProtocol/mina/${MINA_COMMIT}/genesis_ledgers/${MINA_NETWORK}.json"

./docker-start.sh $@
