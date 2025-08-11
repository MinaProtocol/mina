#!/usr/bin/env bash

# Local Network Launcher Script
# Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes
# (a block producer and a snark worker) that continuously produce blocks and send transactions.

set -euo pipefail

# Source shared libraries
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# Environment setup for mina
export MINA_LIBP2P_PASS=
export MINA_PRIVKEY_PASS=

#=============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
#=============================================================================

# Configuration defaults
declare -g TX_INTERVAL="${TX_INTERVAL:-30s}"
declare -g DELAY_MIN="${DELAY_MIN:-20}"
declare -g CONF_SUFFIX="${CONF_SUFFIX:-}"
declare -g CUSTOM_CONF="${CUSTOM_CONF:-}"
declare -g SLOT_TX_END="${SLOT_TX_END:-}"
declare -g SLOT_CHAIN_END="${SLOT_CHAIN_END:-}"
declare -g MINA_EXE="${MINA_EXE:-mina}"
declare -g GENESIS_LEDGER_DIR="${GENESIS_LEDGER_DIR:-}"
declare -g SLOT="${SLOT:-30}"
declare -g GENESIS_TIMESTAMP=""

# Runtime configuration
declare -g CONF_DIR="localnet/config"
declare -ga NODE_ARGS_1=()
declare -ga NODE_ARGS_2=()
declare -ga COMMON_ARGS=()
declare -g bp_pid=""
declare -g sw_pid=""

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes.

OPTIONS:
    -m, --mina PATH               Path to mina executable (default: mina)
    -i, --tx-interval DURATION    Interval between transactions (default: 30s)
    -d, --delay-min MINUTES       Genesis delay in minutes (default: 20)
    -s, --slot SECONDS           Slot duration in seconds (default: 30)
    -c, --config PATH            Custom config file path
    --develop                    Use develop ledger suffix
    --slot-tx-end SLOT           Slot when transactions should end
    --slot-chain-end SLOT        Slot when chain should end
    --genesis-ledger-dir PATH    Genesis ledger directory
    -h, --help                   Show this help message

EXAMPLES:
    # Basic usage
    $0

    # With custom mina executable and shorter slots
    $0 -m ./devnet/bin/mina -s 15

    # With custom transaction interval and delay
    $0 -i 10s -d 5

    # Using custom config
    $0 -c ./my-config.json

ENVIRONMENT:
    TX_INTERVAL         Transaction interval (default: 30s)
    DELAY_MIN          Genesis delay in minutes (default: 20)
    MINA_EXE          Mina executable path (default: mina)
    SLOT              Slot duration in seconds (default: 30)
    GENESIS_TIMESTAMP Genesis timestamp (auto-calculated if not set)
EOF
}

# Parse command line arguments
parse_arguments() {
    local keys=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--delay-min)
                DELAY_MIN="$2"
                shift 2
                ;;
            -i|--tx-interval)
                TX_INTERVAL="$2"
                shift 2
                ;;
            --develop)
                CONF_SUFFIX=".develop"
                shift
                ;;
            -m|--mina)
                MINA_EXE="$2"
                shift 2
                ;;
            -s|--slot)
                SLOT="$2"
                shift 2
                ;;
            -c|--config)
                CUSTOM_CONF="$2"
                shift 2
                ;;
            --slot-chain-end)
                SLOT_CHAIN_END="$2"
                shift 2
                ;;
            --slot-tx-end)
                SLOT_TX_END="$2"
                shift 2
                ;;
            --genesis-ledger-dir)
                GENESIS_LEDGER_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                keys+=("$1")
                shift
                ;;
        esac
    done
    
    log_debug "Parsed ${#keys[@]} additional keys: ${keys[*]}"
}

# Validate configuration and arguments
validate_configuration() {
    log_info "Validating configuration"
    
    # Check for conflicting options
    if [[ -n "$CONF_SUFFIX" ]] && [[ -n "$CUSTOM_CONF" ]]; then
        log_error "Cannot use both --develop and --config options"
        exit 1
    fi
    
    # Check mina executable exists
    if ! cmd_exists "$MINA_EXE"; then
        log_error "Mina executable not found: $MINA_EXE"
        exit 1
    fi
    
    # Calculate genesis timestamp if not provided
    if [[ -z "$GENESIS_TIMESTAMP" ]]; then
        local current_time
        current_time=$(run_cmd_capture date +%s)
        local genesis_time=$((current_time - current_time%60 + DELAY_MIN*60))
        GENESIS_TIMESTAMP=$(run_cmd_capture date -u -d "@$genesis_time" '+%F %H:%M:%S+00:00')
    fi
    
    log_config "set" "Mina executable: $MINA_EXE"
    log_config "set" "Genesis timestamp: $GENESIS_TIMESTAMP"
    log_config "set" "Slot duration: ${SLOT}s"
    log_config "set" "Transaction interval: $TX_INTERVAL"
    log_config "set" "Genesis delay: ${DELAY_MIN}m"
    
    if [[ -n "$SLOT_TX_END" ]]; then
        log_config "set" "Transaction end slot: $SLOT_TX_END"
    fi
    if [[ -n "$SLOT_CHAIN_END" ]]; then
        log_config "set" "Chain end slot: $SLOT_CHAIN_END"
    fi
}

#=============================================================================
# CONFIGURATION GENERATION FUNCTIONS
#=============================================================================

# Create and setup configuration directory
setup_config_directory() {
    log_info "Setting up configuration directory: $CONF_DIR"
    
    log_file_op "mkdir" "$CONF_DIR"
    run_cmd mkdir -p "$CONF_DIR"
    
    log_file_op "chmod" "0700 $CONF_DIR"
    run_cmd chmod 0700 "$CONF_DIR"
}

# Generate block producer keypair
generate_block_producer_key() {
    local bp_key_path="$CONF_DIR/bp"
    
    if [[ ! -f "$bp_key_path" ]]; then
        log_info "Generating block producer keypair"
        run_cmd "$MINA_EXE" advanced generate-keypair --privkey-path "$bp_key_path"
        log_validation "bp-key" "pass" "Block producer key generated"
    else
        log_info "Block producer key already exists, skipping generation"
    fi
}

# Generate libp2p keypairs for both nodes
generate_libp2p_keys() {
    log_info "Generating libp2p keypairs for nodes"
    
    local libp2p_1_path="$CONF_DIR/libp2p_1"
    local libp2p_2_path="$CONF_DIR/libp2p_2"
    
    run_cmd "$MINA_EXE" libp2p generate-keypair --privkey-path "$libp2p_1_path"
    run_cmd "$MINA_EXE" libp2p generate-keypair --privkey-path "$libp2p_2_path"
    
    # Setup node arguments with libp2p keys
    NODE_ARGS_1=( --libp2p-keypair "$PWD/$libp2p_1_path" )
    NODE_ARGS_2=( --libp2p-keypair "$PWD/$libp2p_2_path" )
    
    log_validation "libp2p-keys" "pass" "Libp2p keypairs generated"
}

# Generate test ledger if needed
generate_test_ledger() {
    local ledger_path="$CONF_DIR/ledger.json"
    
    if [[ -z "$CUSTOM_CONF" ]] && [[ ! -f "$ledger_path" ]]; then
        log_info "Generating test ledger"
        
        local bp_pubkey
        bp_pubkey=$(run_cmd_capture cat "$CONF_DIR/bp.pub")
        
        run_cmd_capture bash -c "
            cd '$CONF_DIR' && 
            '$SCRIPT_DIR/../prepare-test-ledger.sh' -c 100000 -b 1000000 '$bp_pubkey' > ledger.json
        "
        
        log_validation "test-ledger" "pass" "Test ledger generated"
    else
        log_info "Using existing ledger or custom config, skipping ledger generation"
    fi
}

# Build jq expression for slot configuration
build_slot_config_expression() {
    local slot_config=""
    
    if [[ -n "$SLOT_TX_END" ]]; then
        slot_config=".daemon.slot_tx_end = $SLOT_TX_END | "
        log_config "set" "Slot TX end: $SLOT_TX_END"
    fi
    
    if [[ -n "$SLOT_CHAIN_END" ]]; then
        slot_config="$slot_config .daemon.slot_chain_end = $SLOT_CHAIN_END | "
        log_config "set" "Slot chain end: $SLOT_CHAIN_END"
    fi
    
    echo "$slot_config .genesis.genesis_state_timestamp = \"$GENESIS_TIMESTAMP\""
}

# Generate base configuration file
generate_base_config() {
    log_info "Generating base configuration"
    
    local config_expr
    config_expr=$(build_slot_config_expression)
    
    log_file_op "create" "$CONF_DIR/base.json"
    run_cmd_capture bash -c "
        jq '$config_expr' > '$CONF_DIR/base.json' << 'EOF'
{
  \"genesis\": {
    \"slots_per_epoch\": 48,
    \"k\": 10,
    \"grace_period_slots\": 3
  },
  \"proof\": {
    \"work_delay\": 1,
    \"level\": \"full\",
    \"transaction_capacity\": { \"2_to_the\": 2 },
    \"block_window_duration_ms\": ${SLOT}000
  }
}
EOF
    "
    
    log_validation "base-config" "pass" "Base configuration generated"
}

# Generate daemon configuration file
generate_daemon_config() {
    log_info "Generating daemon configuration"
    
    local daemon_config_path="$CONF_DIR/daemon$CONF_SUFFIX.json"
    
    if [[ -z "$CUSTOM_CONF" ]]; then
        log_info "Creating daemon config from test ledger"
        log_file_op "create" "$daemon_config_path"
        run_cmd_capture bash -c "
            { 
                echo '{\"ledger\": {\"accounts\": '
                cat '$CONF_DIR/ledger.json'
                echo '}}'
            } > '$daemon_config_path'
        "
    else
        log_info "Using custom configuration: $CUSTOM_CONF"
        log_file_op "copy" "$CUSTOM_CONF -> $daemon_config_path"
        run_cmd cp "$CUSTOM_CONF" "$daemon_config_path"
    fi
    
    log_validation "daemon-config" "pass" "Daemon configuration ready"
}

#=============================================================================
# NODE STARTUP FUNCTIONS
#=============================================================================

# Setup common arguments for both nodes
setup_common_node_args() {
    log_info "Setting up common node arguments"
    
    COMMON_ARGS=( --file-log-level Info --log-level Error --seed )
    COMMON_ARGS+=( --config-file "$PWD/$CONF_DIR/base.json" )
    COMMON_ARGS+=( --config-file "$PWD/$CONF_DIR/daemon$CONF_SUFFIX.json" )
    
    log_debug "Common args: ${COMMON_ARGS[*]}"
}

# Setup genesis ledger directories if specified
setup_genesis_ledger_dirs() {
    if [[ -n "$GENESIS_LEDGER_DIR" ]]; then
        log_info "Setting up genesis ledger directories"
        
        # Clean existing directories
        run_cmd rm -Rf localnet/genesis_1 localnet/genesis_2
        
        # Copy genesis ledger for each node
        log_file_op "copy" "$GENESIS_LEDGER_DIR -> localnet/genesis_1"
        run_cmd cp -Rf "$GENESIS_LEDGER_DIR" localnet/genesis_1
        
        log_file_op "copy" "$GENESIS_LEDGER_DIR -> localnet/genesis_2"
        run_cmd cp -Rf "$GENESIS_LEDGER_DIR" localnet/genesis_2
        
        # Add genesis ledger args to node configurations
        NODE_ARGS_1+=( --genesis-ledger-dir "$PWD/localnet/genesis_1" )
        NODE_ARGS_2+=( --genesis-ledger-dir "$PWD/localnet/genesis_2" )
        
        log_validation "genesis-ledger" "pass" "Genesis ledger directories configured"
    fi
}

# Clean runtime directories
clean_runtime_directories() {
    log_info "Cleaning runtime directories"
    run_cmd rm -Rf localnet/runtime_1 localnet/runtime_2
}

# Start block producer node
start_block_producer_node() {
    log_info "Starting block producer node"
    
    local libp2p_2_peerid
    libp2p_2_peerid=$(run_cmd_capture cat "$CONF_DIR/libp2p_2.peerid")
    
    log_process_op "start" "block producer daemon"
    bp_pid=$(run_cmd_background "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
        --peer "/ip4/127.0.0.1/tcp/10312/p2p/$libp2p_2_peerid" \
        "${NODE_ARGS_1[@]}" \
        --block-producer-key "$PWD/$CONF_DIR/bp" \
        --config-directory "$PWD/localnet/runtime_1" \
        --client-port 10301 --external-port 10302 --rest-port 10303)
    
    log_info "Block producer started with PID: $bp_pid"
}

# Start snark worker node
start_snark_worker_node() {
    log_info "Starting snark worker node"
    
    local libp2p_1_peerid
    libp2p_1_peerid=$(run_cmd_capture cat "$CONF_DIR/libp2p_1.peerid")
    
    local bp_pubkey
    bp_pubkey=$(run_cmd_capture cat "$CONF_DIR/bp.pub")
    
    log_process_op "start" "snark worker daemon"
    sw_pid=$(run_cmd_background "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
        "${NODE_ARGS_2[@]}" \
        --peer "/ip4/127.0.0.1/tcp/10302/p2p/$libp2p_1_peerid" \
        --run-snark-worker "$bp_pubkey" --work-selection seq \
        --config-directory "$PWD/localnet/runtime_2" \
        --client-port 10311 --external-port 10312 --rest-port 10313)
    
    log_info "Snark worker started with PID: $sw_pid"
}

# Wait for account import to succeed
wait_for_account_import() {
    log_info "Waiting for account import to succeed"
    
    local attempts=0
    local max_attempts=20
    
    while ! run_cmd_quiet "$MINA_EXE" accounts import \
        --privkey-path "$PWD/$CONF_DIR/bp" \
        --rest-server 10313; do
        
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            log_error "Account import failed after $max_attempts attempts"
            exit 1
        fi
        
        log_debug "Account import attempt $attempts failed, retrying in 1m"
        log_timing "sleep" "1m before account import retry"
        sleep 1m
    done
    
    log_validation "account-import" "pass" "Account imported successfully"
}

# Export staged ledger for transaction sending
export_staged_ledger() {
    log_info "Exporting staged ledger for transaction sending"
    
    local attempts=0
    local max_attempts=10
    
    while ! run_cmd_quiet bash -c "
        '$MINA_EXE' ledger export staged-ledger --daemon-port 10311 > localnet/exported_staged_ledger.json
    "; do
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            log_error "Staged ledger export failed after $max_attempts attempts"
            exit 1
        fi
        
        log_debug "Staged ledger export attempt $attempts failed, retrying in 1m"
        log_timing "sleep" "1m before staged ledger export retry"
        sleep 1m
    done
    
    log_validation "staged-ledger-export" "pass" "Staged ledger exported"
}

#=============================================================================
# TRANSACTION FUNCTIONS
#=============================================================================

# Send a single payment transaction
send_payment_transaction() {
    local sender_pubkey="$1"
    local receiver_pubkey="$2"
    local tx_number="$3"
    
    log_debug "Sending transaction #$tx_number: $sender_pubkey -> $receiver_pubkey"
    
    if run_cmd_quiet "$MINA_EXE" client send-payment \
        --sender "$sender_pubkey" \
        --receiver "$receiver_pubkey" \
        --amount 0.1 \
        --memo "payment_$tx_number" \
        --rest-server 10313; then
        
        log_info "Sent transaction #$tx_number"
        return 0
    else
        log_warn "Failed to send transaction #$tx_number"
        return 1
    fi
}

# Extract receiver addresses from staged ledger
extract_receiver_addresses() {
    log_debug "Extracting receiver addresses from staged ledger"
    run_cmd_capture bash -c "
        jq -r '.[].pk' localnet/exported_staged_ledger.json | { shuf || true; }
    "
}

# Send transactions continuously
send_transactions_continuously() {
    log_info "Starting continuous transaction sending"
    log_info "Transaction interval: $TX_INTERVAL"
    
    local sender_pubkey
    sender_pubkey=$(run_cmd_capture cat "$CONF_DIR/bp.pub")
    
    local tx_number=0
    
    # Continue while snark worker is running
    while kill -0 "$sw_pid" 2>/dev/null; do
        log_debug "Transaction loop iteration, checking if snark worker (PID: $sw_pid) is still running"
        
        # Extract receiver addresses and send transactions
        extract_receiver_addresses | while read -r receiver_addr; do
            # Check if snark worker is still running
            if ! kill -0 "$sw_pid" 2>/dev/null; then
                log_info "Snark worker stopped, ending transaction loop"
                break
            fi
            
            tx_number=$((tx_number + 1))
            send_payment_transaction "$sender_pubkey" "$receiver_addr" "$tx_number"
            
            log_timing "sleep" "$TX_INTERVAL between transactions"
            sleep "$TX_INTERVAL"
        done
    done
    
    log_info "Transaction sending completed"
}

#=============================================================================
# MAIN ORCHESTRATION FUNCTIONS
#=============================================================================

# Setup configuration and keys
setup_localnet_configuration() {
    log_info "=== Setting up localnet configuration ==="
    
    setup_config_directory
    generate_block_producer_key
    generate_libp2p_keys
    generate_test_ledger
    generate_base_config
    generate_daemon_config
    
    log_validation "configuration" "pass" "Localnet configuration completed"
}

# Launch mina nodes
launch_mina_nodes() {
    log_info "=== Launching Mina nodes ==="
    
    setup_common_node_args
    setup_genesis_ledger_dirs
    clean_runtime_directories
    start_block_producer_node
    start_snark_worker_node
    
    log_validation "node-startup" "pass" "Mina nodes launched successfully"
}

# Setup transaction environment
setup_transaction_environment() {
    log_info "=== Setting up transaction environment ==="
    
    wait_for_account_import
    export_staged_ledger
    
    log_validation "tx-environment" "pass" "Transaction environment ready"
}

# Main execution function
run_localnet() {
    log_info "Starting localnet setup and execution"
    
    # Configuration and validation
    validate_configuration
    
    # Setup and launch
    setup_localnet_configuration
    launch_mina_nodes
    setup_transaction_environment
    
    # Start transaction loop
    send_transactions_continuously
    
    # Wait for all background processes
    log_info "Waiting for background processes to complete"
    log_process_op "wait" "all background processes"
    wait
    
    log_info "Localnet execution completed"
}

#=============================================================================
# MAIN FUNCTION
#=============================================================================

# Main entry point
main() {
    log_info "Mina Localnet Launcher"
    log_info "Creates a quick-epoch-turnaround configuration and launches two Mina nodes"
    
    # Parse arguments and run
    parse_arguments "$@"
    run_localnet
}

#=============================================================================
# SCRIPT ENTRY POINT
#=============================================================================

# Execute main function with all provided arguments
main "$@"