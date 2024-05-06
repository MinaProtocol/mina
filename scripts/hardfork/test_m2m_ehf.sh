#!/usr/bin/env bash

set -eo pipefail

echo "running M2M"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SLOT_TX_END="${SLOT_TX_END:-30}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"

# Slot from which to start calling bestchain query
# to find last non-empty blockp
BEST_CHAIN_QUERY_FROM="${BEST_CHAIN_QUERY_FROM:-25}" #

# Slot duration in seconds to be used for both version
MAIN_SLOT="${MAIN_SLOT:-90}"
FORK_SLOT="${FORK_SLOT:-90}"

# Delay before genesis slot in minutes to be used for both version
MAIN_DELAY="${MAIN_DELAY:-20}"
FORK_DELAY="${FORK_DELAY:-20}"

# script should be run from mina root directory.
source "$SCRIPT_DIR"/test-helper.sh

# Executable built off source branch
MAIN_MINA_EXE="$1"
MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"

# Executables built off destination branch (e.g. berkeley)
FORK_MINA_EXE="$3"
FORK_RUNTIME_GENESIS_LEDGER_EXE="$4"

stop_nodes(){
    echo "Stopping nodes"
    "$1" client stop-daemon --daemon-port 10301
    "$1" client stop-daemon --daemon-port 10311
}

# Block height until which to run this experiment.
# This should be big enough to achieve good probabilistic finality
UNTIL_HEIGHT="${UNTIL_HEIGHT:-10}"
FINALITY_HEIGHT="${FINALITY_HEIGHT:-5}"

if [[ $FINALITY_HEIGHT -ge $UNTIL_HEIGHT  || $FINALITY_HEIGHT -lt 0 ]]; then
    echo "FINALITY_HEIGHT (value: ${FINALITY_HEIGHT}) must be positive and \
    strictly smaller than UNTIL_HEIGHT (value: ${UNTIL_HEIGHT}). Check your arguments."
    exit 3
fi

env UNTIL_HEIGHT=${UNTIL_HEIGHT} K=${K} "$SCRIPT_DIR"/run-localnet.sh -m "$MAIN_MINA_EXE" -i "$MAIN_SLOT" \
  -s "$MAIN_SLOT" &


WAITING="$((MAIN_SLOT * UNTIL_HEIGHT + MAIN_DELAY*60))s"

sleep 1200s

# # 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot
# # $BEST_CHAIN_QUERY_FROM and that there are some user commands in blocks corresponding to slots
# blockHeight=$(get_height 10303)
# echo "Block height is $blockHeight at slot $BEST_CHAIN_QUERY_FROM."

# if [[ $((2*blockHeight)) -lt $BEST_CHAIN_QUERY_FROM ]]; then
#   echo "Assertion failed: slot occupancy is below 50%" >&2
#   stop_nodes "$MAIN_MINA_EXE"
#   exit 3
# fi


echo "Getting fork config from 10313 at height 5 ... "

# current_blockheight=$(get_height 10303)

# if fork_config_height is too far in the past, recompute it like so
# fork_config_height=$((current_blockheight - K))

# 6. Transition root is extracted into a new runtime config
get_fork_config 10313 5 > localnet/fork_config.json

# while [[ "$(stat -c %s localnet/fork_config.json)" == 0 ]] || [[ "$(head -c 4 localnet/fork_config.json)" == "null" ]]; do
#   echo "Failed to fetch fork config" >&2
#   sleep 1
#   get_fork_config 10313 $fork_config_height > localnet/fork_config.json
# done

# # # 7. Runtime config is converted with a script to have only ledger hashes in the config
# stop_nodes "$MAIN_MINA_EXE"

# # Cleanup any pre-existing data
# rm -Rf localnet/hf_ledgers
# mkdir localnet/hf_ledgers

# "$FORK_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json

# NOW_UNIX_TS=$(date +%s)
# FORK_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + FORK_DELAY*60))
# export GENESIS_TIMESTAMP="$( date -u -d @$FORK_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00' )"

# FORKING_FROM_CONFIG_JSON=localnet/config/base.json \
#     SECONDS_PER_SLOT="$MAIN_SLOT" \
#     FORK_CONFIG_JSON=localnet/fork_config.json \
#     LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json \
#     "$SCRIPT_DIR"/create_runtime_config.sh > localnet/config.json

# expected_genesis_slot=$(((FORK_GENESIS_UNIX_TS-MAIN_GENESIS_UNIX_TS)/MAIN_SLOT))
# # expected_modified_fork_data="{\"blockchain_length\":$K,\"global_slot_since_genesis\":$expected_genesis_slot,\"state_hash\":\"$latest_shash\"}"
# # modified_fork_data="$(jq -cS '.proof.fork' localnet/config.json)"
# # if [[ "$modified_fork_data" != "$expected_modified_fork_data" ]]; then
# #    echo "Assertion failed: unexpected modified fork data" >&2
# #    exit 3
# # fi

# wait "$MAIN_NETWORK_PID"

# # # echo "Config for the fork is correct, starting a new network"

# # # 8. Node is shutdown and restarted with mina-fork and the config from previous step
# "$SCRIPT_DIR"/run-localnet.sh -m "$FORK_MINA_EXE" -d "$FORK_DELAY" -i "$FORK_SLOT" \
#    -s "$FORK_SLOT" -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers &

# sleep "${FORK_DELAY}m"

# sleep $((FORK_SLOT*10))s
# echo "getting h1"
# height1=$(! get_height 10303)
# if [[ $height1 == 0 ]]; then
#   echo "Assertion failed: block height $height1 should be greater than 0." >&2
#   stop_nodes "$FORK_MINA_EXE"
#   exit 3
# fi
# echo "Blocks are produced."
