#!/bin/bash

# Rosetta devnet/mainnet connectivity test, run from bare binaries.
#
# This replaces running scripts/tests/rosetta/rosetta-connectivity.sh against the
# prebuilt mina-rosetta docker image. That image is a packaging artifact: to get
# one, the test had to depend on the Debian build and the docker build, which is
# the entire reason those run on ordinary PRs and in nightly.
#
# Everything the image provided is reproduced here from the repository:
#
#   binaries      -> restored from the apps cache (mina / mina-archive /
#                    mina-rosetta / libp2p_helper), see restore-or-install.sh
#   network config-> genesis_ledgers/${MINA_NETWORK}.json, which is byte for byte
#                    what the mina-${network}-config deb installs as
#                    /var/lib/coda/${network}.json (scripts/debian/builder-helpers.sh,
#                    copy_common_daemon_configs)
#   archive schema-> src/app/archive/create_schema.sql
#   upgrade/downgrade SQL -> src/app/archive/{upgrade_to_mesa,downgrade_to_berkeley}.sql
#                    (the image had them under /etc/mina/archive)
#   postgres      -> a cluster created here, as the rosetta image's Dockerfile did
#
# The process layout (rosetta online+offline, archive, daemon, all on localhost)
# is the same one src/app/rosetta/scripts/docker-start.sh sets up inside the
# image, so the sanity/load/compatibility assertions are unchanged -- they just
# talk to processes on this host instead of through `docker exec`.
#
# Not reproduced: mina-missing-blocks-guardian. It backfills gaps from the
# precomputed-block bucket, and nothing this test asserts depends on it: the
# blocks it checks for are the ones the connected daemon writes as it follows
# the chain.
#
# Usage: connectivity.sh --network <devnet|mainnet> [options]

set -eo pipefail

NETWORK="devnet"
SYNC_TIMEOUT=900
NEW_BLOCK_TIMEOUT=600
LOAD_TEST_DURATION=600
RUN_LOAD_TEST=false
COMPATIBILITY_BRANCH=""
METRICS_MODE=""
BRANCH=""
COMMIT=""
PERF_OUTPUT_FILE="rosetta.perf"

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--network) NETWORK="$2"; shift;;
  --sync-timeout) SYNC_TIMEOUT="$2"; shift;;
  --new-block-timeout) NEW_BLOCK_TIMEOUT="$2"; shift;;
  --run-load-test) RUN_LOAD_TEST=true ;;
  --load-test-duration) LOAD_TEST_DURATION="$2"; shift;;
  --perf-output-file) PERF_OUTPUT_FILE="$2"; shift;;
  --run-compatibility-test) COMPATIBILITY_BRANCH="$2"; shift;;
  --metrics-mode) METRICS_MODE="--metrics-mode" ;;
  --branch) BRANCH="$2"; shift;;
  --commit) COMMIT="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [[ "$NETWORK" != "devnet" && "$NETWORK" != "mainnet" ]]; then
  echo "Invalid network: $NETWORK (must be devnet or mainnet)"
  exit 1
fi

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

export MINA_NETWORK="$NETWORK"
export LOG_LEVEL="${LOG_LEVEL:=Info}"

# Provision the binaries. Falls back to installing the debs when
# APPS_BARE_BINARIES is not set, so this script also works in a deb-based
# context (see restore-or-install.sh).
./buildkite/scripts/tests/rosetta/install-debs.sh

# `mina daemon` refuses to load the libp2p keypair when an ancestor directory is
# group/world readable. The toolchain image's $HOME is 0755; the mina-rosetta
# image ran as root with a 0700 $HOME.
chmod 700 "${HOME}"

# The network's runtime config, straight from the repo -- no config deb, no
# download. This is what makes the daemon join ${MINA_NETWORK}.
MINA_CONFIG_FILE="genesis_ledgers/${MINA_NETWORK}.json"
if [[ ! -f "$MINA_CONFIG_FILE" ]]; then
  echo "Genesis ledger ${MINA_CONFIG_FILE} not found; run this from the repo root."
  exit 1
fi
MINA_CONFIG_FILE="$(realpath "$MINA_CONFIG_FILE")"
export MINA_CONFIG_FILE

# Postgres
POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')
export POSTGRES_VERSION
export POSTGRES_USERNAME=${POSTGRES_USERNAME:=pguser}
export POSTGRES_DBNAME=${POSTGRES_DBNAME:=archive}
export POSTGRES_DATA_DIR=${POSTGRES_DATA_DIR:=/data/postgresql}
export PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

# Ports, matching src/app/rosetta/scripts/docker-start.sh so the assertions and
# the rosetta-cli/sanity defaults keep working unchanged.
export MINA_GRAPHQL_PORT=${MINA_GRAPHQL_PORT:=3085}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_ONLINE_PORT=${MINA_ROSETTA_ONLINE_PORT:=3087}
export MINA_ROSETTA_OFFLINE_PORT=${MINA_ROSETTA_OFFLINE_PORT:=3088}

export MINA_LIBP2P_HELPER_PATH=/usr/local/bin/libp2p_helper
export MINA_LIBP2P_KEYPAIR_PATH="${MINA_LIBP2P_KEYPAIR_PATH:=$HOME/libp2p-keypair}"
export MINA_LIBP2P_PASS=${MINA_LIBP2P_PASS:=''}
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=$HOME/.mina-config}"
export PEER_LIST_URL=${PEER_LIST_URL:=https://storage.googleapis.com/seed-lists/${MINA_NETWORK}_seeds.txt}

COLLECT_LOGS_DONE=0
collect_logs() {
  [ "$COLLECT_LOGS_DONE" = "1" ] && return 0
  COLLECT_LOGS_DONE=1

  echo "========================= COLLECTING LOGS ==========================="
  mkdir -p test_output/artifacts

  mina client status --json >test_output/artifacts/daemon-status.json 2>/dev/null \
    || echo "Could not get daemon status" >test_output/artifacts/daemon-status.json

  if [ -n "${DAEMON_PID:-}" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "Stopping daemon gracefully..."
    if ! mina client stop-daemon 2>/dev/null; then
      kill -TERM "$DAEMON_PID"
      sleep 2
    fi
  fi

  cp daemon-stdout.log daemon-stderr.log archive.log rosetta.log test_output/artifacts/ 2>/dev/null || true
  cp -r "${MINA_CONFIG_DIR}" test_output/artifacts/mina-config 2>/dev/null || true

  echo "Logs collected in test_output/artifacts/"
}

cleanup() {
  local exit_code=$?
  # Only collect logs on failure, as the docker-based script did.
  if [[ $exit_code -ne 0 ]]; then
    collect_logs
  fi
  exit $exit_code
}
trap cleanup EXIT

echo "========================= INITIALIZING POSTGRESQL ==========================="
# Cluster ops need root in the toolchain runner (the rosetta image ran as root).
sudo pg_ctlcluster "${POSTGRES_VERSION}" main start || true
sudo pg_dropcluster --stop "${POSTGRES_VERSION}" main || true
sudo mkdir -p "${POSTGRES_DATA_DIR}"
sudo chown postgres:postgres "${POSTGRES_DATA_DIR}"
sudo pg_createcluster --start -d "${POSTGRES_DATA_DIR}" \
  --createclusterconf ./src/app/rosetta/scripts/postgresql.conf "${POSTGRES_VERSION}" main
sudo -u postgres psql --command "CREATE USER ${POSTGRES_USERNAME} WITH SUPERUSER PASSWORD '${POSTGRES_USERNAME}';"
sudo -u postgres createdb -O "${POSTGRES_USERNAME}" "${POSTGRES_DBNAME}"
psql -f ./src/app/archive/create_schema.sql "${PG_CONN}"

echo "=========================== STARTING ROSETTA API ONLINE AND OFFLINE INSTANCES ==========================="
for port in "$MINA_ROSETTA_ONLINE_PORT" "$MINA_ROSETTA_OFFLINE_PORT"; do
  mina-rosetta \
    --archive-uri "${PG_CONN}" \
    --graphql-uri "http://127.0.0.1:${MINA_GRAPHQL_PORT}/graphql" \
    --log-level "${LOG_LEVEL}" \
    --port "${port}" >>rosetta.log 2>&1 &
  sleep 5
done

echo "========================= STARTING ARCHIVE NODE on PORT ${MINA_ARCHIVE_PORT} ==========================="
mina-archive run \
  --postgres-uri "${PG_CONN}" \
  --log-level "${LOG_LEVEL}" \
  --server-port "${MINA_ARCHIVE_PORT}" >>archive.log 2>&1 &
sleep 5

echo "=========================== GENERATING KEYPAIR IN ${MINA_LIBP2P_KEYPAIR_PATH} ==========================="
mina libp2p generate-keypair -privkey-path "${MINA_LIBP2P_KEYPAIR_PATH}"

echo "========================= STARTING DAEMON connected to ${MINA_NETWORK} ==========================="
mina daemon \
  --config-file "${MINA_CONFIG_FILE}" \
  --config-dir "${MINA_CONFIG_DIR}" \
  --libp2p-keypair "${MINA_LIBP2P_KEYPAIR_PATH}" \
  --peer-list-url "${PEER_LIST_URL}" \
  --rest-port "${MINA_GRAPHQL_PORT}" \
  -archive-address "127.0.0.1:${MINA_ARCHIVE_PORT}" \
  -insecure-rest-server \
  --log-level "${LOG_LEVEL}" \
  >daemon-stdout.log 2>daemon-stderr.log &
DAEMON_PID=$!
echo "Daemon started with PID: ${DAEMON_PID}"

sleep 30
if ! kill -0 "${DAEMON_PID}" 2>/dev/null; then
  echo -e "${RED}Mina daemon failed to start${CLEAR}"
  exit 1
fi

# Wait for new blocks to land in the archive database.
wait_for_new_blocks() {
  local previous_blocks=$1
  local test_name=$2
  local timeout_counter=0

  echo "Waiting for new blocks after $test_name..."
  while [[ $timeout_counter -lt $NEW_BLOCK_TIMEOUT ]]; do
    current_blocks=$(psql "$PG_CONN" -t -c 'SELECT COUNT(*) FROM blocks;' | tr -d ' ')
    if [[ "$current_blocks" -gt "$previous_blocks" ]]; then
      echo -e "${GREEN}New blocks detected after $test_name. Test passed.${CLEAR}"
      return 0
    fi
    sleep 10
    timeout_counter=$((timeout_counter + 10))
  done

  echo -e "${RED}Timeout waiting for new blocks after $test_name. Test failed.${CLEAR}"
  exit 1
}

execute_script() {
  local script_path=$1
  local script_name=$2

  if psql "$PG_CONN" -f "$script_path"; then
    echo "$script_name completed successfully."
  else
    echo -e "${RED}$script_name failed.${CLEAR}"
    exit 1
  fi
}

echo "========================= ROSETTA SANITY TEST ==========================="
./scripts/tests/rosetta/rosetta-sanity.sh \
  --address "http://localhost:${MINA_ROSETTA_ONLINE_PORT}" \
  --daemon-graphql-address "http://localhost:${MINA_GRAPHQL_PORT}/graphql" \
  --network "$MINA_NETWORK" \
  --wait-for-sync \
  --timeout "$SYNC_TIMEOUT"

if [[ "$RUN_LOAD_TEST" == true ]]; then
  echo "========================= ROSETTA LOAD TEST ==========================="
  # Runs in this shell rather than through `docker exec`; its pgrep/ps memory
  # sampling now sees the archive and rosetta processes directly.
  load_test_args=(
    --address "http://localhost:${MINA_ROSETTA_ONLINE_PORT}"
    --db-conn-str "$PG_CONN"
    --duration "$LOAD_TEST_DURATION"
    --network "$MINA_NETWORK"
    --perf-output-file "$PERF_OUTPUT_FILE"
  )
  [[ -n "$METRICS_MODE" ]] && load_test_args+=("$METRICS_MODE")
  [[ -n "$BRANCH" ]] && load_test_args+=(--branch "$BRANCH")
  [[ -n "$COMMIT" ]] && load_test_args+=(--commit "$COMMIT")

  if ./scripts/tests/rosetta/rosetta-load.sh "${load_test_args[@]}"; then
    echo -e "${GREEN}Load test completed successfully.${CLEAR}"
  else
    echo -e "${RED}Load test failed.${CLEAR}"
    exit 1
  fi
else
  echo "Skipping load test."
fi

if [[ -n "$COMPATIBILITY_BRANCH" ]]; then
  echo "========================= SCHEMA COMPATIBILITY TEST ==========================="
  echo "Running compatibility test with branch: $COMPATIBILITY_BRANCH"

  # In-repo copies of what the image shipped under /etc/mina/archive.
  upgrade_script_path="./src/app/archive/upgrade_to_mesa.sql"
  rollback_script_path="./src/app/archive/downgrade_to_berkeley.sql"

  initial_blocks=$(psql "$PG_CONN" -t -c 'SELECT COUNT(*) FROM blocks;' | tr -d ' ')

  echo "Test 1: Running double upgrade test..."
  execute_script "$upgrade_script_path" "First upgrade"
  execute_script "$upgrade_script_path" "Second upgrade (should handle already upgraded state)"
  wait_for_new_blocks "$initial_blocks" "double upgrade"

  echo "Test 2: Running rollback and upgrade test..."
  execute_script "$rollback_script_path" "Rollback"
  rollback_blocks=$(psql "$PG_CONN" -t -c 'SELECT COUNT(*) FROM blocks;' | tr -d ' ')
  execute_script "$upgrade_script_path" "Upgrade after rollback"
  wait_for_new_blocks "$rollback_blocks" "rollback and upgrade"

  echo "Test 3: Running second rollback and upgrade test..."
  execute_script "$rollback_script_path" "Second rollback"
  second_rollback_blocks=$(psql "$PG_CONN" -t -c 'SELECT COUNT(*) FROM blocks;' | tr -d ' ')
  execute_script "$upgrade_script_path" "Second upgrade after rollback"
  wait_for_new_blocks "$second_rollback_blocks" "second rollback and upgrade"

  echo -e "${GREEN}All compatibility tests completed successfully.${CLEAR}"
else
  echo "Skipping compatibility test."
fi

echo -e "${GREEN}Rosetta ${MINA_NETWORK} connectivity test passed.${CLEAR}"
