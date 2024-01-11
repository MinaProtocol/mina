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
export MINA_LIBP2P_KEYPAIR_PATH="${MINA_LIBP2P_KEYPAIR_PATH:=$HOME/libp2p-keypair}"
export MINA_LIBP2P_PASS=${MINA_LIBP2P_PASS:=''}
export MINA_NETWORK=${MINA_NETWORK:=mainnet}
export MINA_SUFFIX=${MINA_SUFFIX:=}
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=/data/.mina-config}"
export MINA_CLIENT_TRUSTLIST=${MINA_CLIENT_TRUSTLIST:=}
export PEER_LIST_URL=https://storage.googleapis.com/seed-lists/${MINA_NETWORK}_seeds.txt
# Allows configuring the port that each service runs on.
# To interact with rosetta, use MINA_ROSETTA_ONLINE_PORT and MINA_ROSETTA_OFFLINE_PORT
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_ONLINE_PORT=${MINA_ROSETTA_ONLINE_PORT:=3087}
export MINA_ROSETTA_OFFLINE_PORT=${MINA_ROSETTA_OFFLINE_PORT:=3088}
export MINA_ROSETTA_PG_DATA_INTERVAL=${MINA_ROSETTA_PG_DATA_INTERVAL:=30}
export MINA_ROSETTA_MAX_DB_POOL_SIZE=${MINA_ROSETTA_MAX_DB_POOL_SIZE:=80}
export LOG_LEVEL="${LOG_LEVEL:=Debug}"
DEFAULT_FLAGS="--config-dir ${MINA_CONFIG_DIR} --peer-list-url ${PEER_LIST_URL} --rest-port ${MINA_GRAPHQL_PORT} -archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} -insecure-rest-server --log-level ${LOG_LEVEL} --log-json"
export MINA_FLAGS=${MINA_FLAGS:=$DEFAULT_FLAGS}
# Postgres database connection string and related variables
POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive}
POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}
DUMP_TIME=${DUMP_TIME:=0000}

# Postgres
echo "========================= INITIALIZING POSTGRESQL ==========================="
./init-db.sh ${MINA_NETWORK} ${POSTGRES_DBNAME} ${POSTGRES_USERNAME} ${POSTGRES_DATA_DIR} ${DUMP_TIME}

# Mina Rosetta
echo "=========================== STARTING ROSETTA API ONLINE AND OFFLINE INSTANCES ==========================="
ports=( $MINA_ROSETTA_ONLINE_PORT $MINA_ROSETTA_OFFLINE_PORT )
for port in ${ports[*]}
do
    mina-rosetta${MINA_SUFFIX} \
    --archive-uri "${PG_CONN}" \
    --graphql-uri http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql \
    --log-json \
    --log-level ${LOG_LEVEL} \
    --port ${port} &
    sleep 5
done

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

# Libp2p Keypair
echo "=========================== GENERATING KEYPAIR IN ${MINA_LIBP2P_KEYPAIR_PATH} ==========================="
mina libp2p generate-keypair -privkey-path ${MINA_LIBP2P_KEYPAIR_PATH}

# Daemon
echo "Removing daemon lockfile ${MINA_CONFIG_DIR}/.mina-lock"
rm -f "${MINA_CONFIG_DIR}/.mina-lock"
echo "========================= STARTING DAEMON connected to ${MINA_NETWORK^^} with GRAPHQL on PORT ${MINA_GRAPHQL_PORT}==========================="
echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"
mina${MINA_SUFFIX} daemon \
  --libp2p-keypair ${MINA_LIBP2P_KEYPAIR_PATH} \
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
