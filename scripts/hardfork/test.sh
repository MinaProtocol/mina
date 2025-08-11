#!/usr/bin/env bash

# Hardfork Test Script
# This script performs a comprehensive hardfork test by running a pre-fork network,
# validating block production, extracting fork configuration, and then running
# a post-fork network to ensure the hardfork transition works correctly.

set -euo pipefail

# Source shared libraries
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/graphql-client.sh"

#=============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
#=============================================================================

# Test configuration parameters
declare -g SLOT_TX_END="${SLOT_TX_END:-30}"
declare -g SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"
declare -g BEST_CHAIN_QUERY_FROM="${BEST_CHAIN_QUERY_FROM:-25}"
declare -g MAIN_SLOT="${MAIN_SLOT:-15}"
declare -g FORK_SLOT="${FORK_SLOT:-15}"
declare -g MAIN_DELAY="${MAIN_DELAY:-20}"
declare -g FORK_DELAY="${FORK_DELAY:-10}"

# Executable paths (set by argument parsing)
declare -g MAIN_MINA_EXE=""
declare -g MAIN_RUNTIME_GENESIS_LEDGER_EXE=""
declare -g FORK_MINA_EXE=""
declare -g FORK_RUNTIME_GENESIS_LEDGER_EXE=""

# Runtime variables
declare -g MAIN_NETWORK_PID=""
declare -g MAIN_GENESIS_UNIX_TS=""
declare -g FORK_GENESIS_UNIX_TS=""

# Block data from pre-fork chain
declare -ga first_epoch_ne=()
declare -ga latest_ne=()
declare -ga epochs=()
declare -ga last_snarked_hash_pe=()
declare -g genesis_epoch_staking_hash=""
declare -g genesis_epoch_next_hash=""
declare -g max_slot=""
declare -g latest_shash=""
declare -g latest_height=""
declare -g latest_ne_slot=""

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Hardfork test script that validates hardfork transitions between compatible and fork networks.

OPTIONS:
    --main-mina PATH              Path to main (compatible) mina executable
    --main-genesis PATH           Path to main runtime_genesis_ledger executable  
    --fork-mina PATH              Path to fork mina executable
    --fork-genesis PATH           Path to fork runtime_genesis_ledger executable
    --slot-tx-end SLOT            Slot number when transactions should end (default: 30)
    --slot-chain-end SLOT         Slot number when chain should end (default: SLOT_TX_END + 8)
    --best-chain-query-from SLOT  Slot from which to start best chain queries (default: 25)
    --main-slot SECONDS           Main network slot duration in seconds (default: 15)
    --fork-slot SECONDS           Fork network slot duration in seconds (default: 15)
    --main-delay MINUTES          Main network genesis delay in minutes (default: 20)
    --fork-delay MINUTES          Fork network genesis delay in minutes (default: 10)
    -h, --help                    Show this help message

EXAMPLES:
    # Basic usage
    $0 --main-mina ./compatible-devnet/bin/mina \\
       --main-genesis ./compatible-devnet-genesis/bin/runtime_genesis_ledger \\
       --fork-mina ./fork-devnet/bin/mina \\
       --fork-genesis ./fork-devnet-genesis/bin/runtime_genesis_ledger

    # With custom timing parameters
    $0 --main-mina ./main/mina --main-genesis ./main/genesis \\
       --fork-mina ./fork/mina --fork-genesis ./fork/genesis \\
       --slot-tx-end 50 --main-delay 15
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --main-mina)
                MAIN_MINA_EXE="$2"
                shift 2
                ;;
            --main-genesis)
                MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"
                shift 2
                ;;
            --fork-mina)
                FORK_MINA_EXE="$2"
                shift 2
                ;;
            --fork-genesis)
                FORK_RUNTIME_GENESIS_LEDGER_EXE="$2"
                shift 2
                ;;
            --slot-tx-end)
                SLOT_TX_END="$2"
                SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"
                shift 2
                ;;
            --slot-chain-end)
                SLOT_CHAIN_END="$2"
                shift 2
                ;;
            --best-chain-query-from)
                BEST_CHAIN_QUERY_FROM="$2"
                shift 2
                ;;
            --main-slot)
                MAIN_SLOT="$2"
                shift 2
                ;;
            --fork-slot)
                FORK_SLOT="$2"
                shift 2
                ;;
            --main-delay)
                MAIN_DELAY="$2"
                shift 2
                ;;
            --fork-delay)
                FORK_DELAY="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate required arguments
validate_arguments() {
    local missing_args=()
    
    [[ -z "$MAIN_MINA_EXE" ]] && missing_args+=("--main-mina")
    [[ -z "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" ]] && missing_args+=("--main-genesis")
    [[ -z "$FORK_MINA_EXE" ]] && missing_args+=("--fork-mina")
    [[ -z "$FORK_RUNTIME_GENESIS_LEDGER_EXE" ]] && missing_args+=("--fork-genesis")
    
    if [[ ${#missing_args[@]} -gt 0 ]]; then
        log_error "Missing required arguments: ${missing_args[*]}"
        usage
        exit 1
    fi
    
    # Validate executable files exist
    for exe in "$MAIN_MINA_EXE" "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" "$FORK_MINA_EXE" "$FORK_RUNTIME_GENESIS_LEDGER_EXE"; do
        if [[ ! -f "$exe" ]]; then
            log_error "Executable not found: $exe"
            exit 1
        fi
        if [[ ! -x "$exe" ]]; then
            log_error "File is not executable: $exe"
            exit 1
        fi
    done
}

# Stop running mina nodes
stop_nodes() {
    local mina_exe="$1"
    log_info "Stopping mina nodes"
    run_cmd "$mina_exe" client stop-daemon --daemon-port 10301 || true
    run_cmd "$mina_exe" client stop-daemon --daemon-port 10311 || true
}

# Find staking ledger hash for a given epoch
find_staking_hash() {
    local epoch="$1"
    
    if [[ $epoch == 0 ]]; then
        echo "$genesis_epoch_staking_hash"
    elif [[ $epoch == 1 ]]; then
        echo "$genesis_epoch_next_hash"
    else
        local ix=0
        local target_epoch=$((epoch-2))
        for el in "${epochs[@]}"; do
            [[ "$el" == "$target_epoch" ]] && break
            ix=$((ix+1))
        done
        if [[ $ix == "${#epochs[@]}" ]]; then
            log_error "Last snarked ledger for epoch $target_epoch wasn't captured"
            exit 3
        fi
        echo "${last_snarked_hash_pe[$ix]}"
    fi
}

#=============================================================================
# TEST STEP FUNCTIONS
#=============================================================================

# Test Step 1: Start the main (pre-fork) network
test_step_1_start_main_network() {
    log_info "=== TEST STEP 1: Starting main (pre-fork) network ==="
    
    local now_unix_ts
    now_unix_ts=$(run_cmd_capture date +%s)
    MAIN_GENESIS_UNIX_TS=$((now_unix_ts - now_unix_ts%60 + MAIN_DELAY*60))
    local genesis_timestamp
    genesis_timestamp=$(run_cmd_capture date -u -d "@$MAIN_GENESIS_UNIX_TS" '+%F %H:%M:%S+00:00')
    
    log_info "Main network genesis timestamp: $genesis_timestamp"
    log_info "Slot TX end: $SLOT_TX_END, Slot chain end: $SLOT_CHAIN_END"
    
    export GENESIS_TIMESTAMP="$genesis_timestamp"
    
    log_info "Starting main network with localnet script"
    MAIN_NETWORK_PID=$(run_cmd_background "$SCRIPT_DIR/run-localnet.sh" \
        -m "$MAIN_MINA_EXE" \
        -i "$MAIN_SLOT" \
        -s "$MAIN_SLOT" \
        --slot-tx-end "$SLOT_TX_END" \
        --slot-chain-end "$SLOT_CHAIN_END")
    
    log_info "Main network started with PID: $MAIN_NETWORK_PID"
    
    local sleep_duration=$((MAIN_SLOT * BEST_CHAIN_QUERY_FROM - now_unix_ts%60 + MAIN_DELAY*60))
    log_timing "sleep" "${sleep_duration}s until best chain query"
    sleep "${sleep_duration}s"
    
    log_validation "step-1" "pass" "Main network started successfully"
}

# Test Step 2: Validate block production and slot occupancy
test_step_2_validate_block_production() {
    log_info "=== TEST STEP 2: Validating block production and slot occupancy ==="
    
    local block_height
    block_height=$(get_height 10303)
    log_info "Block height is $block_height at slot $BEST_CHAIN_QUERY_FROM"
    
    # Check >50% slot occupancy
    if [[ $((2*block_height)) -lt $BEST_CHAIN_QUERY_FROM ]]; then
        log_error "Slot occupancy is below 50%: $((2*block_height)) < $BEST_CHAIN_QUERY_FROM"
        stop_nodes "$MAIN_MINA_EXE"
        exit 3
    fi
    log_validation "slot-occupancy" "pass" ">50% slot occupancy confirmed"
    
    # Get genesis epoch data
    local first_epoch_ne_str
    first_epoch_ne_str=$(run_cmd_capture bash -c "blocks 10303 2>/dev/null | latest_nonempty_block")
    IFS=, read -ra first_epoch_ne <<< "$first_epoch_ne_str"
    
    genesis_epoch_staking_hash="${first_epoch_ne[$((3+IX_CUR_EPOCH_HASH))]}"
    genesis_epoch_next_hash="${first_epoch_ne[$((3+IX_NEXT_EPOCH_HASH))]}"
    
    log_info "Genesis epoch staking hash: $genesis_epoch_staking_hash"
    log_info "Genesis epoch next hash: $genesis_epoch_next_hash"
    
    log_validation "step-2" "pass" "Block production validation completed"
}

# Test Step 3: Collect block data until chain end
test_step_3_collect_block_data() {
    log_info "=== TEST STEP 3: Collecting block data until chain end ==="
    
    log_info "Collecting blocks from slot $BEST_CHAIN_QUERY_FROM to $SLOT_CHAIN_END"
    
    local last_ne_str
    last_ne_str=$(run_cmd_capture bash -c "
        for i in \$(seq $BEST_CHAIN_QUERY_FROM $SLOT_CHAIN_END); do
            blocks \$((10303+10*(i%2))) 2>/dev/null || true
            sleep ${MAIN_SLOT}s
        done | latest_nonempty_block
    ")
    
    IFS=, read -ra latest_ne <<< "$last_ne_str"
    
    # Parse block data
    max_slot=${latest_ne[0]}
    IFS=: read -ra epochs <<< "${latest_ne[1]}"
    IFS=: read -ra last_snarked_hash_pe <<< "${latest_ne[2]}"
    latest_ne=( "${latest_ne[@]:3}" )
    
    log_info "Last occupied slot of pre-fork chain: $max_slot"
    
    # Validate slot constraints
    if [[ $max_slot -ge $SLOT_CHAIN_END ]]; then
        log_error "Block with slot $max_slot created after slot chain end $SLOT_CHAIN_END"
        stop_nodes "$MAIN_MINA_EXE"
        exit 3
    fi
    
    latest_shash="${latest_ne[$IX_STATE_HASH]}"
    latest_height=${latest_ne[$IX_HEIGHT]}
    latest_ne_slot=${latest_ne[$IX_SLOT]}
    
    log_info "Latest non-empty block: $latest_shash, height: $latest_height, slot: $latest_ne_slot"
    
    if [[ $latest_ne_slot -ge $SLOT_TX_END ]]; then
        log_error "Non-empty block with slot $latest_ne_slot created after slot tx end $SLOT_TX_END"
        stop_nodes "$MAIN_MINA_EXE"
        exit 3
    fi
    
    log_validation "step-3" "pass" "Block data collection completed"
}

# Test Step 4: Verify no new blocks are created after chain end
test_step_4_verify_no_new_blocks() {
    log_info "=== TEST STEP 4: Verifying no new blocks after chain end ==="
    
    log_timing "sleep" "1m before first height check"
    sleep 1m
    local height1
    height1=$(get_height 10303)
    
    log_timing "sleep" "5m before second height check"
    sleep 5m
    local height2
    height2=$(get_height 10303)
    
    local height_diff=$((height2 - height1))
    log_info "Height difference after chain end: $height_diff (should be 0)"
    
    if [[ $height_diff -gt 0 ]]; then
        log_error "Block height changed after slot chain end: $height1 -> $height2"
        stop_nodes "$MAIN_MINA_EXE"
        exit 3
    fi
    
    log_validation "step-4" "pass" "No new blocks created after chain end"
}

# Test Step 5: Extract fork configuration
test_step_5_extract_fork_config() {
    log_info "=== TEST STEP 5: Extracting fork configuration ==="
    
    log_file_op "create" "localnet/fork_config.json"
    run_cmd_capture bash -c "get_fork_config 10313 > localnet/fork_config.json"
    
    # Wait for valid fork config
    while [[ "$(stat -c %s localnet/fork_config.json)" == 0 ]] || [[ "$(head -c 4 localnet/fork_config.json)" == "null" ]]; do
        log_warn "Failed to fetch fork config, retrying in 1m"
        log_timing "sleep" "1m before retry"
        sleep 1m
        run_cmd_capture bash -c "get_fork_config 10313 > localnet/fork_config.json"
    done
    
    log_validation "step-5" "pass" "Fork configuration extracted successfully"
}

# Test Step 6: Validate fork configuration data
test_step_6_validate_fork_config() {
    log_info "=== TEST STEP 6: Validating fork configuration data ==="
    
    # Stop main network
    stop_nodes "$MAIN_MINA_EXE"
    
    # Validate fork data
    local expected_fork_data="{\"fork\":{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$latest_ne_slot,\"state_hash\":\"$latest_shash\"},\"next_seed\":\"${latest_ne[$IX_NEXT_EPOCH_SEED]}\",\"staking_seed\":\"${latest_ne[$IX_CUR_EPOCH_SEED]}\"}"
    local actual_fork_data
    actual_fork_data=$(run_cmd_capture jq -cS '{fork:.proof.fork,next_seed:.epoch_data.next.seed,staking_seed:.epoch_data.staking.seed}' localnet/fork_config.json)
    
    if [[ "$actual_fork_data" != "$expected_fork_data" ]]; then
        log_error "Unexpected fork data"
        log_error "Expected: $expected_fork_data"
        log_error "Actual: $actual_fork_data"
        exit 3
    fi
    
    log_validation "step-6" "pass" "Fork configuration data validated"
}

# Test Step 7: Generate pre-fork ledgers and validate hashes
test_step_7_generate_prefork_ledgers() {
    log_info "=== TEST STEP 7: Generating pre-fork ledgers and validating hashes ==="
    
    log_info "Generating pre-fork ledgers"
    run_cmd "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" \
        --config-file localnet/fork_config.json \
        --genesis-dir localnet/prefork_hf_ledgers \
        --hash-output-file localnet/prefork_hf_ledger_hashes.json
    
    # Calculate expected hashes
    local slot_tx_end_epoch=$((latest_ne_slot/48))
    local expected_staking_hash
    local expected_next_hash
    expected_staking_hash=$(find_staking_hash $slot_tx_end_epoch)
    expected_next_hash=$(find_staking_hash $((slot_tx_end_epoch+1)))
    
    local expected_prefork_hashes="{\"epoch_data\":{\"next\":{\"hash\":\"$expected_next_hash\"},\"staking\":{\"hash\":\"$expected_staking_hash\"}},\"ledger\":{\"hash\":\"${latest_ne[$IX_STAGED_HASH]}\"}}"
    
    # Validate generated hashes
    local prefork_hashes_select='{epoch_data:{staking:{hash:.epoch_data.staking.hash},next:{hash:.epoch_data.next.hash}},ledger:{hash:.ledger.hash}}'
    local actual_prefork_hashes
    actual_prefork_hashes=$(run_cmd_capture jq -cS "$prefork_hashes_select" localnet/prefork_hf_ledger_hashes.json)
    
    if [[ "$actual_prefork_hashes" != "$expected_prefork_hashes" ]]; then
        log_error "Unexpected ledgers in fork_config"
        log_error "Expected: $expected_prefork_hashes"
        log_error "Actual: $actual_prefork_hashes"
        exit 3
    fi
    
    log_validation "step-7" "pass" "Pre-fork ledgers generated and validated"
}

# Test Step 8: Generate fork ledgers and runtime config
test_step_8_generate_fork_config() {
    log_info "=== TEST STEP 8: Generating fork ledgers and runtime config ==="
    
    # Clean up and create fork ledgers directory
    run_cmd rm -Rf localnet/hf_ledgers
    run_cmd mkdir localnet/hf_ledgers
    
    log_info "Generating fork ledgers"
    run_cmd "$FORK_RUNTIME_GENESIS_LEDGER_EXE" \
        --config-file localnet/fork_config.json \
        --genesis-dir localnet/hf_ledgers \
        --hash-output-file localnet/hf_ledger_hashes.json
    
    # Calculate fork genesis timestamp
    local now_unix_ts
    now_unix_ts=$(run_cmd_capture date +%s)
    FORK_GENESIS_UNIX_TS=$((now_unix_ts - now_unix_ts%60 + FORK_DELAY*60))
    local fork_genesis_timestamp
    fork_genesis_timestamp=$(run_cmd_capture date -u -d "@$FORK_GENESIS_UNIX_TS" '+%F %H:%M:%S+00:00')
    
    log_info "Fork genesis timestamp: $fork_genesis_timestamp"
    export GENESIS_TIMESTAMP="$fork_genesis_timestamp"
    
    # Generate runtime config
    log_info "Generating fork runtime config"
    log_file_op "create" "localnet/config.json"
    run_cmd_capture bash -c "
        FORKING_FROM_CONFIG_JSON=localnet/config/base.json \
        SECONDS_PER_SLOT='$MAIN_SLOT' \
        FORK_CONFIG_JSON=localnet/fork_config.json \
        LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json \
        '$SCRIPT_DIR/create_runtime_config.sh' > localnet/config.json
    "
    
    # Validate modified fork data
    local expected_genesis_slot=$(((FORK_GENESIS_UNIX_TS-MAIN_GENESIS_UNIX_TS)/MAIN_SLOT))
    local expected_modified_fork_data="{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$expected_genesis_slot,\"state_hash\":\"$latest_shash\"}"
    local actual_modified_fork_data
    actual_modified_fork_data=$(run_cmd_capture jq -cS '.proof.fork' localnet/config.json)
    
    if [[ "$actual_modified_fork_data" != "$expected_modified_fork_data" ]]; then
        log_error "Unexpected modified fork data"
        log_error "Expected: $expected_modified_fork_data"
        log_error "Actual: $actual_modified_fork_data"
        exit 3
    fi
    
    log_validation "step-8" "pass" "Fork ledgers and runtime config generated"
}

# Test Step 9: Start fork network and validate initial block
test_step_9_start_fork_network() {
    log_info "=== TEST STEP 9: Starting fork network and validating initial block ==="
    
    # Wait for main network to finish
    log_info "Waiting for main network to complete"
    wait "$MAIN_NETWORK_PID"
    
    log_info "Starting fork network"
    run_cmd_background "$SCRIPT_DIR/run-localnet.sh" \
        -m "$FORK_MINA_EXE" \
        -d "$FORK_DELAY" \
        -i "$FORK_SLOT" \
        -s "$FORK_SLOT" \
        -c localnet/config.json \
        --genesis-ledger-dir localnet/hf_ledgers
    
    log_timing "sleep" "${FORK_DELAY}m for fork network startup"
    sleep $((FORK_DELAY*60))s
    
    # Wait for first block
    local earliest_str=""
    while [[ "$earliest_str" == "" ]] || [[ "$earliest_str" == "," ]]; do
        log_debug "Waiting for first block in fork network"
        earliest_str=$(get_height_and_slot_of_earliest 10303 2>/dev/null || true)
        log_timing "sleep" "${FORK_SLOT}s before retry"
        sleep "$FORK_SLOT"s
    done
    
    IFS=, read -ra earliest <<< "$earliest_str"
    local earliest_height=${earliest[0]}
    local earliest_slot=${earliest[1]}
    
    log_info "Fork network first block: height=$earliest_height, slot=$earliest_slot"
    
    # Validate fork continuity
    local expected_height=$((latest_height+1))
    if [[ $earliest_height != $expected_height ]]; then
        log_error "Unexpected block height $earliest_height at fork start (expected: $expected_height)"
        stop_nodes "$FORK_MINA_EXE"
        exit 3
    fi
    
    local expected_genesis_slot=$(((FORK_GENESIS_UNIX_TS-MAIN_GENESIS_UNIX_TS)/MAIN_SLOT))
    if [[ $earliest_slot -lt $expected_genesis_slot ]]; then
        log_error "Unexpected slot $earliest_slot at fork start (expected: >= $expected_genesis_slot)"
        stop_nodes "$FORK_MINA_EXE"
        exit 3
    fi
    
    log_validation "step-9" "pass" "Fork network started and initial block validated"
}

# Test Step 10: Validate fork network block production
test_step_10_validate_fork_production() {
    log_info "=== TEST STEP 10: Validating fork network block production ==="
    
    # Wait for block production
    log_timing "sleep" "$((FORK_SLOT*10))s for block production"
    sleep $((FORK_SLOT*10))s
    
    local height1
    height1=$(get_height 10303)
    if [[ $height1 == 0 ]]; then
        log_error "Block height $height1 should be greater than 0"
        stop_nodes "$FORK_MINA_EXE"
        exit 3
    fi
    log_info "Fork network is producing blocks (height: $height1)"
    
    # Check for user commands in blocks
    log_info "Checking for user commands in last 10 blocks"
    local all_blocks_empty=true
    for i in {1..10}; do
        log_timing "sleep" "${FORK_SLOT}s before block check"
        sleep "${FORK_SLOT}s"
        local usercmds
        usercmds=$(blocks_with_user_commands 10303)
        log_debug "Block $i has $usercmds user commands"
        if [[ $usercmds != 0 ]]; then
            all_blocks_empty=false
        fi
    done
    
    if $all_blocks_empty; then
        log_error "All blocks in fork chain are empty"
        stop_nodes "$FORK_MINA_EXE"
        exit 3
    fi
    
    log_validation "step-10" "pass" "Fork network block production validated"
    
    # Clean shutdown
    stop_nodes "$FORK_MINA_EXE"
}

#=============================================================================
# MAIN ORCHESTRATION
#=============================================================================

# Execute all test steps in sequence
run_hardfork_test() {
    log_info "Starting comprehensive hardfork test"
    log_info "Configuration: SLOT_TX_END=$SLOT_TX_END, SLOT_CHAIN_END=$SLOT_CHAIN_END"
    log_info "Main executable: $MAIN_MINA_EXE"
    log_info "Fork executable: $FORK_MINA_EXE"
    
    # Execute test steps in sequence
    test_step_1_start_main_network
    test_step_2_validate_block_production
    test_step_3_collect_block_data
    test_step_4_verify_no_new_blocks
    test_step_5_extract_fork_config
    test_step_6_validate_fork_config
    test_step_7_generate_prefork_ledgers
    test_step_8_generate_fork_config
    test_step_9_start_fork_network
    test_step_10_validate_fork_production
    
    log_info "=== HARDFORK TEST COMPLETED SUCCESSFULLY ==="
}

# Main function
main() {
    # Handle legacy positional arguments for backward compatibility
    if [[ $# -eq 4 ]] && [[ "$1" != "--"* ]]; then
        log_warn "Using legacy positional arguments (deprecated)"
        MAIN_MINA_EXE="$1"
        MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"
        FORK_MINA_EXE="$3"
        FORK_RUNTIME_GENESIS_LEDGER_EXE="$4"
    else
        # Parse modern named arguments
        parse_arguments "$@"
    fi
    
    # Validate arguments and run test
    validate_arguments
    run_hardfork_test
}

#=============================================================================
# SCRIPT ENTRY POINT
#=============================================================================

# Execute main function with all provided arguments
main "$@"