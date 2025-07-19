#!/usr/bin/env bash

# Rosetta API Load Test Runner
#
# This script performs comprehensive load testing of the Rosetta API implementation
# for the Mina Protocol. It simulates various API calls at configurable intervals
# to test performance, stability, and correctness under sustained load.
#
# The script supports multiple test scenarios:
# - Network status and options queries
# - Block retrieval operations  
# - Account balance lookups
# - Payment transaction queries
# - zkApp transaction queries
#
# Test data is loaded from a PostgreSQL database containing blocks, accounts,
# and transactions to ensure realistic load patterns.
#
# Usage:
#   ./rosetta-load.sh [options]
#
# Example:
#   ./rosetta-load.sh --network mainnet --duration 300 --max-requests 1000
#   ./rosetta-load.sh --network devnet --address http://localhost:3087 --block-interval 5

set -euo pipefail

source "$(dirname "$0")/rosetta-helper.sh"

################################################################################
# Configuration Constants
################################################################################

# Default network to test against (mainnet or devnet)
readonly DEFAULT_NETWORK="mainnet"

# Default Rosetta API endpoint for mainnet
readonly DEFAULT_ADDRESS="http://rosetta-mainnet.gcp.o1test.net"

# Default PostgreSQL connection string for loading test data
readonly DEFAULT_DB_CONN_STR="postgresql://user:password@localhost/mina"

# Default interval (in seconds) for network status API calls
readonly DEFAULT_STATUS_INTERVAL="10"

# Default interval (in seconds) for network options API calls  
readonly DEFAULT_OPTIONS_INTERVAL="10"

# Default interval (in seconds) for block retrieval API calls
readonly DEFAULT_BLOCK_INTERVAL="2"

# Default interval (in seconds) for account balance API calls
readonly DEFAULT_ACCOUNT_BALANCE_INTERVAL="1"

# Default interval (in seconds) for payment transaction API calls
readonly DEFAULT_PAYMENT_TX_INTERVAL="2"

# Default interval (in seconds) for zkApp transaction API calls
readonly DEFAULT_ZKAPP_TX_INTERVAL="1"

# Statistics reporting interval (in seconds)
readonly STATS_REPORTING_INTERVAL="10"

# Maximum number of test data items to load from database
readonly MAX_TEST_DATA_ITEMS="100"

################################################################################
# Runtime Configuration Variables
################################################################################

NETWORK="$DEFAULT_NETWORK"
ADDRESS="$DEFAULT_ADDRESS"
DB_CONN_STR="$DEFAULT_DB_CONN_STR"
STATUS_INTERVAL="$DEFAULT_STATUS_INTERVAL"
OPTIONS_INTERVAL="$DEFAULT_OPTIONS_INTERVAL"
BLOCK_INTERVAL="$DEFAULT_BLOCK_INTERVAL"
ACCOUNT_BALANCE_INTERVAL="$DEFAULT_ACCOUNT_BALANCE_INTERVAL"
PAYMENT_TX_INTERVAL="$DEFAULT_PAYMENT_TX_INTERVAL"
ZKAPP_TX_INTERVAL="$DEFAULT_ZKAPP_TX_INTERVAL"

# Optional duration limit for test run (in seconds)
DURATION=""

# Optional maximum number of total requests before stopping
MAX_REQUESTS=""

################################################################################
# Help and Usage Functions
################################################################################

# Print usage information and command-line options
#
# This function displays comprehensive help text explaining all available
# command-line options, their default values, and usage examples.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None (exits with code 0)
function usage() {
    echo "Usage: $0 [--network mainnet|devnet] [--address <address>] [--db-conn-str <conn_str>] [--status-interval N] [--options-interval N] [--block-interval N] [--account-balance-interval N] [--payment-tx-interval N] [--zkapp-tx-interval N] [--duration <seconds>] [--max-requests N]"
    echo ""
    echo "Load test parameters:"
    echo "  --network <network>              Target network (mainnet or devnet, default: $DEFAULT_NETWORK)"
    echo "  --address <address>              Rosetta API endpoint (default: $DEFAULT_ADDRESS)"
    echo "  --db-conn-str <conn_str>         PostgreSQL connection string (default: $DEFAULT_DB_CONN_STR)"
    echo ""
    echo "Test intervals (in seconds):"
    echo "  --status-interval N              Network status API call interval (default: $DEFAULT_STATUS_INTERVAL)"
    echo "  --options-interval N             Network options API call interval (default: $DEFAULT_OPTIONS_INTERVAL)"
    echo "  --block-interval N               Block retrieval API call interval (default: $DEFAULT_BLOCK_INTERVAL)"
    echo "  --account-balance-interval N     Account balance API call interval (default: $DEFAULT_ACCOUNT_BALANCE_INTERVAL)"
    echo "  --payment-tx-interval N          Payment transaction API call interval (default: $DEFAULT_PAYMENT_TX_INTERVAL)"
    echo "  --zkapp-tx-interval N            zkApp transaction API call interval (default: $DEFAULT_ZKAPP_TX_INTERVAL)"
    echo ""
    echo "Stop conditions:"
    echo "  --duration <seconds>             Run for specified duration in seconds"
    echo "  --max-requests N                 Stop after N total requests"
    echo "  If neither is specified, runs indefinitely"
    echo ""
    echo "Examples:"
    echo "  $0 --network mainnet --duration 300 --max-requests 1000"
    echo "  $0 --network devnet --address http://localhost:3087 --block-interval 5"
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --address)
            ADDRESS="$2"
            shift 2
            ;;
        --db-conn-str)
            DB_CONN_STR="$2"
            shift 2
            ;;
        --status-interval)
            STATUS_INTERVAL="$2"
            shift 2
            ;;
        --options-interval)
            OPTIONS_INTERVAL="$2"
            shift 2
            ;;
        --block-interval)
            BLOCK_INTERVAL="$2"
            shift 2
            ;;
        --account-balance-interval)
            ACCOUNT_BALANCE_INTERVAL="$2"
            shift 2
            ;;
        --payment-tx-interval)
            PAYMENT_TX_INTERVAL="$2"
            shift 2
            ;;
        --zkapp-tx-interval)
            ZKAPP_TX_INTERVAL="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --max-requests)
            MAX_REQUESTS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "Running Rosetta load tests with the following parameters:"
echo "  Network: $NETWORK"
echo "  Address: $ADDRESS"
echo "  DB Connection String: $DB_CONN_STR"
if [[ -n "$DURATION" ]]; then
    echo "  Duration: ${DURATION}s"
fi
if [[ -n "$MAX_REQUESTS" ]]; then
    echo "  Max Requests: $MAX_REQUESTS"
fi

declare -A load
export load
load[id]=${NETWORK}
load[address]=${ADDRESS}

################################################################################
# Database Loading Functions
################################################################################

# Execute a SQL query and load results into the test data structure
#
# This is a helper function that executes a PostgreSQL query and stores
# the results in the global load associative array under the specified key.
# Results are stored as a space-separated string for easy iteration.
#
# Globals:
#   load (associative array) - Modified to store query results
#
# Arguments:
#   $1 - PostgreSQL connection string
#   $2 - SQL query to execute
#   $3 - Key name to store results under in load array
#
# Returns:
#   None (modifies global load array)
function load_from_db() {
    local conn_str="$1"
    local query="$2"
    local key="$3"
    local result
    result=$(psql "$conn_str" -Atc "$query")
    load["$key"]=$(echo "$result" | tr '\n' ' ')
}

# Load block state hashes from the database for testing
#
# Retrieves the first 100 block state hashes from the blocks table
# to use in block retrieval API tests. These hashes are used to
# make realistic block query requests during load testing.
#
# Globals:
#   load (associative array) - Modified to store block hashes
#
# Arguments:
#   $1 - PostgreSQL connection string
#
# Returns:
#   None (modifies global load array with 'blocks' key)
function load_blocks_from_db() {
    echo "Loading blocks from database..."
    load_from_db "$1" "SELECT state_hash FROM blocks LIMIT $MAX_TEST_DATA_ITEMS;" "blocks"
}

# Load account public keys from the database for testing
#
# Retrieves the first 100 public keys from the public_keys table
# to use in account balance API tests. These keys represent real
# accounts that can be queried during load testing.
#
# Globals:
#   load (associative array) - Modified to store account public keys
#
# Arguments:
#   $1 - PostgreSQL connection string
#
# Returns:
#   None (modifies global load array with 'accounts' key)
function load_accounts_from_db() {
    echo "Loading accounts from database..."
    load_from_db "$1" "SELECT value FROM public_keys LIMIT $MAX_TEST_DATA_ITEMS;" "accounts"
}

# Load payment transaction hashes from the database for testing
#
# Retrieves the first 100 payment transaction hashes from the user_commands
# table to use in payment transaction API tests. These represent real
# payment transactions that can be queried during load testing.
#
# Globals:
#   load (associative array) - Modified to store payment transaction hashes
#
# Arguments:
#   $1 - PostgreSQL connection string
#
# Returns:
#   None (modifies global load array with 'payment_transactions' key)
function load_payment_transactions_from_db() {
    echo "Loading payment transactions from database..."
    load_from_db "$1" "SELECT hash FROM user_commands LIMIT $MAX_TEST_DATA_ITEMS;" "payment_transactions"
}

# Load zkApp transaction hashes from the database for testing
#
# Retrieves the first 100 zkApp transaction hashes from the zkapp_commands
# table to use in zkApp transaction API tests. These represent real
# zkApp transactions that can be queried during load testing.
#
# Globals:
#   load (associative array) - Modified to store zkApp transaction hashes
#
# Arguments:
#   $1 - PostgreSQL connection string
#
# Returns:
#   None (modifies global load array with 'zkapp_transactions' key)
function load_zkapp_transactions_from_db() {
    echo "Loading zkapp transactions from database..."
    load_from_db "$1" "SELECT hash FROM zkapp_commands LIMIT $MAX_TEST_DATA_ITEMS;" "zkapp_transactions"
}


################################################################################
# Test Data Initialization
################################################################################

# Initialize global test data by loading from database
# This section creates the global associative array and populates it
# with test data from the PostgreSQL database.
declare -A load
export load
load[id]=${NETWORK}
load[address]=${ADDRESS}

# Load test data from database
load_blocks_from_db "$DB_CONN_STR" "blocks"
load_accounts_from_db "$DB_CONN_STR" "accounts"
load_payment_transactions_from_db "$DB_CONN_STR" "payment_transactions"
load_zkapp_transactions_from_db "$DB_CONN_STR" "zkapp_transactions"

################################################################################
# System Monitoring Functions
################################################################################

# Print current memory usage for relevant system processes
#
# This function monitors memory consumption of key processes involved
# in the Rosetta API infrastructure:
# - PostgreSQL database processes
# - Mina archive processes  
# - Mina Rosetta API processes
#
# Memory usage is calculated by summing RSS (Resident Set Size) values
# for all matching processes and converting from KB to MB.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None (prints memory usage to stdout)
function print_memory_usage() {
    echo "  📊 Memory Usage:"
    
    # PostgreSQL memory usage (sum of all postgres processes)
    local postgres_memory
    postgres_memory=$(ps -p $(pgrep -d, -f postgres) -o rss= 2>/dev/null | awk '{sum+=$1} END {print sum/1024}' 2>/dev/null)
    if [[ -n "$postgres_memory" ]]; then
        echo "   - 🐘 PostgreSQL: ${postgres_memory} MB"
    else
        echo "   - 🐘 PostgreSQL: N/A (not running)"
    fi
    
    # Mina-archive memory usage
    local archive_memory
    archive_memory=$(ps -p $(pgrep -f mina-archive) -o rss= 2>/dev/null | awk '{print $1/1024}' 2>/dev/null)
    if [[ -n "$archive_memory" ]]; then
        echo "   - 📦 Mina-archive: ${archive_memory} MB"
    else
        echo "   - 📦 Mina-archive: N/A (not running)"
    fi
    
    # Mina-rosetta memory usage (sum of all mina-rosetta processes)
    local rosetta_memory
    rosetta_memory=$(ps -p $(pgrep -d, -f mina-rosetta) -o rss= 2>/dev/null | awk '{sum+=$1} END {print sum/1024}' 2>/dev/null)
    if [[ -n "$rosetta_memory" ]]; then
        echo "   - 🌹 Mina-rosetta: ${rosetta_memory} MB"
    else
        echo "   - 🌹 Mina-rosetta: N/A (not running)"
    fi
}

# Print comprehensive load test performance statistics
#
# This function calculates and displays current and cumulative performance
# metrics for the load test, including:
# - Current TPS (transactions per second) since last report
# - Average TPS over the entire test duration
# - Total requests processed
# - Memory usage of system processes
#
# Globals:
#   None
#
# Arguments:
#   $1 - Current timestamp (float seconds since epoch)
#   $2 - Test start timestamp (float seconds since epoch)
#   $3 - Total number of requests processed
#   $4 - Number of requests since last metric report
#   $5 - Timestamp of last metric report
#   $6 - Optional: "true" to indicate final statistics report
#
# Returns:
#   None (prints statistics to stdout)
function print_load_test_statistics() {
    local now="$1"
    local start_time="$2"
    local total_requests="$3"
    local requests_since_last_metric="$4"
    local last_metric_time="$5"
    local is_final="${6:-false}"
    
    local elapsed_since_last
    elapsed_since_last=$(echo "$now - $last_metric_time" | bc)
    local current_tps
    current_tps=$(echo "scale=2; $requests_since_last_metric / $elapsed_since_last" | bc)
    local total_elapsed
    total_elapsed=$(echo "$now - $start_time" | bc)
    local average_tps
    average_tps=$(echo "scale=2; $total_requests / $total_elapsed" | bc)
    
    if [[ "$is_final" == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🏁 FINAL STATISTICS:"
        echo "  ⏱️  Total Duration: ${total_elapsed}s"
        echo "  📊 Total Requests: $total_requests"
        echo "  📈 Average TPS: $average_tps"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 🔄 Current TPS: $current_tps, 📈 Average TPS: $average_tps, 📊 Total Requests: $total_requests"
    fi
    print_memory_usage
}

################################################################################
# Load Test Execution Functions
################################################################################

# Execute comprehensive load testing with configurable intervals
#
# This is the main load testing function that orchestrates all API test calls
# at their specified intervals. It implements a precise timing system that
# ensures each test type runs at its configured frequency without drift.
#
# The function supports two stop conditions:
# - Duration-based: stops after specified number of seconds
# - Request-based: stops after specified number of total requests
#
# Test types and their functions:
# - Network status: test_network_status() - checks API health
# - Network options: test_network_options() - validates API capabilities  
# - Block retrieval: test_block() - queries random blocks
# - Account balance: test_account_balance() - checks random account balances
# - Payment transactions: test_payment_transaction() - queries random payments
# - zkApp transactions: test_zkapp_transaction() - queries random zkApp txs
#
# Globals:
#   DURATION - Optional duration limit in seconds
#   MAX_REQUESTS - Optional maximum request count
#
# Arguments:
#   $1 - Reference to associative array containing test data
#   $2 - Network status API call interval (seconds)
#   $3 - Network options API call interval (seconds)
#   $4 - Block retrieval API call interval (seconds)
#   $5 - Account balance API call interval (seconds)
#   $6 - Payment transaction API call interval (seconds)
#   $7 - zkApp transaction API call interval (seconds)
#
# Returns:
#   0 on successful completion
#   Exits with code 0 when stop conditions are met
function run_all_tests_custom_intervals() {
    declare -n __test_data=$1
    local status_interval=$2
    local options_interval=$3
    local block_interval=$4
    local account_balance_interval=$5
    local payment_tx_interval=$6
    local zkapp_tx_interval=$7

    # Next execution timestamps for each test type
    local status_next=0
    local options_next=0
    local block_next=0
    local account_balance_next=0
    local payment_tx_next=0
    local zkapp_tx_next=0
    local sleep_time=0.0

    # Select a random element from a space-separated string
    # This helper function is used to randomly select test data items
    # from the loaded database content.
    #
    # Arguments:
    #   $1 - Space-separated string of items
    #
    # Returns:
    #   Single randomly selected item from the input string
    pick_random() {
        local -a arr
        read -ra arr <<< "$1"
        echo "${arr[RANDOM % ${#arr[@]}]}"
    }

    # Initialize timing and metrics
    local start_time
    start_time=$(date +%s.%N)
    local total_requests=0
    local last_metric_time=$start_time
    local requests_since_last_metric=0

    echo "Starting load test with the following parameters:"
    echo "  Network: ${__test_data[id]}"
    echo "  Address: ${__test_data[address]}"
    echo "  Status Interval: ${status_interval}s"
    echo "  Options Interval: ${options_interval}s"
    echo "  Block Interval: ${block_interval}s"
    echo "  Account Balance Interval: ${account_balance_interval}s"
    echo "  Payment Transaction Interval: ${payment_tx_interval}s"
    echo "  zkApp Transaction Interval: ${zkapp_tx_interval}s"
    echo "  Duration: ${DURATION:-none}"
    echo "  Max Requests: ${MAX_REQUESTS:-none}"
    echo "  Statistics Reporting Interval: ${STATS_REPORTING_INTERVAL}s"
    echo "  Initial Memory Usage:"
    # Print initial memory usage before starting the load test
    print_memory_usage

    # Main load testing loop
    while true; do
        local now
        now=$(date +%s.%N)
        local requests_this_iteration=0

        # Check duration-based stop condition
        if [[ -n "$DURATION" ]]; then
            local elapsed
            elapsed=$(echo "$now - $start_time" | bc)
            if (( $(echo "$elapsed >= $DURATION" | bc -l) )); then
                echo "Duration limit reached (${DURATION}s). Stopping load test."
                print_load_test_statistics "$now" "$start_time" "$total_requests" "$requests_since_last_metric" "$last_metric_time" "true"
                exit 0
            fi
        fi

        # Check request-based stop condition
        if [[ -n "$MAX_REQUESTS" && $total_requests -ge $MAX_REQUESTS ]]; then
            echo "Request limit reached ($MAX_REQUESTS). Stopping load test."
            print_load_test_statistics "$now" "$start_time" "$total_requests" "$requests_since_last_metric" "$last_metric_time" "true"
            exit 0
        fi

        # Execute network status test if scheduled
        if (( $(echo "$now >= $status_next" | bc -l) )); then
            test_network_status "$1" || exit $?
            status_next=$(echo "$now + $status_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi
        
        # Execute network options test if scheduled
        if (( $(echo "$now >= $options_next" | bc -l) )); then
            test_network_options "$1" || exit $?
            options_next=$(echo "$now + $options_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi
        
        # Execute block retrieval test if scheduled
        if (( $(echo "$now >= $block_next" | bc -l) )); then
            local block_hash
            block_hash=$(pick_random "${__test_data[blocks]}")
            declare -A tmp_data
            tmp_data[block]="$block_hash"
            tmp_data[id]="${__test_data[id]}"
            tmp_data[address]="${__test_data[address]}"
            test_block tmp_data || exit $?
            block_next=$(echo "$now + $block_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi
        
        # Execute account balance test if scheduled
        if (( $(echo "$now >= $account_balance_next" | bc -l) )); then
            local account
            account=$(pick_random "${__test_data[accounts]}")
            declare -A tmp_data
            tmp_data[account]="$account"
            test_account_balance tmp_data || exit $?
            account_balance_next=$(echo "$now + $account_balance_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi
        
        # Execute payment transaction test if scheduled
        if (( $(echo "$now >= $payment_tx_next" | bc -l) )); then
            local payment_tx
            payment_tx=$(pick_random "${__test_data[payment_transactions]}")
            declare -A tmp_data
            tmp_data[payment_transaction]="$payment_tx"
            test_payment_transaction tmp_data || exit $?
            payment_tx_next=$(echo "$now + $payment_tx_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi
        
        # Execute zkApp transaction test if scheduled
        if (( $(echo "$now >= $zkapp_tx_next" | bc -l) )); then
            local zkapp_tx
            zkapp_tx=$(pick_random "${__test_data[zkapp_transactions]}")
            declare -A tmp_data
            #shellcheck disable=SC2034
            tmp_data[zkapp_transaction]="$zkapp_tx"
            test_zkapp_transaction tmp_data || exit $?
            zkapp_tx_next=$(echo "$now + $zkapp_tx_interval" | bc)
            requests_this_iteration=$((requests_this_iteration + 1))
        fi

        # Update request counters
        total_requests=$((total_requests + requests_this_iteration))
        requests_since_last_metric=$((requests_since_last_metric + requests_this_iteration))

        # Print performance statistics every X seconds
        if (( $(echo "$now - $last_metric_time >= $STATS_REPORTING_INTERVAL" | bc -l) )); then
            print_load_test_statistics "$now" "$start_time" "$total_requests" "$requests_since_last_metric" "$last_metric_time"
            last_metric_time=$now
            requests_since_last_metric=0
        fi

        # Brief pause to prevent excessive CPU usage
        sleep $sleep_time
    done
}

################################################################################
# Main Execution
################################################################################

# Execute the load test with configured parameters
# This starts the main load testing loop using all configured intervals
# and test data loaded from the database.
run_all_tests_custom_intervals load "$STATUS_INTERVAL" "$OPTIONS_INTERVAL" "$BLOCK_INTERVAL" "$ACCOUNT_BALANCE_INTERVAL" "$PAYMENT_TX_INTERVAL" "$ZKAPP_TX_INTERVAL"
