#!/bin/sh

set -e

TESTNET="$1"
[ -n "$TESTNET" ] || (echo 'MISSING ARGUMENT' && exit 1)

get_status() {
  kubectl -n "$1" exec -c coda -i "$2" -- mina client status \
    | grep 'Block height\|Protocol state hash\|Sync status' \
    | xargs -I '{}' printf '  > %s\n' '"{}"'
}
export -f get_status

kubectl -n "$TESTNET" get pods \
  | grep -v NAME \
  | cut -d' ' -f1 \
  | parallel get_status "$TESTNET" '{}'
