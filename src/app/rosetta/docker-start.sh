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
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=/data/.mina-config}"
export MINA_CLIENT_TRUSTLIST=${MINA_CLIENT_TRUSTLIST:=}
export PEER_LIST_URL=https://storage.googleapis.com/seed-lists/${MINA_NETWORK}_seeds.txt
# Allows configuring the port that each service runs on.
# To connect to a network, the MINA_DAEMON_PORT needs to be publicly accessible.
# To interact with rosetta, use MINA_ROSETTA_PORT
export MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=10101}
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
export MINA_ROSETTA_PG_DATA_INTERVAL=${MINA_ROSETTA_PG_DATA_INTERVAL:=30}
export MINA_ROSETTA_MAX_DB_POOL_SIZE=${MINA_ROSETTA_MAX_DB_POOL_SIZE:=80}
export LOG_LEVEL="${LOG_LEVEL:=Debug}"
DEFAULT_FLAGS="--config-dir ${MINA_CONFIG_DIR} --peer-list-url ${PEER_LIST_URL} --external-port ${MINA_DAEMON_PORT} --rest-port ${MINA_GRAPHQL_PORT} -archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} -insecure-rest-server --log-level ${LOG_LEVEL} --log-json"
export MINA_FLAGS=${MINA_FLAGS:=$DEFAULT_FLAGS}
# Postgres database connection string and related variables
POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive_balances_migrated}
POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}
DUMP_TIME=${DUMP_TIME:=0000}

# Postgres
echo "========================= INITIALIZING POSTGRESQL ==========================="
./init-db.sh ${MINA_NETWORK} ${POSTGRES_DBNAME} ${POSTGRES_USERNAME} ${POSTGRES_DATA_DIR} ${DUMP_TIME}

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
echo "Removing daemon lockfile ${MINA_CONFIG_DIR}/.mina-lock"
rm -f "${MINA_CONFIG_DIR}/.mina-lock"
echo "========================= STARTING DAEMON connected to ${MINA_NETWORK^^} with GRAPQL on PORT ${MINA_GRAPHQL_PORT}==========================="
echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"
mina${MINA_SUFFIX} daemon \
  --config-file ${MINA_CONFIG_FILE} \
  ${MINA_FLAGS} $@ &
MINA_DAEMON_PID=$!

# wait for it to settle
sleep 30

echo "========================= POPULATING MISSING BLOCKS ==========================="
./download-missing-blocks.sh ${MINA_NETWORK} ${POSTGRES_DBNAME} ${POSTGRES_USERNAME} &


if ! kill -0 "${MINA_DAEMON_PID}"; then
  echo "[FATAL] Mina daemon failed to start, exiting docker-start.sh"
  exit 1
fi

wait -n < <(jobs -p)
