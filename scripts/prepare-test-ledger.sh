#!/usr/bin/env bash

# Usage: ./scripts/prepare-test-ledger.sh <BP key 1> <BP key 2> ... <BP key n>

# Number of keys in ledger that won't be re-delegated
NUM_GHOST_KEYS=${NUM_GHOST_KEYS:-0}
KEY_BALANCE=100000

echo "Script assumes mainnet's start was at epoch 0 on 17th March 2021, if it's not the case, update the script please" >&2

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/prepare-test-ledger.sh <BP key 1> <BP key 2> ... <BP key n>" >&2
  exit 1
fi

num_keys=$#
num_keys_and_ghost=$((num_keys + NUM_GHOST_KEYS))

now=$(date +%s)
mainnet_start=$(date --date='2021-03-17 00:00:00' -u +%s)
epoch_now=$(( (now-mainnet_start)/7140/180 ))

ledger_file="$epoch_now.json"

echo "Current epoch: $epoch_now" >&2

if [[ ! -f "$ledger_file" ]]; then
  ledgers_url="https://storage.googleapis.com/storage/v1/b/mina-staking-ledgers/o?maxResults=1&prefix=staking-$epoch_now"
  ledger_url=$(curl "$ledgers_url" | jq -r .items[0].mediaLink)

  wget -O $ledger_file "$ledger_url"
fi

##########################################################
# Find indexes of BP keys and appoint first non-occupied
# indices of ledger to serve as such
##########################################################

# Find index of each BP key (or set null if not found)
ixs_=()
for key in "$@"; do
  ixs_+=( "$(<$ledger_file jq "[.[].pk] |index(\"$key\")")" )
done

# Substitute nulls with some indices not occupied by
# other BP keys
ixs=()
i=0
for ix in "${ixs_[@]}"; do
  if [[ $ix == null ]]; then
    while true; do
      found=false
      for ix_ in "${ixs_[@]}"; do
        if [[ $i == "$ix_" ]]; then
          found=true
        fi
      done
      if $found; then
        i=$((i+1))
      else
        break
      fi
    done
    ixs+=( "$i" )
  else
    ixs+=( "$ix" )
  fi
done

# Form a comma-separated string of BP key indices
ixs_str=$(tr " " ,  <<< "${ixs[*]}")

##########################################################
# Calculate and print approximate new balances
##########################################################

num_accounts=$(<$ledger_file jq length)
total_balance=$(<$ledger_file jq '[.[].balance | tonumber] | add | round')
deducted_balance=$(<$ledger_file jq "[.[$ixs_str].balance | tonumber] | add | ceil")
new_total_balance=$((total_balance-deducted_balance+num_keys*KEY_BALANCE))
echo "Total accounts: $num_accounts, balance: $total_balance, new balance: $new_total_balance" >&2

function make_balance_expr(){
  i=$1
  key=$2
  echo "$key: ((([.[range($i; $num_accounts; $num_keys_and_ghost)].balance | tonumber] | add)/$new_total_balance*10000|round/100 | tostring) + \"%\")"
}

balance_expr=$({ i=0; while [[ $i -lt $num_keys ]]; do
  j=$((i+1))
  make_balance_expr $i "${!j}"
  i=$j
done } | tr "\n" "," | head -c -1)

echo "Balance map (warning: may not account well for the balance of delegate):" >&2
jq <$ledger_file "{$balance_expr}" 1>&2

##########################################################
# Build new ledger
##########################################################

function make_expr(){
  i=$1
  key=$2

  # Substitute delegate of some ledger keys with the BP key
  echo ".[range($i; $num_accounts; $num_keys_and_ghost)].delegate = \"$key\""

  # Ensure BP key iytself is in the ledger with non-zero balance
  echo ".[${ixs[$i]}].pk = \"$key\""
  echo ".[${ixs[$i]}].balance = \"$KEY_BALANCE\""
}

expr=$({ i=0; while [[ $i -lt $num_keys ]]; do
  j=$((i+1))
  make_expr $i "${!j}"
  i=$j
done } | tr "\n" "|" | head -c -1)

jq <$ledger_file "$expr"
