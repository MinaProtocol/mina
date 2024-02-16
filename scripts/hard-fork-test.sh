#!/usr/bin/env bash

SLOT_TX_END="${SLOT_TX_END:-15}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-30}"

# Slot duration in seconds to be used for both version
MAIN_SLOT="${MAIN_SLOT:-90}"
FORK_SLOT="${FORK_SLOT:-30}"

# Delay before genesis slot in minutes to be used for both version
MAIN_DELAY="${MAIN_DELAY:-10}"
FORK_DELAY="${FORK_DELAY:-10}"

# script should be run from mina root directory.
source ./scripts/hard-fork-helper.sh

# Executable built off mainnet branch
MAIN_MINA_EXE="$1"

# Executables built off fork branch (e.g. berkeley)
FORK_MINA_EXE="$2"
FORK_RUNTIME_GENESIS_LEDGER_EXE="$3"

# 1. Node is started
./scripts/run-hf-localnet.sh -m "$MAIN_MINA_EXE" -d "$MAIN_DELAY" -i "$MAIN_SLOT" \
  -s "$MAIN_SLOT" --slot-tx-end "$SLOT_TX_END" --slot-chain-end "$SLOT_CHAIN_END" &

MAIN_NETWORK_PID=$!

# Sleep until slot_tx_end plus one minute
sleep $((MAIN_SLOT*(SLOT_TX_END-10)+MAIN_DELAY*60+60))s

# 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot $((SLOT_TX_END / 2)) and that there are some user commands in blocks corresponding to slots
blockHeight=$(get_height 10303)
echo "Block height is $blockHeight at slot $((SLOT_TX_END / 2))."
echo "Blocks are produced."

all_blocks_empty=true
for i in {1..10}
do
  sleep "${MAIN_SLOT}s"
  usercmds=$(blocks_withUserCommands 10303)
  if [[ $usercmds != 0 ]]; then
    all_blocks_empty=false
  fi
done
if $all_blocks_empty; then
  echo "Assertion failed: all blocks are empty" >&2
  exit 3
fi

# 3. Check that transactions stop getting included from slot SLOT_TX_END to slot SLOT_CHAIN_END, i.e. there are some blocks, with no user commands, coinbase set to 0.
sleep $((MAIN_SLOT*(SLOT_CHAIN_END-SLOT_TX_END-10)))s

all_blocks_empty=false
for i in {1..10}
do
  sleep "${MAIN_SLOT}s"
  usercmds=$(blocks_withUserCommands 10303)
  echo "Checking if blocks are empty"
  if [[ $usercmds == 0 ]]; then
    all_blocks_empty=true
  fi
done
if [[ ! $all_blocks_empty ]]; then
  echo "Assertion failed: not all blocks are empty" >&2
  exit 3
fi

# 4. Check that no new blocks are created
sleep 1m
height1=$(get_height 10303)
sleep 5m
height2=$(get_height 10303)
if [[ $(( height2 - height1 )) -gt 0 ]]; then
  echo "Assertion failed: there should be no change in blockheight." >&2
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
"$MAIN_MINA_EXE" client stop-daemon --daemon-port 10301
"$MAIN_MINA_EXE" client stop-daemon --daemon-port 10311

sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' localnet/fork_config.json

rm -Rf localnet/hf_ledgers
mkdir localnet/hf_ledgers

"$FORK_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json

export GENESIS_TIMESTAMP="$( d=$(date +%s); date -u -d @$((d - d % 60 + FORK_DELAY*60)) '+%F %H:%M:%S+00:00' )"
FORKING_FROM_CONFIG_JSON=localnet/config/base.json SECONDS_PER_SLOT=90 FORK_CONFIG_JSON=localnet/fork_config.json LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > localnet/config.json

wait "$MAIN_NETWORK_PID"

# 8. Node is shutdown and restarted with mina-fork and the config from previous step 
./scripts/run-hf-localnet.sh -m "$FORK_MINA_EXE" -d "$FORK_DELAY" -i "$FORK_SLOT" \
  -s "$FORK_SLOT" -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers &

# 9. Check that network eventually creates some blocks

sleep $((FORK_SLOT*60+FORK_DELAY*60+60))s
height1=$(get_height 10303)
if [[ $height1 == 0 ]]; then
  echo "My assertion failed: block height $height1 should be greater than 0." >&2
  exit 3
fi
echo "Blocks are produced."
# Wait and check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks

all_blocks_empty=true
for i in {1..10}
do
  sleep "${FORK_SLOT}s"
  usercmds=$(blocks_withUserCommands 10303)
  if [[ $usercmds != 0 ]]; then
    all_blocks_empty=false
  fi
done
if $all_blocks_empty; then
  echo "Assertion failed: all blocks are empty" >&2
  exit 3
fi

"$FORK_MINA_EXE" client stop-daemon --daemon-port 10301
"$FORK_MINA_EXE" client stop-daemon --daemon-port 10311
