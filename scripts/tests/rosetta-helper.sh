#!/usr/bin/env bash

# Helper functions for Rosetta API sanity and load tests

readonly BLOCKCHAIN="mina"

readonly DEFAULT_HEADERS=(--header "Accept: application/json" --header "Content-Type: application/json")

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

# Queries the daemon and checks if the best tip timestamp is fresh (close to current time).
#
# Arguments:
#   $1 - test data array name (passed by reference)
#
# Returns:
#   0 if best tip is fresh
#   1 if best tip is stale (older than best_tip_age_threshold)
function check_daemon_best_tip_freshness() {
    declare -n __test_data=$1

    # This best tip age threshold is 4 hours, in milliseconds. This is 80 slots
    # at the current 3 min slot time, and more if the slot times have been
    # reduced.
    #
    # If the daemon were really synced to the network, then the best tip being
    # this old means that the network must not have produced a block in at least
    # 80 slots. This implies terrible things about the state of the current
    # network, so we instead take this as evidence that the daemon is not
    # accurately reporting its sync status.
    local best_tip_age_threshold_ms=$((4 * 60 * 60 * 1000))

    # Query daemon directly for best tip timestamp
    local daemon_response
    daemon_response=$(curl --no-progress-meter --request POST \
        "${__test_data[daemon_graphql_address]}" \
        "${DEFAULT_HEADERS[@]}" \
        --data-raw '{"query":"{ bestChain(maxLength: 1) { protocolState { blockchainState { utcDate } } } }"}' 2> /dev/null)

    # Check if we got a valid response (exit test if daemon is unresponsive)
    assert "$daemon_response" \
        '.data.bestChain[0].protocolState.blockchainState.utcDate != null' \
        "   ✅  Best tip timestamp retrieved from daemon" \
        "   ❌  Could not retrieve best tip timestamp from daemon"

    local best_tip_timestamp_ms current_timestamp_ms
    best_tip_timestamp_ms=$(echo "$daemon_response" | jq -r '.data.bestChain[0].protocolState.blockchainState.utcDate')
    current_timestamp_ms=$(($(date +%s) * 1000))

    # Validate best tip freshness
    local time_since_best_tip_ms=$((current_timestamp_ms - best_tip_timestamp_ms))

    if [[ $time_since_best_tip_ms -lt $best_tip_age_threshold_ms ]]; then
        echo "✅  Best tip is fresh ($time_since_best_tip_ms ms old < $best_tip_age_threshold_ms ms threshold)"
        return 0
    else
        echo "❌  Best tip is stale: $time_since_best_tip_ms ms old (threshold: $best_tip_age_threshold_ms ms)"
        return 1
    fi
}

function wait_for_sync() {
    declare -n __test_data=$1
    local __timeout=$2

    echo "⏳  Waiting for rosetta to sync..."
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + __timeout))
    local sync_status=""
    local network_status_response=""

    while true; do
        network_status_response=$(curl --no-progress-meter --request POST "${__test_data[address]}/network/status" "${DEFAULT_HEADERS[@]}" --data-raw "{\"network_identifier\":{\"blockchain\":\"$BLOCKCHAIN\",\"network\":\"${__test_data[id]}\"}}" 2> /dev/null)
        sync_status=$(echo "$network_status_response" | jq '.sync_status.stage')

        if [[ "$sync_status" == "\"Synced\"" ]]; then
            # Check daemon's best tip age before declaring success.
            #
            # TODO: once the daemon's sync status reporting is improved,
            # consider changing this to a hard test failure.
            if check_daemon_best_tip_freshness "$1"; then
                echo "✅  Rosetta is synced"
                break
            else
                echo "⚠️  Daemon reports Synced but validation failed. Continuing to wait..."
            fi
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
        "   ❌  Account: Invalid balance structure or balance not found"
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
