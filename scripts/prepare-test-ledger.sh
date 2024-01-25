#!/usr/bin/env bash

# Number of keys in ledger that won't be re-delegated
KEY_BALANCE=${KEY_BALANCE:-100000}

# Do not touch accounts with balance below $DELEGATEE_CUTOFF
DELEGATEE_CUTOFF=${DELEGATEE_CUTOFF:-100000}

# Use (approximate) normal distribution for keys
# Works well for latger number of keys
NORM=${NORM:-}

echo "Script assumes mainnet's start was at epoch 0 on 17th March 2021, if it's not the case, update the script please" >&2
echo "Usage: $0 [-n|--norm] [-c|--delegation_cutoff $DELEGATEE_CUTOFF] [-b|--key-balance $KEY_BALANCE] <BP key 1> <BP key 2> ... <BP key n>" >&2
echo "Consider reading script's code for information on optional arguments" >&2

MAINNET_START='2021-03-17 00:00:00'

##########################################################
# Parse arguments
##########################################################

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--norm)
      NORM=1; shift ;;
    -c|--delegation-cutoff)
      DELEGATEE_CUTOFF="$2"; shift; shift ;;
    -b|--key-balance)
      KEY_BALANCE="$2"; shift; shift ;;
    -*|--*)
      echo "Unknown option $1"; exit 1 ;;
    *)
      KEYS+=("$1") ; shift ;;
  esac
done

num_keys=${#KEYS[@]}
if [[ $num_keys -eq 0 ]]; then
  echo "No keys specified" >&2
  exit 1
fi

##########################################################
# Download ledger
##########################################################

now=$(date +%s)
mainnet_start=$(date --date="$MAINNET_START" -u +%s)
epoch_now=$(( (now-mainnet_start)/7140/180 ))

ledger_file="$epoch_now.json"

echo "Current epoch: $epoch_now" >&2

if [[ ! -f "$ledger_file" ]]; then
  ledgers_url="https://storage.googleapis.com/storage/v1/b/mina-staking-ledgers/o?maxResults=1&prefix=staking-$epoch_now"
  ledger_url=$(curl "$ledgers_url" | jq -r .items[0].mediaLink)

  wget -O $ledger_file "$ledger_url"
fi

keys_=""
for key in "${KEYS[@]}"; do
  keys_="\"$key\",$keys_"
done
keys_="${keys_:0:-1}"

tmpfile=$(mktemp)

# jq filter to exclude PKs from the ledger
<"$epoch_now.json" jq "[.[] | select(.pk | IN($keys_) | not)]" >"$tmpfile"

num_accounts=$(<"$tmpfile" jq length)

##########################################################
# Create new ledger in a temporary file
##########################################################

function make_expr(){
  i=$1
  key=$2
  interval=$num_keys
  if [[ "$NORM" != "" ]]; then
    interval=$(( (RANDOM+RANDOM+RANDOM)*num_keys/32/1024/3+1 ))
  fi

  # Substitute delegate of some ledger keys with the BP key
  echo "((.[range($i; $num_accounts; $interval)] | select ((.balance|tonumber) > $DELEGATEE_CUTOFF)).delegate |= \"$key\")"
  echo ".[$((i+num_accounts))] = {delegate:\"$key\", pk:\"$key\", balance:\"$KEY_BALANCE\"}"
}

expr=$(for i in "${!KEYS[@]}"; do make_expr $i "${KEYS[$i]}"; done | tr "\n" "|" | head -c -1)
expr="$expr | [.[] | select(.delegate | IN($keys_)) |= del(.receipt_chain_hash)]"

tmpfile2=$(mktemp)
<"$tmpfile" jq "$expr" >"$tmpfile2"
mv "$tmpfile2" "$tmpfile"

##########################################################
# Calculate and print new stake distribution
##########################################################

total_balance=$(<"$tmpfile" jq "[.[].balance | tonumber] | add | round")
echo "Total accounts: $((num_accounts+num_keys)), balance: $total_balance" >&2

function make_balance_expr(){
  label="$1"
  keys="$2"
  echo "$label: ((([.[] | select(.delegate | IN($keys)) | .balance | tonumber] | add))/$total_balance*10000|round/100 )"
}

balance_expr=$({
  make_balance_expr all "$keys_"
  for key in "${KEYS[@]}"; do
    make_balance_expr "$key" "\"$key\""
  done } | tr "\n" "," | head -c -1)

echo "Stake distribution:" >&2
<"$tmpfile" jq "{$balance_expr} | to_entries | sort_by(.value) | reverse | from_entries | map_values((.|tostring) + \"%\")" 1>&2

# Print ledger and remove temporary file

cat "$tmpfile"
rm "$tmpfile"
