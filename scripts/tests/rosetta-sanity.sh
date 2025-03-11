#!/bin/bash

NETWORK="mainnet"
BLOCKCHAIN="mina"
WAIT_FOR_SYNC=false
TIMEOUT=900

declare -A mainnet
mainnet[id]="mainnet"
mainnet[block]="3NLaE5ygWrgssHjchYR7auQTZHveVV5au5cv5VhbWWYPdbdSm4FA"
mainnet[address]="http://rosetta-mainnet.gcp.o1test.net"
mainnet[account]="B62qrQKS9ghd91shs73TCmBJRW9GzvTJK443DPx2YbqcyoLc56g1ny9"
mainnet[payment_transaction]="5JvGLZ22Pt5co9ikFhHVcewsrGNx9xwPx16oKvJ42oujZRU7Ymfh"
mainnet[zkapp_transaction]="5Ju42hSKHMPFFuH2iar8V1scHdWET2TV8ocaazRbEea5yFWDe7RH"

declare -A devnet
devnet[id]="devnet"
devnet[address]="http://rosetta-devnet.gcp.o1test.net"
devnet[block]="3NLX177ZPMRfgYX6sX6tEnhb97gvjWKiivk9Fk2q8M6vHHjAQPYk"
devnet[account]="B62qizKV19RgCtdosaEnoJRF72YjTSDyfJ5Nrdu8ygKD3q2eZcqUp7B"
devnet[payment_transaction]="5Jumdze53X3k8rVaNQpJKdt8voGXRgVcFBZugg21FE1K7QkJBhLb"
devnet[zkapp_transaction]="5JuJuyKtrMvxGroWyNE3sxwpuVsupvj7SA8CDX4mqWms4ZZT4Arz"

DEFAULT_HEADERS=(--header "Accept: application/json" --header "Content-Type: application/json")

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --network) NETWORK="$2"; shift ;;
        --wait-for-sync) WAIT_FOR_SYNC=true ;;
        --timeout) TIMEOUT="$2"; shift ;;
        --address) mainnet[address]="$2"
                   devnet[address]="$2"
                   shift
                   ;;
        -h|--help) echo "Usage: $0 [--network mainnet|devnet] [--address <address>]"; exit 0 ;;
        *) echo "❌  Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

function assert() {
    local __response=$1
    local __query=$2
    local __success_message=$3
    local __error_message=$4
    

    if echo $__response | jq "if ($__query) then true else false end" | grep -q true; then
        echo "$__success_message"
    else
        echo "$__error_message"

        echo "   Response:"
        echo "      $( echo $__response | jq)"
        exit 1
    fi

}


function wait_for_sync() {
    declare -n __test_data=$1

    echo "⏳  Waiting for rosetta to sync..."
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local sync_status=""

    while true; do
        sync_status=$(curl --no-progress-meter --request POST "${__test_data[address]}/network/status" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" 2> /dev/null | jq '.sync_status.stage')
        if [[ "$sync_status" == "\"Synced\"" ]]; then
            echo "✅  Rosetta is synced"
            break
        elif [[ "$sync_status" == "" ]]; then
            echo "ℹ️  Rosetta is in bootstrap stage"
        else 
            echo "ℹ️  Rosetta is $sync_status stage"
        fi

        if [[ $(date +%s) -gt $end_time ]]; then
            echo "❌  Timeout reached. Rosetta did not sync within $TIMEOUT seconds"
            exit 1
        fi

        echo "⏳  Rosetta is not synced yet. Waiting till $(printf '%(%FT%T)T\n' $end_time). Retrying in 30 seconds..."

        sleep 30
    done
}

function run_tests_with_test_data() {
    declare -n __test_data=$1

    echo "🔗  Testing Rosetta sanity functionality for network: ${__test_data[id]}"
    echo ""
    
    echo "🧪  1/6 Testing network/status endpoint"

    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/network/status" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" | jq)" \
        '.sync_status.stage == "Synced"' \
        "   ✅  Rosetta is synced" \
        "   ❌  Rosetta is not synced"
    
    echo "🧪  2/6 Testing network/options endpoint"
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/network/options" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" | jq)" \
        '.version.rosetta_version == "1.4.9"' \
        "   ✅  Rosetta Version is not correct" \
        "   ❌  Invalid Rosetta Version (expected 1.4.9)"

    echo "🧪  3/6 Testing network/list endpoint"
    
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/block" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"},\"block_identifier\":{\"hash\":\"${__test_data[block]}\"}}" | jq)" \
        ".block.block_identifier.hash == \"${__test_data[block]}\" " \
        "   ✅  Block hash correct" \
        "   ❌  Block hash incorrect or not found (expected ${__test_data[block]})"

    echo "🧪  4/6 Testing account/balance endpoint for account"

    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/account/balance" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"},\"account_identifier\":{\"address\":\"${__test_data[account]}\"}}" | jq)" \
        '.balances[0].currency.symbol == "MINA"' \
        "   ✅  Account: Balance for ok" \
        "   ❌  Account: Invalid balance structure or balance not found"

    echo "🧪  5/6 Testing search/transactions endpoint for payment transaction"

    assert "$(curl --no-progress-meter --location "${__test_data[address]}/search/transactions" --header 'Content-Type: application/json' --data "{
        \"network_identifier\": {
            \"blockchain\": \"$BLOCKCHAIN\",
            \"network\": \"${__test_data[id]}\"
        },
        \"transaction_identifier\": {
            \"hash\": \"${__test_data[payment_transaction]}\"
        }
    }" | jq)" \
        ".transactions[0].transaction.transaction_identifier.hash == \"${__test_data[payment_transaction]}\" " \
        "   ✅  Payment transaction found" \
        "   ❌  Payment transaction not found (expected ${__test_data[payment_transaction]})"

    echo "🧪  6/6 Testing search/transactions endpoint for zkapp transaction"
    
    assert "$(curl --no-progress-meter --location "${__test_data[address]}/search/transactions" --header 'Content-Type: application/json' --data "{
        \"network_identifier\": {
            \"blockchain\": \"$BLOCKCHAIN\",
            \"network\": \"${__test_data[id]}\"
        },
        \"transaction_identifier\": {
            \"hash\": \"${__test_data[zkapp_transaction]}\"
        }
    }" | jq)" \
        ".transactions[0].transaction.transaction_identifier.hash == \"${__test_data[zkapp_transaction]}\" " \
        "   ✅  Zkapp transaction found" \
        "   ❌  Zkapp transaction not found (expected ${__test_data[zkapp_transaction]})"

    echo "🎉  All tests passed successfully!"
}

if [[ "$WAIT_FOR_SYNC" == "true" ]]; then
    if [[ "$NETWORK" == "mainnet" ]]; then
        wait_for_sync "mainnet"
    elif [[ "$NETWORK" == "devnet" ]]; then
        wait_for_sync "devnet"
    else
        echo "Unknown network: $NETWORK. available networks: mainnet, devnet. Exiting..."
        exit 1
    fi
fi

if [[ "$NETWORK" == "mainnet" ]]; then
    run_tests_with_test_data "mainnet"
elif [[ "$NETWORK" == "devnet" ]]; then
    run_tests_with_test_data "devnet"
else
    echo "Unknown network: $NETWORK. available networks: mainnet, devnet. Exiting..."
    exit 1
fi