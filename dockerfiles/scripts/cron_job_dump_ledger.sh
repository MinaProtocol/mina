#!/bin/bash

mina daemon --generate-genesis-proof true --peer-list-url https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt --background

# wait 8 minutes for the node to hopefully come online and fully sync
sleep 480

echo "done sleeping"

# retry getting the staking ledger until the node is fully up and the command returns exit code 0
while true; do
  mina ledger export staking-epoch-ledger > staking_epoch_ledger.txt
  if [ "$?" -eq 0 ] && [ "$(cat staking_epoch_ledger.txt)" != "Ledger not found: current staking ledger not available" ]; then
    echo "staking epoch ledger dumped!"
    cat staking_epoch_ledger.txt
    break
  else
    echo "waiting for staking ledger to become available, sleeping for 30s"
    sleep 30
  fi
done

DATE="$(date +%F_%H%M)"

STAKING_LEDGER_HASH=(mina ledger hash --ledger-file staking_epoch_ledger.txt)
LEDGER_FILENAME="$DATE"_staking_epoch_ledger_"$STAKING_LEDGER_HASH".txt
mv ./staking_epoch_ledger.txt ./$LEDGER_FILENAME

# get the next staking ledger.  no need to retry since the node is already up by now
mina ledger export next-epoch-ledger > next_epoch_ledger.txt
echo "next epoch ledger dumped!"

NEXT_LEDGER_HASH=(mina ledger hash --ledger-file next_epoch_ledger.txt)
NEXT_LEDGER_FILENAME="$DATE"_next_epoch_ledger_"$NEXT_LEDGER_HASH".txt
mv ./next_epoch_ledger.txt ./$NEXT_LEDGER_FILENAME

echo "upload to a GCP cloud storage bucket"
gsutil cp $LEDGER_FILENAME gs://mina-staking-ledgers
gsutil cp $NEXT_LEDGER_FILENAME gs://mina-staking-ledgers
