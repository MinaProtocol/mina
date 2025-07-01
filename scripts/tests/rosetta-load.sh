#!/usr/bin/env bash


# Load test runner for Rosetta API

source "$(dirname "$0")/rosetta-helper.sh"

# Example usage:
# ./rosetta-load.sh mainnet 2 5 10 15 20 25
# (network, status_interval, options_interval, block_interval, account_balance_interval, payment_tx_interval, zkapp_tx_interval)

NETWORK="mainnet"
ADDRESS="http://rosetta-mainnet.gcp.o1test.net"
DB_CONN_STR="postgresql://user:password@localhost/mina"
STATUS_INTERVAL="2"
OPTIONS_INTERVAL="5"
BLOCK_INTERVAL="10"
ACCOUNT_BALANCE_INTERVAL="15"
PAYMENT_TX_INTERVAL="20"
ZKAPP_TX_INTERVAL="25"

function usage() {
    echo "Usage: $0 [--network mainnet|devnet] [--address <address>] [--db-conn-str <conn_str>] [--status-interval N] [--options-interval N] [--block-interval N] [--account-balance-interval N] [--payment-tx-interval N] [--zkapp-tx-interval N]"
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

declare -A load
export load
load[id]=${NETWORK}
load[address]=${ADDRESS}

function load_from_db() {
    local conn_str="$1"
    local query="$2"
    local key="$3"
    local result
    result=$(psql "$conn_str" -Atc "$query")
    load["$key"]=$(echo "$result" | tr '\n' ' ')
}

function load_blocks_from_db() {
    # Load the first 100 blocks from the database
    echo "Loading blocks from database..."
    load_from_db "$1" "SELECT state_hash FROM blocks LIMIT 100;" "blocks"
}

function load_accounts_from_db() {
    # Load the first 100 public keys from the database
    echo "Loading accounts from database..."
    load_from_db "$1" "SELECT value FROM public_keys LIMIT 100;" "accounts"
}

function load_payment_transactions_from_db() {
    # Load the first 100 payment transaction hashes from the database
    echo "Loading payment transactions from database..."
    load_from_db "$1" "SELECT hash FROM user_commands LIMIT 100;" "payment_transactions"
}

function load_zkapp_transactions_from_db() {
    # Load the first 100 zkapp transaction hashes from the database
    echo "Loading zkapp transactions from database..."
    load_from_db "$1" "SELECT hash FROM zkapp_commands LIMIT 100;" "zkapp_transactions"
}


load_blocks_from_db "$DB_CONN_STR" "blocks"
load_accounts_from_db "$DB_CONN_STR" "accounts"
load_payment_transactions_from_db "$DB_CONN_STR" "payment_transactions"
load_zkapp_transactions_from_db "$DB_CONN_STR" "zkapp_transactions"

function run_all_tests_custom_intervals() {
    declare -n __test_data=$1
    local status_interval=$2
    local options_interval=$3
    local block_interval=$4
    local account_balance_interval=$5
    local payment_tx_interval=$6
    local zkapp_tx_interval=$7

    local status_next=0
    local options_next=0
    local block_next=0
    local account_balance_next=0
    local payment_tx_next=0
    local zkapp_tx_next=0

    # Helper to pick a random element from a space-separated string
    pick_random() {
        local arr=($1)
        echo "${arr[RANDOM % ${#arr[@]}]}"
    }

    while true; do
        local now=$(date +%s.%N)

        if (( $(echo "$now >= $status_next" | bc -l) )); then
            test_network_status "$1"
            status_next=$(echo "$now + $status_interval" | bc)
        fi
        if (( $(echo "$now >= $options_next" | bc -l) )); then
            test_network_options "$1"
            options_next=$(echo "$now + $options_interval" | bc)
        fi
        if (( $(echo "$now >= $block_next" | bc -l) )); then
            # Pick a random block
            local block_hash=$(pick_random "${__test_data[blocks]}")
            declare -A tmp_data
            tmp_data[block]="$block_hash"
            test_block tmp_data
            block_next=$(echo "$now + $block_interval" | bc)
        fi
        if (( $(echo "$now >= $account_balance_next" | bc -l) )); then
            # Pick a random account
            local account=$(pick_random "${__test_data[accounts]}")
            declare -A tmp_data
            tmp_data[account]="$account"
            test_account_balance tmp_data
            account_balance_next=$(echo "$now + $account_balance_interval" | bc)
        fi
        if (( $(echo "$now >= $payment_tx_next" | bc -l) )); then
            # Pick a random payment transaction
            local payment_tx=$(pick_random "${__test_data[payment_transactions]}")
            declare -A tmp_data
            tmp_data[payment_transaction]="$payment_tx"
            test_payment_transaction tmp_data
            payment_tx_next=$(echo "$now + $payment_tx_interval" | bc)
        fi
        if (( $(echo "$now >= $zkapp_tx_next" | bc -l) )); then
            # Pick a random zkapp transaction
            local zkapp_tx=$(pick_random "${__test_data[zkapp_transactions]}")
            declare -A tmp_data
            tmp_data[zkapp_transaction]="$zkapp_tx"
            test_zkapp_transaction tmp_data
            zkapp_tx_next=$(echo "$now + $zkapp_tx_interval" | bc)
        fi

        sleep 0.1
    done
}

run_all_tests_custom_intervals load "$STATUS_INTERVAL" "$OPTIONS_INTERVAL" "$BLOCK_INTERVAL" "$ACCOUNT_BALANCE_INTERVAL" "$PAYMENT_TX_INTERVAL" "$ZKAPP_TX_INTERVAL"
