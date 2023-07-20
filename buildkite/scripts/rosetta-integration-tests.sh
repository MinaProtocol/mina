#!/bin/bash

# These tests use the mina-dev binary, as rosetta-cli assumes we use a testnet.
# See https://github.com/coinbase/rosetta-sdk-go/blob/master/keys/signer_pallas.go#L222

set -eox pipefail

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
export MINA_SNARKYJS_VERSION=${MINA_SNARKYJS_VERSION:=main}

# Nodejs variables
export NVM_VERSION=0.39.3
export NODE_VERSION=18

# zkApps variables
export ZKAPP_PATH=$HOME/zkapps

echo "=========================== INSTALLING NPM ==========================="
curl -so- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash &>/dev/null
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH
npm install --no-progress --global zkapp-cli

# Debug on CI
which zk
perl -i -p -e "s~await sh('npm run build --silent');~await sh('npm run build');~g" ~/.npm-global/lib/node_modules/zkapp-cli/src/lib/deploy.js

# Rosetta CLI variables
# Files from ROSETTA_CLI_CONFIG_FILES will be read from
# ROSETTA_CONFIGURATION_INPUT_DIR and some placeholders will be
# substituted.
ROSETTA_CONFIGURATION_INPUT_DIR=${ROSETTA_CONFIGURATION_INPUT_DIR:=/rosetta/rosetta-cli-config}
ROSETTA_CLI_CONFIG_FILES=${ROSETTA_CLI_CONFIG_FILES:="config.json mina.ros"}
ROSETTA_CLI_MAIN_CONFIG_FILE=${ROSETTA_CLI_MAIN_CONFIG_FILE:="config.json"}

# Frequency (in seconds) at which payment operations will be sent
TRANSACTION_FREQUENCY=60

# Fetch zkApps
curl -Ls https://github.com/MinaProtocol/rosetta-integration-test-zkapps/tarball/$MINA_SNARKYJS_VERSION | tar xz -C /tmp
mv /tmp/MinaProtocol-rosetta-integration-test-zkapps-* $ZKAPP_PATH

# Libp2p Keypair
echo "=========================== GENERATING KEYPAIR IN ${MINA_LIBP2P_KEYPAIR_PATH} ==========================="
mina-dev libp2p generate-keypair -privkey-path $MINA_LIBP2P_KEYPAIR_PATH

# Configuration
echo "=========================== GENERATING GENESIS LEDGER FOR ${MINA_NETWORK} ==========================="
mkdir -p $MINA_KEYS_PATH
mina-dev advanced generate-keypair --privkey-path $MINA_KEYS_PATH/block-producer.key
mina-dev advanced generate-keypair --privkey-path $MINA_KEYS_PATH/snark-producer.key
chmod -R 0700 $MINA_KEYS_PATH
BLOCK_PRODUCER_PK=$(cat $MINA_KEYS_PATH/block-producer.key.pub)
SNARK_PRODUCER_PK=$(cat $MINA_KEYS_PATH/snark-producer.key.pub)

mkdir -p $MINA_CONFIG_DIR/wallets/store
cp $MINA_KEYS_PATH/block-producer.key $MINA_CONFIG_DIR/wallets/store/$BLOCK_PRODUCER_PK
CURRENT_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")
cat <<EOF >"$MINA_CONFIG_FILE"
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
for zkapp_path in ${ZKAPP_PATH}/*/; do
  zkapp_path=${zkapp_path%/}
  zkapp=$(basename $zkapp_path)
  mina-dev advanced generate-keypair --privkey-path ${MINA_KEYS_PATH}/zkapp-${zkapp}.key
  zkapp_pk=$(cat $MINA_KEYS_PATH/zkapp-${zkapp}.key.pub)
  line="[{ \"pk\": \"${zkapp_pk}\", \"balance\": \"10000\", \"delegate\": null, \"sk\": null }]"
  jq ".ledger.accounts |= . + ${line}" $MINA_CONFIG_FILE >${MINA_CONFIG_FILE}.tmp
  mv ${MINA_CONFIG_FILE}.tmp $MINA_CONFIG_FILE
done
cat $MINA_CONFIG_FILE | jq .

# Substitute placeholders in rosetta-cli configuration
ROSETTA_CONFIGURATION_OUTPUT_DIR=/tmp/rosetta-cli-config
mkdir -p "$ROSETTA_CONFIGURATION_OUTPUT_DIR"
ROSETTA_CONFIGURATION_FILE="${ROSETTA_CONFIGURATION_OUTPUT_DIR}/${ROSETTA_CLI_MAIN_CONFIG_FILE}"
BLOCK_PRODUCER_PRIVKEY=$(mina-ocaml-signer hex-of-private-key-file --private-key-path "$MINA_KEYS_PATH/block-producer.key")
for config_file in $ROSETTA_CLI_CONFIG_FILES; do
  sed -e "s/PLACEHOLDER_PREFUNDED_PRIVKEY/${BLOCK_PRODUCER_PRIVKEY}/" \
    -e "s/PLACEHOLDER_PREFUNDED_ADDRESS/${BLOCK_PRODUCER_PK}/" \
    -e "s/PLACEHOLDER_ROSETTA_OFFLINE_PORT/${MINA_ROSETTA_OFFLINE_PORT}/" \
    -e "s/PLACEHOLDER_ROSETTA_ONLINE_PORT/${MINA_ROSETTA_ONLINE_PORT}/" \
    "$ROSETTA_CONFIGURATION_INPUT_DIR/$config_file" >"$ROSETTA_CONFIGURATION_OUTPUT_DIR/$config_file"
done

# Import Genesis Accounts
echo "==================== IMPORTING GENESIS ACCOUNTS ======================"
mina-dev accounts import --privkey-path $MINA_KEYS_PATH/block-producer.key --config-directory $MINA_CONFIG_DIR
mina-dev accounts import --privkey-path $MINA_KEYS_PATH/snark-producer.key --config-directory $MINA_CONFIG_DIR
for zkapp_path in ${ZKAPP_PATH}/*/; do
  zkapp_path=${zkapp_path%/}
  zkapp=$(basename $zkapp_path)
  mina-dev accounts import --privkey-path $MINA_KEYS_PATH/zkapp-${zkapp}.key --config-directory $MINA_CONFIG_DIR
done

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
ports=($MINA_ROSETTA_ONLINE_PORT $MINA_ROSETTA_OFFLINE_PORT)
for port in ${ports[*]}; do
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
mina-dev daemon \
  --archive-address 127.0.0.1:${MINA_ARCHIVE_PORT} \
  --background \
  --block-producer-pubkey "$BLOCK_PRODUCER_PK" \
  --config-directory ${MINA_CONFIG_DIR} \
  --config-file ${MINA_CONFIG_FILE} \
  --libp2p-keypair ${MINA_LIBP2P_KEYPAIR_PATH} \
  --log-level ${LOG_LEVEL} \
  --proof-level none \
  --rest-port ${MINA_GRAPHQL_PORT} \
  --run-snark-worker "$SNARK_PRODUCER_PK" \
  --seed \
  --demo-mode

echo "========================= WAITING FOR THE DAEMON TO SYNC ==========================="
daemon_status="Pending"
retries_left=20
until [ $daemon_status == "Synced" ]; do
  [[ $retries_left -eq 0 ]] && echo "Unable to Sync the Daemon" && exit 1 || ((retries_left--))
  sleep 15
  daemon_status=$(mina-dev client status --json | jq -r .sync_status 2>/dev/null || echo "Pending")
  echo "Daemon Status: ${daemon_status}"
done

# Unlock Genesis Accounts
echo "==================== UNLOCKING GENESIS ACCOUNTS ======================"
mina-dev accounts unlock --public-key $BLOCK_PRODUCER_PK
mina-dev accounts unlock --public-key $SNARK_PRODUCER_PK

# Start sending payments
send_payments() {
  mina-dev client send-payment -rest-server http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql -amount 1 -nonce 0 -receiver $BLOCK_PRODUCER_PK -sender $BLOCK_PRODUCER_PK
  while true; do
    sleep $TRANSACTION_FREQUENCY
    mina-dev client send-payment -rest-server http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql -amount 1 -receiver $BLOCK_PRODUCER_PK -sender $BLOCK_PRODUCER_PK
  done
}
send_payments &

# Deploy zkApps
echo "==================== DEPLOYING ZKAPPS ======================"
deploy_txs=()
for zkapp_path in ${ZKAPP_PATH}/*/; do
  zkapp_path=${zkapp_path%/}
  zkapp=$(basename $zkapp_path)
  echo "Deploying ${zkapp}..."

  zkapp_pk=$(cat ${MINA_KEYS_PATH}/zkapp-${zkapp}.key.pub)
  zkapp_privkey=$(mina-dev advanced dump-keypair --privkey-path "${MINA_KEYS_PATH}/zkapp-${zkapp}.key" | sed -ne "s/Private key: //p")

  mina-dev accounts unlock --public-key $zkapp_pk

  mkdir -p ${zkapp_path}/keys
  echo -e "{\n    \"privateKey\": \"${zkapp_privkey}\",\n    \"publicKey\": \"${zkapp_pk}\"\n}" >"${zkapp_path}/keys/sandbox.json"

  cat <<EOF >"${zkapp_path}/config.json"
{
  "version": 1,
  "networks": {
    "sandbox": {
      "url": "http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql",
      "keyPath": "keys/sandbox.json",
      "fee": "1"
    }
  }
}
EOF
  cd "$zkapp_path"
  # npm install --no-progress ${OLDPWD}/src/lib/snarkyjs --no-audit
  npm ci
  zk deploy sandbox -y
  txn=$(zk deploy sandbox -y | sed -ne "s/https:\/\/berkeley.minaexplorer.com\/transaction\///p")
  deploy_txs+=txn
  cd -
  echo "Done."
done

# TODO: wait until all zkApps deploy txns are included in a block

next_block_time=$(mina-dev client status --json | jq '.next_block_production.timing[1].time' | tr -d '"')
curr_time=$(date +%s%N | cut -b1-13)
sleep_time=$((($next_block_time - $curr_time) / 1000))
echo "Sleeping for ${sleep_time}s until next block is created..."
sleep ${sleep_time}

# Start calling zkApp methods
echo "==================== INTERACTING WITH ZKAPPS ======================"
RECEIVER_PK=$BLOCK_PRODUCER_PK
for zkapp_path in ${ZKAPP_PATH}/*/; do
  zkapp_path=${zkapp_path%/}
  zkapp=$(basename $zkapp_path)
  echo "Interacting with ${zkapp}..."

  cd "$zkapp_path"
  npm run build
  ./interact.sh sandbox
  cd -
  echo "Done."
done

next_block_time=$(mina-dev client status --json | jq '.next_block_production.timing[1].time' | tr -d '"')
curr_time=$(date +%s%N | cut -b1-13)
sleep_time=$((($next_block_time - $curr_time) / 1000))
echo "Sleeping for ${sleep_time}s until next block is created..."
sleep ${sleep_time}

# Mina Rosetta Checks (spec construction data perf)
echo "============ ROSETTA CLI: VALIDATE CONF FILE ${ROSETTA_CONFIGURATION_FILE} =============="
rosetta-cli configuration:validate ${ROSETTA_CONFIGURATION_FILE}

echo "========================= ROSETTA CLI: CHECK:SPEC ==========================="
rosetta-cli check:spec --all --configuration-file ${ROSETTA_CONFIGURATION_FILE}

echo "========================= ROSETTA CLI: CHECK:CONSTRUCTION ==========================="
rosetta-cli check:construction --configuration-file ${ROSETTA_CONFIGURATION_FILE}

echo "========================= ROSETTA CLI: CHECK:DATA ==========================="
rosetta-cli check:data --configuration-file ${ROSETTA_CONFIGURATION_FILE}

echo "========================= ROSETTA CLI: CHECK:PERF ==========================="
echo "rosetta-cli check:perf" # Will run this command when tests are fully implemented
