#!/usr/bin/env bash

# Exit script when commands fail
set -e

# ================================================
# Constants

POLL_INTERVAL=10s

MINA_EXE=${MINA_EXE:-_build/default/src/app/cli/src/mina.exe}
ARCHIVE_EXE=${ARCHIVE_EXE:-_build/default/src/app/archive/archive.exe}
ROSETTA_EXE=${ROSETTA_EXE:-_build/default/src/app/rosetta/rosetta.exe}
ZKAPP_EXE=${ZKAPP_EXE:-_build/default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe}

export MINA_PRIVKEY_PASS='naughty blue worm'
export MINA_LIBP2P_PASS="${MINA_PRIVKEY_PASS}"
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
SNARK_COORDINATOR_PEER_KEY="CAESQFjWdR18zKuCssN+Fi33fah9f5QGebOCc9xTITR8cdoyC+bk+nO9hW3wne6Ky2Om+fetaH3917/iEHnt+UQzH4A=,CAESIAvm5PpzvYVt8J3uistjpvn3rWh9/de/4hB57flEMx+A,12D3KooWAcprha9pvfdwz52F4RuBYjr2HenzLRNt4W9zWXugN1Z9"

# ================================================
# Inputs (set to default values)

WHALES=2
FISH=1
NODES=1
LOG_LEVEL="Trace"
FILE_LOG_LEVEL=${LOG_LEVEL}
VALUE_TRANSFERS=false
SNARK_WORKERS_COUNT=2
ZKAPP_TRANSACTIONS=false
CONFIG_MODE=inherit
UPDATE_GENESIS_TIMESTAMP=no
OVERRIDE_SLOT_TIME_MS=""
PROOF_LEVEL="full"
LOG_PRECOMPUTED_BLOCKS=false

SNARK_WORKER_FEE=0.001
TRANSACTION_INTERVAL=10 # in seconds

SEED="spawn:3000"
ARCHIVE_SERVER_PORT=
SNARK_COORDINATOR_PORT=7000
WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000
ROSETTA_PORT=

MINA_ROSETTA_MAX_DB_POOL_SIZE=64

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="${USER}"
PG_PASSWD=""
PG_DB="archive"

DEMO_MODE=false
SLOT_TX_END=
SLOT_CHAIN_END=
HARDFORK_GENESIS_SLOT_DELTA=
HARDFORK_HANDLING=

# ================================================
# Globals (assigned during execution of script)

ARCHIVE_ADDRESS_CLI_ARG=""
ROOT="${HOME}/.mina-network"
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
ON_EXIT="grace_exit_all"
REDIRECT_LOGS=false
NODE_STATUS_URL=""


# =================================================
# ITN features flags

ITN_KEYS=""

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
-s   |--seed                             | How to start the seed. Set to 'spawn:SEED_START_PORT' to spawn the seed in this script with Seed range start port, 'at:SEED_PEER_ID' to let the script discover the seed node at specific address. Regardless the option taken, this script will always store the seed peer ID used under ROOT/seed_peer_id.txt, when the seed node is/should be ready.
                                         |   Default: ${SEED}
-swp |--snark-coordinator-start-port <#> | Snark Worker Coordinator Node range start port. Set to empty to disable snark coodinator
                                         |   Default: ${SNARK_COORDINATOR_PORT}
-swc |--snark-workers-count <#>          | Snark Workers count
                                         |   Default: ${SNARK_WORKERS_COUNT}
-wp  |--whale-start-port <#>             | Whale Nodes range start port
                                         |   Default: ${WHALE_START_PORT}
-fp  |--fish-start-port <#>              | Fish Nodes range start port
                                         |   Default: ${FISH_START_PORT}
-np  |--node-start-port <#>              | Non block-producing Nodes range start port
                                         |   Default: ${NODE_START_PORT}
-ap  |--archive-server-port <#>          | Archive Node server port. Set to empty to disable archive node.
                                         |   Default: ${ARCHIVE_SERVER_PORT}
-rp  |--rosetta-port <#>                 | Rosetta server port. Set to empty to disable Rosetta server.
                                         |   Default: ${ROSETTA_PORT}
-rmps|--rosetta-max-pool-size <#>        | Rosetta Db max pool size
                                         |   Default: ${MINA_ROSETTA_MAX_DB_POOL_SIZE}
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
-ti  |--transaction-interval <#>         | Frequency of periodic transactions execution (in seconds)
                                         |   Default: ${TRANSACTION_INTERVAL}
-sf  |--snark-worker-fee <#>             | SNARK Worker fee
                                         |   Default: ${SNARK_WORKER_FEE}
-lp  |--log-precomputed-blocks           | Log precomputed blocks
                                         |   Default: ${LOG_PRECOMPUTED_BLOCKS}
-pl  |--proof-level <proof-level>        | Proof level
                                         |   Default: ${PROOF_LEVEL}
-c   |--config                           | Config to use. Set to 'reset' to generate a new config, new keypairs and new ledgers, 'inherit' to reuse the one found in previously deployed networks
                                         |   Default: ${CONFIG_MODE}
-u   |--update-genesis-timestamp         | Whether to update the Genesis Ledger timestamp (presence of argument). Set to 'fixed:TIMESTAMP' to be a fixed time, 'delay_sec:SECONDS' to be set genesis to be SECONDS in the future, or 'no' to do nothing.
                                         |   Default: ${UPDATE_GENESIS_TIMESTAMP}
-st  |--override-slot-time <milliseconds>| Override the slot time for block production
                                         |   Default: value from executable
-d   |--demo                             | Whether to run the demo (presence of argument). Demo mode is used to run the single node which is already bootstrapped and synced with the network.
                                         |   Default: false
-ste |--slot-transaction-end             | When set, stop adding transactions from this slot on.
                                         |   Default: None
-sce |--slot-chain-end                   | When set, stop producing blocks from this chain on.
                                         |   Default: None
--itn-keys <keys>                        | Use ITN keys for nodes authentication
                                         |   Default: not set
-hfd |--hardfork-genesis-slot-delta      | When set override the value 'hard_fork_genesis_slot_delta' in daemon config. 
--hardfork-handling                      | When set, passed to daemons participating the network.
                                         |   Default: not set
-r   |--root                             | When set, override the root working folder (i.e. the value of ROOT) for this script. WARN: this script will clean up anything inside that folder when initializing any run!
                                         |   Default: ${ROOT}
--redirect-logs                          | When set, redirect logs for nodes (excluding workers) and archive to file instead of console output
                                         |   Default: ${REDIRECT_LOGS}
--on-exit                                | Possible Values : {grace_exit_all,kill_snark_workers} . Defines how script exit is handled. If set to 'grace_exit_all' mina CLI to stop all daemon nodes, and kill SNARK workers; If set to 'kill_snark_workers' to only kill SNARK workers but ignoring everything else.
                                         |   Default: ${ON_EXIT}
--node-status-url                        | Url of the node status collection service 
                                         |   Default: not set
-h   |--help                             | Displays this help message

Available logging levels:
  Spam, Trace, Debug, Info, Warn, Error, Faulty_peer, Fatal

Available proof levels:
  full, check, none

EOF

  exit
}

stop-node() {
    local tag="$1"
    local port="$2"

    echo "Stopping $tag at $port"

    "$MINA_EXE" client stop-daemon --daemon-port "$port"
    if [ $? -ne 0 ]; then
        echo "Failed to stop $tag on port $port" >&2
    fi
}

# Kill all processes when script exits
on-exit() {
  echo "Shutting down mina local network"

  local job_pids=()

  # 1. stop all SNARK workers
  for pid in "${SNARK_WORKERS_PIDS[@]}"; do
    {
      echo "Killing SNARK worker at $pid"
      kill "$pid"
    } &
    job_pids+=("$!")
  done

  for jpid in "${job_pids[@]}"; do
    wait "$jpid"
  done

  job_pids=()

  case "$ON_EXIT" in
    grace_exit_all)
      # 2. stop every non-seed nodes
      if [[ -n "${SNARK_COORDINATOR_PORT}" ]]; then
        stop-node "snark-coordinator" "$SNARK_COORDINATOR_PORT" &
        job_pids+=("$!")
      fi

      for ((i=0; i<FISH; i++)); do
        port=$((FISH_START_PORT + i*6))
        stop-node "fish_${i}" "$port" &
        job_pids+=("$!")
      done

      for ((i=0; i<NODES; i++)); do
        port=$((NODE_START_PORT + i*6))
        stop-node "node_${i}" "$port" &
        job_pids+=("$!")
      done

      for ((i=0; i<WHALES; i++)); do
        port=$((WHALE_START_PORT + i*6))
        stop-node "whale_${i}" "$port" &
        job_pids+=("$!")
      done

      for jpid in "${job_pids[@]}"; do
        wait "$jpid"
      done

      if [[ -n "${ROSETTA_PORT}" ]]; then
        kill "$ROSETTA_PID"
        wait "$ROSETTA_PID"
      fi

      # 3. stop the seed node, if we've spawned it.
      if [[ -n "${SEED_PID}" ]]; then
        stop-node "seed" "$SEED_START_PORT"
      fi
      ;;
    kill_snark_workers)
      # NOTE: SNARK workers are already killed out of this case-statement. Hence
      # no need to do anything here.
      : ;;
    *)
      echo "Unknown ON_EXIT value: $1" >&2
      return 1 ;;
  esac
}

trap on-exit TERM INT

clean-dir() {
  rm -rf "${1}"
  mkdir -p "${1}"
}

generate-keypair() {
  if ! ${MINA_EXE} advanced generate-keypair -privkey-path "${1}"; then
    echo "❌ Failed to generate daemon keypair at '${1}'." >&2
    return 1
  fi
}

generate-libp2p-keypair() {
  if ! ${MINA_EXE} libp2p generate-keypair -privkey-path "${1}"; then
    echo "❌ Failed to generate libp2p keypair at '${1}'." >&2
    return 1
  fi 
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


  local extra_opts=()

  # ITN features: only enabled when ITN_KEYS is provided
  # This only takes effect for daemons
  if [ -n "$ITN_KEYS" ]; then
    ITN_GRAPHQL_PORT=$((BASE_PORT + 5))

    extra_opts+=( --itn-keys "$ITN_KEYS" )
    extra_opts+=( --itn-graphql-port "${ITN_GRAPHQL_PORT}" )
  fi

  if [ -n "$HARDFORK_HANDLING" ]; then
    extra_opts+=( --hardfork-handling "$HARDFORK_HANDLING" )
  fi

  if [ -n "$NODE_STATUS_URL" ]; then
    extra_opts+=( --node-status-url "$NODE_STATUS_URL" )
  fi

  # shellcheck disable=SC2068
  exec ${MINA_EXE} daemon \
    --client-port "${CLIENT_PORT}" \
    --rest-port ${REST_PORT} \
    --insecure-rest-server \
    --external-port ${EXTERNAL_PORT} \
    --metrics-port ${DAEMON_METRICS_PORT} \
    --libp2p-metrics-port ${LIBP2P_METRICS_PORT} \
    --config-file "${CONFIG}" \
    --log-level "${LOG_LEVEL}" \
    --file-log-level "${FILE_LOG_LEVEL}" \
    --precomputed-blocks-file "${FOLDER}"/precomputed_blocks.log \
    --log-precomputed-blocks ${LOG_PRECOMPUTED_BLOCKS} \
    --proof-level "${PROOF_LEVEL}" \
    $@ ${extra_opts[@]}
}

# Executes the Mina Snark Worker
exec-snark-worker() {
  COORDINATOR_PORT=${1}
  shift
  COORDINATOR_HOST_AND_PORT="localhost:${COORDINATOR_PORT}"

  # shellcheck disable=SC2068
  exec ${MINA_EXE} internal snark-worker \
    --proof-level "${PROOF_LEVEL}" \
    --shutdown-on-disconnect false \
    --log-level "${LOG_LEVEL}" \
    --file-log-level "${FILE_LOG_LEVEL}" \
    --daemon-address "${COORDINATOR_HOST_AND_PORT}" \
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

exec-rosetta-node() {
  # shellcheck disable=SC2068
  MINA_ROSETTA_MAX_DB_POOL_SIZE=${MINA_ROSETTA_MAX_DB_POOL_SIZE} exec ${ROSETTA_EXE} \
    --archive-uri postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}"/"${PG_DB}" \
    --graphql-uri $((SEED_START_PORT + 1)) \
    --port "${ROSETTA_PORT}" \
    --log-level "${LOG_LEVEL}" \
    $@
}

log-file() {
  # If $1 is provided, use it. Otherwise, fall back to $REDIRECT_LOGS.
  local should_redirect="${1:-$REDIRECT_LOGS}"

  if [[ "$should_redirect" == true ]]; then
    tee "${FOLDER}/log.txt"
  else
    cat
  fi
}

tag-stdout() {
  awk -v tag="$1" '{ print "[" tag "] " $0 }'
}

# Spawns the Node in background
spawn-daemon() {
  local tag=${1}
  FOLDER=${2}
  shift 2

  # shellcheck disable=SC2068
  exec-daemon $@ --config-directory "$FOLDER" 2>&1 \
    | log-file | tag-stdout "$tag" &
}

# Spawns worker in background
# Optionally redirect worker logs to file if REDIRECT_WORKER_LOGS is true
spawn-snark-worker() {
  local tag=${1}
  FOLDER=${2}
  shift 2

  # shellcheck disable=SC2068
  exec-snark-worker $@ --config-directory "${FOLDER}" 2>&1 \
    | log-file "$REDIRECT_WORKER_LOGS" | tag-stdout "$tag" &
}

# Spawns the Archive Node in background
spawn-archive-node() {
  FOLDER=${1}
  shift

  # shellcheck disable=SC2068
  exec-archive-node $@ 2>&1 | log-file | tag-stdout "archive" &
}

spawn-rosetta-server() {
  FOLDER=${1}
  shift

  # shellcheck disable=SC2068
  exec-rosetta-node $@ 2>&1 | log-file | tag-stdout "rosetta" &
}

# Resets genesis ledger
reset-genesis-ledger() {
  GENESIS_LEDGER_FOLDER=${1}
  DAEMON_CONFIG=${2}
  echo 'Resetting Genesis Ledger...'
  printf "\n"

  jq --arg timestamp "$(date +"%Y-%m-%dT%H:%M:%S%z")" \
     --arg proof_level "$PROOF_LEVEL" \
  '
  {
    genesis: {
      slot_per_epoch: 48,
      k: 10,
      grace_period_slots: 3,
      genesis_state_timestamp: $timestamp
    },
    proof: {
      work_delay: 1,
      level: $proof_level,
      transaction_capacity: { 
        "2_to_the": 2 
      },
    },
    ledger: .
  }
  ' < "${GENESIS_LEDGER_FOLDER}/genesis_ledger.json" > "${DAEMON_CONFIG}"
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

jq-inplace() {
  local jq_filter="$1"
  local file="$2"

  local tmp
  tmp=$(mktemp)
  jq "$jq_filter" "$file" > "$tmp" && mv -f "$tmp" "$file"
}

config_mode_is_inherit() {
  [[ "$1" == "inherit" ]]
}

is_process_running() {
  kill -0 "$1" 2>/dev/null
}

REDIRECT_WORKER_LOGS=true

# ================================================
# Parse inputs from arguments

for ARG in "$@"; do
  if [[ "${ARG}" == "-h" || "${ARG}" == "--help" ]]; then
    help
  fi
done

while [[ "$#" -gt 0 ]]; do
  case ${1} in
    --no-worker-log-redirect)
      REDIRECT_WORKER_LOGS=false
      ;;
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
  -s | --seed)
    SEED="${2}"
    shift
    ;;
  -rmps | --rosetta-max-pool-size)
    MINA_ROSETTA_MAX_DB_POOL_SIZE="${2}"
    shift
    ;;
  -rp | --rosetta-port)
    ROSETTA_PORT="${2}"
    shift
    ;;
  -d | --demo)
    DEMO_MODE=true
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
  -ti | --transaction-interval)
    TRANSACTION_INTERVAL="${2}"
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
  -c | --config)
    CONFIG_MODE="${2}"
    shift
    ;;
  -u | --update-genesis-timestamp) 
    UPDATE_GENESIS_TIMESTAMP="${2}"
    shift
    ;;
  -st |--override-slot-time)
    OVERRIDE_SLOT_TIME_MS="${2}"
    shift
    ;;
  -ste | --slot-transaction-end) 
    SLOT_TX_END="${2}"
    shift
    ;;
  -sce | --slot-chain-end) 
    SLOT_CHAIN_END="${2}"
    shift
    ;;
  --itn-keys)
    ITN_KEYS="${2}"
    shift
    ;;
  -hfd |--hardfork-genesis-slot-delta)
    HARDFORK_GENESIS_SLOT_DELTA="${2}"
    shift
    ;;
  --hardfork-handling)
    HARDFORK_HANDLING="${2}"
    shift
    ;;
  -r | --root)
    ROOT="${2}"
    shift
    ;;
  --redirect-logs)
    REDIRECT_LOGS=true
    ;;
  --on-exit)
    ON_EXIT="${2}"
    shift
    ;;
  --node-status-url) 
    NODE_STATUS_URL="${2}"
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

if [[ -n "${ARCHIVE_SERVER_PORT}" ]]; then
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

  if ! config_mode_is_inherit "$CONFIG_MODE"; then
    recreate-schema
  fi

  psql postgresql://"${PG_USER}":"${PG_PASSWD}"@"${PG_HOST}":"${PG_PORT}"/"${PG_DB}" -c "SELECT * FROM user_commands;" &>/dev/null

  ARCHIVE_ADDRESS_CLI_ARG="-archive-address ${ARCHIVE_SERVER_PORT}"
fi

# ================================================
#

# Ensure at least 1 Whale or 1 Fish for standard transfers
if [ "${VALUE_TRANSFERS}" = "true" ] && [ "${WHALES}" -lt 1 ] && [ "${FISH}" -lt 1 ]; then
    echo "Error: Value transfers require at least 1 Whale or 1 Fish node."
    exit 1
fi

# Ensure at least 2 Whales for zkApp transactions
if [ "${ZKAPP_TRANSACTIONS}" = "true" ] && [ "${WHALES}" -lt 2 ]; then
    echo "Error: zkApp transactions require at least 2 Whale accounts."
    exit 1
fi

# ================================================
# Create the Genesis Ledger

if ! config_mode_is_inherit "$CONFIG_MODE" ; then
  rm -rf "${ROOT}"
elif [ ! -d "${ROOT}" ]; then
  echo "Error: ROOT does not exist to inherit from."
  exit 1
fi

if [ ! -d "${ROOT}" ]; then
  echo "Generating keypairs..."
  printf "\n"

  mkdir -p "${ROOT}"

  clean-dir "${ROOT}"/offline_whale_keys
  clean-dir "${ROOT}"/offline_fish_keys
  clean-dir "${ROOT}"/online_whale_keys
  clean-dir "${ROOT}"/online_fish_keys
  clean-dir "${ROOT}"/snark_coordinator_keys
  clean-dir "${ROOT}"/libp2p_keys
  clean-dir "${ROOT}"/zkapp_keys

  if ${ZKAPP_TRANSACTIONS}; then
    generate-keypair ${ROOT}/zkapp_keys/zkapp_account
  fi

  generate-keypair "${ROOT}"/snark_coordinator_keys/snark_coordinator_account
  for ((i = 0; i < FISH; i++)); do
    generate-keypair "${ROOT}"/offline_fish_keys/offline_fish_account_${i}
    generate-keypair "${ROOT}"/online_fish_keys/online_fish_account_${i}
    generate-libp2p-keypair "${ROOT}"/libp2p_keys/fish_${i}
  done
  for ((i = 0; i < WHALES; i++)); do
    generate-keypair "${ROOT}"/offline_whale_keys/offline_whale_account_${i}
    generate-keypair "${ROOT}"/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair "${ROOT}"/libp2p_keys/whale_${i}
  done
  for ((i = 0; i < NODES; i++)); do
    generate-keypair "${ROOT}"/offline_whale_keys/offline_whale_account_${i}
    generate-keypair "${ROOT}"/online_whale_keys/online_whale_account_${i}
    generate-libp2p-keypair "${ROOT}"/libp2p_keys/node_${i}
  done

  if [ "$(uname)" != "Darwin" ] && [ ${FISH} -gt 0 ]; then
    FILE=$(find "${ROOT}/offline_fish_keys" -mindepth 1 -maxdepth 1 -type f | head -n 1)
    OWNER=$(stat -c "%U" "${FILE}")

    if [ "${FILE}" != "${OWNER}" ]; then
      # Check if sudo command exists
      if command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
      else
        SUDO_CMD=""
      fi

      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/zkapp_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/offline_fish_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/online_fish_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/offline_whale_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/online_whale_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/snark_coordinator_keys
      ${SUDO_CMD} chown -R "${OWNER}" "${ROOT}"/libp2p_keys
    fi
  fi

  chmod -R 0700 "${ROOT}"/zkapp_keys
  chmod -R 0700 "${ROOT}"/offline_fish_keys
  chmod -R 0700 "${ROOT}"/online_fish_keys
  chmod -R 0700 "${ROOT}"/offline_whale_keys
  chmod -R 0700 "${ROOT}"/online_whale_keys
  chmod -R 0700 "${ROOT}"/snark_coordinator_keys
  chmod -R 0700 "${ROOT}"/libp2p_keys
fi

printf "\n"
echo "================================"
printf "\n"

SNARK_COORDINATOR_PUBKEY=$(cat "${ROOT}"/snark_coordinator_keys/snark_coordinator_account.pub)

# ================================================
# Check the demo mode

if ${DEMO_MODE}; then
  echo "Demo mode requires no standalone whales, fish, plain nodes, or snark workers!"
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
    $([[ -n "$ARCHIVE_SERVER_PORT" ]] && echo 1 || echo 0) archive
    $([[ -n "$ROSETTA_PORT" ]] && echo 1 || echo 0) rosetta
    ${WHALES} whales
    ${FISH} fish
    ${NODES} non block-producing nodes
    Sending transactions: ${VALUE_TRANSFERS}
    Sending zkApp transactions: ${ZKAPP_TRANSACTIONS}

================================

EOF


# ================================================
# Update the Genesis State Timestamp or Reset the Genesis Ledger

CONFIG=${ROOT}/daemon.json

load_config() {
  local config_mode="${1}"
  local config_file="${2}"

  case "${config_mode}" in
    inherit)
      if [ ! -f "${config_file}" ]; then
        echo "Error: Config file '${config_file}' does not exist, can't inherit." >&2
        exit 1
      fi
      echo "Inheriting config file ${config_file}:"
      cat "${config_file}"
      ;;

    reset)
      echo "Making the Ledger..." 
      python3 scripts/mina-local-network/generate-mina-local-network-ledger.py \
        --num-whale-accounts "${WHALES}" \
        --num-fish-accounts "${FISH}" \
        --offline-whale-accounts-directory "${ROOT}"/offline_whale_keys \
        --offline-fish-accounts-directory "${ROOT}"/offline_fish_keys \
        --online-whale-accounts-directory "${ROOT}"/online_whale_keys \
        --online-fish-accounts-directory "${ROOT}"/online_fish_keys \
        --snark-coordinator-accounts-directory "${ROOT}"/snark_coordinator_keys \
        --out-genesis-ledger-file "${ROOT}"/genesis_ledger.json

      reset-genesis-ledger "${ROOT}" "${config_file}"
      echo "Using freshly generated config file ${config_file}:"
      cat "${config_file}"
      ;;
  esac
}

load_config "${CONFIG_MODE}" "${CONFIG}"

update_genesis_timestamp() {
  case "$1" in
    fixed:*)
      local timestamp="${1#fixed:}"
      echo "Updating Genesis State timestamp to ${timestamp}..."

      local overridden_unix
      overridden_unix=$(date -d "$timestamp" +%s)
      local now_unix
      now_unix=$(date +%s)

      # NOTE: while there's still race condition that before all nodes are 
      # spawned up we passed this instant, we should catch the improperly-set 
      # genesis timestamp in most scenarios
      if (( overridden_unix < now_unix )); then
        echo "Spawning a network with genesis $timestamp in the past!!"
        return 1
      fi
      jq-inplace ".genesis.genesis_state_timestamp=\"${timestamp}\"" "${CONFIG}"
      ;;
    delay_sec:*)
      local delay_sec="${1#delay_sec:}"
      local now
      now=$(date +%s)
      local timestamp
      timestamp=$(date -u -d "@$((now + delay_sec))" '+%F %H:%M:%S+00:00')
      echo "Updating Genesis State timestamp to ${timestamp}..."
      jq-inplace ".genesis.genesis_state_timestamp=\"${timestamp}\"" "${CONFIG}"
      ;;
    no)
      : ;;
    *)
      echo "Unknown UPDATE_GENESIS_TIMESTAMP value: $1" >&2
      return 1 ;;
  esac
}

update_genesis_timestamp "${UPDATE_GENESIS_TIMESTAMP}"

if [ ! -z "${OVERRIDE_SLOT_TIME_MS}" ]; then
  echo "Setting proof.block_window_duration_ms to ${OVERRIDE_SLOT_TIME_MS}..."
  jq-inplace ".proof.block_window_duration_ms=${OVERRIDE_SLOT_TIME_MS}" "${CONFIG}"
fi

if [ ! -z "${SLOT_TX_END}" ]; then
  echo "Setting daemon.slot_tx_end to ${SLOT_TX_END}..."
  jq-inplace ".daemon.slot_tx_end=${SLOT_TX_END}" "${CONFIG}"
fi

if [ ! -z "${SLOT_CHAIN_END}" ]; then
  echo "Setting daemon.slot_chain_end to ${SLOT_CHAIN_END}..."
  jq-inplace ".daemon.slot_chain_end=${SLOT_CHAIN_END}" "${CONFIG}"
fi

if [ ! -z "${HARDFORK_GENESIS_SLOT_DELTA}" ]; then
  echo "Setting daemon.hard_fork_genesis_slot_delta to ${HARDFORK_GENESIS_SLOT_DELTA}..."
  jq-inplace ".daemon.hard_fork_genesis_slot_delta=${HARDFORK_GENESIS_SLOT_DELTA}" "${CONFIG}"
fi

# ================================================
# Launch the Nodes

NODES_FOLDER=${ROOT}/nodes
mkdir -p ${NODES_FOLDER}/seed

mkdir -p "${NODES_FOLDER}"/snark_coordinator
mkdir -p "${NODES_FOLDER}"/snark_workers

if ! config_mode_is_inherit "$CONFIG_MODE"; then
  clean-dir "${NODES_FOLDER}"
  mkdir -p "${NODES_FOLDER}"/seed
  mkdir -p "${NODES_FOLDER}"/snark_coordinator
  mkdir -p "${NODES_FOLDER}"/snark_workers
fi

# ----------

if [[ -n "${ARCHIVE_SERVER_PORT}" ]]; then
  echo 'Starting the Archive Node...'
  printf "\n"

  mkdir -p "${NODES_FOLDER}"/archive

  spawn-archive-node "${NODES_FOLDER}"/archive
  ARCHIVE_PID=$!
fi

if [[ -n "${ROSETTA_PORT}" ]]; then
  if [[ -z "${ARCHIVE_SERVER_PORT}" ]]; then
    echo "Rosetta server requires Archive node to be running!"
    printf "\n"

    exit 1
  fi

  echo 'Starting the Rosetta server...'
  printf "\n"

  mkdir -p "${NODES_FOLDER}"/rosetta

  spawn-rosetta-server "${NODES_FOLDER}"/rosetta
  ROSETTA_PID=$!
fi

# ----------

SEED_PEER_ID=
case "${SEED}" in
  spawn:*)
    SEED_START_PORT="${SEED#spawn:}"
    SEED_PEER_ID="/ip4/127.0.0.1/tcp/$((SEED_START_PORT + 2))/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
    if ${DEMO_MODE}; then
      echo "Running in demo mode, an amalgamation node is going to be started."
      printf "\n"
      spawn-daemon seed ${NODES_FOLDER}/seed ${SEED_START_PORT} \
        -block-producer-key ${ROOT}/online_whale_keys/online_whale_account_0 \
        --run-snark-worker "$(cat ${ROOT}/snark_coordinator_keys/snark_coordinator_account.pub)" \
        --snark-worker-fee 0.001 \
        --demo-mode \
        --external-ip "$(hostname -i)" \
        --seed \
        ${ARCHIVE_ADDRESS_CLI_ARG}
    else
      spawn-daemon seed "${NODES_FOLDER}"/seed "${SEED_START_PORT}" -seed -libp2p-keypair ${SEED_PEER_KEY} "${ARCHIVE_ADDRESS_CLI_ARG}"
    fi
    SEED_PID=$!

    echo 'Waiting for seed to go up...'
    printf "\n"

    until ${MINA_EXE} client status -daemon-port "${SEED_START_PORT}" &>/dev/null; do
      sleep ${POLL_INTERVAL}
    done
    ;;

  at:*)
    if ${DEMO_MODE}; then
      echo "Running in demo mode, external seed is not supported!" >&2
      exit 1
    fi

    SEED_PEER_ID="${SEED#at:}"
    echo "Listening to external seed node at ${SEED_PEER_ID}"
    SEED_PID=""
    ;;
esac
printf "$SEED_PEER_ID" > "${ROOT}/seed_peer_id.txt"

#---------- Starting snark coordinator


if [[ -z "${SNARK_COORDINATOR_PORT}" ]]; then
  echo "Skipping snark coordinator because no SNARK_COORDINATOR_PORT is provided"
elif [ "${SNARK_WORKERS_COUNT}" -eq "0" ]; then
  echo "Skipping snark coordinator because SNARK_WORKERS_COUNT is 0"
  SNARK_COORDINATOR_PORT=""
fi

if [[ -n "${SNARK_COORDINATOR_PORT}" ]]; then
  SNARK_COORDINATOR_FLAGS="-snark-worker-fee ${SNARK_WORKER_FEE} -run-snark-coordinator ${SNARK_COORDINATOR_PUBKEY} -work-selection seq"
  spawn-daemon snark_coordinator "${NODES_FOLDER}"/snark_coordinator "${SNARK_COORDINATOR_PORT}" -peer ${SEED_PEER_ID} -libp2p-keypair ${SNARK_COORDINATOR_PEER_KEY} ${SNARK_COORDINATOR_FLAGS}
  SNARK_COORDINATOR_PID=$!
fi

# ----------

for ((i = 0; i < WHALES; i++)); do
  FOLDER=${NODES_FOLDER}/whale_${i}
  KEY_FILE=${ROOT}/online_whale_keys/online_whale_account_${i}
  mkdir -p "${FOLDER}"
  spawn-daemon "whale_${i}" "${FOLDER}" $((WHALE_START_PORT + i * 6)) -peer ${SEED_PEER_ID} -block-producer-key ${KEY_FILE} \
    -libp2p-keypair "${ROOT}"/libp2p_keys/whale_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  WHALE_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < FISH; i++)); do
  FOLDER=${NODES_FOLDER}/fish_${i}
  KEY_FILE=${ROOT}/online_fish_keys/online_fish_account_${i}
  mkdir -p "${FOLDER}"
  spawn-daemon "fish_${i}" "${FOLDER}" $((FISH_START_PORT + i * 6)) -peer ${SEED_PEER_ID} -block-producer-key "${KEY_FILE}" \
    -libp2p-keypair "${ROOT}"/libp2p_keys/fish_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  FISH_PIDS[${i}]=$!
done

# ----------

for ((i = 0; i < NODES; i++)); do
  FOLDER=${NODES_FOLDER}/node_${i}
  mkdir -p "${FOLDER}"
  spawn-daemon "plain_${i}" "${FOLDER}" $((NODE_START_PORT + i * 6)) -peer ${SEED_PEER_ID} \
    -libp2p-keypair "${ROOT}"/libp2p_keys/node_${i} "${ARCHIVE_ADDRESS_CLI_ARG}"
  NODE_PIDS[${i}]=$!
done

#---------- Starting snark workers


if [[ -n "${SNARK_COORDINATOR_PORT}" ]]; then
  echo 'Waiting for snark coordinator to go up before spawning snark workers...'
  printf "\n"

  until ${MINA_EXE} client status -daemon-port "${SNARK_COORDINATOR_PORT}" &>/dev/null; do
    sleep ${POLL_INTERVAL}
  done

  for ((i = 0; i < SNARK_WORKERS_COUNT; i++)); do
    FOLDER=${NODES_FOLDER}/snark_workers/worker_${i}
    mkdir -p "${FOLDER}"
    spawn-snark-worker "snark_worker_${i}" "${FOLDER}" "${SNARK_COORDINATOR_PORT}"
    SNARK_WORKERS_PIDS[${i}]=$!
  done
fi

# ================================================

cat <<EOF
================================
Network participants information:
EOF
if [[ -n "${SEED_PID}" ]]; then
  cat <<EOF
          Seed:
                  Instance #0:
                    pid ${SEED_PID}
                    status: ${MINA_EXE} client status -daemon-port ${SEED_START_PORT}
                    data dir: ${NODES_FOLDER}/seed
EOF
fi

if [ "${SNARK_WORKERS_COUNT}" -gt 0 ]; then
  cat <<EOF
	Snark Coordinator:
		Instance #0:
		  pid ${SNARK_COORDINATOR_PID}
		  status: ${MINA_EXE} client status -daemon-port ${SNARK_COORDINATOR_PORT}
		  data dir: ${NODES_FOLDER}/snark_coordinator

	Snark Workers:
EOF

  for ((i = 0; i < SNARK_WORKERS_COUNT; i++)); do
    cat <<EOF
		Instance #${i}:
		  pid ${SNARK_WORKERS_PIDS[${i}]}
		  data dir: ${NODES_FOLDER}/snark_workers/worker_${i}
EOF
  done
fi

if [[ -n "${ARCHIVE_SERVER_PORT}" ]]; then
  cat <<EOF
	Archive:
		Instance #0:
		  pid ${ARCHIVE_PID}
		  server-port: ${ARCHIVE_SERVER_PORT}
		  data dir: "${NODES_FOLDER}"/archive
EOF
fi

if [[ -n "${ROSETTA_PORT}" ]]; then
  cat <<EOF
  Rosetta:
    Instance #0:
      pid ${ROSETTA_PID}
      port: ${ROSETTA_PORT}
      data dir: "${NODES_FOLDER}"/rosetta
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
		  status: ${MINA_EXE} client status -daemon-port $((WHALE_START_PORT + i * 6))
		  data dir: ${NODES_FOLDER}/whale_${i}
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
		  status: ${MINA_EXE} client status -daemon-port $((FISH_START_PORT + i * 6))
		  data dir: ${NODES_FOLDER}/fish_${i}
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
		  status: ${MINA_EXE} client status -daemon-port $((NODE_START_PORT + i * 6))
		  data dir: ${NODES_FOLDER}/node_${i}
EOF
  done
fi

echo "================================"
printf "\n"

# ================================================
# Start sending transactions and zkApp transactions

if ${VALUE_TRANSFERS} || ${ZKAPP_TRANSACTIONS}; then

  VALID_TRANSFER_NODES=$((WHALES + FISH))

  if [ "$VALID_TRANSFER_NODES" -eq 0 ]; then
      echo "Error: No nodes available to send transactions."
      exit 1
  fi

  RANDOM_INDEX=$(( RANDOM % VALID_TRANSFER_NODES ))

  # Determine if the index falls into the Whale or Fish range
  if [ "$RANDOM_INDEX" -lt "$WHALES" ]; then
      TRANSFER_NODE_TYPE="whale"
      # For whales, the relative index is just the RANDOM_INDEX
      TRANSFER_NODE_INDEX="$RANDOM_INDEX"
      TRANSFER_PORT_BASE=$(( WHALE_START_PORT + TRANSFER_NODE_INDEX * 6 ))
      TRANFER_NODE_PID="${WHALE_PIDS[TRANSFER_NODE_INDEX]}"
  else
      TRANSFER_NODE_TYPE="fish" # Fixed variable name here
      TRANSFER_NODE_INDEX=$((RANDOM_INDEX - WHALES))
      # For fish, we subtract the whale count to get the 0-based fish index
      TRANSFER_PORT_BASE=$(( FISH_START_PORT + TRANSFER_NODE_INDEX * 6 ))
      TRANFER_NODE_PID="${FISH_PIDS[TRANSFER_NODE_INDEX]}"
  fi

  echo "Using ${TRANSFER_NODE_TYPE} at base port ${TRANSFER_PORT_BASE} to send transactions"


  FEE_PAYER_KEY_FILE=${ROOT}/offline_whale_keys/offline_whale_account_0
  SENDER_KEY_FILE=${ROOT}/offline_whale_keys/offline_whale_account_1
  if ${ZKAPP_TRANSACTIONS}; then
    ZKAPP_ACCOUNT_KEY_FILE=${ROOT}/zkapp_keys/zkapp_account
    ZKAPP_ACCOUNT_PUB_KEY=$(cat "${ROOT}/zkapp_keys/zkapp_account.pub")
  fi

  KEY_FILE="${ROOT}/online_${TRANSFER_NODE_TYPE}_keys/online_${TRANSFER_NODE_TYPE}_account_${TRANSFER_NODE_INDEX}"
  PUB_KEY=$(cat "${KEY_FILE}.pub")
  REST_SERVER="http://127.0.0.1:$((TRANSFER_PORT_BASE + 1))/graphql"

  echo "Waiting for Node (${REST_SERVER}) to be up to start sending value transfer transactions..."
  printf "\n"

  until ${MINA_EXE} client status -daemon-port "${TRANSFER_PORT_BASE}" &>/dev/null; do
    sleep ${POLL_INTERVAL}
  done

  SYNCED=0

  echo "Waiting for Node (${REST_SERVER})'s transition frontier to be up"
  printf "\n"

  set +e

  while [ $SYNCED -eq 0 ]; do
    SYNC_STATUS=$(curl -sS -g -X POST -H "Content-Type: application/json" -d '{"query":"query { syncStatus }"}' ${REST_SERVER})
    SYNCED=$(echo "${SYNC_STATUS}" | grep -c "SYNCED")
    sleep ${POLL_INTERVAL}
  done

  echo "Starting to send value transfer transactions/zkApp transactions every: ${TRANSACTION_INTERVAL} seconds"
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

    sleep "${TRANSACTION_INTERVAL}"
    ${MINA_EXE} client send-payment -rest-server ${REST_SERVER} -amount 1 -nonce 0 -receiver "${PUB_KEY}" -sender "${PUB_KEY}"
  fi

  fee_payer_nonce=1
  sender_nonce=1
  state=0

  # TODO: simulate scripts/hardfork/run-localnet.sh to send txns to everyone in the ledger.
  value_txn_id=0
  while is_process_running "${TRANFER_NODE_PID}"; do
    sleep ${TRANSACTION_INTERVAL}
    echo "${TRANSFER_NODE_TYPE} ${TRANSFER_NODE_INDEX} at ${TRANFER_NODE_PID} is alive, sending txns"

    if ${VALUE_TRANSFERS} && \
      ${MINA_EXE} client send-payment \
        -rest-server ${REST_SERVER} -amount 1 -receiver ${PUB_KEY} -sender ${PUB_KEY}; then
      echo "Sent value txn #$value_txn_id"
      value_txn_id=$((value_txn_id+1))
    else
      echo "Failed to send value txn #$value_txn_id"
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
