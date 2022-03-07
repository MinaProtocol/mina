#!/bin/bash

set -eou pipefail

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')

function cleanup
{
  echo "========================= CLEANING UP ==========================="
  echo "Stopping mina daemon and waiting 30 seconds"
  mina client stop-daemon && sleep 30
  echo "Killing mina daemon"
  pkill 'mina' || true
  echo "Killing archive node"
  pkill 'mina-archive' || true
  echo "Killing rosetta api"
  pkill 'mina-rosetta' || true
  echo "Stopping postgres cluster"
  pg_ctlcluster ${POSTGRES_VERSION} main stop
  exit
}

trap cleanup TERM
trap cleanup INT
trap cleanup EXIT


# Allows configuring the port that each service runs on.
# This script does not connect to a network, so MINA_DAEMON_PORT can be kept private.
# To interact with rosetta, use MINA_ROSETTA_PORT.
MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=8301}
MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
LOG_LEVEL=${LOG_LEVEL:=Debug}
PG_CONN=postgres://pguser:pguser@localhost:5432/archive


# ====== Set up demo environment ========
export MINA_PRIVKEY_PASS=${MINA_PRIVKEY_PASS:-""}
export MINA_TIME_OFFSET=0


# Demo keys and config file
echo "Running Mina demo..."
MINA_CONFIG_DIR=${MINA_CONFIG_DIR:-/root/.mina-config}
MINA_CONFIG_FILE="${MINA_CONFIG_DIR}/daemon.json}"

export PK=${PK:-"B62qiZfzW27eavtPrnF6DeDSAKEjXuGFdkouC3T5STRa6rrYLiDUP2p"}
SNARK_PK=${SNARK_PK:-"B62qjnkjj3zDxhEfxbn1qZhUawVeLsUr2GCzEz8m1MDztiBouNsiMUL"}

CONFIG_TEMPLATE=${CONFIG_TEMPLATE:-/genesis_ledgers/daemon.json.template}

set +u
if [ -z "$GENESIS_STATE_TIMESTAMP" ]; then
  export GENESIS_STATE_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi
set -u
echo "Genesis State Timestamp for this run is: ${GENESIS_STATE_TIMESTAMP}"

echo "Rewriting config file from template ${CONFIG_TEMPLATE} to ${MINA_CONFIG_FILE}"
envsubst < ${CONFIG_TEMPLATE} > ${MINA_CONFIG_FILE}

# Start postgres
echo "========================= STARTING POSTGRESQL ==========================="
pg_ctlcluster ${POSTGRES_VERSION} main start

# wait for it to settle
sleep 3

# rosetta
echo "========================= STARTING ROSETTA API on PORT ${MINA_ROSETTA_PORT} ==========================="
mina-rosetta \
  --archive-uri $PG_CONN \
  --graphql-uri "http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql" \
  --log-level "${LOG_LEVEL}" \
  --port "${MINA_ROSETTA_PORT}" &

# wait for it to settle
sleep 3

# archive
echo "========================= STARTING ARCHIVE PROCESS ==========================="
mina-archive run \
  --postgres-uri $PG_CONN \
  --server-port "${MINA_ARCHIVE_PORT}" \
  --log-level "${LOG_LEVEL}" \
  --log-json &

# wait for it to settle
sleep 6

# MINA_CONFIG_DIR is exposed by the dockerfile and contains demo mode essentials
echo "========================= STARTING DAEMON ==========================="
echo "Contents of config file ${MINA_CONFIG_FILE}:"
cat "${MINA_CONFIG_FILE}"
export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
mina daemon \
  --block-producer-pubkey "${PK}" \
  --run-snark-worker "${SNARK_PK}" \
  --config-dir "${MINA_CONFIG_DIR}" \
  --config-file "${MINA_CONFIG_FILE}" \
  --seed \
  --demo-mode \
  --proof-level none \
  --disable-node-status \
  --background \
  --external-port "${MINA_DAEMON_PORT}" \
  --archive-address "127.0.0.1:${MINA_ARCHIVE_PORT}" \
  --rest-port "${MINA_GRAPHQL_PORT}" \
  --insecure-rest-server \
  --log-level "${LOG_LEVEL}" \
  --log-json \
  $@

# Possibly useful flags:
#   Rosetta documentation specifies that /data/ will be a volume mount for various state.
#  -working-dir /data/ \

sleep infinity
