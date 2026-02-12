#!/usr/bin/env bash

# Rosetta Connectivity Test Script
#
# This script tests the connectivity and functionality of the Mina Rosetta API
# by running a Docker container with the Rosetta service and executing various tests.
#
# DESCRIPTION:
#   - Starts a Mina Rosetta Docker container with specified network configuration
#   - Runs sanity tests to verify basic connectivity and synchronization
#   - Optionally runs load tests to stress-test the Rosetta API
#   - Optionally runs compatibility tests to verify schema upgrade functionality
#   - Automatically cleans up Docker resources on completion or error
#
# REQUIREMENTS:
#   - Docker must be installed and running
#   - Script must be executed from the root of the mina repository
#   - rosetta-sanity.sh and rosetta-load.sh scripts must be available
#
# PARAMETERS:
#   -t, --tag           Docker image tag version (required)
#   -n, --network       Network configuration: devnet or mainnet (default: devnet)
#   --timeout           Timeout duration in seconds for tests (default: 900)
#   --run-load-test     Enable load testing (default: false)
#   --run-compatibility-test  Enable compatibility testing with specified branch
#   --upgrade-scripts-workdir  Working directory for upgrade/downgrade scripts (default: src/app/archive)
#   -h, --help          Display usage information
#
# EXAMPLES:
#   ./rosetta-connectivity.sh --tag 3.0.3-bullseye-devnet --network devnet
#   ./rosetta-connectivity.sh --tag 3.0.3 --network mainnet --run-load-test --timeout 1200
#   ./rosetta-connectivity.sh --tag 3.0.3 --run-compatibility-test develop
#   ./rosetta-connectivity.sh --tag 3.0.3 --run-compatibility-test develop --upgrade-scripts-workdir /custom/path
#
# EXIT CODES:
#   0 - Success
#   1 - Invalid parameters or missing required arguments
#
# NOTES:
#   - The script sets up error trapping to ensure Docker cleanup
#   - Container runs on port 3087 and mounts current directory as /workdir
#   - Load test duration is fixed at 600 seconds when enabled

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

NETWORK=devnet
TIMEOUT=900
DB_CONN_STR="postgres://pguser:pguser@localhost:5432/archive"
UPGRADE_SCRIPTS_WORKDIR="src/app/archive"

LOAD_TEST_DURATION=600
RUN_LOAD_TEST=false

USAGE="Usage: $0 [-t docker-tag] [-n network]
  -t, --version             The version to be used in the docker image tag
  -n, --network             The network configuration to use (devnet or mainnet). Default=$NETWORK
  --timeout                 The timeout duration in seconds. Default=$TIMEOUT
  --run-compatibility-test  Enable compatibility testing with specified branch
  --upgrade-scripts-workdir Working directory for upgrade/downgrade scripts. Default=$UPGRADE_SCRIPTS_WORKDIR
  -h, --help                Show help

Example: $0 --network devnet --tag 3.0.3-bullseye-devnet
Example: $0 --network devnet --tag 3.0.3 --run-compatibility-test develop
Example: $0 --network devnet --tag 3.0.3 --run-compatibility-test develop --upgrade-scripts-workdir /custom/path

Warning:
Please execute this script from the root of the mina repository.
"

function usage() {
    if [[ -n "$1" ]]; then
        echo -e "${RED}☞  $1${CLEAR}\n";
    fi
    echo "$USAGE"
}   

while [[ "$#" -gt 0 ]]; do case $1 in
    -n|--network) NETWORK="$2"; shift;;
    --run-load-test) RUN_LOAD_TEST=true ;;
    --run-compatibility-test) COMPATIBILITY_BRANCH="$2"; shift;;
    -t|--tag) TAG="$2"; shift;;
    -r|--repo) REPO="$2"; shift;;
    --timeout) TIMEOUT="$2"; shift;;
    --upgrade-scripts-workdir) UPGRADE_SCRIPTS_WORKDIR="$2"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done

if [[ "$NETWORK" != "devnet" && "$NETWORK" != "mainnet" ]]; then
    echo "❌  Invalid network: $NETWORK"
    echo "❌  Network must be either 'devnet' or 'mainnet'"
    echo ""
    usage; exit 1;
fi

if [[ -z "$REPO" ]]; then
    echo "❌  Docker repo is not set! Use -r or --repo to set it."
    echo ""
    usage; exit 1;
fi

if [[ -z "$TAG" ]]; then usage "Docker tag is not set!"; usage; exit 1; fi;

set -eox pipefail

container_id=$(docker run -v .:/workdir -p 3087:3087 -p 3085:3085 -d --env MINA_NETWORK=$NETWORK $REPO/mina-rosetta:$TAG-$NETWORK )

# Function to collect logs from the Docker container (called on exit or error)
collect_logs() {
    echo "========================= COLLECTING LOGS ==========================="
    mkdir -p test_output/artifacts

    # Container stdout/stderr (includes rosetta, archive output)
    docker logs "$container_id" > test_output/artifacts/container-stdout.log 2> test_output/artifacts/container-stderr.log

    # Copy top-level .log files from mina config directory (excludes binary LevelDB logs in subdirs)
    mkdir -p test_output/artifacts/mina-logs
    docker exec "$container_id" bash -c "cd /data/.mina-config && find . -maxdepth 1 -name '*.log' | tar -cf - -T -" | tar -xf - -C test_output/artifacts/mina-logs 2>/dev/null || true

    # Daemon status at end of test
    docker exec "$container_id" mina client status --json > test_output/artifacts/daemon-status.json 2>/dev/null || echo "Could not get daemon status" > test_output/artifacts/daemon-status.json

    echo "Logs collected in test_output/artifacts/"
}

stop_docker() {
        { docker stop "$container_id" ; docker rm "$container_id" ; } || true
}

cleanup() {
    local exit_code=$?
    # Only collect logs on failure
    if [[ $exit_code -ne 0 ]]; then
        collect_logs
    fi
    stop_docker
    exit $exit_code
}

trap cleanup EXIT

# Function to wait for new blocks
wait_for_new_blocks() {
        local previous_blocks=$1
        local test_name=$2
        local timeout_counter=0
        local max_wait=600  # 10 minutes

        echo "Waiting for new blocks after $test_name..."

        while [[ $timeout_counter -lt $max_wait ]]; do
                current_blocks=$(docker exec $container_id bash -c "psql $DB_CONN_STR -t -c 'SELECT COUNT(*) FROM blocks;'" | tr -d ' ')

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

# Function to execute upgrade/rollback operations
execute_script() {
        local script_path=$1
        local script_name=$2

        if docker exec $container_id bash -c "psql $DB_CONN_STR -f $script_path"; then
                echo "$script_name completed successfully."
                return 0
        else
                echo -e "${RED}$script_name failed.${CLEAR}"
                exit 1
        fi
}

# Wait for the container to start
sleep 5
#run sanity test
./scripts/tests/rosetta-sanity.sh --address "http://localhost:3087" --daemon-graphql-address "http://localhost:3085/graphql" --network $NETWORK --wait-for-sync --timeout $TIMEOUT

# Run load test
if [[ "$RUN_LOAD_TEST" == true ]]; then
        echo "Running load test for $LOAD_TEST_DURATION seconds..."
        if docker exec $container_id bash -c "/workdir/scripts/tests/rosetta-load.sh --address \"http://localhost:3087\" --db-conn-str $DB_CONN_STR --duration $LOAD_TEST_DURATION --network $NETWORK "; then
                echo -e "${GREEN}Load test completed successfully.${CLEAR}"
        else
                echo -e "${RED}Load test failed.${CLEAR}"
                exit 1
        fi
else
        echo "Skipping load test."
fi

# Run compatibility test
if [[ -n "${COMPATIBILITY_BRANCH:-}" ]]; then
        echo "Running compatibility test with branch: $COMPATIBILITY_BRANCH"

        upgrade_script_path="/etc/mina/archive/upgrade_to_mesa.sql"
        rollback_script_path="/etc/mina/archive/downgrade_to_berkeley.sql"

        # Get initial block count
        initial_blocks=$(docker exec $container_id bash -c "psql $DB_CONN_STR -t -c 'SELECT COUNT(*) FROM blocks;'" | tr -d ' ')

        # Test 1: Double upgrade test
        echo "Test 1: Running double upgrade test..."
        execute_script "$upgrade_script_path" "First upgrade"
        execute_script "$upgrade_script_path" "Second upgrade (should handle already upgraded state)"
        wait_for_new_blocks "$initial_blocks" "double upgrade"

        # Test 2: Rollback and upgrade test
        echo "Test 2: Running rollback and upgrade test..."
        execute_script "$rollback_script_path" "Rollback"
        rollback_blocks=$(docker exec $container_id bash -c "psql $DB_CONN_STR -t -c 'SELECT COUNT(*) FROM blocks;'" | tr -d ' ')
        execute_script "$upgrade_script_path" "Upgrade after rollback"
        wait_for_new_blocks "$rollback_blocks" "rollback and upgrade"

        # Test 3: Second rollback and upgrade test
        echo "Test 3: Running second rollback and upgrade test..."
        execute_script "$rollback_script_path" "Second rollback"
        second_rollback_blocks=$(docker exec $container_id bash -c "psql $DB_CONN_STR -t -c 'SELECT COUNT(*) FROM blocks;'" | tr -d ' ')
        execute_script "$upgrade_script_path" "Second upgrade after rollback"
        wait_for_new_blocks "$second_rollback_blocks" "second rollback and upgrade"

        echo -e "${GREEN}All compatibility tests completed successfully.${CLEAR}"
else
        echo "Skipping compatibility test."
fi

# cleanup is called automatically on EXIT via trap
