#!/usr/bin/env bash

set -euo pipefail

export MINA_LIBP2P_PASS=
export MINA_PRIVKEY_PASS=
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source shared libraries
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# Default configuration values
TX_INTERVAL=${TX_INTERVAL:-30s}           # Interval at which to send transactions
DELAY_MIN=${DELAY_MIN:-20}               # Delay between now and genesis timestamp, in minutes
CONF_SUFFIX=${CONF_SUFFIX:-}             # Allows to use develop ledger when equals to .develop
CUSTOM_CONF=${CUSTOM_CONF:-}             # Custom configuration file path
SLOT_TX_END=${SLOT_TX_END:-}             # Specify slot_tx_end parameter in the config
SLOT_CHAIN_END=${SLOT_CHAIN_END:-}       # Specify slot_chain_end parameter in the config
MINA_EXE=${MINA_EXE:-mina}               # Mina executable
GENESIS_LEDGER_DIR=${GENESIS_LEDGER_DIR:-} # Genesis ledger directory
SLOT=${SLOT:-30}                         # Slot duration (a.k.a. block window duration), seconds

show_usage() {
    cat >&2 << EOF
Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes

Usage: $0 [OPTIONS]

OPTIONS:
  -m, --mina EXECUTABLE         Mina executable path (default: $MINA_EXE)
  -i, --tx-interval INTERVAL    Transaction interval (default: $TX_INTERVAL)
  -d, --delay-min MINUTES       Genesis delay in minutes (default: $DELAY_MIN)
  -s, --slot SECONDS            Slot duration in seconds (default: $SLOT)
  --develop                     Use develop ledger
  -c, --config FILE             Custom config file path
  --slot-tx-end SLOT            Slot tx end parameter
  --slot-chain-end SLOT         Slot chain end parameter
  --genesis-ledger-dir DIR      Genesis ledger directory

Consider reading script's code for information on optional arguments
EOF
}

parse_arguments() {
    local keys=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage; exit 0 ;;
            -d|--delay-min)
                DELAY_MIN="$2"; shift 2 ;;
            -i|--tx-interval)
                TX_INTERVAL="$2"; shift 2 ;;
            --develop)
                CONF_SUFFIX=".develop"; shift ;;
            -m|--mina)
                MINA_EXE="$2"; shift 2 ;;
            -s|--slot)
                SLOT="$2"; shift 2 ;;
            -c|--config)
                CUSTOM_CONF="$2"; shift 2 ;;
            --slot-chain-end)
                SLOT_CHAIN_END="$2"; shift 2 ;;
            --slot-tx-end)
                SLOT_TX_END="$2"; shift 2 ;;
            --genesis-ledger-dir)
                GENESIS_LEDGER_DIR="$2"; shift 2 ;;
            -*)
                log_error "Unknown option: $1"
                show_usage; exit 1 ;;
            *)
                keys+=("$1"); shift ;;
        esac
    done
    
    # Return unused positional arguments
    printf '%s\n' "${keys[@]}"
}

validate_configuration() {
    if [[ -n "$CONF_SUFFIX" ]] && [[ -n "$CUSTOM_CONF" ]]; then
        log_error "Cannot use both --develop and --config options"
        return 1
    fi

    if ! command -v "$MINA_EXE" >/dev/null; then
        log_error "Mina executable not found: $MINA_EXE"
        return 1
    fi
    
    log_debug "Configuration validated successfully"
    return 0
}

# Parse command line arguments
readarray -t KEYS < <(parse_arguments "$@")
validate_configuration

calculate_genesis_timestamp() {
    local delay_min="$1"
    local current_time
    current_time=$(date +%s)
    date -u -d "@$((current_time - current_time % 60 + delay_min * 60))" '+%F %H:%M:%S+00:00'
}

setup_configuration_directory() {
    local conf_dir="$1"
    
    log_env_setup "configuration directory" "$conf_dir"
    
    log_file_op "mkdir" "$conf_dir"
    mkdir -p "$conf_dir"

    log_file_op "chmod" "0700" "$conf_dir"
    chmod 0700 "$conf_dir"
    
    if [[ ! -f "$conf_dir/bp" ]]; then
        log_info "Generating block producer keypair"
        run_cmd "$MINA_EXE" advanced generate-keypair --privkey-path "$conf_dir/bp"
    fi
    
    log_info "Generating libp2p keypairs"
    run_cmd "$MINA_EXE" libp2p generate-keypair --privkey-path "$conf_dir/libp2p_1"
    run_cmd "$MINA_EXE" libp2p generate-keypair --privkey-path "$conf_dir/libp2p_2"
    
    if [[ -z "$CUSTOM_CONF" ]] && [[ ! -f "$conf_dir/ledger.json" ]]; then
        log_info "Generating test ledger"
        log_cmd "(cd $conf_dir && $SCRIPT_DIR/../prepare-test-ledger.sh -c 100000 -b 1000000 \$(cat bp.pub) > ledger.json)"
        if ! (cd "$conf_dir" && "$SCRIPT_DIR/../prepare-test-ledger.sh" -c 100000 -b 1000000 "$(cat bp.pub)" > ledger.json); then
            log_error "Failed to generate test ledger"
            return 1
        fi
    fi
}

generate_base_config() {
    local conf_dir="$1"
    local genesis_timestamp="$2"
    local slot="$3"
    local slot_tx_end="$4"
    local slot_chain_end="$5"
    
    log_config "generate" "base configuration"
    log_debug "Genesis timestamp: $genesis_timestamp, Slot: ${slot}s"
    log_debug "Slot TX end: ${slot_tx_end:-none}, Slot chain end: ${slot_chain_end:-none}"
    
    local slot_ends=""
    if [[ -n "$slot_tx_end" ]]; then
        slot_ends=".daemon.slot_tx_end = $slot_tx_end | "
        log_config "set" "slot_tx_end = $slot_tx_end"
    fi
    if [[ -n "$slot_chain_end" ]]; then
        slot_ends="$slot_ends .daemon.slot_chain_end = $slot_chain_end | "
        log_config "set" "slot_chain_end = $slot_chain_end"
    fi
    
    local update_config_expr="$slot_ends .genesis.genesis_state_timestamp = \"$genesis_timestamp\""
    
    log_file_op "create" "$conf_dir/base.json"
    log_cmd jq "$update_config_expr"
    jq "$update_config_expr" > "$conf_dir/base.json" << EOF
{
  "genesis": {
    "slots_per_epoch": 48,
    "k": 10,
    "grace_period_slots": 3
  },
  "proof": {
    "work_delay": 1,
    "level": "full",
    "transaction_capacity": { "2_to_the": 2 },
    "block_window_duration_ms": ${slot}000
  }
}
EOF
}

setup_daemon_config() {
    local conf_dir="$1"
    local custom_conf="$2"
    
    if [[ -z "$custom_conf" ]]; then
        log_config "generate" "daemon configuration from ledger"
        log_file_op "read" "$conf_dir/ledger.json"
        log_file_op "create" "$conf_dir/daemon.json"
        { echo '{"ledger": {"accounts": '; cat "$conf_dir/ledger.json"; echo '}}'; } > "$conf_dir/daemon.json"
    else
        log_config "use" "custom daemon configuration: $custom_conf"
        log_file_op "copy" "$custom_conf" "$conf_dir/daemon.json"
        cp "$custom_conf" "$conf_dir/daemon.json"
    fi
}

# Calculate genesis timestamp
calculated_timestamp=$(calculate_genesis_timestamp "$DELAY_MIN")
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:-"$calculated_timestamp"}

log_info "Starting localnet setup"
log_info "Genesis timestamp: $GENESIS_TIMESTAMP"

# Setup configuration
CONF_DIR="localnet/config"
setup_configuration_directory "$CONF_DIR"
generate_base_config "$CONF_DIR" "$GENESIS_TIMESTAMP" "$SLOT" "$SLOT_TX_END" "$SLOT_CHAIN_END"
setup_daemon_config "$CONF_DIR" "$CUSTOM_CONF"

prepare_node_arguments() {
    local conf_dir="$1"
    local conf_suffix="$2"
    local genesis_ledger_dir="$3"
    
    # Common arguments for both nodes
    COMMON_ARGS=( --file-log-level Info --log-level Error --seed )
    COMMON_ARGS+=( --config-file "$PWD/$conf_dir/base.json" )
    COMMON_ARGS+=( --config-file "$PWD/$conf_dir/daemon$conf_suffix.json" )
    
    # Node-specific arguments
    NODE_ARGS_1=( --libp2p-keypair "$PWD/$conf_dir/libp2p_1" )
    NODE_ARGS_2=( --libp2p-keypair "$PWD/$conf_dir/libp2p_2" )
    
    if [[ -n "$genesis_ledger_dir" ]]; then
        log_info "Setting up genesis ledger directories"
        rm -rf localnet/genesis_{1,2}
        cp -rf "$genesis_ledger_dir" localnet/genesis_1
        cp -rf "$genesis_ledger_dir" localnet/genesis_2
        NODE_ARGS_1+=( --genesis-ledger-dir "$PWD/localnet/genesis_1" )
        NODE_ARGS_2+=( --genesis-ledger-dir "$PWD/localnet/genesis_2" )
    fi
}

launch_nodes() {
    local conf_dir="$1"
    
    log_info "Cleaning runtime directories"
    log_file_op "delete" "localnet/runtime_1 localnet/runtime_2"
    rm -rf localnet/runtime_1 localnet/runtime_2
    
    log_process_op "start" "block producer node"
    local peer_id
    peer_id=$(cat "$conf_dir/libp2p_2.peerid")
    log_debug "Block producer will connect to peer: /ip4/127.0.0.1/tcp/10312/p2p/$peer_id"
    
    log_cmd "$MINA_EXE daemon with block producer configuration"
    "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
        --peer "/ip4/127.0.0.1/tcp/10312/p2p/$(cat "$conf_dir/libp2p_2.peerid")" \
        "${NODE_ARGS_1[@]}" \
        --block-producer-key "$PWD/$conf_dir/bp" \
        --config-directory "$PWD/localnet/runtime_1" \
        --client-port 10301 --external-port 10302 --rest-port 10303 &
    
    local bp_pid=$!
    log_process_op "start" "block producer with PID $bp_pid"
    
    log_process_op "start" "snark worker node"
    peer_id=$(cat "$conf_dir/libp2p_1.peerid")
    log_debug "Snark worker will connect to peer: /ip4/127.0.0.1/tcp/10302/p2p/$peer_id"
    
    log_cmd "$MINA_EXE daemon with snark worker configuration"
    "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
        "${NODE_ARGS_2[@]}" \
        --peer "/ip4/127.0.0.1/tcp/10302/p2p/$(cat "$conf_dir/libp2p_1.peerid")" \
        --run-snark-worker "$(cat "$conf_dir/bp.pub")" --work-selection seq \
        --config-directory "$PWD/localnet/runtime_2" \
        --client-port 10311 --external-port 10312 --rest-port 10313 &
    
    local sw_pid=$!
    log_process_op "start" "snark worker with PID $sw_pid"
    
    echo "$bp_pid $sw_pid"
}

wait_for_node_ready() {
    local conf_dir="$1"
    
    log_info "Waiting for nodes to be ready"
    log_timing "wait" "for accounts import to succeed"
    while ! run_cmd "$MINA_EXE" accounts import --privkey-path "$PWD/$conf_dir/bp" --rest-server 10313; do
        log_debug "Waiting for accounts import to succeed..."
        log_timing "sleep" "1 minute"
        sleep 1m
    done
    log_info "Accounts imported successfully"
    
    log_info "Exporting staged ledger"
    log_timing "wait" "for ledger export to succeed"
    while ! run_cmd "$MINA_EXE" ledger export staged-ledger --daemon-port 10311 --output localnet/exported_staged_ledger.json; do
        log_debug "Waiting for ledger export to succeed..."
        log_timing "sleep" "1 minute"
        sleep 1m
    done
    log_file_op "create" "localnet/exported_staged_ledger.json"
    log_info "Staged ledger exported successfully"
}

send_transactions() {
    local conf_dir="$1"
    local sw_pid="$2"
    local tx_interval="$3"
    
    log_info "Starting transaction sender with interval: $tx_interval"
    log_timing "wait" "for process $sw_pid to end while sending transactions"
    
    local i=0
    while kill -0 "$sw_pid" 2>/dev/null; do
        log_debug "Transaction sending loop iteration, checking if process $sw_pid is still running"
        
        # Send transactions to random accounts from the ledger
        # shuf's exit code is masked by `true` because we do not expect
        # all of the output to be read
        log_cmd "jq -r '.[].pk' < localnet/exported_staged_ledger.json | shuf"
        if ! jq -r '.[].pk' < localnet/exported_staged_ledger.json | { shuf || true; } | while IFS= read -r acc; do
            if ! kill -0 "$sw_pid" 2>/dev/null; then
                log_debug "Process $sw_pid ended, stopping transaction sending"
                break
            fi
            
            log_cmd "$MINA_EXE client send-payment --sender $(cat $conf_dir/bp.pub) --receiver $acc --amount 0.1 --memo payment_$i --rest-server 10313"
            if "$MINA_EXE" client send-payment \
                --sender "$(cat "$conf_dir/bp.pub")" \
                --receiver "$acc" \
                --amount 0.1 \
                --memo "payment_$i" \
                --rest-server 10313 2>/dev/null; then
                i=$((i+1))
                log_info "Sent transaction #$i to $acc"
            else
                log_debug "Failed to send transaction #$i to $acc"
            fi
            
            log_timing "sleep" "$tx_interval"
            sleep "$tx_interval"
        done; then
            log_debug "Transaction sending loop completed"
        fi
    done
    
    log_process_op "stop" "transaction sender (node process $sw_pid ended)"
}

# Launch nodes and handle transactions
log_info "Preparing node arguments and launching localnet"
prepare_node_arguments "$CONF_DIR" "$CONF_SUFFIX" "$GENESIS_LEDGER_DIR"

log_debug "Node launch configuration:"
log_debug "  Config directory: $CONF_DIR"
log_debug "  Config suffix: ${CONF_SUFFIX:-none}"
log_debug "  Genesis ledger dir: ${GENESIS_LEDGER_DIR:-none}"

read -r BP_PID SW_PID < <(launch_nodes "$CONF_DIR")

wait_for_node_ready "$CONF_DIR"
send_transactions "$CONF_DIR" "$SW_PID" "$TX_INTERVAL"

log_process_op "wait" "for all background nodes to finish"
wait
