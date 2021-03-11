#!/bin/bash

set -e

CONFIG_TEMPLATE=${CONFIG_TEMPLATE:-/daemon.json.template}
export MINA_CONFIG_FILE=${MINA_CONFIG_FILE:-/root/.mina-config/daemon.json}
export CODA_CONFIG_FILE=$MINA_CONFIG_FILE
export PK=${PK:-B62qiZfzW27eavtPrnF6DeDSAKEjXuGFdkouC3T5STRa6rrYLiDUP2p}
export MINA_CONFIG_DIR=${MINA_CONFIG_DIR:-/root/.mina-config}
export CODA_TIME_OFFSET=0
export MINA_TIME_OFFSET=0
export CODA_PRIVKEY_PASS=""
export MINA_PRIVKEY_PASS=""

if [ -z "$GENESIS_STATE_TIMESTAMP" ]; then
   export GENESIS_STATE_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi

echo "Genesis State Timestamp for this run is: ${GENESIS_STATE_TIMESTAMP}"

echo "Rewriting config file from template ${CONFIG_TEMPLATE} to ${MINA_CONFIG_FILE}"
envsubst < ${CONFIG_TEMPLATE} > ${MINA_CONFIG_FILE}
echo "Contents of config file ${MINA_CONFIG_FILE}:"
cat "${MINA_CONFIG_FILE}"
echo

exec mina daemon --generate-genesis-proof true --seed --demo-mode --config-dir ${MINA_CONFIG_DIR} --block-producer-pubkey ${PK} --run-snark-worker ${PK} -insecure-rest-server $@
