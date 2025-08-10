#!/usr/bin/env bash

set -euo pipefail

# Configuration constants
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source shared libraries
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# Default configuration values
SLOT_TX_END="${SLOT_TX_END:-30}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"
BEST_CHAIN_QUERY_FROM="${BEST_CHAIN_QUERY_FROM:-25}"
MAIN_SLOT="${MAIN_SLOT:-15}"
FORK_SLOT="${FORK_SLOT:-15}"
MAIN_DELAY="${MAIN_DELAY:-20}"
FORK_DELAY="${FORK_DELAY:-10}"

# Source helper functions
# shellcheck disable=SC1090
source "$SCRIPT_DIR/graphql-client.sh"

log_info "Starting hard fork test"
log_debug "Configuration: SLOT_TX_END=$SLOT_TX_END, SLOT_CHAIN_END=$SLOT_CHAIN_END"
log_debug "MAIN_SLOT=$MAIN_SLOT, FORK_SLOT=$FORK_SLOT"
log_debug "MAIN_DELAY=$MAIN_DELAY, FORK_DELAY=$FORK_DELAY"

# Validate command line arguments
validate_arguments() {
    if [[ $# -ne 4 ]]; then
        log_error "Usage: $0 <main_mina_exe> <main_genesis_exe> <fork_mina_exe> <fork_genesis_exe>"
        exit 1
    fi
    
    local main_mina="$1"
    local main_genesis="$2" 
    local fork_mina="$3"
    local fork_genesis="$4"
    
    for exe in "$main_mina" "$main_genesis" "$fork_mina" "$fork_genesis"; do
        if [[ ! -x "$exe" ]]; then
            log_error "Executable not found or not executable: $exe"
            exit 1
        fi
    done
    
    log_info "All executables validated successfully"
}

# Stop running Mina nodes
stop_nodes() {
    local mina_exe="$1"
    
    log_info "Stopping Mina nodes"
    if ! "$mina_exe" client stop-daemon --daemon-port 10301 2>/dev/null; then
        log_debug "Node on port 10301 was not running or failed to stop"
    fi
    if ! "$mina_exe" client stop-daemon --daemon-port 10311 2>/dev/null; then
        log_debug "Node on port 10311 was not running or failed to stop"
    fi
}

# Start pre-fork network
start_prefork_network() {
    local main_mina_exe="$1"
    local genesis_timestamp="$2"
    local main_slot="$3"
    local slot_tx_end="$4"
    local slot_chain_end="$5"
    
    log_process_op "start" "pre-fork network"
    log_config "set" "GENESIS_TIMESTAMP=$genesis_timestamp"
    log_debug "Network configuration: slot=${main_slot}s, tx_end=$slot_tx_end, chain_end=$slot_chain_end"
    
    export GENESIS_TIMESTAMP="$genesis_timestamp"
    
    log_cmd "$SCRIPT_DIR/run-localnet.sh -m $main_mina_exe -i $main_slot -s $main_slot --slot-tx-end $slot_tx_end --slot-chain-end $slot_chain_end"
    "$SCRIPT_DIR/run-localnet.sh" \
        -m "$main_mina_exe" \
        -i "$main_slot" \
        -s "$main_slot" \
        --slot-tx-end "$slot_tx_end" \
        --slot-chain-end "$slot_chain_end" &
    
    local network_pid=$!
    log_process_op "start" "pre-fork network with PID $network_pid"
    echo "$network_pid"
}

validate_arguments "$@"

# Executable paths
MAIN_MINA_EXE="$1"
MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"
FORK_MINA_EXE="$3"
FORK_RUNTIME_GENESIS_LEDGER_EXE="$4"

# Validate pre-fork network state
validate_prefork_chain() {
    local best_chain_query_from="$1"
    local slot_tx_end="$2"
    local slot_chain_end="$3"
    local main_slot="$4"
    
    log_info "Validating pre-fork chain from slot $best_chain_query_from"
    
    # Check block height and slot occupancy
    local block_height
    block_height=$(get_height 10303)
    log_info "Block height is $block_height at slot $best_chain_query_from"
    
    if [[ $((2 * block_height)) -lt $best_chain_query_from ]]; then
        log_error "Assertion failed: slot occupancy is below 50%"
        return 1
    fi
    
    # Get genesis epoch hashes
    local first_epoch_ne_str
    first_epoch_ne_str="$(blocks 10303 2>/dev/null | latest_nonempty_block)"
    IFS=',' read -ra first_epoch_ne <<< "$first_epoch_ne_str"
    
    local genesis_epoch_staking_hash="${first_epoch_ne[$((3+IX_CUR_EPOCH_HASH))]}"
    local genesis_epoch_next_hash="${first_epoch_ne[$((3+IX_NEXT_EPOCH_HASH))]}"
    
    log_info "Genesis epoch staking/next hashes: $genesis_epoch_staking_hash, $genesis_epoch_next_hash"
    
    # Monitor chain until slot_chain_end
    log_info "Monitoring chain from slot $best_chain_query_from to $slot_chain_end"
    local last_ne_str
    last_ne_str="$(for i in $(seq "$best_chain_query_from" "$slot_chain_end"); do
        blocks $((10303+10*(i%2))) 2>/dev/null || true
        sleep "${main_slot}s"
    done | latest_nonempty_block)"
    
    echo "$genesis_epoch_staking_hash,$genesis_epoch_next_hash,$last_ne_str"
}

# Extract and validate fork data
extract_fork_data() {
    local last_ne_str="$1"
    local slot_tx_end="$2"
    local slot_chain_end="$3"
    
    IFS=',' read -ra latest_ne <<< "$last_ne_str"
    
    # Maximum slot observed for a block
    local max_slot=${latest_ne[0]}
    
    # List of epochs for which last snarked ledger hashes were captured
    IFS=':' read -ra epochs <<< "${latest_ne[1]}"
    # List of last snarked ledger hashes captured
    IFS=':' read -ra last_snarked_hash_pe <<< "${latest_ne[2]}"
    
    # Extract latest block data (skip first 3 fields)
    latest_ne=( "${latest_ne[@]:3}" )
    
    log_info "Last occupied slot of pre-fork chain: $max_slot"
    if [[ $max_slot -ge $slot_chain_end ]]; then
        log_error "Assertion failed: block with slot $max_slot created after slot chain end"
        return 1
    fi
    
    local latest_state_hash="${latest_ne[$IX_STATE_HASH]}"
    local latest_height="${latest_ne[$IX_HEIGHT]}"
    local latest_ne_slot="${latest_ne[$IX_SLOT]}"
    
    log_info "Latest non-empty block: $latest_state_hash, height: $latest_height, slot: $latest_ne_slot"
    if [[ $latest_ne_slot -ge $slot_tx_end ]]; then
        log_error "Assertion failed: non-empty block with slot $latest_ne_slot created after slot tx end"
        return 1
    fi
    
    # Return processed data
    printf '%s\n' "$max_slot" "${epochs[*]}" "${last_snarked_hash_pe[*]}" "${latest_ne[*]}"
}

log_info "Main Mina executable: $MAIN_MINA_EXE"
log_info "Fork Mina executable: $FORK_MINA_EXE"

# Calculate timing and start pre-fork network
NOW_UNIX_TS=$(date +%s)
MAIN_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + MAIN_DELAY*60))
GENESIS_TIMESTAMP="$(date -u -d @$MAIN_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00')"

start_prefork_network "$MAIN_MINA_EXE" "$GENESIS_TIMESTAMP" "$MAIN_SLOT" "$SLOT_TX_END" "$SLOT_CHAIN_END"

# Wait for network to be ready for testing
log_info "Waiting for pre-fork network to reach slot $BEST_CHAIN_QUERY_FROM"
sleep $((MAIN_SLOT * BEST_CHAIN_QUERY_FROM - NOW_UNIX_TS%60 + MAIN_DELAY*60))s

# Validate pre-fork chain and extract data
if ! validation_result=$(validate_prefork_chain "$BEST_CHAIN_QUERY_FROM" "$SLOT_TX_END" "$SLOT_CHAIN_END" "$MAIN_SLOT"); then
    log_error "Pre-fork chain validation failed"
    stop_nodes "$MAIN_MINA_EXE"
    exit 3
fi

# Parse validation results
IFS=',' read -ra validation_data <<< "$validation_result"
genesis_epoch_staking_hash="${validation_data[0]}"
genesis_epoch_next_hash="${validation_data[1]}"

# Extract fork data from the remaining string
fork_data_str="${validation_result#*,*,}"
if ! fork_results=$(extract_fork_data "$fork_data_str" "$SLOT_TX_END" "$SLOT_CHAIN_END"); then
    log_error "Fork data extraction failed"
    stop_nodes "$MAIN_MINA_EXE"
    exit 3
fi

# Parse fork results
readarray -t fork_data_array <<< "$fork_results"
max_slot="${fork_data_array[0]}"
epochs_str="${fork_data_array[1]}"
last_snarked_hash_pe_str="${fork_data_array[2]}"
latest_ne_str="${fork_data_array[3]}"

# Parse latest block data
IFS=' ' read -ra epochs <<< "$epochs_str"
IFS=' ' read -ra last_snarked_hash_pe <<< "$last_snarked_hash_pe_str"
IFS=' ' read -ra latest_ne <<< "$latest_ne_str"

# Extract individual values
latest_shash="${latest_ne[$IX_STATE_HASH]}"
latest_height="${latest_ne[$IX_HEIGHT]}"
latest_ne_slot="${latest_ne[$IX_SLOT]}"

# Verify no new blocks are created after chain end
verify_chain_stopped() {
    log_info "Verifying that chain stops producing blocks"
    sleep 1m
    
    local height1
    height1=$(get_height 10303)
    log_debug "Height after 1 minute: $height1"
    
    sleep 5m
    local height2
    height2=$(get_height 10303)
    log_debug "Height after 6 minutes total: $height2"
    
    if [[ $((height2 - height1)) -gt 0 ]]; then
        log_error "Assertion failed: chain should have stopped producing blocks after slot chain end"
        return 1
    fi
    
    log_info "Chain successfully stopped producing blocks"
}

# Extract and validate fork configuration
extract_fork_config() {
    local expected_fork_data="$1"
    
    log_info "Extracting fork configuration"
    
    # Retry until we get a valid fork config
    local max_attempts=10
    for ((i=1; i<=max_attempts; i++)); do
        log_debug "Attempting to extract fork config (attempt $i/$max_attempts)"
        
        if run_cmd get_fork_config 10313 > localnet/fork_config.json; then
            log_file_op "create" "localnet/fork_config.json"
            
            if [[ -s localnet/fork_config.json ]] && [[ "$(head -c 4 localnet/fork_config.json)" != "null" ]]; then
                log_info "Successfully extracted fork configuration (attempt $i)"
                break
            else
                log_debug "Fork config file is empty or null (attempt $i)"
            fi
        else
            log_debug "Failed to get fork config from GraphQL (attempt $i)"
        fi
        
        if [[ $i -eq $max_attempts ]]; then
            log_error "Failed to extract valid fork configuration after $max_attempts attempts"
            return 1
        fi
        
        log_timing "sleep" "1 minute before retry"
        sleep 1m
    done
    
    # Validate fork data matches expectations
    log_validation "fork data" "start"
    local actual_fork_data
    actual_fork_data=$(run_cmd_capture jq -cS '{fork:.proof.fork,next_seed:.epoch_data.next.seed,staking_seed:.epoch_data.staking.seed}' localnet/fork_config.json)
    
    if [[ "$actual_fork_data" != "$expected_fork_data" ]]; then
        log_validation "fork data" "fail"
        log_error "Expected: $expected_fork_data"
        log_error "Actual: $actual_fork_data"
        return 1
    fi
    
    log_validation "fork data" "pass"
}

# Generate prefork ledgers
generate_prefork_ledgers() {
    local main_genesis_exe="$1"
    
    log_info "Generating pre-fork ledger files"
    log_file_op "read" "localnet/fork_config.json"
    log_file_op "create" "localnet/prefork_hf_ledgers directory"
    log_file_op "create" "localnet/prefork_hf_ledger_hashes.json"
    
    if ! run_cmd "$main_genesis_exe" \
        --config-file localnet/fork_config.json \
        --genesis-dir localnet/prefork_hf_ledgers \
        --hash-output-file localnet/prefork_hf_ledger_hashes.json; then
        log_error "Failed to generate pre-fork ledgers"
        return 1
    fi
    
    log_info "Pre-fork ledgers generated successfully"
}

expected_fork_data="{\"fork\":{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$latest_ne_slot,\"state_hash\":\"$latest_shash\"},\"next_seed\":\"${latest_ne[$IX_NEXT_EPOCH_SEED]}\",\"staking_seed\":\"${latest_ne[$IX_CUR_EPOCH_SEED]}\"}"

# Verify chain has stopped and extract fork configuration
if ! verify_chain_stopped; then
    stop_nodes "$MAIN_MINA_EXE"
    exit 3
fi

if ! extract_fork_config "$expected_fork_data"; then
    stop_nodes "$MAIN_MINA_EXE"
    exit 3
fi

# Stop nodes and generate ledgers
stop_nodes "$MAIN_MINA_EXE"

if ! generate_prefork_ledgers "$MAIN_RUNTIME_GENESIS_LEDGER_EXE"; then
    exit 3
fi

# Find staking ledger hash for a specific epoch
find_staking_hash() {
    local epoch="$1"
    
    if [[ $epoch == 0 ]]; then
        echo "$genesis_epoch_staking_hash"
    elif [[ $epoch == 1 ]]; then
        echo "$genesis_epoch_next_hash"
    else
        local adjusted_epoch=$((epoch - 2))
        local index=0
        
        for el in "${epochs[@]}"; do
            if [[ "$el" == "$adjusted_epoch" ]]; then
                echo "${last_snarked_hash_pe[$index]}"
                return 0
            fi
            index=$((index + 1))
        done
        
        log_error "Assertion failed: last snarked ledger for epoch $adjusted_epoch wasn't captured"
        exit 3
    fi
}

# Validate pre-fork ledger hashes
validate_prefork_ledger_hashes() {
    local latest_ne_slot="$1"
    
    log_info "Validating pre-fork ledger hashes"
    
    local slot_tx_end_epoch=$((latest_ne_slot / 48))
    
    local expected_staking_hash
    expected_staking_hash=$(find_staking_hash "$slot_tx_end_epoch")
    
    local expected_next_hash
    expected_next_hash=$(find_staking_hash $((slot_tx_end_epoch + 1)))
    
    local expected_prefork_hashes="{\"epoch_data\":{\"next\":{\"hash\":\"$expected_next_hash\"},\"staking\":{\"hash\":\"$expected_staking_hash\"}},\"ledger\":{\"hash\":\"${latest_ne[$IX_STAGED_HASH]}\"}}"
    
    # SHA3 hashes are not checked, because this is irrelevant to checking that correct ledgers are used
    local prefork_hashes_select='{epoch_data:{staking:{hash:.epoch_data.staking.hash},next:{hash:.epoch_data.next.hash}},ledger:{hash:.ledger.hash}}'
    
    local prefork_hashes
    prefork_hashes="$(jq -cS "$prefork_hashes_select" localnet/prefork_hf_ledger_hashes.json)"
    
    if [[ "$prefork_hashes" != "$expected_prefork_hashes" ]]; then
        log_error "Assertion failed: unexpected ledgers in fork_config"
        log_error "Expected: $expected_prefork_hashes"
        log_error "Actual: $prefork_hashes"
        return 1
    fi
    
    log_info "Pre-fork ledger hashes validated successfully"
}

# Generate fork ledgers and configuration
generate_fork_config() {
    local fork_genesis_exe="$1"
    local main_genesis_unix_ts="$2"
    local latest_height="$3"
    local latest_shash="$4"
    
    log_info "Generating fork ledgers and configuration"
    
    log_file_op "delete" "localnet/hf_ledgers"
    rm -rf localnet/hf_ledgers
    
    log_file_op "mkdir" "localnet/hf_ledgers"
    mkdir -p localnet/hf_ledgers
    
    log_info "Running fork genesis ledger generation"
    if ! run_cmd "$fork_genesis_exe" \
        --config-file localnet/fork_config.json \
        --genesis-dir localnet/hf_ledgers \
        --hash-output-file localnet/hf_ledger_hashes.json; then
        log_error "Failed to generate fork ledgers"
        return 1
    fi
    
    log_file_op "create" "localnet/hf_ledgers directory with genesis files"
    log_file_op "create" "localnet/hf_ledger_hashes.json"
    
    # Calculate fork genesis time
    local now_unix_ts
    now_unix_ts=$(date +%s)
    local fork_genesis_unix_ts=$((now_unix_ts - now_unix_ts % 60 + FORK_DELAY * 60))
    local genesis_timestamp
    genesis_timestamp="$(date -u -d @$fork_genesis_unix_ts '+%F %H:%M:%S+00:00')"
    
    log_config "set" "fork genesis timestamp: $genesis_timestamp"
    
    # Generate runtime config
    log_env_setup "runtime config generation environment"
    log_config "set" "GENESIS_TIMESTAMP=$genesis_timestamp"
    log_config "set" "FORKING_FROM_CONFIG_JSON=localnet/config/base.json"
    log_config "set" "SECONDS_PER_SLOT=$MAIN_SLOT"
    log_config "set" "FORK_CONFIG_JSON=localnet/fork_config.json"
    log_config "set" "LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json"
    
    log_cmd "GENESIS_TIMESTAMP=$genesis_timestamp FORKING_FROM_CONFIG_JSON=localnet/config/base.json SECONDS_PER_SLOT=$MAIN_SLOT FORK_CONFIG_JSON=localnet/fork_config.json LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json $SCRIPT_DIR/create_runtime_config.sh > localnet/config.json"
    
    GENESIS_TIMESTAMP="$genesis_timestamp" \
    FORKING_FROM_CONFIG_JSON=localnet/config/base.json \
    SECONDS_PER_SLOT="$MAIN_SLOT" \
    FORK_CONFIG_JSON=localnet/fork_config.json \
    LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json \
    "$SCRIPT_DIR/create_runtime_config.sh" > localnet/config.json
    
    log_file_op "create" "localnet/config.json"
    
    # Validate the generated config
    local expected_genesis_slot=$(((fork_genesis_unix_ts - main_genesis_unix_ts) / MAIN_SLOT))
    local expected_modified_fork_data="{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$expected_genesis_slot,\"state_hash\":\"$latest_shash\"}"
    
    log_validation "generated config" "start"
    local modified_fork_data
    modified_fork_data=$(run_cmd_capture jq -cS '.proof.fork' localnet/config.json)
    
    if [[ "$modified_fork_data" != "$expected_modified_fork_data" ]]; then
        log_validation "generated config" "fail"
        log_error "Expected: $expected_modified_fork_data"
        log_error "Actual: $modified_fork_data"
        return 1
    fi
    
    log_validation "generated config" "pass"
    echo "$fork_genesis_unix_ts,$expected_genesis_slot"
}

# Validate ledger hashes and generate fork configuration
if ! validate_prefork_ledger_hashes "$latest_ne_slot"; then
    exit 3
fi

if ! fork_config_result=$(generate_fork_config "$FORK_RUNTIME_GENESIS_LEDGER_EXE" "$MAIN_GENESIS_UNIX_TS" "$latest_height" "$latest_shash"); then
    exit 3
fi

IFS=',' read -r FORK_GENESIS_UNIX_TS expected_genesis_slot <<< "$fork_config_result"

# Start fork network and validate
start_fork_network() {
    local fork_mina_exe="$1"
    local fork_delay="$2"
    local fork_slot="$3"
    
    log_process_op "start" "fork network"
    log_debug "Fork network configuration: executable=$fork_mina_exe, delay=${fork_delay}min, slot=${fork_slot}s"
    
    log_cmd "$SCRIPT_DIR/run-localnet.sh -m $fork_mina_exe -d $fork_delay -i $fork_slot -s $fork_slot -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers"
    "$SCRIPT_DIR/run-localnet.sh" \
        -m "$fork_mina_exe" \
        -d "$fork_delay" \
        -i "$fork_slot" \
        -s "$fork_slot" \
        -c localnet/config.json \
        --genesis-ledger-dir localnet/hf_ledgers &
    
    local fork_network_pid=$!
    log_process_op "start" "fork network with PID $fork_network_pid"
    
    # Wait for network to be ready
    log_timing "sleep" "$((fork_delay * 60)) seconds for fork network to initialize"
    sleep $((fork_delay * 60))s
    
    echo "$fork_network_pid"
}

# Validate fork network initialization
validate_fork_initialization() {
    local expected_height="$1"
    local expected_slot="$2"
    local fork_slot="$3"
    local fork_mina_exe="$4"
    
    log_info "Validating fork network initialization"
    
    # Wait for earliest block data
    local earliest_str=""
    local max_attempts=20
    for ((i=1; i<=max_attempts; i++)); do
        earliest_str=$(get_height_and_slot_of_earliest 10303 2>/dev/null || true)
        if [[ -n "$earliest_str" ]] && [[ "$earliest_str" != "," ]]; then
            log_info "Fork network initialized (attempt $i)"
            break
        fi
        
        if [[ $i -eq $max_attempts ]]; then
            log_error "Fork network failed to initialize after $max_attempts attempts"
            return 1
        fi
        
        log_debug "Waiting for fork network to initialize (attempt $i/$max_attempts)"
        sleep "$fork_slot"s
    done
    
    # Parse and validate initialization data
    IFS=',' read -ra earliest <<< "$earliest_str"
    local earliest_height="${earliest[0]}"
    local earliest_slot="${earliest[1]}"
    
    log_info "Fork network earliest block: height=$earliest_height, slot=$earliest_slot"
    
    if [[ $earliest_height != $((expected_height + 1)) ]]; then
        log_error "Assertion failed: unexpected block height $earliest_height at the beginning of the fork (expected $((expected_height + 1)))"
        return 1
    fi
    
    if [[ $earliest_slot -lt $expected_slot ]]; then
        log_error "Assertion failed: unexpected slot $earliest_slot at the beginning of the fork (expected >= $expected_slot)"
        return 1
    fi
    
    log_info "Fork network initialization validated successfully"
}

# Verify fork network is producing blocks with transactions
verify_fork_network() {
    local fork_slot="$1"
    local fork_mina_exe="$2"
    
    log_info "Verifying fork network is producing blocks"
    
    # Check that blocks are being produced
    sleep $((fork_slot * 10))s
    local height1
    height1=$(get_height 10303)
    
    if [[ $height1 == 0 ]]; then
        log_error "Assertion failed: block height $height1 should be greater than 0"
        return 1
    fi
    
    log_info "Fork network is producing blocks (height: $height1)"
    
    # Check that some blocks contain transactions
    log_info "Checking for transactions in fork chain blocks"
    local all_blocks_empty=true
    
    for i in {1..10}; do
        sleep "${fork_slot}s"
        local usercmds
        usercmds=$(blocks_with_user_commands 10303)
        
        log_debug "Block $i has $usercmds user commands"
        
        if [[ $usercmds != 0 ]]; then
            all_blocks_empty=false
        fi
    done
    
    if $all_blocks_empty; then
        log_error "Assertion failed: all blocks in fork chain are empty"
        return 1
    fi
    
    log_info "Fork network is successfully producing blocks with transactions"
}

# Wait for pre-fork network to complete
log_process_op "wait" "for pre-fork network (PID $MAIN_NETWORK_PID) to complete"
wait "$MAIN_NETWORK_PID"
log_info "Pre-fork network completed successfully"

# Start and validate fork network
log_info "====== STARTING FORK NETWORK PHASE ======"
FORK_NETWORK_PID=$(start_fork_network "$FORK_MINA_EXE" "$FORK_DELAY" "$FORK_SLOT")

log_validation "fork network initialization" "start"
if ! validate_fork_initialization "$latest_height" "$expected_genesis_slot" "$FORK_SLOT" "$FORK_MINA_EXE"; then
    log_validation "fork network initialization" "fail"
    stop_nodes "$FORK_MINA_EXE"
    exit 3
fi
log_validation "fork network initialization" "pass"

log_validation "fork network functionality" "start"
if ! verify_fork_network "$FORK_SLOT" "$FORK_MINA_EXE"; then
    log_validation "fork network functionality" "fail"
    stop_nodes "$FORK_MINA_EXE"
    exit 3
fi
log_validation "fork network functionality" "pass"

# Clean shutdown
log_process_op "stop" "all fork network nodes"
stop_nodes "$FORK_MINA_EXE"

log_info "====== HARD FORK TEST COMPLETED SUCCESSFULLY! ======"
log_info "All validations passed:"
log_info "  ✓ Pre-fork network operated correctly"
log_info "  ✓ Chain stopped at designated slot"
log_info "  ✓ Fork configuration extracted and validated"
log_info "  ✓ Fork network initialized properly"
log_info "  ✓ Fork network produced blocks with transactions"
