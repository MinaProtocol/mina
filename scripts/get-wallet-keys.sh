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

dune build src/app/cli/src/coda.exe

# Iterate over the keys in the JSON and wrap them in the proper format
i=1
max=$(jq -r '.|length' < "$jsonpath")
for k in $(jq -r '.[] | .private_key' < "$jsonpath"); do
    echo "wrapping key $i/$max"
    ./_build/default/src/app/cli/src/coda.exe advanced wrap-key -privkey-path "wallet-keys/$i" >/dev/null <<<"$k"
    # echo "$k" > "wallet-keys/$i"
    i=$((i + 1))
done

chmod 700 wallet-keys

rm -rf "$tmpdir"
