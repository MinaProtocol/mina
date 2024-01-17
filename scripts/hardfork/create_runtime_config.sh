#!/bin/bash

set -e

FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
LEDGER_HASHES_JSON=${LEDGER_HASHES_JSON:=ledger_hashes.json}

# If not given, the genesis timestamp is set to 10 mins into the future
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "10 mins")}

jq "{\
    genesis: {\
        genesis_state_timestamp: \"$GENESIS_TIMESTAMP\"\
    },\
    proof: {\
        fork: .proof.fork\
    },\
    ledger: {\
        add_genesis_winner: false,\
        hash: \$hashes.genesis_hash\
    },\
    epoch_data: {\
        staking: {\
            seed: .epoch_data.staking.seed,\
            hash: \$hashes.epoch_data.staking_hash\
        },\
        next: {\
            seed: .epoch_data.next.seed,\
            hash: \$hashes.epoch_data.next_hash\
        }\
    }\
  }" -M --argjson hashes "$(cat $LEDGER_HASHES_JSON)" $FORK_CONFIG_JSON
