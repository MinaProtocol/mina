#!/bin/bash

set -eo pipefail

export MINA_NETWORK=${MINA_NETWORK:=sandbox}
export LOG_LEVEL="${LOG_LEVEL:=Info}"

# Postgres database connection string and related variables
export POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')
export POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
export POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive}
export POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
export PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

# Mina Archive variables
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ARCHIVE_SQL_SCHEMA_PATH=${MINA_ARCHIVE_SQL_SCHEMA_PATH:=/archive/create_schema.sql}

# Mina Rosetta variables
export MINA_ROSETTA_ONLINE_PORT=${MINA_ROSETTA_ONLINE_PORT:=3087}
export MINA_ROSETTA_OFFLINE_PORT=${MINA_ROSETTA_OFFLINE_PORT:=3088}
export MINA_ROSETTA_PG_DATA_INTERVAL=${MINA_ROSETTA_PG_DATA_INTERVAL:=30}
export MINA_ROSETTA_MAX_DB_POOL_SIZE=${MINA_ROSETTA_MAX_DB_POOL_SIZE:=128}

# Mina Daemon variables
export MINA_LIBP2P_KEYPAIR_PATH="${MINA_LIBP2P_KEYPAIR_PATH:=$HOME/libp2p-keypair}"
export MINA_KEYS_PATH="${MINA_KEYS_PATH:=$HOME/keys}"
export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
export MINA_LIBP2P_PASS=${MINA_LIBP2P_PASS:=''}
export MINA_PRIVKEY_PASS=${MINA_PRIVKEY_PASS:=''}
export MINA_CONFIG_FILE=$HOME/${MINA_NETWORK}.json
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=$HOME/.mina-config}"
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}

# Rosetta CLI variables
export ROSETTA_CONFIGURATION_FILE=${ROSETTA_CONFIGURATION_FILE:=/rosetta/rosetta-cli-config/config.json}

# Libp2p Keypair
echo "=========================== GENERATING KEYPAIR IN ${MINA_LIBP2P_KEYPAIR_PATH} ==========================="
mina libp2p generate-keypair -privkey-path $MINA_LIBP2P_KEYPAIR_PATH

# Configuration
echo "=========================== GENERATING GENESIS LEDGER FOR ${MINA_NETWORK} ==========================="
mkdir -p $MINA_KEYS_PATH
mina advanced generate-keypair --privkey-path $MINA_KEYS_PATH/block-producer.key
mina advanced generate-keypair --privkey-path $MINA_KEYS_PATH/snark-producer.key
chmod -R 0700 $MINA_KEYS_PATH
BLOCK_PRODUCER_PK=$(cat $MINA_KEYS_PATH/block-producer.key.pub)
SNARK_PRODUCER_PK=$(cat $MINA_KEYS_PATH/snark-producer.key.pub)

mkdir -p $MINA_CONFIG_DIR/wallets/store
cp $MINA_KEYS_PATH/block-producer.key $MINA_CONFIG_DIR/wallets/store/$BLOCK_PRODUCER_PK
CURRENT_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")
cat <<EOF > "$MINA_CONFIG_FILE"
{
  "genesis": { "genesis_state_timestamp": "$CURRENT_TIME" },
  "proof": { "block_window_duration_ms": 20000 },
  "ledger": {
    "name": "${MINA_NETWORK}",
    "accounts": [
      { "pk": "${BLOCK_PRODUCER_PK}", "balance": "1000", "delegate": null, "sk": null },
      { "pk": "${SNARK_PRODUCER_PK}", "balance": "2000", "delegate": "${BLOCK_PRODUCER_PK}", "sk": null }
    ]
  }
}
EOF
cat $MINA_CONFIG_FILE | jq .

# Import Genesis Accounts
echo "==================== IMPORTING GENESIS ACCOUNTS ======================"
mina accounts import --privkey-path $MINA_KEYS_PATH/block-producer.key --config-directory $MINA_CONFIG_DIR
mina accounts import --privkey-path $MINA_KEYS_PATH/snark-producer.key --config-directory $MINA_CONFIG_DIR

# Postgres
echo "========================= INITIALIZING POSTGRESQL ==========================="
pg_ctlcluster ${POSTGRES_VERSION} main start
pg_dropcluster --stop ${POSTGRES_VERSION} main
pg_createcluster --start -d ${POSTGRES_DATA_DIR} --createclusterconf /rosetta/postgresql.conf ${POSTGRES_VERSION} main
sudo -u postgres psql --command "CREATE USER ${POSTGRES_USERNAME} WITH SUPERUSER PASSWORD '${POSTGRES_USERNAME}';"
sudo -u postgres createdb -O ${POSTGRES_USERNAME} ${POSTGRES_DBNAME}
psql -f "${MINA_ARCHIVE_SQL_SCHEMA_PATH}" "${PG_CONN}"

# Mina Rosetta
echo "=========================== STARTING ROSETTA API ONLINE AND OFFLINE INSTANCES ==========================="
ports=( $MINA_ROSETTA_ONLINE_PORT $MINA_ROSETTA_OFFLINE_PORT )
for port in ${ports[*]}
do
    mina-rosetta \
    --archive-uri "${PG_CONN}" \
    --graphql-uri http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql \
    --log-level ${LOG_LEVEL} \
    --port ${port} &
    sleep 5
done

# Mina Archive
echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
mina-archive run \
  --config-file ${MINA_CONFIG_FILE} \
  --log-level ${LOG_LEVEL} \
  --postgres-uri "${PG_CONN}" \
  --server-port ${MINA_ARCHIVE_PORT} &
sleep 5

# Daemon
echo "========================= STARTING DAEMON connected to ${MINA_NETWORK} ==========================="
mina daemon \
  --archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} \
  --background \
  --block-producer-pubkey "$BLOCK_PRODUCER_PK" \
  --config-file ${MINA_CONFIG_FILE} \
  --libp2p-keypair ${MINA_LIBP2P_KEYPAIR_PATH} \
  --log-level ${LOG_LEVEL} \
  --proof-level none \
  --rest-port ${MINA_GRAPHQL_PORT} \
  --run-snark-worker "$SNARK_PRODUCER_PK" \
  --seed

echo "========================= WAITING FOR THE DAEMON TO SYNC ==========================="
daemon_status="Pending"
retries_left=20
until [ $daemon_status == "Synced" ]
do
  [[ $retries_left -eq 0 ]] && echo "Unable to Sync the Daemon" && exit 1  || ((retries_left--))
  sleep 15
  daemon_status=$(mina client status --json | jq -r .sync_status 2> /dev/null || echo "Pending")
  echo "Daemon Status: ${daemon_status}"
done

# Unlock Genesis Accounts
echo "==================== UNLOCKING GENESIS ACCOUNTS ======================"
mina accounts unlock --public-key $BLOCK_PRODUCER_PK
mina accounts unlock --public-key $SNARK_PRODUCER_PK

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
