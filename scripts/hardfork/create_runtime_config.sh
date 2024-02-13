#!/usr/bin/env bash

set -e

FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
LEDGER_HASHES_JSON=${LEDGER_HASHES_JSON:=ledger_hashes.json}

# If not given, the genesis timestamp is set to 10 mins into the future
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "10 mins")}

# jq expression below could be written with less code,
# but we aimed for maximum verbosity

# Epoch data is explicitely cleared of null and empty objects

jq "{\
    genesis: {\
        genesis_state_timestamp: \"$GENESIS_TIMESTAMP\"\
    },\
    proof: {\
        fork: .proof.fork\
    },\
    ledger: {\
        add_genesis_winner: false,\
        hash: \$hashes[0].ledger.hash,\
        s3_data_hash: \$hashes[0].ledger.s3_data_hash\
    },\
    epoch_data: ({\
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
      } | del(..|nulls) | del(..|select(.=={})) )\
    } | del(.epoch_data|select(.=={}))" -M \
  --slurpfile hashes "$LEDGER_HASHES_JSON" "$FORK_CONFIG_JSON"
