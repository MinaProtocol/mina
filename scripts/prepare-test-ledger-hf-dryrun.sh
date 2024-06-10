#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Number of extra keys to be included into ledger
EXTRA_KEYS=${EXTRA_KEYS:-0}

# Balance of each extra key
EXTRA_KEY_BALANCE=${EXTRA_KEY_BALANCE:-10000000}

# Do not use "next" ledgers
NO_NEXT=${NO_NEXT:-}

echo "Script downloads ledgers for the three latest consequetive epochs of mainnet and converts them into ledgers suitable for HF dryrun" >&2
echo "Script creates three files in current directory: genesis.json staking.json and next.json" >&2
echo "Script assumes mainnet's start was at epoch 0 on 17th March 2021, if it's not the case, update the script please" >&2
echo "Usage: $0 [-e|--extra-keys $EXTRA_KEYS] [-b|--extra-key-balance $EXTRA_KEY_BALANCE] <BP key 1> <BP key 2> ... <BP key n>" >&2

MAINNET_START='2021-03-17 00:00:00'
now=$(date +%s)
mainnet_start=$(date --date="$MAINNET_START" -u +%s)

# Last epoch of mainnet (to be used as genesis ledger)
EPOCH=${EPOCH:-$(( (now-mainnet_start)/7140/180 ))}

##########################################################
# Parse arguments
##########################################################

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--extra-keys)
      EXTRA_KEYS="$2"; shift; shift ;;
    -b|--extra-key-balance)
      KEY_BALANCE="$2"; shift; shift ;;
    --no-next)
      NO_NEXT=1; shift ;;
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

function update_extra_balances(){
  jq ".[range(-1; -$((EXTRA_KEYS+1)); -1)].balance=\"$EXTRA_KEY_BALANCE\""
}

ledger_script="$SCRIPT_DIR/prepare-test-ledger.sh"

if [[ "$NO_NEXT" == "" ]]; then
  "$ledger_script" -r -p next-staking-$EPOCH "${KEYS[@]}" | update_extra_balances > genesis.json
else
  "$ledger_script" -r -p staking-$EPOCH "${KEYS[@]}" | update_extra_balances > genesis.json
  EPOCH=$((EPOCH-1))
fi
"$ledger_script" -r -p staking-$EPOCH "${KEYS[@]}" | update_extra_balances > next.json
"$ledger_script" -r -p staking-$((EPOCH-1)) "${KEYS[@]}" | update_extra_balances > staking.json
