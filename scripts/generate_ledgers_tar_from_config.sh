#!/usr/bin/env bash

set -e

RUNTIME_GENESIS_LEDGER_EXE=${RUNTIME_GENESIS_LEDGER_EXE:-"./_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe"}

if [ $# -lt 3 ]; then
    echo "Usage: $0 <config-file-input> <genesis-dir> <config-file-output>"
    exit 1
fi

config_file_input=$1
genesis_dir=$2
config_file_output=$3

tmp_hash_json_file=$(mktemp)

"$RUNTIME_GENESIS_LEDGER_EXE" --config-file "$config_file_input" --genesis-dir "$genesis_dir" --hash-output-file "$tmp_hash_json_file"

expr='del(.ledger.accounts) | del(.epoch_data.staking.accounts) | del(.epoch_data.next.accounts) | ( . |= . * ($f[0] | del(..|nulls)) )'
jq --slurpfile f "$tmp_hash_json_file" "$expr" "$config_file_input" > "$config_file_output"

rm "$tmp_hash_json_file"

find "$genesis_dir" -type l -exec rm '{}' ';'
