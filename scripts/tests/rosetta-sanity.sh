#!/bin/bash

# Rosetta Sanity Test Script
#
# This script performs comprehensive sanity tests on Mina Protocol's Rosetta API endpoints
# for both mainnet and devnet networks. It validates core functionality including network
# status, block retrieval, account balances, and transaction searches.
#
# USAGE:
#   ./rosetta-sanity.sh [OPTIONS]
#
# OPTIONS:
#   --network <mainnet|devnet>    Specify the network to test (default: mainnet)
#   --wait-for-sync               Wait for Rosetta node to sync before running tests
#   --timeout <seconds>           Timeout for sync wait in seconds (default: 900)
#   --address <url>               Override the default Rosetta endpoint address
#   --daemon-graphql-address <url> Override the default daemon GraphQL endpoint address
#   -h, --help                    Display this help message
#
# EXAMPLES:
#   ./rosetta-sanity.sh --network mainnet
#   ./rosetta-sanity.sh --network devnet --wait-for-sync --timeout 1200
#   ./rosetta-sanity.sh --address http://localhost:3087 --network mainnet
#   ./rosetta-sanity.sh --address http://localhost:3087 --daemon-graphql-address http://localhost:3085/graphql --network mainnet
#
# TEST COVERAGE:
#   1. Network status endpoint validation
#   2. Network options endpoint validation  
#   3. Block retrieval functionality
#   4. Account balance queries
#   5. Payment transaction searches
#   6. zkApp transaction searches
#
# DEPENDENCIES:
#   - rosetta-helper.sh (must be in the same directory)
#   - curl (for API requests)
#   - jq (for JSON processing)
#
# EXIT CODES:
#   0 - All tests passed successfully
#   1 - Test failure or invalid parameters
#
# AUTHOR: Mina Protocol Team
# VERSION: 1.0

NETWORK="mainnet"
WAIT_FOR_SYNC=false
TIMEOUT=900

declare -A mainnet
mainnet[id]="mainnet"
mainnet[block]="3NLaE5ygWrgssHjchYR7auQTZHveVV5au5cv5VhbWWYPdbdSm4FA"
mainnet[address]="http://rosetta-mainnet.gcp.o1test.net"
mainnet[daemon_graphql_address]="http://localhost:3085/graphql"
mainnet[account]="B62qrQKS9ghd91shs73TCmBJRW9GzvTJK443DPx2YbqcyoLc56g1ny9"
mainnet[payment_transaction]="5JvGLZ22Pt5co9ikFhHVcewsrGNx9xwPx16oKvJ42oujZRU7Ymfh"
mainnet[zkapp_transaction]="5Ju42hSKHMPFFuH2iar8V1scHdWET2TV8ocaazRbEea5yFWDe7RH"

declare -A devnet
devnet[id]="devnet"
devnet[address]="http://rosetta-devnet.gcp.o1test.net"
devnet[daemon_graphql_address]="http://localhost:3085/graphql"
devnet[block]="3NLX177ZPMRfgYX6sX6tEnhb97gvjWKiivk9Fk2q8M6vHHjAQPYk"
devnet[account]="B62qizKV19RgCtdosaEnoJRF72YjTSDyfJ5Nrdu8ygKD3q2eZcqUp7B"
devnet[payment_transaction]="5Jumdze53X3k8rVaNQpJKdt8voGXRgVcFBZugg21FE1K7QkJBhLb"
devnet[zkapp_transaction]="5JuJuyKtrMvxGroWyNE3sxwpuVsupvj7SA8CDX4mqWms4ZZT4Arz"


while [[ "$#" -gt 0 ]]; do
    case $1 in
        --network) NETWORK="$2"; shift ;;
        --wait-for-sync) WAIT_FOR_SYNC=true ;;
        --timeout) TIMEOUT="$2"; shift ;;
        --address)
                   # shellcheck disable=SC2034
                   mainnet[address]="$2"
                   # shellcheck disable=SC2034
                   devnet[address]="$2"
                   shift
                   ;;
        --daemon-graphql-address)
                   # shellcheck disable=SC2034
                   mainnet[daemon_graphql_address]="$2"
                   # shellcheck disable=SC2034
                   devnet[daemon_graphql_address]="$2"
                   shift
                   ;;
        -h|--help) echo "Usage: $0 [--network mainnet|devnet] [--address <address>] [--daemon-graphql-address <address>]"; exit 0 ;;
        *) echo "❌  Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/rosetta-helper.sh"

function run_tests_with_test_data() {
    declare -n __test_data=$1

    echo "🔗  Testing Rosetta sanity functionality for network: ${__test_data[id]} with address: ${__test_data[address]}"
    echo ""
    
    echo "🧪  1/6 Testing network/status endpoint"
    test_network_status "$1" || exit $?

    echo "🧪  2/6 Testing network/options endpoint"
    test_network_options "$1" || exit $?

    echo "🧪  3/6 Testing block endpoint"
    test_block "$1" || exit $?

    echo "🧪  4/6 Testing account/balance endpoint for account"
    test_account_balance "$1" || exit $?

    echo "🧪  5/6 Testing search/transactions endpoint for payment transaction"
    test_payment_transaction "$1" || exit $?

    echo "🧪  6/6 Testing search/transactions endpoint for zkapp transaction"
    test_zkapp_transaction "$1" || exit $?

    echo "🎉  All tests passed successfully!"
}

if [[ "$NETWORK" == "mainnet" ]]; then
    if [[ "$WAIT_FOR_SYNC" == "true" ]]; then
        echo "⏳  Waiting for Rosetta to sync on mainnet..."
        if ! wait_for_sync "mainnet" "$TIMEOUT"; then
            echo "❌  Failed to sync with mainnet within timeout period"
            exit 1
        fi
    fi
    run_tests_with_test_data "mainnet"
elif [[ "$NETWORK" == "devnet" ]]; then
    if [[ "$WAIT_FOR_SYNC" == "true" ]]; then
        echo "⏳  Waiting for Rosetta to sync on devnet..."
        if ! wait_for_sync "devnet" "$TIMEOUT"; then
            echo "❌  Failed to sync with devnet within timeout period"
            exit 1
        fi
    fi
    run_tests_with_test_data "devnet"
else
    echo "Unknown network: $NETWORK. available networks: mainnet, devnet. Exiting..."
    exit 1
fi
