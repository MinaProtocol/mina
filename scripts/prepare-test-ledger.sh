#!/usr/bin/env bash
# Backward-compatibility wrapper: translates the old prepare-test-ledger.sh
# CLI into a JSON spec and calls patch-ledger.

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

VENV_DIR="$SCRIPT_DIR/patch-ledger/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install -q -r "$SCRIPT_DIR/patch-ledger/requirements.txt"
fi
PYTHON="$VENV_DIR/bin/python"

KEY_BALANCE=${KEY_BALANCE:-1000}
DELEGATEE_CUTOFF=${DELEGATEE_CUTOFF:-100000}
NORM=${NORM:-}
REPLACE_TOP=${REPLACE_TOP:-}
EXIT_ON_OLD_LEDGER=${EXIT_ON_OLD_LEDGER:-}
LEDGER_PREFIX=""
OUTPUT=""

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--replace-top)
      REPLACE_TOP=1; shift ;;
    -n|--norm)
      NORM=1; shift ;;
    -c|--delegation-cutoff)
      DELEGATEE_CUTOFF="$2"; shift; shift ;;
    -b|--key-balance)
      KEY_BALANCE="$2"; shift; shift ;;
    -p|--ledger-prefix)
      LEDGER_PREFIX="$2"; shift; shift ;;
    -o|--exit-on-old-ledger)
      EXIT_ON_OLD_LEDGER=1; shift ;;
    --output)
      OUTPUT="$2"; shift; shift ;;
    -h|--help)
      echo "Usage: $0 [-r|--replace-top] [-n|--norm] [-c|--delegation-cutoff N] [-b|--key-balance N] [-p|--ledger-prefix PREFIX] [-o|--exit-on-old-ledger] --output FILE <key1> <key2> ..." >&2
      echo "Wrapper around patch-ledger. See patch-ledger/__main__.py --help for details." >&2
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

if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required" >&2
  exit 1
fi

if [[ "$REPLACE_TOP" != "" ]] && [[ "$NORM" != "" ]]; then
  echo "Can't use --norm and --replace-top at the same time" >&2
  exit 1
fi

delegation_type="reassign-delegation"
strategy="even"
if [[ "$REPLACE_TOP" != "" ]]; then
  delegation_type="replace-top-delegation"
elif [[ "$NORM" != "" ]]; then
  strategy="norm"
fi

exit_on_old="false"
[[ "$EXIT_ON_OLD_LEDGER" != "" ]] && exit_on_old="true"

keys_json=$(printf '%s\n' "${KEYS[@]}" | jq -R . | jq -s .)

add_entries=$(printf '%s\n' "${KEYS[@]}" | jq -R --arg bal "$KEY_BALANCE" '{pk: ., balance: $bal}' | jq -s .)

spec=$(jq -n \
  --argjson keys "$keys_json" \
  --arg prefix "$LEDGER_PREFIX" \
  --argjson exit_on_old "$exit_on_old" \
  --arg delegation_type "$delegation_type" \
  --arg strategy "$strategy" \
  --argjson cutoff "$DELEGATEE_CUTOFF" \
  --argjson add_entries "$add_entries" \
  '{
    source: {type: "gcs-epoch", prefix: $prefix, exit_on_old_ledger: $exit_on_old},
    transforms: [
      {type: "remove-accounts", keys: $keys},
      (if $delegation_type == "replace-top-delegation" then
        {type: "replace-top-delegation", to: $keys}
      else
        {type: "reassign-delegation", to: $keys, strategy: $strategy, delegation_cutoff: $cutoff}
      end),
      {type: "add-accounts", entries: $add_entries},
      {type: "strip-receipt-chain-hash", delegate_keys: $keys}
    ]
  }')

exec "$PYTHON" "$SCRIPT_DIR/patch-ledger/__main__.py" --spec "$spec" --output "$OUTPUT"
