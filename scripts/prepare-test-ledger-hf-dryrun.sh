#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v date >/dev/null 2>&1; then
        missing_deps+=("date")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install the missing dependencies and try again." >&2
        exit 1
    fi
}

check_dependencies

# Number of extra keys to be included into ledger
EXTRA_KEYS=${EXTRA_KEYS:-0}

# Balance of each extra key
EXTRA_KEY_BALANCE=${EXTRA_KEY_BALANCE:-10000000}

# Do not use "next" ledgers
NO_NEXT=${NO_NEXT:-}

# Replace top
REPLACE_TOP=${REPLACE_TOP:-}

# Mainnet configuration constants
MAINNET_START='2024-06-05T00:00:00Z'
SLOTS_PER_EPOCH=7140
SLOT_TIME_SECONDS=180

now=$(date +%s)
mainnet_start=$(date --date="$MAINNET_START" -u +%s)

# Last epoch of mainnet (to be used as genesis ledger)
EPOCH=${EPOCH:-$(( (now-mainnet_start)/(SLOTS_PER_EPOCH*SLOT_TIME_SECONDS) ))}

##########################################################
# Parse arguments
##########################################################

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--extra-keys)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 0 ]]; then
        echo "Error: --extra-keys must be a non-negative integer" >&2
        exit 1
      fi
      EXTRA_KEYS="$2"; shift; shift ;;
    -b|--extra-key-balance)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -le 0 ]]; then
        echo "Error: --extra-key-balance must be a positive integer" >&2
        exit 1
      fi
      EXTRA_KEY_BALANCE="$2"; shift; shift ;;
    -r|--replace-top)
      REPLACE_TOP=1; shift ;;
    --no-next)
      NO_NEXT=1; shift ;;
    -h|--help)
      echo "Script downloads ledgers for the three latest consecutive epochs of mainnet and converts them into ledgers suitable for HF dryrun" >&2
      echo "Script creates three files in current directory: genesis.json staking.json and next.json" >&2
      echo "Script assumes mainnet's start was at epoch 0 on $(date --date="$MAINNET_START" '+%d %B %Y'), if it's not the case, update the script please" >&2
      echo "Usage: $0 [-e|--extra-keys $EXTRA_KEYS] [-b|--extra-key-balance $EXTRA_KEY_BALANCE] <BP key 1> <BP key 2> ... <BP key n>" >&2
      exit 0 ;;
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

# Validate EXTRA_KEYS doesn't exceed number of provided keys
if [[ $EXTRA_KEYS -gt $num_keys ]]; then
  echo "Error: Extra keys ($EXTRA_KEYS) cannot exceed number of provided keys ($num_keys)" >&2
  exit 1
fi

function update_extra_balances(){
  if ! jq ".[range(-1; -$((EXTRA_KEYS+1)); -1)].balance=\"$EXTRA_KEY_BALANCE\""; then
    echo "Error: Failed to update balances with jq" >&2
    exit 1
  fi
}

ledger_script="$SCRIPT_DIR/prepare-test-ledger.sh"

# Verify required script exists and is executable
if [[ ! -x "$ledger_script" ]]; then
  echo "Error: Required script not found or not executable: $ledger_script" >&2
  exit 1
fi

args=()
if [[ "$REPLACE_TOP" != "" ]]; then
  args=("-r")
fi

if [[ "$NO_NEXT" == "" ]]; then
  "$ledger_script" "${args[@]}" -p next-staking-$EPOCH "${KEYS[@]}" | update_extra_balances > genesis.json
else
  "$ledger_script" "${args[@]}" -p staking-$EPOCH "${KEYS[@]}" | update_extra_balances > genesis.json
  EPOCH=$((EPOCH-1))
fi
"$ledger_script" "${args[@]}" -p staking-$EPOCH "${KEYS[@]}" | update_extra_balances > next.json
"$ledger_script" "${args[@]}" -p staking-$((EPOCH-1)) "${KEYS[@]}" | update_extra_balances > staking.json
