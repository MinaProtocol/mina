#!/usr/bin/env bash

set -euo pipefail

# Source shared libraries
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# GraphQL query function with error handling
graphql() {
    local port="$1"
    local query="$2"
    local max_retries="${3:-3}"
    local retry_delay="${4:-2}"
    
    log_net_op "graphql" "$port" "$query"
    
    for ((i=1; i<=max_retries; i++)); do
        log_cmd curl --silent --location --max-time 30 "http://localhost:$port/graphql" --header "Content-Type: application/json" --data "{\"query\":\"query Q {$query}\"}"
        
        if result=$(curl --silent --location --max-time 30 \
            "http://localhost:$port/graphql" \
            --header "Content-Type: application/json" \
            --data "{\"query\":\"query Q {$query}\"}"); then
            
            # Check if result contains errors
            if echo "$result" | jq -e '.errors' >/dev/null 2>&1; then
                local errors
                errors=$(echo "$result" | jq -r '.errors' 2>/dev/null || echo "unknown errors")
                log_debug "GraphQL query returned errors (attempt $i/$max_retries): $errors"
                if [[ $i -eq $max_retries ]]; then
                    log_error "GraphQL query failed with errors: $errors"
                    return 1
                fi
            else
                log_debug "GraphQL query succeeded (attempt $i/$max_retries)"
                echo "$result"
                return 0
            fi
        else
            log_debug "GraphQL query network request failed (attempt $i/$max_retries)"
            if [[ $i -eq $max_retries ]]; then
                log_error "GraphQL query failed after $max_retries attempts"
                return 1
            fi
        fi
        
        if [[ $i -lt $max_retries ]]; then
            log_timing "sleep" "${retry_delay}s before retry"
            sleep "$retry_delay"
        fi
    done
}

# Get height and slot of earliest block
get_height_and_slot_of_earliest() {
    local port="$1"
    log_debug "Getting height and slot of earliest block from port $port"
    graphql "$port" 'bestChain { protocolState { consensusState { blockHeight slotSinceGenesis } } }' | \
        run_cmd_capture jq -r '.data.bestChain[0].protocolState.consensusState | .blockHeight + "," + .slotSinceGenesis'
}

# Get current block height
get_height() {
    local port="$1"
    log_debug "Getting current block height from port $port"
    graphql "$port" 'bestChain(maxLength: 1) { protocolState { consensusState { blockHeight } } }' | \
        run_cmd_capture jq -r '.data.bestChain[-1].protocolState.consensusState.blockHeight'
}

# Get fork configuration
get_fork_config() {
    local port="$1"
    log_debug "Getting fork configuration from port $port"
    graphql "$port" 'fork_config' | run_cmd_capture jq '.data.fork_config'
}

# Count blocks with user commands
blocks_with_user_commands() {
    local port="$1"
    log_debug "Counting blocks with user commands from port $port"
    graphql "$port" 'bestChain { commandTransactionCount }' | \
        run_cmd_capture jq -r '[.data.bestChain[] | select(.commandTransactionCount>0)] | length'
}

# Constants for block data field indices
declare -r IX_STATE_HASH=0
declare -r IX_HEIGHT=1
declare -r IX_SLOT=2
declare -r IX_NON_EMPTY=3
declare -r IX_CUR_EPOCH_HASH=4
declare -r IX_CUR_EPOCH_SEED=5
declare -r IX_NEXT_EPOCH_HASH=6
declare -r IX_NEXT_EPOCH_SEED=7
declare -r IX_STAGED_HASH=8
declare -r IX_SNARKED_HASH=9
declare -r IX_EPOCH=10

# Export for use in other scripts
export IX_STATE_HASH IX_HEIGHT IX_SLOT IX_NON_EMPTY IX_CUR_EPOCH_HASH IX_CUR_EPOCH_SEED
export IX_NEXT_EPOCH_HASH IX_NEXT_EPOCH_SEED IX_STAGED_HASH IX_SNARKED_HASH IX_EPOCH

# GraphQL query for comprehensive block data
get_blocks_query() {
    cat << 'EOF'
bestChain {
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
      epoch
      stakingEpochData {
        ledger { hash }
        seed
      }
      nextEpochData {
        ledger { hash }
        seed
      }
    }
    blockchainState {
      stagedLedgerHash
      snarkedLedgerHash
    }
  }
  transactions {
    coinbase
    feeTransfer { fee }
  }
  stateHash
}
EOF
}

# jq filter to extract and format block data
get_blocks_filter() {
    cat << 'EOF'
.data.bestChain[] |
  [ .stateHash
  , .protocolState.consensusState.blockHeight
  , .protocolState.consensusState.slotSinceGenesis
  , .commandTransactionCount + (.transactions.feeTransfer|length) + (if .transactions.coinbase == "0" then 0 else 1 end)>0
  , .protocolState.consensusState.stakingEpochData.ledger.hash
  , .protocolState.consensusState.stakingEpochData.seed
  , .protocolState.consensusState.nextEpochData.ledger.hash
  , .protocolState.consensusState.nextEpochData.seed
  , .protocolState.blockchainState.stagedLedgerHash
  , .protocolState.blockchainState.snarkedLedgerHash
  , .protocolState.consensusState.epoch
  ] | join(",")
EOF
}

# Get formatted block data
blocks() {
    local port="$1"
    local query
    local filter
    
    log_debug "Getting formatted block data from port $port"
    
    query=$(get_blocks_query)
    filter=$(get_blocks_filter)
    
    log_debug "Using complex GraphQL query for comprehensive block data"
    graphql "$port" "$query" | run_cmd_capture jq -r "$filter"
}

# Process block stream and find latest non-empty block
# Reads stream of blocks (output of blocks() command) and calculates/finds:
# 1. maximum seen slot
# 2. Latest snarked ledger hashes per-epoch  
# 3. Latest non-empty block
# Returns: "max_slot,epochs,snarked_hashes,latest_block_data"
latest_nonempty_block() {
    log_debug "Processing block stream to find latest non-empty block"
    
    # Data of a non-empty block with the largest slot
    local -a latest=()
    latest[$IX_SLOT]=0

    # Latest snarked hashes per epoch
    local -A snarked_hash_per_epoch=()
    # Latest seen slot per epoch
    local -A slot_per_epoch=()

    local max_slot=0
    local line_count=0

    # Read line by line, updating data above
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        
        line_count=$((line_count + 1))
        log_debug "Processing block line $line_count"
        
        # Parse CSV line into array
        IFS=',' read -ra fields <<< "$line"
        
        # Validate we have enough fields
        if [[ ${#fields[@]} -le $IX_EPOCH ]]; then
            log_error "Invalid block data line: $line"
            continue
        fi
        
        # Update maximum slot
        local current_slot="${fields[$IX_SLOT]}"
        if [[ $max_slot -lt $current_slot ]]; then
            max_slot=$current_slot
        fi
        
        # Update latest non-empty block
        if [[ "${fields[$IX_NON_EMPTY]}" == "true" ]] && [[ ${latest[$IX_SLOT]:-0} -lt $current_slot ]]; then
            latest=( "${fields[@]}" )
            log_debug "Updated latest non-empty block at slot $current_slot"
        fi
        
        # Update per-epoch data
        local epoch="${fields[$IX_EPOCH]}"
        if [[ -z "${slot_per_epoch[$epoch]:-}" ]] || [[ ${slot_per_epoch[$epoch]} -lt $current_slot ]]; then
            slot_per_epoch[$epoch]=$current_slot
            snarked_hash_per_epoch[$epoch]="${fields[$IX_SNARKED_HASH]}"
            log_debug "Updated epoch $epoch data at slot $current_slot"
        fi
    done
    
    log_debug "Processed $line_count block lines"
    log_debug "Max slot: $max_slot"
    log_debug "Latest non-empty block slot: ${latest[$IX_SLOT]:-0}"
    
    # Format output
    local latest_str="${latest[*]}"
    local -a epoch_list=()
    local -a hash_list=()
    
    # Build sorted epoch and hash lists
    for epoch in "${!slot_per_epoch[@]}"; do
        epoch_list+=("$epoch")
        hash_list+=("${snarked_hash_per_epoch[$epoch]}")
    done
    
    local epoch_str
    local snarked_hash_str
    
    # Join arrays with colons
    epoch_str=$(IFS=':'; echo "${epoch_list[*]}")
    snarked_hash_str=$(IFS=':'; echo "${hash_list[*]}")
    latest_str=$(IFS=','; echo "${latest[*]}")
    
    echo "$max_slot,$epoch_str,$snarked_hash_str,$latest_str"
}
