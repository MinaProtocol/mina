#!/usr/bin/env bash

# Daemon Docker Sync and Shutdown Test
#
# Tests that a Mina daemon Docker container can sync to the network and shut
# down cleanly. After syncing, `docker stop` is sent and the container's exit
# code is verified to be 130 (the daemon's signal handler exit code).
#
# DESCRIPTION:
#   - Starts a Mina daemon container connected to the specified network
#   - Waits for the daemon to sync (sync status and best tip freshness check)
#   - Sends `docker stop` and asserts the container exit code is 130
#
# REQUIREMENTS:
#   - Docker must be installed and running
#
# PARAMETERS:
#   -t, --tag       Docker image tag (required)
#   -r, --repo      Docker image repo (required)
#   -n, --network   Network configuration: devnet or mainnet (default: devnet)
#   --timeout       Sync timeout in seconds (default: 900)
#   -h, --help      Display usage information
#
# EXAMPLES:
#   ./daemon-docker-sync.sh -r gcr.io/o1labs-192920/mina-daemon -t 3.3.1-7b34378-bullseye-devnet -n devnet
#
# EXIT CODES:
#   0 - Success (daemon synced and exited with code 130 after docker stop)
#   1 - Failure (sync timeout, wrong exit code, or other error)

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

NETWORK=devnet
TIMEOUT=900

USAGE="Usage: $0 -r repo -t tag [-n network] [--timeout seconds]
  -t, --tag       Docker image tag (required)
  -r, --repo      Docker image repo (required)
  -n, --network   Network configuration: devnet or mainnet (default: $NETWORK)
  --timeout        Sync timeout in seconds (default: $TIMEOUT)
  -h, --help      Show help

Example: $0 -r gcr.io/o1labs-192920/mina-daemon -t 3.3.1-7b34378-bullseye-devnet -n devnet
"

function usage() {
    if [[ -n "$1" ]]; then
        echo -e "${RED}$1${CLEAR}\n";
    fi
    echo "$USAGE"
}

while [[ "$#" -gt 0 ]]; do case $1 in
    -t|--tag) TAG="$2"; shift;;
    -r|--repo) REPO="$2"; shift;;
    -n|--network) NETWORK="$2"; shift;;
    --timeout) TIMEOUT="$2"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done

if [[ "$NETWORK" != "devnet" && "$NETWORK" != "mainnet" ]]; then
    echo "Invalid network: $NETWORK (must be devnet or mainnet)"
    usage; exit 1
fi

if [[ -z "$REPO" ]]; then
    usage "Docker repo is not set! Use -r or --repo to set it."
    exit 1
fi

if [[ -z "$TAG" ]]; then
    usage "Docker tag is not set! Use -t or --tag to set it."
    exit 1
fi

IMAGE="$REPO/mina-daemon:$TAG"
# Note: the expected exit code matches what the daemon currently ought to
# produce if it shuts down cleanly in response to `docker stop`. This code is
# the usual exit code for SIGINT. I'd argue it should actually be 0. This will
# need to be adjusted if that daemon behaviour is changed.
EXPECTED_EXIT_CODE=130
 # How far in the past the daemon's best tip must be before it's considered too
 # old. The daemon has some issues related to establishing a frontier at
 # genesis, so we include this just to make sure the daemon's "synced" status is
 # plausible.
BEST_TIP_AGE_THRESHOLD_MS=$((4 * 60 * 60 * 1000))

echo "=== Daemon Docker Stop Test ==="
echo "Image:   $IMAGE"
echo "Network: $NETWORK"
echo "Timeout: ${TIMEOUT}s"

# --- Start daemon container ---

echo ""
echo "Starting daemon container..."
container_id=$(docker run -d \
    --env PEER_LIST_URL="https://storage.googleapis.com/seed-lists/${NETWORK}_seeds.txt" \
    "$IMAGE" \
    daemon)

echo "Container started: $container_id"

# --- Stream docker logs to files ---

mkdir -p test_output/artifacts
docker logs --follow "$container_id" > test_output/artifacts/container-stdout.log 2> test_output/artifacts/container-stderr.log &
docker_logs_pid=$!

# --- Cleanup trap ---

# Copy daemon log files out of the (stopped) container. This uses docker cp
# instead of a volume mount because volume mounts don't work reliably when the
# test runs inside a CI container that shares a Docker socket with the host.
copy_logs_from_container() {
    mkdir -p test_output/artifacts/mina-logs
    docker cp "$container_id:/root/.mina-config/" test_output/artifacts/mina-config/ 2>/dev/null || true
}

check_daemon_logs() {
    copy_logs_from_container

    local log_files
    log_files=(test_output/artifacts/mina-config/mina.log*)
    if [[ ! -e "${log_files[0]}" ]]; then
        echo "Warning: no daemon log files found in container"
        return 0
    fi

    local fatal_lines
    fatal_lines=$(grep '"level":"Fatal"' "${log_files[@]}" || true)
    if [[ -n "$fatal_lines" ]]; then
        echo -e "${RED}Fatal errors found in daemon logs:${CLEAR}"
        echo "$fatal_lines"
        return 1
    fi

    echo "No Fatal errors found in daemon logs."
    return 0
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        copy_logs_from_container
    fi
    kill "$docker_logs_pid" 2>/dev/null; wait "$docker_logs_pid" 2>/dev/null || true
    { docker stop "$container_id" 2>/dev/null; docker rm "$container_id" 2>/dev/null; } || true
    exit $exit_code
}
trap cleanup EXIT

# --- Sync check function ---

# Queries the daemon's GraphQL endpoint for sync status and best tip freshness.
# Returns 0 if the daemon reports SYNCED and the best tip is fresh, 1 otherwise.
# Prints a status message on each call.
check_daemon_synced() {
    local response
    response=$(docker exec "$container_id" curl --no-progress-meter --request POST \
        "http://localhost:3085/graphql" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data-raw '{"query":"{ syncStatus, bestChain(maxLength: 1) { protocolState { blockchainState { utcDate } } } }"}' 2>/dev/null) || true

    if [[ -z "$response" ]]; then
        echo "GraphQL endpoint not available yet. Waiting..."
        return 1
    fi

    local sync_status
    sync_status=$(echo "$response" | jq -r '.data.syncStatus' 2>/dev/null) || true

    if [[ "$sync_status" != "SYNCED" ]]; then
        echo "Daemon sync status: ${sync_status:-unknown}. Waiting..."
        return 1
    fi

    local best_tip_timestamp_ms
    best_tip_timestamp_ms=$(echo "$response" | jq -r '.data.bestChain[0].protocolState.blockchainState.utcDate' 2>/dev/null) || true

    if [[ -z "$best_tip_timestamp_ms" || "$best_tip_timestamp_ms" == "null" ]]; then
        echo "Daemon reports SYNCED but no best tip yet. Waiting..."
        return 1
    fi

    local current_timestamp_ms time_since_best_tip_ms
    current_timestamp_ms=$(( $(date +%s) * 1000 ))
    time_since_best_tip_ms=$(( current_timestamp_ms - best_tip_timestamp_ms ))

    if [[ $time_since_best_tip_ms -lt $BEST_TIP_AGE_THRESHOLD_MS ]]; then
        echo -e "${GREEN}Daemon is synced (best tip is ${time_since_best_tip_ms}ms old)${CLEAR}"
        return 0
    else
        echo "Daemon reports SYNCED but best tip is stale (${time_since_best_tip_ms}ms old, threshold: ${BEST_TIP_AGE_THRESHOLD_MS}ms). Waiting..."
        return 1
    fi
}

# --- Wait for sync ---

echo ""
echo "Waiting for daemon to sync (timeout: ${TIMEOUT}s)..."

start_time=$(date +%s)
end_time=$((start_time + TIMEOUT))

while true; do
    # Check that the container is still running
    container_running=$(docker inspect --format='{{.State.Running}}' "$container_id" 2>/dev/null) || true
    if [[ "$container_running" != "true" ]]; then
        echo -e "${RED}Container is no longer running!${CLEAR}"
        actual_exit=$(docker inspect --format='{{.State.ExitCode}}' "$container_id" 2>/dev/null) || true
        echo "Container exit code: $actual_exit"
        tail -10 test_output/artifacts/container-stdout.log 2>/dev/null || true
        exit 1
    fi

    if check_daemon_synced; then
        break
    fi

    if [[ $(date +%s) -gt $end_time ]]; then
        echo -e "${RED}Timeout reached. Daemon did not sync within ${TIMEOUT}s${CLEAR}"
        exit 1
    fi

    sleep 30
done

# --- Stop container and check exit code ---

echo ""
echo "Stopping container..."
docker stop "$container_id"
exit_code=$(docker wait "$container_id")

echo "Container exit code: $exit_code (expected: $EXPECTED_EXIT_CODE)"

echo ""
echo "Checking daemon logs for Fatal errors..."
check_daemon_logs || exit 1

if [[ "$exit_code" -eq "$EXPECTED_EXIT_CODE" ]]; then
    echo -e "${GREEN}PASS: Container exited with expected code $EXPECTED_EXIT_CODE${CLEAR}"
else
    # Some unexpected error codes we might see here:
    # 143 - SIGTERM, likely from the `docker stop` signal not being handled properly
    # 137 - SIGKILL, likely from `docker stop` timing out and forcibly killing the daemon
    echo -e "${RED}FAIL: Container exited with code $exit_code, expected $EXPECTED_EXIT_CODE${CLEAR}"
    echo ""
    echo "Last 10 lines of container logs:"
    tail -10 test_output/artifacts/container-stdout.log 2>/dev/null || true
    # Docker container cleanup handled in exit trap
    exit 1
fi
