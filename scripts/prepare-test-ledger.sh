#!/usr/bin/env bash

set -euo pipefail

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v date >/dev/null 2>&1; then
        missing_deps+=("date")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install the missing dependencies and try again." >&2
        exit 1
    fi
}

check_dependencies

# Balance of keys to which delegation will happen
KEY_BALANCE=${KEY_BALANCE:-1000}

# Do not touch accounts with balance below $DELEGATEE_CUTOFF
DELEGATEE_CUTOFF=${DELEGATEE_CUTOFF:-100000}

# Use (approximate) normal distribution for keys
# Works well for larger number of keys
NORM=${NORM:-}

# Replace top N delegate keys with the specified keys
REPLACE_TOP=${REPLACE_TOP:-}

# Mainnet configuration constants
MAINNET_START='2024-06-05T00:00:00Z'
SLOTS_PER_EPOCH=7140
SLOT_TIME_SECONDS=180

now=$(date +%s)
mainnet_start=$(date --date="$MAINNET_START" -u +%s)

# Exit if ledger with specified prefix is really old (i.e. not synced for a long time)
# This is a safety mechanism to avoid using an old ledger by mistake
# (e.g. when ledger prefix is not updated for a long time)
# If set, script will exit with code 2 if the ledger is older than 1 year
EXIT_ON_OLD_LEDGER=${EXIT_ON_OLD_LEDGER:-}

# Ledger prefix to use for structuring ledger
LEDGER_PREFIX=${LEDGER_PREFIX:-staking-$(( (now-mainnet_start)/(SLOTS_PER_EPOCH*SLOT_TIME_SECONDS) ))}

##########################################################
# Parse arguments
##########################################################

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--replace-top)
      REPLACE_TOP=1; shift ;;
    -n|--norm)
      NORM=1; shift ;;
    -c|--delegation-cutoff)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -le 0 ]]; then
        echo "Error: --delegation-cutoff must be a positive integer" >&2
        exit 1
      fi
      DELEGATEE_CUTOFF="$2"; shift; shift ;;
    -b|--key-balance)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -le 0 ]]; then
        echo "Error: --key-balance must be a positive integer" >&2
        exit 1
      fi
      KEY_BALANCE="$2"; shift; shift ;;
    -p|--ledger-prefix)
      LEDGER_PREFIX="$2"; shift; shift ;;
    -o|--exit-on-old-ledger)
      EXIT_ON_OLD_LEDGER=1; shift ;;
    -h|--help)
      echo "Script assumes mainnet's start was at epoch 0 on 05 June 2024, if it's not the case, update the script please" >&2
      echo "Usage: $0 [-r|--replace-top] [-n|--norm] [-c|--delegation-cutoff $DELEGATEE_CUTOFF] [-b|--key-balance $KEY_BALANCE] [-p|--ledger-prefix $LEDGER_PREFIX] <BP key 1> <BP key 2> ... <BP key n>" >&2
      echo "Consider reading script's code for information on optional arguments" >&2
      exit 0 ;;
    -*|--*)
      echo "Unknown option $1"; exit 1 ;;
    *)
      KEYS+=("$1") ; shift ;;
  esac
done

if [[ "$REPLACE_TOP" != "" ]] && [[ "$NORM" != "" ]]; then
  echo "Can't use --norm and --replace-top at the same time" >&2
  exit 1
fi

num_keys=${#KEYS[@]}
if [[ $num_keys -eq 0 ]]; then
  echo "No keys specified" >&2
  exit 1
fi

# Validate that all keys are non-empty
for i in "${!KEYS[@]}"; do
  if [[ -z "${KEYS[$i]}" ]]; then
    echo "Error: Key at position $((i+1)) is empty" >&2
    exit 1
  fi
done

##########################################################
# Download ledger
##########################################################

ledger_file="$LEDGER_PREFIX.json"

echo "Using ledger with prefix: $LEDGER_PREFIX" >&2

if [[ ! -f "$ledger_file" ]]; then
  ledgers_url="https://storage.googleapis.com/storage/v1/b/mina-staking-ledgers/o?maxResults=1000&prefix=$LEDGER_PREFIX"
  echo "$ledgers_url" >&2
  ledger_url_content=$(curl -s "$ledgers_url")
  if ! ledger_url=$(echo "$ledger_url_content" | jq -r '.items | sort_by(.size|tonumber) | last.mediaLink'); then
    echo "Error: Failed to parse ledger URL from response" >&2
    exit 1
  fi
  if [[ "$ledger_url" == null ]]; then
    echo "Couldn't find ledger with prefix $LEDGER_PREFIX" >&2
    exit 2
  fi
  curl "$ledger_url" >"$ledger_file"
  not_finalized_msg="Ledger not found: next staking ledger is not finalized yet"
  if [[ "$(head -c ${#not_finalized_msg} "$ledger_file")" == "$not_finalized_msg" ]]; then
    echo "Next ledger not finalized yet" >&2 && rm "$ledger_file" && exit 2
  fi
  if [[ "$EXIT_ON_OLD_LEDGER" != "" ]]; then
    if ! ledger_timestamp=$(echo "$ledger_url_content" | jq -r '.items | sort_by(.size|tonumber) | last.timeCreated'); then
      echo "Error: Failed to parse ledger timestamp from response" >&2
      exit 1
    fi
    ledger_time=$(date --date="$ledger_timestamp" -u +%s 2>/dev/null || echo 0)
    one_year_ago=$((now - 365*24*3600))

    if [[ $ledger_time -lt $one_year_ago ]]; then
      echo "Ledger is older than 1 year (timestamp: $ledger_timestamp), exiting" >&2
      rm "$ledger_file"
      exit 2
    fi
  fi
fi

keys_=""
for key in "${KEYS[@]}"; do
  keys_="\"$key\",$keys_"
done
keys_="${keys_:0:-1}"

tmpfile=$(mktemp)

# jq filter to exclude PKs from the ledger
if ! <"$ledger_file" jq "[.[] | select(.pk | IN($keys_) | not)]" >"$tmpfile"; then
  echo "Error: Failed to filter ledger with jq" >&2
  rm "$tmpfile"
  exit 1
fi

if ! num_accounts=$(<"$tmpfile" jq length); then
  echo "Error: Failed to count accounts with jq" >&2
  rm "$tmpfile"
  exit 1
fi

##########################################################
# Create new ledger in a temporary file
##########################################################

TOP_KEYS=()
if [[ "$REPLACE_TOP" != "" ]]; then
  top_expr="[group_by(.delegate)[] | [(map(.balance|tonumber)|add), .[0].delegate]] | sort | reverse | map(.[1]) | .[0:$num_keys][]"
  if ! readarray -t TOP_KEYS < <( jq -r "$top_expr" "$tmpfile" ); then
    echo "Error: Failed to extract top keys with jq" >&2
    rm "$tmpfile"
    exit 1
  fi
fi

function make_expr(){
  i=$1
  key="${KEYS[$i]}"

  if [[ "$REPLACE_TOP" == "" ]]; then
    interval=$num_keys
    if [[ "$NORM" != "" ]]; then
      interval=$(( (RANDOM+RANDOM+RANDOM)*num_keys/32/1024/3+1 ))
    fi
    # Substitute delegate of some ledger keys with the BP key
    echo "((.[range($i; $num_accounts; $interval)] | select ((.balance|tonumber) > $DELEGATEE_CUTOFF)).delegate |= \"$key\")"
  else
    echo "((.[] | select(.delegate == \"${TOP_KEYS[$i]}\")).delegate |= \"$key\")"
  fi
  echo ".[$((i+num_accounts))] = {delegate:\"$key\", pk:\"$key\", balance:\"$KEY_BALANCE\"}"
}

expr=$(for i in "${!KEYS[@]}"; do make_expr $i; done | tr "\n" "|" | head -c -1)
expr="$expr | [.[] | select(.delegate | IN($keys_)) |= del(.receipt_chain_hash)]"


tmpfile2=$(mktemp)
if ! <"$tmpfile" jq "$expr" >"$tmpfile2"; then
  echo "Error: Failed to apply ledger transformations with jq" >&2
  rm "$tmpfile" "$tmpfile2"
  exit 1
fi
mv "$tmpfile2" "$tmpfile"

##########################################################
# Calculate and print new stake distribution
##########################################################

if ! total_balance=$(<"$tmpfile" jq "[.[].balance | tonumber] | add | round"); then
  echo "Error: Failed to calculate total balance with jq" >&2
  rm "$tmpfile"
  exit 1
fi
if [[ "$total_balance" == "0" ]] || [[ "$total_balance" == "null" ]]; then
  echo "Error: Total balance is zero or invalid, cannot calculate percentages" >&2
  rm "$tmpfile"
  exit 1
fi
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
if ! <"$tmpfile" jq "{$balance_expr} | to_entries | sort_by(.value) | reverse | from_entries | map_values((.|tostring) + \"%\")" 1>&2; then
  echo "Error: Failed to display stake distribution with jq" >&2
  rm "$tmpfile"
  exit 1
fi

# Print ledger and remove temporary file

cat "$tmpfile"
rm "$tmpfile"
