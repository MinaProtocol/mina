#!/bin/bash

set -eou pipefail

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')

function cleanup
{
  echo "========================= CLEANING UP ==========================="
  echo "Stopping mina daemon and waiting 3 seconds"
  mina client stop-daemon && sleep 3
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
export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
export MINA_NETWORK=${MINA_NETWORK:=mainnet}
export MINA_SUFFIX=${MINA_SUFFIX:=}
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json
export MINA_CLIENT_TRUSTLIST=${MINA_CLIENT_TRUSTLIST}
export PEER_LIST_URL=https://storage.googleapis.com/seed-lists/${MINA_NETWORK}_seeds.txt
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
# Postgres database connection string and related variables
POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive}
POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

# Postgres
echo "========================= STARTING POSTGRESQL ==========================="
./init-db.sh ${POSTGRES_DATA_DIR} ${POSTGRES_DBNAME} ${POSTGRES_USERNAME}

sleep 5

echo "========================= POPULATING POSTGRESQL ==========================="
DATE="$(date -Idate)_0000"
curl "https://storage.googleapis.com/mina-archive-dumps/${MINA_NETWORK}-archive-dump-${DATE}.sql.tar.gz" -o o1labs-archive-dump.tar.gz
tar -xvf o1labs-archive-dump.tar.gz
# It would help to know the block height of this dump in addition to the date
psql -f "${MINA_NETWORK}-archive-dump-${DATE}.sql" "${PG_CONN}"

# Rosetta
echo "========================= STARTING ROSETTA API on PORT ${MINA_ROSETTA_PORT} ==========================="
mina-rosetta${MINA_SUFFIX} \
  --archive-uri "${PG_CONN}" \
  --graphql-uri http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --port ${MINA_ROSETTA_PORT} &

# wait for it to settle
sleep 5

# Archive
echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
mina-archive run \
  --postgres-uri "${PG_CONN}" \
  --config-file ${MINA_CONFIG_FILE} \
  --log-level ${LOG_LEVEL} \
  --log-json \
  --server-port ${MINA_ARCHIVE_PORT} &

# wait for it to settle
sleep 10

# Daemon
echo "========================= STARTING DAEMON connected to ${MINA_NETWORK^^} with GRAPQL on PORT ${MINA_GRAPHQL_PORT}==========================="
echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"
mina${MINA_SUFFIX} daemon \
  --config-file ${MINA_CONFIG_FILE} \
  ${MINA_FLAGS} $@ &

# wait for it to settle
sleep 30

echo "========================= POPULATING MISSING BLOCKS SINCE $DATE ==========================="
# Wait until there is a block missing
PARENT=null
until [[ "$PARENT" != "null" ]] ; do
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
  echo "FINDING PARENT BLOCK HASH: $(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].message)"
  sleep 300 # Wait for the daemon to catchup and start downloading new blocks
done

# Continue until no more blocks are missing
until [[ "$PARENT" == "null" ]] ; do
  PARENT_FILE="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs '.[-1].metadata | "'${MINA_NETWORK}'-\(.parent_height)-\(.parent_hash).json"')"
  echo "Downloading $PARENT_FILE block"
  curl -sO "https://storage.googleapis.com/mina_network_block_data/$PARENT_FILE"
  mina-archive-blocks --precomputed --archive-uri "$PG_CONN" "$PARENT_FILE" | jq -rs '"[BOOTSTRAP] Populated database with old block: \(.[-1].message)"'
  rm "$PARENT_FILE"
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
done

sleep infinity
