#!/bin/bash

set -e

RUNTIME_GENESIS_LEDGER_EXE=${RUNTIME_GENESIS_LEDGER_EXE:-"./_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe"}

if [ $# -lt 3 ]; then
    echo "Usage: $0 <config-file-input> <genesis-dir> <config-file-output>"
    exit 1
fi

config_file_input=$1
genesis_dir=$2
config_file_output=$3

# preprocess config file
config_file_tmp=$(mktemp)
echo "preprocessing config file..."
jq -r 'if .proof.fork | has("previous_global_slot") then .proof.fork.genesis_slot = .proof.fork.previous_global_slot | del(.proof.fork.previous_global_slot) else . end' "$config_file_input" >"$config_file_tmp"

echo "generating genesis ledger... (this may take a while)"
tmp_hash_json_file=$(mktemp)
$RUNTIME_GENESIS_LEDGER_EXE --config-file "$config_file_tmp" --genesis-dir "$genesis_dir" --hash-output-file "$tmp_hash_json_file"
echo "genesis ledger generated"

echo "updating config file..."
tmp_file=$(mktemp)
jq -r 'del(.ledger.accounts) | del(.epoch_data.staking.accounts) | del(.epoch_data.next.accounts)' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(jq -r '.genesis_hash' <"$tmp_hash_json_file")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.ledger.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(jq -r '.epoch_data.staking_hash' <"$tmp_hash_json_file")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.epoch_data.staking.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(jq -r '.epoch_data.next_hash' <"$tmp_hash_json_file")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.epoch_data.next.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

mv "$config_file_tmp" "$config_file_output"
rm "$tmp_hash_json_file"
echo "new config file: $config_file_output"
