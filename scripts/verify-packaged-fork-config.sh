#!/usr/bin/env bash

set -eo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <mainnet-fork-config.json> <working-dir>"
    cat <<EOF
This script is used to validate that an installed package is correct
according to an exported fork_config.json file.

Inputs:
- The exported mainnet full config.json fork config, with all accounts
- A working directory where ledgers/configs will be created
- Installed MINA_EXE (default: mina) and MINA_GENESIS_EXE (default: mina-create-genesis) programs
- PACKAGED_CONFIG_JSON (default: /var/lib/coda/config_*.json)
- GENESIS_LEDGER_DIR (default: /var/lib/coda)

Ensures:
- The accounts listed in config.json are the ones in the PACKAGED_CONFIG_JSON
- The genesis ledger directory tarfile contents match a reference copies created
  anew from config.json

Outputs:
- Exit code 0 if validated, 1 otherwise.
EOF
    
    exit 1
fi

MINA_EXE=${MINA_EXE:-"mina"}
MINA_GENESIS_EXE=${MINA_GENESIS_EXE:-"mina-create-genesis"}
found_config=$(echo /var/lib/coda/config_*.json)
PACKAGED_CONFIG_JSON=${PACKAGED_CONFIG_JSON:-$found_config}
GENESIS_LEDGER_DIR=${GENESIS_LEDGER_DIR:-"/var/lib/coda"}

export MINA_LIBP2P_PASS=''

workdir=$2
mkdir -p "$workdir"
mkdir -p "$workdir/ledgers"
mkdir -p "$workdir/ledgers-backup"
mkdir -p "$workdir/keys"
chmod 700 "$workdir/keys"

if [ ! -e "$workdir/keys/p2p" ]; then
    "$MINA_EXE" libp2p generate-keypair --privkey-path "$workdir/keys/p2p"
fi

# This is a copy of scripts/generate_ledgers_tar_from_config.sh so that this script can be
# bundled + run in the .deb without any extra dependencies. Keep them in sync!
function generate_ledgers_tar_from_config() {
    config_file_input=$1
    genesis_dir=$2
    config_file_output=$3

    # preprocess config file
    config_file_tmp=$(mktemp)
    echo "preprocessing config file..."
    cp "$config_file_input" "$config_file_tmp"
    sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' "$config_file_tmp"

    echo "generating genesis ledger... (this may take a while)"
    tmp_hash_json_file=$(mktemp)
    $RUNTIME_GENESIS_LEDGER_EXE --config-file "$config_file_tmp" --genesis-dir "$genesis_dir" --hash-output-file "$tmp_hash_json_file"
    echo "genesis ledger generated"

    echo "updating config file..."
    tmp_file=$(mktemp)
    jq -r 'del(.ledger.accounts) | del(.epoch_data.staking.accounts) | del(.epoch_data.next.accounts)' "$config_file_tmp" >"$tmp_file"
    mv "$tmp_file" "$config_file_tmp"

    ledger_hash=$(jq -r '.ledger.hash' <"$tmp_hash_json_file")
    tmp_file=$(mktemp)
    jq --arg hash "$ledger_hash" '.ledger.hash = $hash' "$config_file_tmp" >"$tmp_file"
    mv "$tmp_file" "$config_file_tmp"

    ledger_hash=$(jq -r '.epoch_data.staking.hash' <"$tmp_hash_json_file")
    tmp_file=$(mktemp)
    jq --arg hash "$ledger_hash" '.epoch_data.staking.hash = $hash' "$config_file_tmp" >"$tmp_file"
    mv "$tmp_file" "$config_file_tmp"

    ledger_hash=$(jq -r '.epoch_data.next.hash' <"$tmp_hash_json_file")
    tmp_file=$(mktemp)
    jq --arg hash "$ledger_hash" '.epoch_data.next.hash = $hash' "$config_file_tmp" >"$tmp_file"
    mv "$tmp_file" "$config_file_tmp"

    mv "$config_file_tmp" "$config_file_output"
    rm "$tmp_hash_json_file"
    echo "new config file: $config_file_output"
}

RUNTIME_GENESIS_LEDGER_EXE=$MINA_GENESIS_EXE generate_ledgers_tar_from_config "$1" "$workdir/ledgers" "$workdir/config-substituted.json"

result=$(jq --slurpfile a "$workdir/config-substituted.json" --slurpfile b "$PACKAGED_CONFIG_JSON" -n '
  ($a[0].epoch_data.staking.hash == $b[0].epoch_data.staking.hash and
   $a[0].epoch_data.next.hash == $b[0].epoch_data.next.hash and
$a[0].ledger.hash == $b[0].ledger.hash)')

if [ "$result" != "true" ]; then
    echo "Packaged config hashes in $PACKAGED_CONFIG_JSON not expected compared to $workdir/config-substituted.json"
    exit 1
fi

# export the packaged ledgers in a way where we know which one is which
function extract_ledgers() {
    "$MINA_EXE" daemon --libp2p-keypair "$workdir/keys/p2p" --config-file "$1" --seed --genesis-ledger-dir "$2" &
    
    while ! "$MINA_EXE" ledger export staged-ledger  | jq >"$3-staged.json"; do
        sleep 1m
    done
    
    "$MINA_EXE" ledger export staking-epoch-ledger | jq > "$3-staking.json"
    "$MINA_EXE" ledger export next-epoch-ledger | jq > "$3-next.json"
    
    "$MINA_EXE" client stop
}

extract_ledgers "$PACKAGED_CONFIG_JSON" "$GENESIS_LEDGER_DIR" "$workdir/packaged"
mv -t "$workdir/ledgers-backup" /var/lib/coda/*.tar.gz
extract_ledgers "$workdir/config-substituted.json" "$workdir/ledgers" "$workdir/reference"
mv -t /var/lib/coda "$workdir/ledgers-backup"/*

echo "Performing final comparisons..."

error=0
for file in "$workdir"/packaged-*.json; do
    name=$(basename "$file")
    name=${name%.json}
    name=${name#packaged-}

    if ! diff "$file" "$workdir/reference-$name.json"; then
        echo "Error: $file does not match reference"
        error=1
    fi
done


for file in "$workdir"/ledgers/*.tar.gz; do
    tarname=$(basename "$file")
    tarname=${tarname%.tar.gz}
    mkdir "$workdir/ledgers/$tarname/packaged";
    mkdir "$workdir/ledgers/$tarname/reference";
    tar -xzf "$file" -C "$workdir/ledgers/$tarname/reference"
    tar -xzf "$GENESIS_LEDGER_DIR/$tarname.tar.gz" -C "$workdir/ledgers/$tarname/packaged"
    if ! "$MINA_EXE" internal kvdb eq --rocksdb-dir "$workdir/ledgers/$tarname/packaged" --rocksdb-dir "$workdir/ledgers/$tarname/reference"; then
        echo "Tarfile kvdb contents mismatch for $tarname"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Error: failed validation"
    exit 1
else
    echo "Validation successful"
    exit 0
fi