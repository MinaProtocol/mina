#!/usr/bin/env bash

set -eo pipefail

FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
FORKING_FROM_CONFIG_JSON=${FORKING_FROM_CONFIG_JSON:=genesis_ledgers/mainnet.json}

# If not given, the genesis timestamp is set to 10 mins into the future
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "10 mins")}

# Pull the original genesis timestamp from the pre-fork config file
ORIGINAL_GENESIS_TIMESTAMP=$(jq -r '.genesis.genesis_state_timestamp' "$FORKING_FROM_CONFIG_JSON")

DIFFERENCE_IN_SECONDS=$(($(date -d "$GENESIS_TIMESTAMP" "+%s") - $(date -d "$ORIGINAL_GENESIS_TIMESTAMP" "+%s")))
# Default: mainnet currently uses 180s per slot
SECONDS_PER_SLOT=${SECONDS_PER_SLOT:=180}
DIFFERENCE_IN_SLOTS=$(($DIFFERENCE_IN_SECONDS / $SECONDS_PER_SLOT))

# jq expression below could be written with less code,
# but we aimed for maximum verbosity

jq "{\
    genesis: {\
        genesis_state_timestamp: \"$GENESIS_TIMESTAMP\"\
    },\
    proof: {\
        fork: {\
            state_hash: .proof.fork.state_hash,\
            blockchain_length: .proof.fork.blockchain_length,\
            global_slot_since_genesis: $DIFFERENCE_IN_SLOTS,\
        },\
    },\
    ledger: {\
        add_genesis_winner: false,\
        accounts: .ledger.accounts,\
        balance: [],\
    },\
    epoch_data: .epoch_data\
  }" -M "$FORK_CONFIG_JSON"


