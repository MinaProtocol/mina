#!/usr/bin/env bash

SLOT_TX_END="${SLOT_TX_END:-15}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-30}"

# Slot duration in seconds to be used for both version
MAIN_SLOT="${MAIN_SLOT:-90}"
FORK_SLOT="${MAIN_SLOT:-30}"

# Delay before genesis slot in minutes to be used for both version
MAIN_DELAY="${MAIN_SLOT:-15}"
FORK_DELAY="${MAIN_SLOT:-15}"

# script should be run from mina root directory.
source ./scripts/hard-fork-helper.sh

# Executable built off mainnet branch
MAIN_MINA_EXE="$1"

# Executable built off fork branch (e.g. berkeley)
FORK_MINA_EXE="$2"

# 1. Node is started
./scripts/run-hf-localnet.sh -m "$MAIN_MINA_EXE" -d "$MAIN_DELAY" -i "$MAIN_SLOT" \
  -s "$MAIN_SLOT" --slot-tx-end "$SLOT_TX_END" --slot-chain-end "$SLOT_CHAIN_END" &

# Sleep until slot_tx_end plus one minute
sleep $((MAIN_SLOT*(SLOT_TX_END-10)+MAIN_DELAY*60+60))s

# 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot 90 and that there are some user commands in blocks corresponding to slots 90 to 100
blockHeight=$(get_height 10303)
echo "Block height is $blockHeight at slot 90 and should be around 45 blocks."
echo "Blocks are produced."

for i in {1..10}
do
    sleep "${MAIN_SLOT}s"
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

# 3. Check that transactions stop getting included from slot 100 to slot 130, i.e. there are some blocks, with no user commands, coinbase set to 0.
sleep $((MAIN_SLOT*(SLOT_CHAIN_END-SLOT_TX_END-10)))s
for i in {1..10}
do
    sleep "${MAIN_SLOT}s"
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

# 4. Check that no blocks are created from slot 130 to slot 140
sleep 1m
height1=get_height 10303
sleep 5m
height2=get_height 10303
echo "Block height is $height2 at slot 140 and should be the same as $height1 at slot 130."
echo "No blocks are produced."

# 6. Transition root is extracted into a new runtime config
get_fork_config 10303 > localnet/fork_config.json

# 7. Runtime config is converted with a script to have only ledger hashes in the config
"$MAIN_MINA_EXE" client stop-daemon --daemon-port 10301
"$MAIN_MINA_EXE" client stop-daemon --daemon-port 10311

# mkdir -p localnet/genesis && scripts/generate_ledgers_tar_from_config.sh localnet/fork_config.json localnet/genesis localnet/config.json

FORK_CONFIG_JSON=localnet/fork_config.json RUNTIME_CONFIG_JSON=localnet/config.json ./scripts/hardfork/convert_fork_config.sh

# 8. Node is shutdown and restarted with mina-fork and the config from previous step 
./scripts/run-hf-localnet.sh -m "$FORK_MINA_EXE" -d "$FORK_DELAY" -i "$FORK_SLOT" \
  -s "$FORK_SLOT" -c localnet/config.json &

# 9. Check that network creates some blocks not later than 40 minutes after start

# Sleep for 60 slots (one epoch + a few more slots)
sleep $((FORK_SLOT*60+FORK_DELAY*60+60))s
height1=get_height 10303
echo "Block height is $height1 at slot 80 and should be greater than 0."
echo "Blocks are produced."
# Wait until slot 100 of the new network, check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks prior to slot 100
for i in {1..10}
do
    sleep "${FORK_SLOT}s"
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

"$FORK_MINA_EXE" client stop-daemon --daemon-port 10301
"$FORK_MINA_EXE" client stop-daemon --daemon-port 10311
