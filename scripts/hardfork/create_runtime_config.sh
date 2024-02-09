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
        hash: \$hashes.genesis.ledger_hash,\
        s3_data_hash: \$hashes.genesis.s3_data_hash\
    },\
    epoch_data: {\
        staking: {\
            seed: .epoch_data.staking.seed,\
            hash: \$hashes.staking.ledger_hash,\
            s3_data_hash: \$hashes.staking.s3_data_hash\
        },\
        next: {\
            seed: .epoch_data.next.seed,\
            hash: \$hashes.next_staking.ledger_hash,\
            s3_data_hash: \$hashes.next_staking.s3_data_hash\
        }\
    }\
  }" -M --argjson hashes "$(cat $LEDGER_HASHES_JSON)" $FORK_CONFIG_JSON
