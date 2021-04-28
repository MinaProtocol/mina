#!/bin/bash

/root/init_mina.sh daemon --generate-genesis-proof true --peer-list-url https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt --background

sleep 480 #wait 8 minutes for the node to, hopefully, come online anbd fully sync

while true; do
  mina ledger export staking-epoch-ledger > staking_epoch_ledger.txt
  if [ "$?" -eq 0 ]; then
    echo "ledger dumped!"
    cat staking_epoch_ledger.txt
    break
  else
    echo "waiting for staking ledger to become available, sleeping for 30s"
    sleep 30
  fi
done

STAKING_LEDGER_HASH = mina ledger hash --ledger-file staking_epoch_ledger.txt

DATE = "$(date +'%F_%H%M')"
mv ./staking_epoch_ledger.txt ./$(DATE)_staking_epoch_ledger_$(staking_ledger_hash).txt

# echo STAKING_LEDGER > $(DATE)_staking_epoch_ledger_$(STAKING_LEDGER_HASH).txt

mina ledger export next-epoch-ledger > next_epoch_ledger.txt
NEXT_LEDGER_HASH = mina ledger hash --ledger-file next_epoch_ledger.txt
mv ./next_epoch_ledger.txt ./$(DATE)_next_epoch_ledger_$(next_ledger_hash).txt
# echo NEXT_LEDGER > $(DATE)_next_epoch_ledger_$(STAKING_LEDGER_HASH).txt




#will need service account and some access keys for below to work

gsutil cp $(DATE)_staking_epoch_ledger_$(staking_ledger_hash).txt gs://mina-staking-ledgers

gsutil cp $(DATE)_next_epoch_ledger$(staking_ledger_hash).txt gs://mina-staking-ledgers
