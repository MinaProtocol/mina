#!/bin/bash

S=../coda-automation/scripts

rm -rf $S/offline_whale_keys
rm -rf $S/offline_fish_keys
rm -rf $S/online_whale_keys
rm -rf $S/online_fish_keys
rm -rf $S/service-keys


python3 $S/testnet-keys.py keys generate-offline-fish-keys --count 1
python3 $S/testnet-keys.py keys generate-online-fish-keys --count 1
python3 $S/testnet-keys.py keys generate-offline-whale-keys --count 1
python3 $S/testnet-keys.py keys generate-online-whale-keys --count 1

python3 $S/testnet-keys.py ledger generate-ledger --num-whale-accounts 1 --num-fish-accounts 1


cp $S/genesis_ledger.json .
date -u +"%Y-%m-%dT%H:%M:%SZ"
