#!/usr/bin/env bash
# set -x

# Exit script when commands fail
set -e
# Kill background process when script exits
trap "killall background" EXIT

# ================================================
# Constants

MINA_EXE=_build/default/src/app/cli/src/mina.exe
ARCHIVE_EXE=_build/default/src/app/archive/archive.exe
LOGPROC_EXE=_build/default/src/app/logproc/logproc.exe
ZKAPP_EXE=_build/default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe 

export MINA_PRIVKEY_PASS='naughty blue worm'
export MINA_LIBP2P_PASS="${MINA_PRIVKEY_PASS}"
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

# ================================================
# Inputs (set to default values)

WHALES=2
FISH=1
NODES=1
ARCHIVE=false
LOG_LEVEL="Trace"
FILE_LOG_LEVEL=${LOG_LEVEL}
VALUE_TRANSFERS=false
ZKAPP_TRANSACTIONS=false
RESET=false
UPDATE_GENESIS_TIMESTAMP=false

SNARK_WORKER_FEE=0.01
TRANSACTION_FREQUENCY=10 # in seconds

SEED_START_PORT=3000
ARCHIVE_SERVER_PORT=3086
WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="${USER}"
PG_PASSWD=""
PG_DB="archive"

ARCHIVE_ADDRESS_CLI_ARG=""

# ================================================
# Globals (assigned during execution of script)

LEDGER_FOLDER=""
SNARK_WORKER_PUBKEY=""
NODES_FOLDER=""
CONFIG=""
SEED_PID=""
ARCHIVE_PID=""
WHALE_PIDS=()
FISH_PIDS=()
NODE_PIDS=()

# ================================================
# Helper functions

help() {
  echo "-w  |--whales <#>                 | Number of BP Whale Nodes (bigger stake) to spin-up"
  echo "                                  |   Default: ${WHALES}"
  echo "-f  |--fish <#>                   | Number of BP Fish Nodes (less stake) to spin-up"
  echo "                                  |   Default: ${FISH}"
  echo "-n  |--nodes <#>                  | Nimber of non block-producing nodes to spin-up"
  echo "                                  |   Default: ${NODES}"
  echo "-a  |--archive                    | Whether to run the Archive Node (presence of argument)"
  echo "                                  |   Default: ${ARCHIVE}"
  echo "-sp |--seed-start-port <#>        | Seed Node range start port"
  echo "                                  |   Default: ${SEED_START_PORT}"
  echo "-wp |--whale-start-port <#>       | Whale Nodes range start port"
  echo "                                  |   Default: ${WHALE_START_PORT}"
  echo "-fp |--fish-start-port <#>        | Fish Nodes range start port"
  echo "                                  |   Default: ${FISH_START_PORT}"
  echo "-np |--node-start-port <#>        | Non block-producing Nodes range start port"
  echo "                                  |   Default: ${NODE_START_PORT}"
  echo "-ap |--archive-server-port <#>    | Archive Node server port"
  echo "                                  |   Default: ${ARCHIVE_SERVER_PORT}"
  echo "-ll |--log-level <level>          | Console output logging level"
  echo "                                  |   Default: ${LOG_LEVEL}"
  echo "-fll|--file-log-level <level>     | File output logging level"
  echo "                                  |   Default: ${FILE_LOG_LEVEL}"
  echo "-ph |--pg-host <host>             | PostgreSQL host"
  echo "                                  |   Default: ${PG_HOST}"
  echo "-pp |--pg-port <#>                | PostgreSQL port"
  echo "                                  |   Default: ${PG_PORT}"
  echo "-pu |--pg-user <user>             | PostgreSQL user"
  echo "                                  |   Default: ${PG_USER}"
  echo "-ppw|--pg-passwd <password>       | PostgreSQL password"
  echo "                                  |   Default: <empty_string>"
  echo "-pd |--pg-db <db>                 | PostgreSQL database name"
  echo "                                  |   Default: ${PG_DB}"
  echo "-vt |--value-transfer-txns        | Whether to execute periodic value transfer transactions (presence of argument)"
  echo "                                  |   Default: ${VALUE_TRANSFERS}"
  echo "-zt |--zkapp-transactions         | Whether to execute periodic zkapp transactions (presence of argument)"
  echo "                                  |   Default: ${ZKAPP_TRANSACTIONS}"
  echo "-tf |--transactions-frequency <#> | Frequency of periodic transactions execution (in seconds)"
  echo "                                  |   Default: ${TRANSACTION_FREQUENCY}"
  echo "-sf |--snark-worker-fee <#>       | SNARK Worker fee"
  echo "                                  |   Default: ${SNARK_WORKER_FEE}"
  echo "-r  |--reset                      | Whether to reset the Mina Local Network storage file-system (presence of argument)"
  echo "                                  |   Default: ${RESET}"
  echo "-u  |--update-genesis-timestamp   | Whether to update the Genesis Ledger timestamp (presence of argument)"
  echo "                                  |   Default: ${UPDATE_GENESIS_TIMESTAMP}"
  echo "-h  |--help                       | Displays this help message"
  printf "\n"
  echo "Available logging levels:"
  echo "  Spam, Trace, Debug, Info, Warn, Error, Faulty_peer, Fatal"
  printf "\n"

  exit
}

clean-dir() {
  rm -rf ${1}
  mkdir -p ${1}
}

generate-keypair() {
  ${MINA_EXE} advanced generate-keypair -privkey-path ${1}
}

generate-libp2p-keypair() {
  ${MINA_EXE} libp2p generate-keypair -privkey-path ${1}
}

# Executes the Mina Daemon, exposing all 5 ports in
# sequence starting with provided base port
exec-daemon() {
  BASE_PORT=${1}
  shift
  CLIENT_PORT=${BASE_PORT}
  REST_PORT=$((${BASE_PORT} + 1))
  EXTERNAL_PORT=$((${BASE_PORT} + 2))
  DAEMON_METRICS_PORT=$((${BASE_PORT} + 3))
  LIBP2P_METRICS_PORT=$((${BASE_PORT} + 4))

  exec ${MINA_EXE} daemon \
    -client-port ${CLIENT_PORT} \
    -rest-port ${REST_PORT} \
    -insecure-rest-server \
    -external-port ${EXTERNAL_PORT} \
    -metrics-port ${DAEMON_METRICS_PORT} \
    -libp2p-metrics-port ${LIBP2P_METRICS_PORT} \
    -config-file ${CONFIG} \
    -log-json \
    -log-level ${LOG_LEVEL} \
    -file-log-level ${FILE_LOG_LEVEL} \
    $@
}

# Executes the Archive node
exec-archive-node() {
  exec ${ARCHIVE_EXE} run \
    --config-file ${CONFIG} \
    --log-level ${LOG_LEVEL} \
    --postgres-uri postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB} \
    --server-port ${ARCHIVE_SERVER_PORT} \
    $@
}

# Spawns the Node in background
spawn-node() {
  FOLDER=${1}
  shift
  exec-daemon $@ -config-directory ${FOLDER} &>${FOLDER}/log.txt &
}

# Spawns the Archive Node in background
spawn-archive-node() {
  FOLDER=${1}
  shift
  exec-archive-node $@ &>${FOLDER}/log.txt &
}

# ================================================
# Parse inputs from arguments

for ARG in "$@"; do
  if [[ "${ARG}" == "-h" || "${ARG}" == "--help" ]]; then
    help
  fi
done

while [[ "$#" -gt 0 ]]; do
  case ${1} in
  -w | --whales)
    WHALES="${2}"
    shift
    ;;
  -f | --fish)
    FISH="${2}"
    shift
    ;;
  -n | --nodes)
    NODES="${2}"
    shift
    ;;
  -a | --archive) ARCHIVE=true ;;
  -sp | --seed-start-port)
    SEED_START_PORT="${2}"
    shift
    ;;
  -wp | --whale-start-port)
    WHALE_START_PORT="${2}"
    shift
    ;;
  -fp | --fish-start-port)
    FISH_START_PORT="${2}"
    shift
    ;;
  -np | --node-start-port)
    NODE_START_PORT="${2}"
    shift
    ;;
  -ap | --archive-server-port)
    ARCHIVE_SERVER_PORT="${2}"
    shift
    ;;
  -ll | --log-level)
    LOG_LEVEL="${2}"
    shift
    ;;
  -fll | --file-log-level)
    FILE_LOG_LEVEL="${2}"
    shift
    ;;
  -ph | --pg-host)
    PG_HOST="${2}"
    shift
    ;;
  -pp | --pg-port)
    PG_PORT="${2}"
    shift
    ;;
  -pu | --pg-user)
    PG_USER="${2}"
    shift
    ;;
  -ppw | --pg-passwd)
    PG_PASSWD="${2}"
    shift
    ;;
  -pd | --pg-db)
    PG_DB="${2}"
    shift
    ;;
  -vt | --value-transfer-txns) VALUE_TRANSFERS=true ;;
  -zt | --zkapp-transactions) ZKAPP_TRANSACTIONS=true ;;
  -tf | --transactions-frequency)
    TRANSACTION_FREQUENCY="${2}"
    shift
    ;;
  -sf | --snark-worker-fee)
    SNARK_WORKER_FEE="${2}"
    shift
    ;;
  -r | --reset) RESET=true ;;
  -u | --update-genesis-timestamp) UPDATE_GENESIS_TIMESTAMP=true ;;
  *)
    echo "Unknown parameter passed: ${1}"

    exit 1
    ;;
  esac
  shift
done

printf "\n"
echo "================================"
printf "\n"
echo "███╗   ███╗██╗███╗   ██╗ █████╗ "
echo "████╗ ████║██║████╗  ██║██╔══██╗"
echo "██╔████╔██║██║██╔██╗ ██║███████║"
echo "██║╚██╔╝██║██║██║╚██╗██║██╔══██║"
echo "██║ ╚═╝ ██║██║██║ ╚████║██║  ██║"
echo "╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
echo "      .:: LOCAL NETWORK ::.     "
printf "\n"
echo "================================"
printf "\n"

# ================================================
# Check the PostgreSQL configuration required
# for Archive Node operation

if ${ARCHIVE}; then
  echo "Archive Node spawning is enabled, we need to do the PostgreSQL communication check."
  echo "In case of any issues please make sure that you:"
  echo -e "\t1. Run the PostgreSQL server;"
  echo -e "\t2. Have configured the PostgreSQL access;"
  echo -e "\t3. Have configured the PostgreSQL 'database';"
  echo -e "\t\t3.1. psql -c 'CREATE DATABASE ${PG_DB}'"
  echo -e "\t\t3.2. psql ${PG_DB} < ./src/app/archive/create_schema.sql'"
  echo -e "\t4. Passed correct PostgreSQL credentials as CLI arguments to this script."
  printf "\n"
  echo "================================"
  printf "\n"

  psql postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB} -c "SELECT * FROM user_commands;" &>/dev/null

  ARCHIVE_ADDRESS_CLI_ARG="-archive-address ${ARCHIVE_SERVER_PORT}"
fi

# ================================================
# Configure the Seed Peer ID

SEED_PEER_ID="/ip4/127.0.0.1/tcp/$((${SEED_START_PORT} + 2))/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

# ================================================
#

if ${VALUE_TRANSFERS}; then
  if [ "${FISH}" -eq "0" ]; then
    echo "Sending transactions requires at least one 'Fish' node running!"
    printf "\n"

    exit 1
  fi
fi

if ${ZKAPP_TRANSACTIONS}; then
  if [ "${WHALES}" -lt "2" ] || [ "${FISH}" -eq "0" ]; then
    echo "Send zkApp transactions requires at least one 'Fish' node running and at least 2 whale accounts acting as the fee payer and sender account!"
    printf "\n"

    exit 1
  fi
fi

echo "Starting the Network with:"
echo -e "\t1 seed"

if ${ARCHIVE}; then
  echo -e "\t1 archive"
fi

echo -e "\t${WHALES} whales"
echo -e "\t${FISH} fish"
echo -e "\t${NODES} non block-producing nodes"
echo -e "\tSending transactions: ${VALUE_TRANSFERS}"
echo -e "\tSending zkApp transactions: ${ZKAPP_TRANSACTIONS}"
printf "\n"
echo "================================"
printf "\n"

# ================================================
# Create the Genesis Ledger

LEDGER_FOLDER="${HOME}/.mina-network/mina-local-network-${WHALES}-${FISH}-${NODES}"

if ${RESET}; then
  rm -rf ${LEDGER_FOLDER}
fi

if [ ! -d "${LEDGER_FOLDER}" ]; then
  echo "Making the Ledger..."
  printf "\n"

  mkdir -p ${LEDGER_FOLDER}

  clean-dir ${LEDGER_FOLDER}/offline_whale_keys
  clean-dir ${LEDGER_FOLDER}/offline_fish_keys
  clean-dir ${LEDGER_FOLDER}/online_whale_keys
  clean-dir ${LEDGER_FOLDER}/online_fish_keys
  clean-dir ${LEDGER_FOLDER}/libp2p_keys
  clean-dir ${LEDGER_FOLDER}/service-keys
  clean-dir ${LEDGER_FOLDER}/zkapp_keys

  if ${ZKAPP_TRANSACTIONS}; then
    generate-keypair ${LEDGER_FOLDER}/zkapp_keys/zkapp_account
  fi

  generate-keypair ${LEDGER_FOLDER}/snark_worker_keys/snark_worker_account
  for ((i = 0; i < ${FISH}; i++)); do
    generate-keypair ${LEDGER_FOLDER}/offline_fish_keys/offline_fish_account_${i}
    generate-keypair ${LEDGER_FOLDER}/online_fish_keys/online_fish_account_${i}
    generate-libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/fish_${i}
  done
  for ((i = 0; i < ${WHALES}; i++)); do
    generate-keypair ${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_${i}
    generate-keypair ${LEDGER_FOLDER}/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/whale_${i}
  done
  for ((i = 0; i < ${NODES}; i++)); do
    generate-keypair ${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_${i}
    generate-keypair ${LEDGER_FOLDER}/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/node_${i}
  done

  if [ "$(uname)" != "Darwin" ] && [ ${FISH} -gt 0 ]; then
    FILE=$(ls ${LEDGER_FOLDER}/offline_fish_keys/ | head -n 1)
    OWNER=$(stat -c "%U" ${LEDGER_FOLDER}/offline_fish_keys/${FILE})

    if [ "${FILE}" != "${USER}" ]; then
      sudo chown -R ${USER} ${LEDGER_FOLDER}/zkapp_keys
      sudo chown -R ${USER} ${LEDGER_FOLDER}/offline_fish_keys
      sudo chown -R ${USER} ${LEDGER_FOLDER}/online_fish_keys
      sudo chown -R ${USER} ${LEDGER_FOLDER}/offline_whale_keys
      sudo chown -R ${USER} ${LEDGER_FOLDER}/online_whale_keys
      sudo chown -R ${USER} ${LEDGER_FOLDER}/libp2p_keys
    fi
  fi

  chmod -R 0700 ${LEDGER_FOLDER}/zkapp_keys
  chmod -R 0700 ${LEDGER_FOLDER}/offline_fish_keys
  chmod -R 0700 ${LEDGER_FOLDER}/online_fish_keys
  chmod -R 0700 ${LEDGER_FOLDER}/offline_whale_keys
  chmod -R 0700 ${LEDGER_FOLDER}/online_whale_keys
  chmod -R 0700 ${LEDGER_FOLDER}/libp2p_keys

  python3 scripts/mina-local-network/generate-mina-local-network-ledger.py \
    --num-whale-accounts ${WHALES} \
    --num-fish-accounts ${FISH} \
    --offline-whale-accounts-directory ${LEDGER_FOLDER}/offline_whale_keys \
    --offline-fish-accounts-directory ${LEDGER_FOLDER}/offline_fish_keys \
    --online-whale-accounts-directory ${LEDGER_FOLDER}/online_whale_keys \
    --online-fish-accounts-directory ${LEDGER_FOLDER}/online_fish_keys

  mv -f scripts/mina-local-network/genesis_ledger.json ${LEDGER_FOLDER}/genesis_ledger.json

  printf "\n"
  echo "================================"
  printf "\n"
fi

SNARK_WORKER_PUBKEY=$(cat ${LEDGER_FOLDER}/snark_worker_keys/snark_worker_account.pub)

# ================================================
# Update the Genesis State Timestamp

CONFIG=${LEDGER_FOLDER}/daemon.json

if ${RESET} || ${UPDATE_GENESIS_TIMESTAMP}; then
  echo 'Updating Genesis State timestamp...'
  printf "\n"

  jq "{genesis: {genesis_state_timestamp:\"$(date +"%Y-%m-%dT%H:%M:%S%z")\"}, ledger:.}" \
    <${LEDGER_FOLDER}/genesis_ledger.json \
    >${CONFIG}
fi

# ================================================
# Launch the Nodes

NODES_FOLDER=${LEDGER_FOLDER}/nodes
mkdir -p ${NODES_FOLDER}/seed

if ${RESET}; then
  clean-dir ${NODES_FOLDER}
  mkdir -p ${NODES_FOLDER}/seed
fi

# ----------

if ${ARCHIVE}; then
  echo 'Starting the Archive Node...'
  printf "\n"

  mkdir -p ${NODES_FOLDER}/archive

  spawn-archive-node ${NODES_FOLDER}/archive
  ARCHIVE_PID=$!
fi

# ----------

spawn-node ${NODES_FOLDER}/seed ${SEED_START_PORT} -seed -libp2p-keypair ${SEED_PEER_KEY} ${ARCHIVE_ADDRESS_CLI_ARG}
SEED_PID=$!

echo 'Waiting for seed to go up...'
printf "\n"

until ${MINA_EXE} client status -daemon-port ${SEED_START_PORT} &>/dev/null; do
  sleep 1
done

# ----------

SNARK_WORKER_FLAGS="-snark-worker-fee ${SNARK_WORKER_FEE} -run-snark-worker ${SNARK_WORKER_PUBKEY} -work-selection seq"

for ((i = 0; i < ${WHALES}; i++)); do
  FOLDER=${NODES_FOLDER}/whale_${i}
  KEY_FILE=${LEDGER_FOLDER}/online_whale_keys/online_whale_account_${i}
  mkdir -p ${FOLDER}
  spawn-node ${FOLDER} $((${WHALE_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} -block-producer-key ${KEY_FILE} \
    -libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/whale_${i} ${SNARK_WORKER_FLAGS} ${ARCHIVE_ADDRESS_CLI_ARG}
  WHALE_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < ${FISH}; i++)); do
  FOLDER=${NODES_FOLDER}/fish_${i}
  KEY_FILE=${LEDGER_FOLDER}/online_fish_keys/online_fish_account_${i}
  mkdir -p ${FOLDER}
  spawn-node ${FOLDER} $((${FISH_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} -block-producer-key ${KEY_FILE} \
    -libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/fish_${i} ${SNARK_WORKER_FLAGS} ${ARCHIVE_ADDRESS_CLI_ARG}
  FISH_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < ${NODES}; i++)); do
  FOLDER=${NODES_FOLDER}/node_${i}
  mkdir -p ${FOLDER}
  spawn-node ${FOLDER} $((${NODE_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} \
    -libp2p-keypair ${LEDGER_FOLDER}/libp2p_keys/node_${i} ${ARCHIVE_ADDRESS_CLI_ARG}
  NODE_PIDS[${i}]=$!
done

# ================================================

echo "================================"
echo "Network participants information:"
printf "\n"

echo -e "\tSeed:"
echo -e "\t\tInstance #0:"
echo -e "\t\t  pid ${SEED_PID}"
echo -e "\t\t  status: ${MINA_EXE} client status -daemon-port ${SEED_START_PORT}"
echo -e "\t\t  logs: cat ${NODES_FOLDER}/seed/log.txt | ${LOGPROC_EXE}"

if ${ARCHIVE}; then
  echo -e "\tArchive:"
  echo -e "\t\tInstance #0:"
  echo -e "\t\t  pid ${ARCHIVE_PID}"
  echo -e "\t\t  server-port: ${ARCHIVE_SERVER_PORT}"
  echo -e "\t\t  logs: cat ${NODES_FOLDER}/archive/log.txt | ${LOGPROC_EXE}"
fi

if [ "${WHALES}" -gt "0" ]; then
  echo -e "\tWhales:"
  for ((i = 0; i < ${WHALES}; i++)); do
    echo -e "\t\tInstance #${i}:"
    echo -e "\t\t  pid ${WHALE_PIDS[${i}]}"
    echo -e "\t\t  status: ${MINA_EXE} client status -daemon-port $((${WHALE_START_PORT} + (${i} * 5)))"
    echo -e "\t\t  logs: cat ${NODES_FOLDER}/whale_${i}/log.txt | ${LOGPROC_EXE}"
  done
fi

if [ "${FISH}" -gt "0" ]; then
  echo -e "\tFish:"
  for ((i = 0; i < ${FISH}; i++)); do
    echo -e "\t\tInstance #${i}:"
    echo -e "\t\t  pid ${FISH_PIDS[${i}]}"
    echo -e "\t\t  status: ${MINA_EXE} client status -daemon-port $((${FISH_START_PORT} + (${i} * 5)))"
    echo -e "\t\t  logs: cat ${NODES_FOLDER}/fish_${i}/log.txt | ${LOGPROC_EXE}"
  done
fi

if [ "${NODES}" -gt "0" ]; then
  echo -e "\tNon block-producing nodes:"
  for ((i = 0; i < ${NODES}; i++)); do
    echo -e "\t\tInstance #${i}:"
    echo -e "\t\t  pid ${NODE_PIDS[${i}]}"
    echo -e "\t\t  status: ${MINA_EXE} client status -daemon-port $((${NODE_START_PORT} + (${i} * 5)))"
    echo -e "\t\t  logs: cat ${NODES_FOLDER}/node_${i}/log.txt | ${LOGPROC_EXE}"
  done
fi

echo "================================"
printf "\n"

# ================================================
# Start sending transactions and zkApp transactions

if [ ${VALUE_TRANSFERS} ] || [ ${ZKAPP_TRANSACTIONS} ]; then
  FEE_PAYER_KEY_FILE=${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_0
  SENDER_KEY_FILE=${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_1
  ZKAPP_ACCOUNT_KEY_FILE=${LEDGER_FOLDER}/zkapp_keys/zkapp_account
  ZKAPP_ACCOUNT_PUB_KEY=$(cat ${LEDGER_FOLDER}/zkapp_keys/zkapp_account.pub)

  KEY_FILE=${LEDGER_FOLDER}/online_fish_keys/online_fish_account_0
  PUB_KEY=$(cat ${LEDGER_FOLDER}/online_fish_keys/online_fish_account_0.pub)
  REST_SERVER="http://127.0.0.1:$((${FISH_START_PORT} + 1))/graphql"
  
  echo "Waiting for Node (${REST_SERVER}) to be up to start sending value transfer transactions..."
  printf "\n"

  until ${MINA_EXE} client status -daemon-port ${FISH_START_PORT} &>/dev/null; do
    sleep 1
  done
  
  SYNCED=0

  echo "Waiting for Node (${REST_SERVER})'s transition frontier to be up"
  printf "\n"

  set +e

  while [ $SYNCED -eq 0 ]; do
    SYNC_STATUS=$(curl -g -X POST -H "Content-Type: application/json" -d '{"query":"query { syncStatus }"}' ${REST_SERVER})
    SYNCED=$(echo ${SYNC_STATUS} | grep -c "SYNCED")
    sleep 1
  done

  echo "Starting to send value transfer transactions/zkApp transactions every: ${TRANSACTION_FREQUENCY} seconds"
  printf "\n"

  if ${ZKAPP_TRANSACTIONS}; then
    echo "Set up zkapp account"
    printf "\n"

    QUERY=$(${ZKAPP_EXE} create-zkapp-account --fee-payer-key ${FEE_PAYER_KEY_FILE} --nonce 0 --sender-key ${SENDER_KEY_FILE} --sender-nonce 0 --receiver-amount 1000 --zkapp-account-key ${ZKAPP_ACCOUNT_KEY_FILE} --fee 5 | sed 1,7d)
    python3 scripts/mina-local-network/send-graphql-query.py ${REST_SERVER} "${QUERY}"
  fi

  if ${VALUE_TRANSFER}; then
    ${MINA_EXE} account import -rest-server ${REST_SERVER} -privkey-path ${KEY_FILE}
    ${MINA_EXE} account unlock -rest-server ${REST_SERVER} -public-key ${PUB_KEY}

    sleep ${TRANSACTION_FREQUENCY}
    ${MINA_EXE} client send-payment -rest-server ${REST_SERVER} -amount 1 -nonce 0 -receiver ${PUB_KEY} -sender ${PUB_KEY}
  fi

  fee_payer_nonce=1
  sender_nonce=1
  state=0

  while true; do
    sleep ${TRANSACTION_FREQUENCY}

    if ${VALUE_TRANSFER}; then
      ${MINA_EXE} client send-payment -rest-server ${REST_SERVER} -amount 1 -receiver ${PUB_KEY} -sender ${PUB_KEY}
    fi

    if ${ZKAPP_TRANSACTIONS}; then
      QUERY=$(${ZKAPP_EXE} transfer-funds-one-receiver --fee-payer-key ${FEE_PAYER_KEY_FILE} --nonce $fee_payer_nonce --sender-key ${SENDER_KEY_FILE} --sender-nonce $sender_nonce --receiver-amount 1 --fee 5 --receiver $ZKAPP_ACCOUNT_PUB_KEY | sed 1,5d)
      python3 scripts/mina-local-network/send-graphql-query.py ${REST_SERVER} "${QUERY}"
      let fee_payer_nonce++
      let sender_nonce++

      QUERY=$(${ZKAPP_EXE} update-state --fee-payer-key ${FEE_PAYER_KEY_FILE} --nonce $fee_payer_nonce --zkapp-account-key ${ZKAPP_ACCOUNT_KEY_FILE} --zkapp-state $state --fee 5 | sed 1,5d)
      python3 scripts/mina-local-network/send-graphql-query.py ${REST_SERVER} "${QUERY}"
      let fee_payer_nonce++
      let state++
    fi
  done

  set -e
fi

# ================================================
# Wait for child processes to finish

wait