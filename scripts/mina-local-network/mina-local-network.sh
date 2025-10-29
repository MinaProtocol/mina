#!/usr/bin/env bash
set -x

# Exit script when commands fail
set -e
# Kill background process when script exits
trap "jobs -p | xargs kill" EXIT

# ================================================
# Constants

POLL_INTERVAL=10s

MINA_EXE=${MINA_EXE:-_build/default/src/app/cli/src/mina.exe}
ARCHIVE_EXE=${ARCHIVE_EXE:-_build/default/src/app/archive/archive.exe}
LOGPROC_EXE=${LOGPROC_EXE:-_build/default/src/app/logproc/logproc.exe}
ZKAPP_EXE=${ZKAPP_EXE:-_build/default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe}

unset MINA_BP_PRIVKEY
export MINA_PRIVKEY_PASS='naughty blue worm'
export MINA_LIBP2P_PASS="${MINA_PRIVKEY_PASS}"
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
SNARK_COORDINATOR_PEER_KEY="CAESQFjWdR18zKuCssN+Fi33fah9f5QGebOCc9xTITR8cdoyC+bk+nO9hW3wne6Ky2Om+fetaH3917/iEHnt+UQzH4A=,CAESIAvm5PpzvYVt8J3uistjpvn3rWh9/de/4hB57flEMx+A,12D3KooWAcprha9pvfdwz52F4RuBYjr2HenzLRNt4W9zWXugN1Z9"

# ================================================
# Inputs (set to default values)

WHALES=2
FISH=1
NODES=1
ARCHIVE=false
LOG_LEVEL="Trace"
FILE_LOG_LEVEL=${LOG_LEVEL}
VALUE_TRANSFERS=false
SNARK_WORKERS_COUNT=1
ZKAPP_TRANSACTIONS=false
RESET=false
UPDATE_GENESIS_TIMESTAMP=false
OVERRIDE_SLOT_TIME_MS=""
PROOF_LEVEL="full"
LOG_PRECOMPUTED_BLOCKS=false

SNARK_WORKER_FEE=0.001
TRANSACTION_FREQUENCY=10 # in seconds

SEED_START_PORT=3000
ARCHIVE_SERVER_PORT=3086
SNARK_COORDINATOR_PORT=7000
WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="${USER}"
PG_PASSWD=""
PG_DB="archive"

ARCHIVE_ADDRESS_CLI_ARG=""
DEMO_MODE=false

SLOT_TX_END=
SLOT_CHAIN_END=

# ================================================
# Globals (assigned during execution of script)

LEDGER_FOLDER=""
SNARK_COORDINATOR_PUBKEY=""
NODES_FOLDER=""
CONFIG=""
SNARK_COORDINATOR_PID=""
SEED_PID=""
ARCHIVE_PID=""
WHALE_PIDS=()
SNARK_WORKERS_PIDS=()
FISH_PIDS=()
NODE_PIDS=()

# ================================================
# Helper functions

help() {

  cat <<EOF

-w   |--whales <#>                       | Number of BP Whale Nodes (bigger stake) to spin-up
                                         |   Default: ${WHALES}
-f   |--fish <#>                         | Number of BP Fish Nodes (less stake) to spin-up
                                         |   Default: ${FISH}
-n   |--nodes <#>                        | Number of non block-producing nodes to spin-up
                                         |   Default: ${NODES}
-a   |--archive                          | Whether to run the Archive Node (presence of argument)
                                         |   Default: ${ARCHIVE}
-sp  |--seed-start-port <#>              | Seed Node range start port
                                         |   Default: ${SEED_START_PORT}
-swp |--snark-coordinator-start-port <#> | Snark Worker Coordinator Node range start port
                                         |   Default: ${SNARK_COORDINATOR_PORT}
-swc |--snark-workers-count <#>          | Snark Workers count
                                         |   Default: ${SNARK_WORKERS_COUNT}
-wp  |--whale-start-port <#>             | Whale Nodes range start port
                                         |   Default: ${WHALE_START_PORT}
-fp  |--fish-start-port <#>              | Fish Nodes range start port
                                         |   Default: ${FISH_START_PORT}
-np  |--node-start-port <#>              | Non block-producing Nodes range start port
                                         |   Default: ${NODE_START_PORT}
-ap  |--archive-server-port <#>          | Archive Node server port
                                         |   Default: ${ARCHIVE_SERVER_PORT}
-ll  |--log-level <level>                | Console output logging level
                                         |   Default: ${LOG_LEVEL}
-fll |--file-log-level <level>           | File output logging level
                                         |   Default: ${FILE_LOG_LEVEL}
-ph  |--pg-host <host>                   | PostgreSQL host
                                         |   Default: ${PG_HOST}
-pp  |--pg-port <#>                      | PostgreSQL port
                                         |   Default: ${PG_PORT}
-pu  |--pg-user <user>                   | PostgreSQL user
                                         |   Default: ${PG_USER}
-ppw |--pg-passwd <password>             | PostgreSQL password
                                         |   Default: <empty_string>
-pd  |--pg-db <db>                       | PostgreSQL database name
                                         |   Default: ${PG_DB}
-vt  |--value-transfer-txns              | Whether to execute periodic value transfer transactions (presence of argument)
                                         |   Default: ${VALUE_TRANSFERS}
-zt  |--zkapp-transactions               | Whether to execute periodic zkapp transactions (presence of argument)
                                         |   Default: ${ZKAPP_TRANSACTIONS}
-tf  |--transactions-frequency <#>       | Frequency of periodic transactions execution (in seconds)
                                         |   Default: ${TRANSACTION_FREQUENCY}
-sf  |--snark-worker-fee <#>             | SNARK Worker fee
                                         |   Default: ${SNARK_WORKER_FEE}
-lp  |--log-precomputed-blocks           | Log precomputed blocks
                                         |   Default: ${LOG_PRECOMPUTED_BLOCKS}
-pl  |--proof-level <proof-level>        | Proof level (currently consumed by SNARK Workers only)
                                         |   Default: ${PROOF_LEVEL}
-r   |--reset                            | Whether to reset the Mina Local Network storage file-system (presence of argument)
                                         |   Default: ${RESET}
-u   |--update-genesis-timestamp         | Whether to update the Genesis Ledger timestamp (presence of argument)
                                         |   Default: ${UPDATE_GENESIS_TIMESTAMP}
-st  |--override-slot-time <milliseconds>| Override the slot time for block production
                                         |   Default: value from executable
-d   |--demo                             | Whether to run the demo (presence of argument). Demo mode is used to run the single node which is already bootstrapped and synced with the network.
                                         |   Default: false
-ste |--slot-transaction-end             | When set, stop adding transactions from this slot on.
                                         |   Default: None
-sce |--slot-chain-end                   | When set, stop producing blocks from this chain on.
                                         |   Default: None
-h   |--help                             | Displays this help message

Available logging levels:
  Spam, Trace, Debug, Info, Warn, Error, Faulty_peer, Fatal

Available proof levels:
  full, check, none

EOF

  exit
}

clean-dir() {
  rm -rf "${1}"
  mkdir -p "${1}"
}

generate-keypair() {
  ${MINA_EXE} advanced generate-keypair -privkey-path "${1}"
}

generate-libp2p-keypair() {
  ${MINA_EXE} libp2p generate-keypair -privkey-path "${1}"
}

# Executes the Mina Daemon, exposing all 5 ports in
# sequence starting with provided base port
exec-daemon() {
  BASE_PORT=${1}
  shift
  CLIENT_PORT=${BASE_PORT}
  REST_PORT=$((BASE_PORT + 1))
  EXTERNAL_PORT=$((BASE_PORT + 2))
  DAEMON_METRICS_PORT=$((BASE_PORT + 3))
  LIBP2P_METRICS_PORT=$((BASE_PORT + 4))

  # shellcheck disable=SC2068
  exec ${MINA_EXE} daemon \
    -client-port "${CLIENT_PORT}" \
    -rest-port ${REST_PORT} \
    -insecure-rest-server \
    -external-port ${EXTERNAL_PORT} \
    -metrics-port ${DAEMON_METRICS_PORT} \
    -libp2p-metrics-port ${LIBP2P_METRICS_PORT} \
    -config-file "${CONFIG}" \
    -log-json \
    -log-level "${LOG_LEVEL}" \
    -file-log-level "${FILE_LOG_LEVEL}" \
    -precomputed-blocks-file "${FOLDER}"/precomputed_blocks.log \
    -log-precomputed-blocks ${LOG_PRECOMPUTED_BLOCKS} \
    $@
}

# Executes the Mina Snark Worker
exec-worker-daemon() {
  COORDINATOR_PORT=${1}
  shift
  SHUTDOWN_ON_DISCONNECT="false"
  COORDINATOR_HOST_AND_PORT="localhost:${COORDINATOR_PORT}"

  # shellcheck disable=SC2068
  exec ${MINA_EXE} internal snark-worker \
    -proof-level "${PROOF_LEVEL}" \
    -shutdown-on-disconnect "${SHUTDOWN_ON_DISCONNECT}" \
    -daemon-address "${COORDINATOR_HOST_AND_PORT}" \
    $@
}

# Executes the Archive node
exec-archive-node() {
  # shellcheck disable=SC2068
  exec ${ARCHIVE_EXE} run \
    --config-file "${CONFIG}" \
    --log-level "${LOG_LEVEL}" \
    --postgres-uri postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}"/"${PG_DB}" \
    --server-port "${ARCHIVE_SERVER_PORT}" \
    $@
}

# Spawns the Node in background
spawn-node() {
  FOLDER=${1}
  shift
  # shellcheck disable=SC2068
  exec-daemon $@ -config-directory "${FOLDER}" &>"${FOLDER}"/log.txt &
}

# Spawns worker in background
spawn-worker() {
  FOLDER=${1}
  shift
  # shellcheck disable=SC2068
  exec-worker-daemon $@ -config-directory "${FOLDER}" &>"${FOLDER}"/log.txt &
}

# Spawns the Archive Node in background
spawn-archive-node() {
  FOLDER=${1}
  shift
  # shellcheck disable=SC2068
  exec-archive-node $@ &>"${FOLDER}"/log.txt &
}

# Resets genesis ledger
reset-genesis-ledger() {
  GENESIS_LEDGER_FOLDER=${1}
  DAEMON_CONFIG=${2}
  echo 'Resetting Genesis Ledger...'
  printf "\n"

  jq "{genesis: {genesis_state_timestamp:\"$(date +"%Y-%m-%dT%H:%M:%S%z")\"}, ledger:.}" \
    <"${GENESIS_LEDGER_FOLDER}"/genesis_ledger.json \
    >"${DAEMON_CONFIG}"
}

recreate-schema() {
  echo "Recreating database '${PG_DB}'..."

  psql postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}" -c "DROP DATABASE IF EXISTS ${PG_DB};"

  psql postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}" -c "CREATE DATABASE ${PG_DB};"

  # We need to change our working directory as script has relation to others subscripts
  # and calling them from local folder
  pushd ./src/app/archive
  psql postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}"/"${PG_DB}" < create_schema.sql
  popd

  echo "Schema '${PG_DB}' created successfully."
  printf "\n"
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
  -scp | --snark-coordinator-start-port)
    SNARK_COORDINATOR_PORT="${2}"
    shift
    ;;
  -swc | --snark-workers-count)
    SNARK_WORKERS_COUNT="${2}"
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
  -lp | --log-precomputed-blocks) LOG_PRECOMPUTED_BLOCKS=true ;;
  -pl | --proof-level)
    PROOF_LEVEL="${2}"
    shift
    ;;
  -r | --reset) RESET=true ;;
  -u | --update-genesis-timestamp) UPDATE_GENESIS_TIMESTAMP=true ;;
  -st |--override-slot-time)
    OVERRIDE_SLOT_TIME_MS="${2}"
    shift
    ;;
  -d | --demo) DEMO_MODE=true ;;
  -ste | --slot-transaction-end) 
    SLOT_TX_END="${2}"
    shift
    ;;
  -sce | --slot-chain-end) 
    SLOT_CHAIN_END="${2}"
    shift
    ;;
  *)
    echo "Unknown parameter passed: ${1}"

    exit 1
    ;;
  esac
  shift
done


cat <<'EOF'
================================

███╗   ███╗██╗███╗   ██╗ █████╗ 
████╗ ████║██║████╗  ██║██╔══██╗
██╔████╔██║██║██╔██╗ ██║███████║
██║╚██╔╝██║██║██║╚██╗██║██╔══██║
██║ ╚═╝ ██║██║██║ ╚████║██║  ██║
╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝
      .:: LOCAL NETWORK ::.     

================================

EOF

# ================================================
# Check the PostgreSQL configuration required
# for Archive Node operation

if ${ARCHIVE}; then
cat <<EOF

Archive Node spawning is enabled, we need to do the PostgreSQL communication check.
In case of any issues please make sure that you:
  1. Run the PostgreSQL server;
  2. Have configured the PostgreSQL access;
  3. Have configured the PostgreSQL 'database';
    3.1. psql -c 'CREATE DATABASE ${PG_DB}'
    3.2. psql ${PG_DB} < ./src/app/archive/create_schema.sql'
  4. Passed correct PostgreSQL credentials as CLI arguments to this script.

================================

EOF

  if ${RESET}; then
    recreate-schema
  fi

  psql postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}"/"${PG_DB}" -c "SELECT * FROM user_commands;" &>/dev/null

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

# ================================================
# Create the Genesis Ledger

if ${DEMO_MODE}; then
  LEDGER_FOLDER="${HOME}/.mina-network/mina-local-network-demo"
else
  LEDGER_FOLDER="${HOME}/.mina-network/mina-local-network-${WHALES}-${FISH}-${NODES}"
fi

if ${RESET}; then
  rm -rf "${LEDGER_FOLDER}"
  if ${ARCHIVE}; then
    recreate-schema
  fi
fi

if [ ! -d "${LEDGER_FOLDER}" ]; then
  echo "Making the Ledger..."
  printf "\n"

  mkdir -p "${LEDGER_FOLDER}"

  clean-dir "${LEDGER_FOLDER}"/offline_whale_keys
  clean-dir "${LEDGER_FOLDER}"/offline_fish_keys
  clean-dir "${LEDGER_FOLDER}"/online_whale_keys
  clean-dir "${LEDGER_FOLDER}"/online_fish_keys
  clean-dir "${LEDGER_FOLDER}"/snark_coordinator_keys
  clean-dir "${LEDGER_FOLDER}"/service-keys
  clean-dir "${LEDGER_FOLDER}"/libp2p_keys
  clean-dir "${LEDGER_FOLDER}"/zkapp_keys

  if ${ZKAPP_TRANSACTIONS}; then
    generate-keypair ${LEDGER_FOLDER}/zkapp_keys/zkapp_account
  fi

  generate-keypair "${LEDGER_FOLDER}"/snark_coordinator_keys/snark_coordinator_account
  for ((i = 0; i < FISH; i++)); do
    generate-keypair "${LEDGER_FOLDER}"/offline_fish_keys/offline_fish_account_${i}
    generate-keypair "${LEDGER_FOLDER}"/online_fish_keys/online_fish_account_${i}
    generate-libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/fish_${i}
  done
  for ((i = 0; i < WHALES; i++)); do
    generate-keypair "${LEDGER_FOLDER}"/offline_whale_keys/offline_whale_account_${i}
    generate-keypair "${LEDGER_FOLDER}"/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/whale_${i}
  done
  for ((i = 0; i < NODES; i++)); do
    generate-keypair "${LEDGER_FOLDER}"/offline_whale_keys/offline_whale_account_${i}
    generate-keypair "${LEDGER_FOLDER}"/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/node_${i}
  done

  if [ "$(uname)" != "Darwin" ] && [ ${FISH} -gt 0 ]; then
    FILE=$(find "${LEDGER_FOLDER}/offline_fish_keys" -mindepth 1 -maxdepth 1 -type f | head -n 1)
    OWNER=$(stat -c "%U" "${FILE}")

    if [ "${FILE}" != "${OWNER}" ]; then
      # Check if sudo command exists
      if command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
      else
        SUDO_CMD=""
      fi

      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/zkapp_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/offline_fish_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/online_fish_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/offline_whale_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/online_whale_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/snark_coordinator_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/service-keys
      ${SUDO_CMD} chown -R "${OWNER}" "${LEDGER_FOLDER}"/libp2p_keys
    fi
  fi

  chmod -R 0700 "${LEDGER_FOLDER}"/zkapp_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/offline_fish_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/online_fish_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/offline_whale_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/online_whale_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/snark_coordinator_keys
  chmod -R 0700 "${LEDGER_FOLDER}"/service-keys
  chmod -R 0700 "${LEDGER_FOLDER}"/libp2p_keys

  python3 scripts/mina-local-network/generate-mina-local-network-ledger.py \
    --num-whale-accounts "${WHALES}" \
    --num-fish-accounts "${FISH}" \
    --offline-whale-accounts-directory "${LEDGER_FOLDER}"/offline_whale_keys \
    --offline-fish-accounts-directory "${LEDGER_FOLDER}"/offline_fish_keys \
    --online-whale-accounts-directory "${LEDGER_FOLDER}"/online_whale_keys \
    --online-fish-accounts-directory "${LEDGER_FOLDER}"/online_fish_keys \
    --snark-coordinator-accounts-directory "${LEDGER_FOLDER}"/snark_coordinator_keys

  mv -f scripts/mina-local-network/genesis_ledger.json "${LEDGER_FOLDER}"/genesis_ledger.json

  printf "\n"
  echo "================================"
  printf "\n"
fi

SNARK_COORDINATOR_PUBKEY=$(cat "${LEDGER_FOLDER}"/snark_coordinator_keys/snark_coordinator_account.pub)


# ================================================
# Check the demo mode

if ${DEMO_MODE}; then
  echo "Demo mode requires no Whale nodes, no Fish nodes and no non block-producing nodes!"
  echo "Resetting the values to 0."

  # Set the default values for demo mode
  SNARK_WORKERS_COUNT=0
  WHALES=0
  FISH=0
  NODES=0

  if ${VALUE_TRANSFERS} || ${ZKAPP_TRANSACTIONS}; then
    echo "Demo mode does not support transactions!"
    printf "\n"

    exit 1
  fi

fi

# ================================================
# Print the configuration summary

cat <<EOF
Starting the Network with:
    1 seed
    1 snark coordinator
    ${SNARK_WORKERS_COUNT} snark worker(s)
    $( ${ARCHIVE} && echo 1 || echo 0) archive
    ${WHALES} whales
    ${FISH} fish
    ${NODES} non block-producing nodes
    Sending transactions: ${VALUE_TRANSFERS}
    Sending zkApp transactions: ${ZKAPP_TRANSACTIONS}

================================

EOF


# ================================================
# Update the Genesis State Timestamp or Reset the Genesis Ledger

CONFIG=${LEDGER_FOLDER}/daemon.json

if ${RESET}; then
  reset-genesis-ledger "${LEDGER_FOLDER}" "${CONFIG}"
fi

if ${UPDATE_GENESIS_TIMESTAMP}; then
  if test -f "${CONFIG}"; then
    echo 'Updating Genesis State timestamp...'
    printf "\n"

    tmp=$(mktemp)
    jq ".genesis.genesis_state_timestamp=\"$(date +"%Y-%m-%dT%H:%M:%S%z")\"" "${CONFIG}" >"$tmp" && mv -f "$tmp" "${CONFIG}"
  else
    reset-genesis-ledger "${LEDGER_FOLDER}" "${CONFIG}"
  fi
fi

if [ ! -z "${OVERRIDE_SLOT_TIME_MS}" ]; then
  echo 'Modifying configuration to override slot time'
  
  if [ ! -f "${CONFIG}" ]; then
    reset-genesis-ledger "${LEDGER_FOLDER}" "${CONFIG}"
  fi
  
  printf "\n"
  tmp=$(mktemp)
  jq ".proof.block_window_duration_ms=${OVERRIDE_SLOT_TIME_MS}" "${CONFIG}" >"$tmp" && mv -f "$tmp" "${CONFIG}"
fi

# ================================================
# Launch the Nodes

NODES_FOLDER=${LEDGER_FOLDER}/nodes
mkdir -p ${NODES_FOLDER}/seed

if ! ${DEMO_MODE}; then
  mkdir -p "${NODES_FOLDER}"/snark_coordinator
  mkdir -p "${NODES_FOLDER}"/snark_workers
fi

if ${RESET}; then
  clean-dir "${NODES_FOLDER}"
  mkdir -p "${NODES_FOLDER}"/seed
  mkdir -p "${NODES_FOLDER}"/snark_coordinator
  mkdir -p "${NODES_FOLDER}"/snark_workers
fi

# ----------

if ${ARCHIVE}; then
  echo 'Starting the Archive Node...'
  printf "\n"

  mkdir -p "${NODES_FOLDER}"/archive

  spawn-archive-node "${NODES_FOLDER}"/archive
  ARCHIVE_PID=$!
fi

# ----------

if ${DEMO_MODE}; then
  echo "Running in demo mode, only seed node is going to be started."
  printf "\n"

  spawn-node ${NODES_FOLDER}/seed ${SEED_START_PORT} \
    -block-producer-key ${LEDGER_FOLDER}/online_whale_keys/online_whale_account_0 \
    --run-snark-worker "$(cat ${LEDGER_FOLDER}/snark_coordinator_keys/snark_coordinator_account.pub)" \
    --snark-worker-fee 0.001 \
    --proof-level ${PROOF_LEVEL} \
    --demo-mode \
    --external-ip "$(hostname -i)" \
    --seed \
    ${ARCHIVE_ADDRESS_CLI_ARG}

else 
  spawn-node "${NODES_FOLDER}"/seed "${SEED_START_PORT}" -seed -libp2p-keypair ${SEED_PEER_KEY} "${ARCHIVE_ADDRESS_CLI_ARG}"
fi

SEED_PID=$!

echo 'Waiting for seed to go up...'
printf "\n"

until ${MINA_EXE} client status -daemon-port "${SEED_START_PORT}" &>/dev/null; do
  sleep ${POLL_INTERVAL}
done

#---------- Starting snark coordinator

if [ "${SNARK_WORKERS_COUNT}" -eq "0" ]; then
  echo "Skipping snark coordinator because SNARK_WORKERS_COUNT is 0"
  SNARK_COORDINATOR_PID=""

else

  SNARK_COORDINATOR_FLAGS="-snark-worker-fee ${SNARK_WORKER_FEE} -run-snark-coordinator ${SNARK_COORDINATOR_PUBKEY} -work-selection seq"
  spawn-node "${NODES_FOLDER}"/snark_coordinator "${SNARK_COORDINATOR_PORT}" -peer ${SEED_PEER_ID} -libp2p-keypair ${SNARK_COORDINATOR_PEER_KEY} ${SNARK_COORDINATOR_FLAGS}
  SNARK_COORDINATOR_PID=$!

  echo 'Waiting for snark coordinator to go up...'
  printf "\n"

  until ${MINA_EXE} client status -daemon-port "${SNARK_COORDINATOR_PORT}" &>/dev/null; do
    sleep ${POLL_INTERVAL}
  done
fi

#---------- Starting snark workers

for ((i = 0; i < SNARK_WORKERS_COUNT; i++)); do
  FOLDER=${NODES_FOLDER}/snark_workers/worker_${i}
  mkdir -p "${FOLDER}"
  spawn-worker "${FOLDER}" "${SNARK_COORDINATOR_PORT}"
  SNARK_WORKERS_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < WHALES; i++)); do
  FOLDER=${NODES_FOLDER}/whale_${i}
  KEY_FILE=${LEDGER_FOLDER}/online_whale_keys/online_whale_account_${i}
  mkdir -p "${FOLDER}"
  spawn-node "${FOLDER}" $((${WHALE_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} -block-producer-key ${KEY_FILE} \
    -libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/whale_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  WHALE_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < FISH; i++)); do
  FOLDER=${NODES_FOLDER}/fish_${i}
  KEY_FILE=${LEDGER_FOLDER}/online_fish_keys/online_fish_account_${i}
  mkdir -p "${FOLDER}"
  spawn-node "${FOLDER}" $((${FISH_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} -block-producer-key "${KEY_FILE}" \
    -libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/fish_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  FISH_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < NODES; i++)); do
  FOLDER=${NODES_FOLDER}/node_${i}
  mkdir -p "${FOLDER}"
  spawn-node "${FOLDER}" $((${NODE_START_PORT} + (${i} * 5))) -peer ${SEED_PEER_ID} \
    -libp2p-keypair "${LEDGER_FOLDER}"/libp2p_keys/node_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  NODE_PIDS[${i}]=$!
done

# ================================================

cat <<EOF
================================
Network participants information:

	Seed:
		Instance #0:
		  pid ${SEED_PID}
		  status: ${MINA_EXE} client status -daemon-port ${SEED_START_PORT}
		  logs: cat ${NODES_FOLDER}/seed/log.txt | ${LOGPROC_EXE}
EOF

if [ "${SNARK_WORKERS_COUNT}" -gt 0 ]; then
  cat <<EOF
	Snark Coordinator:
		Instance #0:
		  pid ${SNARK_COORDINATOR_PID}
		  status: ${MINA_EXE} client status -daemon-port ${SNARK_COORDINATOR_PORT}
		  logs: cat ${NODES_FOLDER}/snark_coordinator/log.txt | ${LOGPROC_EXE}

	Snark Workers:
EOF

  for ((i = 0; i < SNARK_WORKERS_COUNT; i++)); do
    cat <<EOF
		Instance #${i}:
		  pid ${SNARK_WORKERS_PIDS[${i}]}
		  logs: cat ${NODES_FOLDER}/snark_workers/snark_worker_${i}/log.txt | ${LOGPROC_EXE}
EOF
  done
fi

if ${ARCHIVE}; then
  cat <<EOF
	Archive:
		Instance #0:
		  pid ${ARCHIVE_PID}
		  server-port: ${ARCHIVE_SERVER_PORT}
		  logs: cat ${NODES_FOLDER}/archive/log.txt | ${LOGPROC_EXE}
EOF
fi

if [ "${WHALES}" -gt 0 ]; then
  cat <<EOF
	Whales:
EOF
  for ((i = 0; i < WHALES; i++)); do
    cat <<EOF
		Instance #${i}:
		  pid ${WHALE_PIDS[${i}]}
		  status: ${MINA_EXE} client status -daemon-port $((${WHALE_START_PORT} + i*5))
		  logs: cat ${NODES_FOLDER}/whale_${i}/log.txt | ${LOGPROC_EXE}
EOF
  done
fi

if [ "${FISH}" -gt 0 ]; then
  cat <<EOF
	Fish:
EOF
  for ((i = 0; i < FISH; i++)); do
    cat <<EOF
		Instance #${i}:
		  pid ${FISH_PIDS[${i}]}
		  status: ${MINA_EXE} client status -daemon-port $((${FISH_START_PORT} + i*5))
		  logs: cat ${NODES_FOLDER}/fish_${i}/log.txt | ${LOGPROC_EXE}
EOF
  done
fi

if [ "${NODES}" -gt 0 ]; then
  cat <<EOF
	Non block-producing nodes:
EOF
  for ((i = 0; i < NODES; i++)); do
    cat <<EOF
		Instance #${i}:
		  pid ${NODE_PIDS[${i}]}
		  status: ${MINA_EXE} client status -daemon-port $((${NODE_START_PORT} + i*5))
		  logs: cat ${NODES_FOLDER}/node_${i}/log.txt | ${LOGPROC_EXE}
EOF
  done
fi

echo "================================"
printf "\n"

# ================================================
# Start sending transactions and zkApp transactions

if ${VALUE_TRANSFERS} || ${ZKAPP_TRANSACTIONS}; then
  FEE_PAYER_KEY_FILE=${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_0
  SENDER_KEY_FILE=${LEDGER_FOLDER}/offline_whale_keys/offline_whale_account_1
  if ${ZKAPP_TRANSACTIONS}; then
    ZKAPP_ACCOUNT_KEY_FILE=${LEDGER_FOLDER}/zkapp_keys/zkapp_account
    ZKAPP_ACCOUNT_PUB_KEY=$(cat "${LEDGER_FOLDER}/zkapp_keys/zkapp_account.pub")
  fi

  KEY_FILE=${LEDGER_FOLDER}/online_fish_keys/online_fish_account_0
  PUB_KEY=$(cat "${LEDGER_FOLDER}"/online_fish_keys/online_fish_account_0.pub)
  REST_SERVER="http://127.0.0.1:$((${FISH_START_PORT} + 1))/graphql"

  echo "Waiting for Node (${REST_SERVER}) to be up to start sending value transfer transactions..."
  printf "\n"

  until ${MINA_EXE} client status -daemon-port "${FISH_START_PORT}" &>/dev/null; do
    sleep ${POLL_INTERVAL}
  done

  SYNCED=0

  echo "Waiting for Node (${REST_SERVER})'s transition frontier to be up"
  printf "\n"

  set +e

  while [ $SYNCED -eq 0 ]; do
    SYNC_STATUS=$(curl -g -X POST -H "Content-Type: application/json" -d '{"query":"query { syncStatus }"}' ${REST_SERVER})
    SYNCED=$(echo "${SYNC_STATUS}" | grep -c "SYNCED")
    sleep ${POLL_INTERVAL}
  done

  echo "Starting to send value transfer transactions/zkApp transactions every: ${TRANSACTION_FREQUENCY} seconds"
  printf "\n"

  if ${ZKAPP_TRANSACTIONS}; then
    echo "Set up zkapp account"
    printf "\n"

    QUERY=$(${ZKAPP_EXE} create-zkapp-account --fee-payer-key "${FEE_PAYER_KEY_FILE}" --nonce 0 --sender-key "${SENDER_KEY_FILE}" --sender-nonce 0 --receiver-amount 1000 --zkapp-account-key ${ZKAPP_ACCOUNT_KEY_FILE} --fee 5 | sed 1,7d)
    python3 scripts/mina-local-network/send-graphql-query.py ${REST_SERVER} "${QUERY}"
  fi

  if ${VALUE_TRANSFERS}; then
    ${MINA_EXE} account import -rest-server ${REST_SERVER} -privkey-path "${KEY_FILE}"
    ${MINA_EXE} account unlock -rest-server ${REST_SERVER} -public-key "${PUB_KEY}"

    sleep "${TRANSACTION_FREQUENCY}"
    ${MINA_EXE} client send-payment -rest-server ${REST_SERVER} -amount 1 -nonce 0 -receiver "${PUB_KEY}" -sender "${PUB_KEY}"
  fi

  fee_payer_nonce=1
  sender_nonce=1
  state=0

  while true; do
    sleep ${TRANSACTION_FREQUENCY}

    if ${VALUE_TRANSFERS}; then
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
