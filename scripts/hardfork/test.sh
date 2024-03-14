#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SLOT_TX_END="${SLOT_TX_END:-30}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"

# Slot from which to start calling bestchain query
# to find last non-empty block
BEST_CHAIN_QUERY_FROM="${BEST_CHAIN_QUERY_FROM:-25}"

# Slot duration in seconds to be used for both version
MAIN_SLOT="${MAIN_SLOT:-90}"
FORK_SLOT="${FORK_SLOT:-30}"

# Delay before genesis slot in minutes to be used for both version
MAIN_DELAY="${MAIN_DELAY:-20}"
FORK_DELAY="${FORK_DELAY:-10}"

# script should be run from mina root directory.
source "$SCRIPT_DIR"/test-helper.sh

# Executable built off mainnet branch
MAIN_MINA_EXE="$1"
MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"

# Executables built off fork branch (e.g. berkeley)
FORK_MINA_EXE="$3"
FORK_RUNTIME_GENESIS_LEDGER_EXE="$4"

stop_nodes(){
  "$1" client stop-daemon --daemon-port 10301
  "$1" client stop-daemon --daemon-port 10311
}

# 1. Node is started
NOW_UNIX_TS=$(date +%s)
MAIN_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + MAIN_DELAY*60))
export GENESIS_TIMESTAMP="$(date -u -d @$MAIN_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00')"
"$SCRIPT_DIR"/run-localnet.sh -m "$MAIN_MINA_EXE" -i "$MAIN_SLOT" \
  -s "$MAIN_SLOT" --slot-tx-end "$SLOT_TX_END" --slot-chain-end "$SLOT_CHAIN_END" &

MAIN_NETWORK_PID=$!

sleep $((MAIN_SLOT * BEST_CHAIN_QUERY_FROM - NOW_UNIX_TS%60 + MAIN_DELAY*60))s

# 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot
# $BEST_CHAIN_QUERY_FROM and that there are some user commands in blocks corresponding to slots
blockHeight=$(get_height 10303)
echo "Block height is $blockHeight at slot $BEST_CHAIN_QUERY_FROM."

if [[ $((2*blockHeight)) -lt $BEST_CHAIN_QUERY_FROM ]]; then
  echo "Assertion failed: slot occupancy is below 50%" >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

first_epoch_ne_str="$(blocks 10303 2>/dev/null | latest_nonempty_block)"
IFS=, read -ra first_epoch_ne <<< "$first_epoch_ne_str"

genesis_epoch_staking_hash="${first_epoch_ne[$IX_CUR_EPOCH_HASH]}"
genesis_epoch_next_hash="${first_epoch_ne[$IX_NEXT_EPOCH_HASH]}"

last_ne_str="$(for i in $(seq $BEST_CHAIN_QUERY_FROM $SLOT_CHAIN_END); do
  blocks $((10303+10*(i%2))) 2>/dev/null || true
  sleep "${MAIN_SLOT}s"
done | latest_nonempty_block)"

IFS=, read -ra latest_ne <<< "$last_ne_str"

# Maximum slot observed for a block
max_slot=${latest_ne[0]}

# List of epochs for which last snarked ledger hashes were captured
IFS=: read -ra epochs <<< "${latest_ne[1]}"
# List of last snarked ledger hashes captured
IFS=: read -ra last_snarked_hash_pe <<< "${latest_ne[2]}"

latest_ne=( "${latest_ne[@]:3}" )

echo "Last occupied slot of pre-fork chain: $max_slot"
if [[ $max_slot -ge $SLOT_CHAIN_END ]]; then
  echo "Assertion failed: block with slot $max_slot created after slot chain end" >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

latest_shash="${latest_ne[$IX_STATE_HASH]}"
latest_height=${latest_ne[$IX_HEIGHT]}
latest_slot=${latest_ne[$IX_SLOT]}

echo "Latest non-empty block: $latest_shash, height: $latest_height, slot: $latest_slot"
if [[ $latest_slot -ge $SLOT_TX_END ]]; then
  echo "Assertion failed: non-empty block with slot $latest_slot created after slot tx end" >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

expected_fork_data="{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$latest_slot,\"state_hash\":\"$latest_shash\"}"

# 4. Check that no new blocks are created
sleep 1m
height1=$(get_height 10303)
sleep 5m
height2=$(get_height 10303)
if [[ $(( height2 - height1 )) -gt 0 ]]; then
  echo "Assertion failed: there should be no change in blockheight after slot chain end." >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

# 6. Transition root is extracted into a new runtime config
get_fork_config 10313 > localnet/fork_config.json

while [[ "$(stat -c %s localnet/fork_config.json)" == 0 ]] || [[ "$(head -c 4 localnet/fork_config.json)" == "null" ]]; do
  echo "Failed to fetch fork config" >&2
  sleep 1m
  get_fork_config 10313 > localnet/fork_config.json
done

# 7. Runtime config is converted with a script to have only ledger hashes in the config
stop_nodes "$MAIN_MINA_EXE"

fork_data="$(jq -cS '.proof.fork' localnet/fork_config.json)"
if [[ "$fork_data" != "$expected_fork_data" ]]; then
  echo "Assertion failed: unexpected fork data" >&2
  exit 3
fi

# TODO run compatible's runtime_genesis_ledger (using exe "$MAIN_RUNTIME_GENESIS_LEDGER_EXE", similar how it's
# done below but with different 
"$MAIN_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json

# TODO compare resulting (throwaway) hashes file to what is expected:
# From slot_tx_end calculate the epoch `e`.
# Compare ${last_snarked_hash_pe[${epochs[$e-2]}]} to staking ledger hash of hashes
# and ${last_snarked_hash_pe[${epochs[$e-2]}]} to the next ledger
# (if e < 2, use $genesis_epoch_staking_hash
# and $genesis_epoch_next_hash to avoid a negative index calling on a bash array)
#
# Sha3 hashes are not to be considered
#
# Compare genesis ledger hash of hashes to ${latest_ne[$IX_STAGED_HASH]}
# Compare seeds of fork config to ${latest_ne[$IX_CUR_EPOCH_SEED]}
# and ${latest_ne[$IX_CUR_EPOCH_SEED]} respectively
#
# For comparing against fork config it's easiest to modify $expected_fork_data and related comparison above
# And use similar technique for hashes file check
# Exit 3 if either check fails

sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' localnet/fork_config.json

rm -Rf localnet/hf_ledgers
mkdir localnet/hf_ledgers

"$FORK_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json

NOW_UNIX_TS=$(date +%s)
FORK_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + FORK_DELAY*60))
export GENESIS_TIMESTAMP="$( date -u -d @$FORK_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00' )"
FORKING_FROM_CONFIG_JSON=localnet/config/base.json SECONDS_PER_SLOT="$MAIN_SLOT" FORK_CONFIG_JSON=localnet/fork_config.json LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json "$SCRIPT_DIR"/create_runtime_config.sh > localnet/config.json

expected_genesis_slot=$(((FORK_GENESIS_UNIX_TS-MAIN_GENESIS_UNIX_TS)/MAIN_SLOT))
expected_modified_fork_data="{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$expected_genesis_slot,\"state_hash\":\"$latest_shash\"}"
modified_fork_data="$(jq -cS '.proof.fork' localnet/config.json)"
if [[ "$modified_fork_data" != "$expected_modified_fork_data" ]]; then
  echo "Assertion failed: unexpected modified fork data" >&2
  exit 3
fi

# TODO check ledgers in localnet/config.json

wait "$MAIN_NETWORK_PID"

# 8. Node is shutdown and restarted with mina-fork and the config from previous step 
"$SCRIPT_DIR"/run-localnet.sh -m "$FORK_MINA_EXE" -d "$FORK_DELAY" -i "$FORK_SLOT" \
  -s "$FORK_SLOT" -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers &

sleep $((FORK_DELAY*60))s

earliest_str=""
while [[ "$earliest_str" == "" ]] || [[ "$earliest_str" == "," ]]; do
  earliest_str=$(get_height_and_slot_of_earliest 10303 2>/dev/null)
  sleep "$FORK_SLOT"s
done
IFS=, read -ra earliest <<< "$earliest_str"
earliest_height=${earliest[0]}
earliest_slot=${earliest[1]}
if [[ $earliest_height != $((latest_height+1)) ]]; then
  echo "Assertion failed: unexpected block height $earliest_height at the beginning of the fork" >&2
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

if [[ $earliest_slot -lt $expected_genesis_slot ]]; then
  echo "Assertion failed: unexpected slot $earliest_slot at the beginning of the fork" >&2
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

# 9. Check that network eventually creates some blocks

sleep $((FORK_SLOT*10))s
height1=$(get_height 10303)
if [[ $height1 == 0 ]]; then
  echo "Assertion failed: block height $height1 should be greater than 0." >&2
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi
echo "Blocks are produced."

# Wait and check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks

all_blocks_empty=true
for i in {1..10}
do
  sleep "${FORK_SLOT}s"
  usercmds=$(blocks_with_user_commands 10303)
  if [[ $usercmds != 0 ]]; then
    all_blocks_empty=false
  fi
done
if $all_blocks_empty; then
  echo "Assertion failed: all blocks in fork chain are empty" >&2
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

stop_nodes "$FORK_MINA_EXE"
