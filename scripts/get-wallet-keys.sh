#!/usr/bin/env bash

# Script to get keypairs associated with genesis wallets in a format usable by
# the coda cli, with blank passwords.

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# Generate the JSON file containing the unencrypted keys
tmpdir="$(mktemp -d)"
cd "$tmpdir"
"$SCRIPTPATH"/../_build/default/src/lib/coda_base/gen/gen.exe
jsonpath="$tmpdir/sample_keypairs.json"

cd "$SCRIPTPATH/.."

mkdir -p wallet-keys
export CODA_PRIVKEY_PASS=""

# Iterate over the keys in the JSON and wrap them in the proper format
i=1
for k in $(jq -r '.[] | .private_key' < "$jsonpath"); do
    dune exec -- coda client wrap-key -privkey-path "wallet-keys/$i" <<<"$k"
    # echo "$k" > "wallet-keys/$i"
    i=$((i + 1))
done

chmod 700 wallet-keys

rm -rf "$tmpdir"
