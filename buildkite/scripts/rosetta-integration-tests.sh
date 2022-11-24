#!/bin/bash

set -eo pipefail

export MINA_NETWORK=${MINA_NETWORK:=berkeley}
export LOG_LEVEL="${LOG_LEVEL:=Info}"
export MINA_SUFFIX=${MINA_SUFFIX:='-dev'}

# Postgres database connection string and related variables
export POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
export POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive}
export POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
export PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}
export DUMP_TIME=${DUMP_TIME:=0000}

# Mina Archive variables
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}

# Mina Rosetta variables
export MINA_ROSETTA_ONLINE_PORT=${MINA_ROSETTA_ONLINE_PORT:=3087}
export MINA_ROSETTA_OFFLINE_PORT=${MINA_ROSETTA_OFFLINE_PORT:=3088}
export MINA_ROSETTA_PG_DATA_INTERVAL=${MINA_ROSETTA_PG_DATA_INTERVAL:=30}
export MINA_ROSETTA_MAX_DB_POOL_SIZE=${MINA_ROSETTA_MAX_DB_POOL_SIZE:=80}

# Mina Daemon variables
export MINA_LIBP2P_KEYPAIR_PATH="${MINA_LIBP2P_KEYPAIR_PATH:=$HOME/libp2p-keypair}"
export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
export MINA_COMMIT="${MINA_COMMIT:=0b63498e271575dbffe2b31f3ab8be293490b1ac}" #https://github.com/MinaProtocol/mina/discussions/12217
export MINA_LIBP2P_PASS=${MINA_LIBP2P_PASS:=''}
export MINA_CONFIG_FILE=$HOME/${MINA_NETWORK}.json
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=$HOME/.mina-config}"
export PEER_LIST_URL=https://storage.googleapis.com/seed-lists/${MINA_NETWORK}_seeds.txt
export MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=10101}
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}

# Rosetta CLI variables
export ROSETTA_CONFIGURATION_FILE=${ROSETTA_CONFIGURATION_FILE:=/rosetta/rosetta-cli-config/config.json}

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
    --log-level ${LOG_LEVEL} \
    --port ${port} &
    sleep 5
done

# Configuration
echo "=========================== DOWNLOADING CONFIGURATION FOR ${MINA_NETWORK} ==========================="
curl -s -o "${MINA_CONFIG_FILE}" "https://raw.githubusercontent.com/MinaProtocol/mina/${MINA_COMMIT}/genesis_ledgers/${MINA_NETWORK}.json"

# Mina Archive
echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
mina-archive run \
  --postgres-uri "${PG_CONN}" \
  --config-file ${MINA_CONFIG_FILE} \
  --log-level ${LOG_LEVEL} \
  --server-port ${MINA_ARCHIVE_PORT} &
sleep 5

# Libp2p Keypair
echo "=========================== GENERATING KEYPAIR IN ${MINA_LIBP2P_KEYPAIR_PATH} ==========================="
mina libp2p generate-keypair -privkey-path ${MINA_LIBP2P_KEYPAIR_PATH}

# Daemon
echo "========================= STARTING DAEMON connected to ${MINA_NETWORK} ==========================="
mina$MINA_SUFFIX daemon \
  --libp2p-keypair ${MINA_LIBP2P_KEYPAIR_PATH} \
  --archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} \
  --peer-list-url ${PEER_LIST_URL} \
  --external-port ${MINA_DAEMON_PORT} \
  --rest-port ${MINA_GRAPHQL_PORT} \
  --log-level ${LOG_LEVEL} \
  --config-file ${MINA_CONFIG_FILE} \
  --background

# wait for it to settle
sleep 30

# echo "========================= POPULATING MISSING BLOCKS ==========================="
./download-missing-blocks.sh ${MINA_NETWORK} ${POSTGRES_DBNAME} ${POSTGRES_USERNAME} &

echo "========================= WAITING FOR THE DAEMON TO SYNC ==========================="
status="Pending"
max_retries=10
until [ $status == "Synced" ]
do
  [[ $max_retries -eq 0 ]] && echo "Unable to Sync the Daemon" && exit 1  || ((max_retries--))
  sleep 60
  status=$(mina client status --json | jq -r .sync_status 2> /dev/null || echo "Pending")
  echo "Daemon Status: ${status}"
done

# Mina Rosetta Checks (spec construction data perf)
echo "============ ROSETTA CLI: VALIDATE CONF FILE ${ROSETTA_CONFIGURATION_FILE} =============="
rosetta-cli configuration:validate ${ROSETTA_CONFIGURATION_FILE}

echo "========================= ROSETTA CLI: CHECK:SPEC ==========================="
rosetta-cli check:spec --all

echo "========================= ROSETTA CLI: CHECK:CONSTRUCTION ==========================="
echo "rosetta-cli check:construction" # Will run this command when tests are fully implemented

echo "========================= ROSETTA CLI: CHECK:DATA ==========================="
echo "rosetta-cli check:data" # Will run this command when tests are fully implemented

echo "========================= ROSETTA CLI: CHECK:PERF ==========================="
echo "rosetta-cli check:perf" # Will run this command when tests are fully implemented
