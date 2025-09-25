#!/usr/bin/env bash

# Helper functions for Rosetta API sanity and load tests

readonly BLOCKCHAIN="mina"

readonly DEFAULT_HEADERS=(--header "Accept: application/json" --header "Content-Type: application/json")

function assert() {
    local __response=$1
    local __query=$2
    local __success_message=$3
    local __error_message=$4
    local __attempts_left="${5:-1}"
    local __retry_sleep="${6:-5}"


    local attempt=1
    while (( attempt <= __attempts_left )); do
        if echo "$__response" | jq "if ($__query) then true else false end" | grep -q true; then
            echo "$__success_message"
            return 0
        else
            echo "$__error_message (attempt $attempt of $__attempts_left)"
            echo "   Response:"
            echo "      $( echo "$__response" | jq )"

            if (( attempt < __attempts_left )); then
                echo "Retrying in $__retry_sleep seconds..."
                sleep "$__retry_sleep"
            fi
        fi
        ((attempt++))
    done

    echo "Failed after $__attempts_left attempts."
    exit 1
}

function wait_for_sync() {
    declare -n __test_data=$1
    local __timeout=$2

    echo "⏳  Waiting for rosetta to sync..."
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + __timeout))
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

function test_network_status() {
    declare -n __test_data=$1
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/network/status" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" | jq)" \
        '.sync_status.stage == "Synced"' \
        "   ✅  Rosetta is synced" \
        "   ❌  Rosetta is not synced"
}

function test_network_options() {
    declare -n __test_data=$1
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/network/options" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" | jq)" \
        '.version.rosetta_version == "1.4.9"' \
        "   ✅  Rosetta Version is correct" \
        "   ❌  Invalid Rosetta Version (expected 1.4.9)"
}

function test_block() {
    declare -n __test_data=$1
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/block" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"},\"block_identifier\":{\"hash\":\"${__test_data[block]}\"}}" | jq)" \
        ".block.block_identifier.hash == \"${__test_data[block]}\" " \
        "   ✅  Block hash correct" \
        "   ❌  Block hash incorrect or not found (expected ${__test_data[block]})"
}

function test_account_balance() {
    declare -n __test_data=$1
    assert "$(curl --no-progress-meter --request POST "${__test_data[address]}/account/balance" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"},\"account_identifier\":{\"address\":\"${__test_data[account]}\"}}" | jq)" \
        '.balances[0].currency.symbol == "MINA"' \
        "   ✅  Account: Balance ok" \
        "   ❌  Account: Invalid balance structure or balance not found" \
        5 \
        30
}

function test_payment_transaction() {
    declare -n __test_data=$1
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
}

function test_zkapp_transaction() {
    declare -n __test_data=$1
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
}
