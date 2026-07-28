#!/usr/bin/env bash

# Generate a set of zkApp transactions with the zkApp test transaction tool and
# optionally submit them to a daemon's GraphQL endpoint.
#
# The variants come from a manifest rather than from this script, so the same
# runner drives different test plans, and the same manifest can be replayed
# against networks whose zkApp limits differ. Which limits apply is decided by
# the tool binary, not here: point --tool at a build matching the network.

set -euo pipefail

TOOL=""
FEE_PAYER_KEY=""
ZKAPP_KEY=""
ENDPOINT=""
MANIFEST="$(dirname "${BASH_SOURCE[0]}")/general.manifest"
OUT_DIR=""
NONCE=""
FEE=""
DRY_RUN=0
ONLY=""

usage() {
  cat <<'EOF'
Usage: send-payloads.sh --tool PATH --fee-payer-key FILE --zkapp-key FILE
                        [--endpoint URL] [--manifest FILE] [--out-dir DIR]
                        [--nonce N] [--fee AMOUNT] [--only NAME] [--dry-run]

  --tool           zkApp test transaction binary (mina-zkapp-test-transaction)
  --fee-payer-key  private key file of the fee payer
  --zkapp-key      private key file of the zkApp account being updated
  --endpoint       daemon GraphQL endpoint; omit, or pass --dry-run, to only
                   generate the transactions without submitting them
  --manifest       variants to generate (default: general.manifest beside this
                   script)
  --out-dir        where to write the generated transactions
                   (default: a new directory under the current directory)
  --nonce          fee payer nonce to start from; queried from --endpoint when
                   omitted
  --fee            fee for each transaction, passed through to the tool
  --only           generate just the named variant
  --dry-run        generate but do not submit

The fee payer key password is read from MINA_PRIVKEY_PASS, as the tool itself
does. The key files must live in a directory with 0700 permissions.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --fee-payer-key) FEE_PAYER_KEY="$2"; shift 2 ;;
    --zkapp-key) ZKAPP_KEY="$2"; shift 2 ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --nonce) NONCE="$2"; shift 2 ;;
    --fee) FEE="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for required in TOOL FEE_PAYER_KEY ZKAPP_KEY; do
  if [[ -z "${!required}" ]]; then
    echo "missing required argument for ${required}" >&2
    usage >&2
    exit 2
  fi
done

[[ -x "$TOOL" ]] || { echo "not executable: $TOOL" >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "cannot read manifest: $MANIFEST" >&2; exit 2; }

if [[ -z "$ENDPOINT" ]]; then
  DRY_RUN=1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="zkapp-payloads-$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUT_DIR"

# The tool prints the key prompts on stdout ahead of the transaction, so take
# everything from the opening "mutation" keyword rather than the whole stream.
extract_mutation() {
  sed -n '/^[[:space:]]*mutation/,$p' "$1"
}

# Ask the daemon for the fee payer's next nonce. Only reached when the caller
# did not pass --nonce and an endpoint is available.
query_nonce() {
  local pubkey_file="${FEE_PAYER_KEY}.pub" pubkey response nonce
  [[ -r "$pubkey_file" ]] || {
    echo "cannot read ${pubkey_file}; pass --nonce instead" >&2
    return 1
  }
  pubkey="$(tr -d '[:space:]' < "$pubkey_file")"
  response="$(curl -sS -X POST -H 'Content-Type: application/json' \
    -d "{\"query\":\"{ account(publicKey: \\\"${pubkey}\\\") { nonce } }\"}" \
    "$ENDPOINT")" || return 1
  nonce="$(printf '%s' "$response" |
    sed -n 's/.*"nonce"[[:space:]]*:[[:space:]]*"\{0,1\}\([0-9]\{1,\}\).*/\1/p')"
  [[ -n "$nonce" ]] || {
    echo "could not read a nonce from: ${response}" >&2
    return 1
  }
  printf '%s' "$nonce"
}

if [[ -z "$NONCE" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    NONCE=0
    echo "no --nonce and not submitting; generating from nonce 0"
  else
    NONCE="$(query_nonce)"
    echo "fee payer nonce from ${ENDPOINT}: ${NONCE}"
  fi
fi

# Submit one generated transaction, echoing whatever the daemon replies. The
# tool emits a complete GraphQL document, so it is sent as the query verbatim.
submit() {
  local file="$1" payload
  payload="$(python3 -c 'import json,sys; print(json.dumps({"query": open(sys.argv[1]).read()}))' "$file")"
  curl -sS -X POST -H 'Content-Type: application/json' -d "$payload" "$ENDPOINT"
}

declare -a NAMES=() RESULTS=()
generated=0
submitted=0
failed=0

while read -r name flags; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  if [[ -n "$ONLY" && "$name" != "$ONLY" ]]; then
    continue
  fi

  raw="${OUT_DIR}/${name}.raw"
  out="${OUT_DIR}/${name}.graphql"

  # Deliberately unquoted: the manifest supplies whole flag lists.
  # shellcheck disable=SC2086
  set -- $flags
  if [[ -n "$FEE" ]]; then
    set -- "$@" --fee "$FEE"
  fi

  if "$TOOL" update-state \
    --fee-payer-key "$FEE_PAYER_KEY" \
    --zkapp-account-key "$ZKAPP_KEY" \
    --nonce "$NONCE" \
    "$@" > "$raw" 2>&1
  then
    extract_mutation "$raw" > "$out"
    if [[ ! -s "$out" ]]; then
      NAMES+=("$name"); RESULTS+=("no transaction in output")
      failed=$((failed + 1))
      continue
    fi
    generated=$((generated + 1))
    rm -f "$raw"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      NAMES+=("$name"); RESULTS+=("generated")
    else
      if response="$(submit "$out")" && [[ "$response" != *'"errors"'* ]]; then
        submitted=$((submitted + 1))
        NAMES+=("$name"); RESULTS+=("submitted")
        NONCE=$((NONCE + 1))
      else
        failed=$((failed + 1))
        printf '%s\n' "$response" > "${OUT_DIR}/${name}.error"
        NAMES+=("$name"); RESULTS+=("rejected, see ${name}.error")
      fi
    fi
  else
    failed=$((failed + 1))
    NAMES+=("$name"); RESULTS+=("generation failed, see ${name}.raw")
  fi
done < "$MANIFEST"

echo
echo "results, written to ${OUT_DIR}:"
for i in "${!NAMES[@]}"; do
  printf '  %-24s %s\n' "${NAMES[$i]}" "${RESULTS[$i]}"
done
echo
echo "generated ${generated}, submitted ${submitted}, failed ${failed}"

[[ "$failed" -eq 0 ]]
