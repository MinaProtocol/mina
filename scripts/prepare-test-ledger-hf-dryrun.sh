#!/usr/bin/env bash
# Backward-compatibility wrapper: translates the old prepare-test-ledger-hf-dryrun.sh
# CLI into 3 JSON specs and calls patch-ledger 3 times.

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PATCH_LEDGER="$SCRIPT_DIR/patch-ledger/run.sh"

EXTRA_KEYS=${EXTRA_KEYS:-0}
EXTRA_KEY_BALANCE=${EXTRA_KEY_BALANCE:-10000000}
NO_NEXT=${NO_NEXT:-}
REPLACE_TOP=${REPLACE_TOP:-}

MAINNET_START='2024-06-05T00:00:00Z'
SLOTS_PER_EPOCH=7140
SLOT_TIME_SECONDS=180

now=$(date +%s)
mainnet_start=$(date --date="$MAINNET_START" -u +%s)
EPOCH=${EPOCH:-$(( (now-mainnet_start)/(SLOTS_PER_EPOCH*SLOT_TIME_SECONDS) ))}

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--extra-keys)
      EXTRA_KEYS="$2"; shift; shift ;;
    -b|--extra-key-balance)
      EXTRA_KEY_BALANCE="$2"; shift; shift ;;
    -r|--replace-top)
      REPLACE_TOP=1; shift ;;
    --no-next)
      NO_NEXT=1; shift ;;
    -h|--help)
      echo "Downloads ledgers for 3 consecutive mainnet epochs and patches them for HF dryrun." >&2
      echo "Creates genesis.json, staking.json, next.json in CWD." >&2
      echo "Usage: $0 [-e|--extra-keys N] [-b|--extra-key-balance N] [-r|--replace-top] [--no-next] <key1> <key2> ..." >&2
      exit 0 ;;
    -*|--*)
      echo "Unknown option $1" >&2; exit 1 ;;
    *)
      KEYS+=("$1"); shift ;;
  esac
done

if [[ ${#KEYS[@]} -eq 0 ]]; then
  echo "No keys specified" >&2
  exit 1
fi

if [[ $EXTRA_KEYS -gt ${#KEYS[@]} ]]; then
  echo "Error: Extra keys ($EXTRA_KEYS) cannot exceed number of provided keys (${#KEYS[@]})" >&2
  exit 1
fi

delegation_type="reassign-delegation"
strategy="even"
if [[ "$REPLACE_TOP" != "" ]]; then
  delegation_type="replace-top-delegation"
fi

keys_json=$(printf '%s\n' "${KEYS[@]}" | jq -R . | jq -s .)
add_entries=$(printf '%s\n' "${KEYS[@]}" | jq -R '{pk: ., balance: "1000"}' | jq -s .)

build_spec() {
  local prefix="$1"
  local transforms
  transforms=$(jq -n \
    --argjson keys "$keys_json" \
    --arg delegation_type "$delegation_type" \
    --arg strategy "$strategy" \
    --argjson add_entries "$add_entries" \
    '[
      {type: "remove-accounts", keys: $keys},
      (if $delegation_type == "replace-top-delegation" then
        {type: "replace-top-delegation", to: $keys}
      else
        {type: "reassign-delegation", to: $keys, strategy: $strategy}
      end),
      {type: "add-accounts", entries: $add_entries},
      {type: "strip-receipt-chain-hash", delegate_keys: $keys}
    ]')

  if [[ "$EXTRA_KEYS" -gt 0 ]]; then
    transforms=$(echo "$transforms" | jq \
      --argjson count "$EXTRA_KEYS" \
      --arg balance "$EXTRA_KEY_BALANCE" \
      '. + [{type: "boost-last", count: $count, balance: $balance}]')
  fi

  jq -n \
    --arg prefix "$prefix" \
    --argjson transforms "$transforms" \
    '{source: {type: "gcs-epoch", prefix: $prefix}, transforms: $transforms}'
}

if [[ "$NO_NEXT" == "" ]]; then
  "$PATCH_LEDGER" --spec "$(build_spec "next-staking-$EPOCH")" --output genesis.json
else
  "$PATCH_LEDGER" --spec "$(build_spec "staking-$EPOCH")" --output genesis.json
  EPOCH=$((EPOCH-1))
fi
"$PATCH_LEDGER" --spec "$(build_spec "staking-$EPOCH")" --output next.json
"$PATCH_LEDGER" --spec "$(build_spec "staking-$((EPOCH-1))")" --output staking.json
