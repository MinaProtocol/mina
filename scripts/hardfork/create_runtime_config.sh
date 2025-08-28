#!/usr/bin/env bash

set -euo pipefail

# Source shared libraries
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# Configuration validation
validate_config_files() {
    local fork_config="$1"
    local ledger_hashes="$2" 
    local forking_from_config="$3"
    
    if [[ ! -f "$fork_config" ]]; then
        log_error "Fork config file not found: $fork_config"
        return 1
    fi
    
    if [[ ! -f "$ledger_hashes" ]]; then
        log_error "Ledger hashes file not found: $ledger_hashes"
        return 1
    fi
    
    if [[ ! -f "$forking_from_config" ]]; then
        log_error "Forking from config file not found: $forking_from_config"
        return 1
    fi
    
    log_debug "All config files validated successfully"
    return 0
}

# Calculate slot timing
calculate_slot_timing() {
    local genesis_timestamp="$1"
    local original_genesis_timestamp="$2"
    local offset="$3"
    local seconds_per_slot="$4"
    
    log_debug "Calculating slot timing"
    log_debug "Genesis timestamp: $genesis_timestamp"
    log_debug "Original genesis timestamp: $original_genesis_timestamp"
    log_debug "Offset: $offset"
    log_debug "Seconds per slot: $seconds_per_slot"
    
    local difference_in_seconds
    difference_in_seconds=$(($(date -d "$genesis_timestamp" "+%s") - $(date -d "$original_genesis_timestamp" "+%s")))
    
    local difference_in_slots
    difference_in_slots=$((difference_in_seconds / seconds_per_slot))
    
    local slot
    slot=$((difference_in_slots + offset))
    
    log_debug "Calculated slot: $slot"
    echo "$slot"
}

# Set default values
FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
LEDGER_HASHES_JSON=${LEDGER_HASHES_JSON:=ledger_hashes.json}
FORKING_FROM_CONFIG_JSON=${FORKING_FROM_CONFIG_JSON:=genesis_ledgers/mainnet.json}

# If not given, the genesis timestamp is set to 10 mins into the future
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "10 mins")}

log_info "Creating runtime configuration"
log_info "Fork config: $FORK_CONFIG_JSON"
log_info "Ledger hashes: $LEDGER_HASHES_JSON"
log_info "Forking from config: $FORKING_FROM_CONFIG_JSON"

# Validate input files
log_validation "config files" "start"
validate_config_files "$FORK_CONFIG_JSON" "$LEDGER_HASHES_JSON" "$FORKING_FROM_CONFIG_JSON"
log_validation "config files" "pass"

# Pull the original genesis timestamp from the pre-fork config file
log_config "get" "original genesis timestamp from $FORKING_FROM_CONFIG_JSON"
ORIGINAL_GENESIS_TIMESTAMP=$(run_cmd_capture jq -r '.genesis.genesis_state_timestamp' "$FORKING_FROM_CONFIG_JSON")
if [[ "$ORIGINAL_GENESIS_TIMESTAMP" == "null" ]]; then
    log_error "Could not extract original genesis timestamp from $FORKING_FROM_CONFIG_JSON"
    exit 1
fi
log_debug "Original genesis timestamp: $ORIGINAL_GENESIS_TIMESTAMP"

log_config "get" "fork offset from $FORKING_FROM_CONFIG_JSON"
OFFSET=$(run_cmd_capture jq -r '.proof.fork.global_slot_since_genesis' "$FORKING_FROM_CONFIG_JSON")
if [[ "$OFFSET" == "null" ]]; then
    OFFSET=0
    log_debug "No offset found in config, using default: $OFFSET"
fi
log_debug "Fork offset: $OFFSET"

# Default: mainnet currently uses 180s per slot
SECONDS_PER_SLOT=${SECONDS_PER_SLOT:=180}

SLOT=$(calculate_slot_timing "$GENESIS_TIMESTAMP" "$ORIGINAL_GENESIS_TIMESTAMP" "$OFFSET" "$SECONDS_PER_SLOT")

# Generate the runtime configuration
generate_runtime_config() {
    local genesis_timestamp="$1"
    local slot="$2"
    local ledger_hashes_file="$3"
    local fork_config_file="$4"
    
    log_info "Generating runtime configuration with slot: $slot"
    log_file_op "read" "$ledger_hashes_file"
    log_file_op "read" "$fork_config_file"
    
    # jq expression below could be written with less code,
    # but we aimed for maximum verbosity
    log_cmd jq "complex JSON transformation" --slurpfile hashes "$ledger_hashes_file" "$fork_config_file"
    jq "{\
        genesis: {\
            genesis_state_timestamp: \"$genesis_timestamp\"\
        },\
        proof: {\
            fork: {\
                state_hash: .proof.fork.state_hash,\
                blockchain_length: .proof.fork.blockchain_length,\
                global_slot_since_genesis: $slot,\
            },\
        },\
        ledger: {\
            add_genesis_winner: false,\
            hash: \$hashes[0].ledger.hash,\
            s3_data_hash: \$hashes[0].ledger.s3_data_hash\
        },\
        epoch_data: {\
            staking: {\
                seed: .epoch_data.staking.seed,\
                hash: \$hashes[0].epoch_data.staking.hash,\
                s3_data_hash: \$hashes[0].epoch_data.staking.s3_data_hash\
            },\
            next: {\
                seed: .epoch_data.next.seed,\
                hash: \$hashes[0].epoch_data.next.hash,\
                s3_data_hash: \$hashes[0].epoch_data.next.s3_data_hash\
            }\
        }\
      }" -M \
      --slurpfile hashes "$ledger_hashes_file" "$fork_config_file"
}

# Generate and output the configuration
log_config "generate" "runtime configuration with slot $SLOT"
if ! generate_runtime_config "$GENESIS_TIMESTAMP" "$SLOT" "$LEDGER_HASHES_JSON" "$FORK_CONFIG_JSON"; then
    log_error "Failed to generate runtime configuration"
    exit 1
fi

log_info "Runtime configuration generated successfully"
