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
echo "proprocessing config file..."
jq -r 'if .proof.fork | has("previous_global_slot") then .proof.fork.genesis_slot = .proof.fork.previous_global_slot | del(.proof.fork.previous_global_slot) else . end' "$config_file_input" >"$config_file_tmp"

echo "generating genesis ledger... (this may take a while)"
tmp_log_file=$(mktemp)
grep_strings=("ledger_file" "tar_path" "root_hash")
pattern=$(
    IFS="|"
    echo "${grep_strings[*]}"
)
$RUNTIME_GENESIS_LEDGER_EXE --config-file "$config_file_tmp" --genesis-dir "$genesis_dir" | tee >(grep -E "$pattern" >"$tmp_log_file")
tmp_file=$(mktemp)
echo "genesis ledger generated"

function get_ledger_root_hash() {
    ledger_name=$1
    json=$(grep "$ledger_name" <"$tmp_log_file")
    ledger_accounts_file=$(echo "$json" | jq -r '.metadata.ledger_file')
    json=$(grep "Linking ledger file" <"$tmp_log_file" | grep "$ledger_accounts_file")
    ledger_file=$(echo "$json" | jq -r '.metadata.tar_path')
    json=$(grep "$ledger_file" <"$tmp_log_file" | grep "root_hash")
    ledger_hash=$(echo "$json" | jq -r '.metadata.root_hash')

    echo "$ledger_hash"
}

echo "updating config file..."
jq -r 'del(.ledger.accounts) | del(.epoch_data.staking.accounts) | del(.epoch_data.next.accounts)' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(get_ledger_root_hash "genesis ledger")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.ledger.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(get_ledger_root_hash "staking epoch ledger")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.epoch_data.staking.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

ledger_hash=$(get_ledger_root_hash "next epoch ledger")
tmp_file=$(mktemp)
jq --arg hash "$ledger_hash" '.epoch_data.next.hash = $hash' "$config_file_tmp" >"$tmp_file"
mv "$tmp_file" "$config_file_tmp"

mv "$config_file_tmp" "$config_file_output"
echo "new config file: $config_file_output"
