#!/usr/bin/env bash

# script should be run from mina root directory.
source ./scripts/hard-fork-helper.sh

mina_main=$1
mina_berkeley=$2

# 1. Node is started
./scripts/run-hf-localnet.sh -m $mina_main --slot-tx-end 100 --slot-chain-end 130 &
sleep 65m

# 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot 90 and that there are some user commands in blocks corresponding to slots 90 to 100
blockHeight=$(get_height 10303)
echo "Block height is $blockHeight at slot 90 and should be around 45 blocks."
echo "Blocks are produced."

for i in {1..10}
do
    sleep 30s
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

# 3. Check that transactions stop getting included from slot 100 to slot 130, i.e. there are some blocks, with no user commands, coinbase set to 0.
sleep 12m
for i in {1..30}
do
    sleep 30s
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

# 4. Check that no blocks are created from slot 130 to slot 140
height1=get_height 10303
sleep 5m
height2=get_height 10303
echo "Block height is $height2 at slot 140 and should be the same as $height1 at slot 130."
echo "No blocks are produced."

# 6. Transition root is extracted into a new runtime config
get_fork_config 10303 > localnet/fork_config.json

# 7. Runtime config is converted with a script to have only ledger hashes in the config
$mina_main client stop-daemon --daemon-port 10301
$mina_main client stop-daemon --daemon-port 10311
# mkdir -p localnet/genesis && scripts/generate_ledgers_tar_from_config.sh localnet/fork_config.json localnet/genesis localnet/config.json
FORK_CONFIG_JSON=localnet/fork_config.json 
RUNTIME_CONFIG_JSON=localnet/config.json 
./scripts/hardfork/convert_fork_config.sh

# 8. Node is shutdown and restarted with mina-berkeley and the config from previous step 
./scripts/run-hf-localnet.sh -m $mina_berkeley -c localnet/config.json &

# 9. Check that network creates some blocks not later than 40 minutes after start
sleep 40m
height1=get_height 10303
echo "Block height is $height1 at slot 80 and should be greater than 0."
echo "Blocks are produced."
sleep 5m
# Wait until slot 100 of the new network, check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks prior to slot 100
for i in {1..10}
do
    sleep 30s
    echo "There are $(blocks_withUserCommands 10303) blocks with at least one user command in the last 2 blocks."
done

$mina_berkeley client stop-daemon --daemon-port 10301
$mina_berkeley client stop-daemon --daemon-port 10311