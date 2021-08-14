#!/bin/bash

set -eou pipefail

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')

function cleanup
{
  echo "========================= CLEANING UP ==========================="
  echo "Killing archive.exe"
  kill $(ps aux | egrep '/mina-bin/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing mina.exe"
  kill $(ps aux | egrep '/mina-bin/.*mina.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '/mina-bin/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  echo "Stopping postgres"
  pg_ctlcluster ${POSTGRES_VERSION} main stop
  exit
}

trap cleanup TERM
trap cleanup INT
trap cleanup EXIT

# Setup and export useful variables/defaults
export MINA_PRIVKEY_PASS=""
export MINA_LIBP2P_HELPER_PATH=/mina-bin/libp2p_helper
export MINA_CONFIG_FILE=${MINA_CONFIG_FILE:=/genesis_ledgers/devnet.json}
export PEER_LIST_URL=${PEER_LIST_URL:=https://storage.googleapis.com/seed-lists/devnet_seeds.txt}
# Allows configuring the port that each service runs on.
# To connect to a network, the MINA_DAEMON_PORT needs to be publicly accessible.
# To interact with rosetta, use MINA_ROSETTA_PORT
export MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=10101}
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
export LOG_LEVEL="Debug"
DEFAULT_FLAGS="--peer-list-url ${PEER_LIST_URL} --external-port ${MINA_DAEMON_PORT} --rest-port ${MINA_GRAPHQL_PORT} -archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} -insecure-rest-server --log-level ${LOG_LEVEL} --log-json"
export MINA_FLAGS=${MINA_FLAGS:=$DEFAULT_FLAGS}
export PK=${MINA_PK:=B62qiZfzW27eavtPrnF6DeDSAKEjXuGFdkouC3T5STRa6rrYLiDUP2p}



PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

# Postgres
echo "========================= STARTING POSTGRESQL ==========================="
pg_ctlcluster ${POSTGRES_VERSION} main start

# wait for it to settle
sleep 3

# Archive
echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
/mina-bin/archive/archive.exe run \
  --postgres-uri "${PG_CONN}" \
  --config-file ${MINA_CONFIG_FILE} \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --server-port ${MINA_ARCHIVE_PORT} &

# wait for it to settle
sleep 3

# Daemon
# Use MINA_CONFIG_FILE=/genesis_ledgers/mainnet.json to run on mainnet
echo "========================= STARTING DAEMON with GRAPQL on PORT ${MINA_GRAPHQL_PORT}==========================="
echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"
/mina-bin/cli/src/mina.exe daemon \
    --config-file ${MINA_CONFIG_FILE} \
    ${MINA_FLAGS} $@ &

# wait for it to settle
sleep 3

# Rosetta
echo "========================= STARTING ROSETTA API on PORT ${MINA_ROSETTA_PORT} ==========================="
/mina-bin/rosetta/rosetta.exe \
  --archive-uri "${PG_CONN}" \
  --graphql-uri http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --port ${MINA_ROSETTA_PORT} &

# wait for a signal
sleep infinity
