#!/bin/bash

set -eou pipefail

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')

function cleanup
{
  echo "========================= CLEANING UP ==========================="
  echo "Stopping mina daemon and waiting 30 seconds"
  mina client stop-daemon && sleep 30
  echo "Killing archive node"
  pkill 'mina-archive' || true
  echo "Killing mina daemon"
  pkill 'mina' || true
  echo "Killing rosetta api"
  pkill 'mina-rosetta' || true
  echo "Stopping postgres cluster"
  pg_ctlcluster ${POSTGRES_VERSION} main stop
  exit
}

trap cleanup TERM
trap cleanup INT
trap cleanup EXIT

# Setup and export useful variables/defaults
export MINA_PRIVKEY_PASS=""
export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
export MINA_CONFIG_FILE=${MINA_CONFIG_FILE:=/genesis_ledgers/mainnet.json}
export PEER_LIST_URL=${PEER_LIST_URL:=https://storage.googleapis.com/seed-lists/mainnet_seeds.txt}
# Allows configuring the port that each service runs on.
# To connect to a network, the MINA_DAEMON_PORT needs to be publicly accessible.
# To interact with rosetta, use MINA_ROSETTA_PORT
export MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=10101}
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
export LOG_LEVEL="${LOG_LEVEL:=Debug}"
DEFAULT_FLAGS="--peer-list-url ${PEER_LIST_URL} --external-port ${MINA_DAEMON_PORT} --rest-port ${MINA_GRAPHQL_PORT} -archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} -insecure-rest-server --log-level ${LOG_LEVEL} --log-json"
export MINA_FLAGS=${MINA_FLAGS:=$DEFAULT_FLAGS}
export PK=${MINA_PK:=B62qiZfzW27eavtPrnF6DeDSAKEjXuGFdkouC3T5STRa6rrYLiDUP2p}
# Postgres database connection string. Override PG_CONN to connect to a more permanent external database.
PG_CONN="${PG_CONN:=postgres://pguser:pguser@127.0.0.1:5432/archive}"

# Postgres
echo "========================= STARTING POSTGRESQL ==========================="
pg_ctlcluster ${POSTGRES_VERSION} main start

# wait for it to settle
sleep 15

echo "========================= POPULATING POSTGRESQL ==========================="
DATE="$(date -Idate)"
curl https://storage.googleapis.com/mina-archive-dumps/archive-dump-${DATE}_0000.sql.tar.gz" -o o1labs-archive-dump.tar.gz
tar -xvf o1labs-archive-dump.tar.gz
# It would help to know the block height of this dump in addition to the date
psql -f archive-dump-$DATE.sql "${PG_CONN}"

# Wait until there is a block missing
until [[ "$PARENT" != "3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d" ]] ; do
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
  sleep 5
done

# Continue until no more blocks are missing
# 3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d is the parent hash of the genesis block
until [[ "$PARENT" == "3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d" ]] ; do
  # It would help to get this from the blocks auditor output instead of minaexplorer
  HEIGHT="$(curl -s https://api.minaexplorer.com/blocks/$PARENT | jq -rs .[0].block.blockHeight)"
  echo "Downloading $PARENT block at height $HEIGHT"
  FILE="mainnet-${HEIGHT}-${PARENT}.json"
  curl -sO https://storage.googleapis.com/mina_network_block_data/$FILE
  mina-archive-blocks --precomputed --archive-uri $PG_CONN $FILE | jq -rs .[-1].message
  rm $FILE # Clean up the block file
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
done

# Rosetta
echo "========================= STARTING ROSETTA API on PORT ${MINA_ROSETTA_PORT} ==========================="
mina-rosetta \
  --archive-uri "${PG_CONN}" \
  --graphql-uri http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --port ${MINA_ROSETTA_PORT} &

# wait for it to settle
sleep 3

# Archive
echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
mina-archive run \
  --postgres-uri "${PG_CONN}" \
  --config-file ${MINA_CONFIG_FILE} \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --server-port ${MINA_ARCHIVE_PORT} &

# wait for it to settle
sleep 6

# Daemon
# Use MINA_CONFIG_FILE=/genesis_ledgers/mainnet.json to run on mainnet
echo "========================= STARTING DAEMON connected to MAINNET with GRAPQL on PORT ${MINA_GRAPHQL_PORT}==========================="
echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"
mina daemon \
  --config-file ${MINA_CONFIG_FILE} \
  ${MINA_FLAGS} $@ &

# wait for a signal
sleep infinity
