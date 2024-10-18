#!/bin/bash

# test mina ledger test-apply
set -x

export MINA_PRIVKEY_PASS='naughty blue worm'

MINA_APP=_build/default/src/app/cli/src/mina.exe
GENERATE_LEDGER_APP=_build/default/src/test/generate_random_ledger/generate_random_ledger.exe
RUNTIME_LEDGER_APP=_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe

TEMP_FOLDER=$(mktemp -d)

while [[ "$#" -gt 0 ]]; do case $1 in
  -m|--mina-app) MINA_APP="$2"; shift;;
  -g|--generate-ledger-app) GENERATE_LEDGER_APP="$2"; shift;;
  -r|--runtime-ledger-app) RUNTIME_LEDGER_APP="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


echo "Exporting ledger to $TEMP_FOLDER"
$GENERATE_LEDGER_APP --output $TEMP_FOLDER --no-num-accounts

echo "creating runtime ledger in $TEMP_FOLDER"
$RUNTIME_LEDGER_APP --config-file $TEMP_FOLDER/genesis_ledger.config --genesis-dir $TEMP_FOLDER/genesis --hash-output-file $TEMP_FOLDER/genesis/hash.out --ignore-missing

chmod 700 $TEMP_FOLDER/alice

mkdir $TEMP_FOLDER/genesis/ledger

tar -zxf  $TEMP_FOLDER/genesis/genesis_ledger_*.tar.gz -C $TEMP_FOLDER/genesis/ledger


echo "running test:"
$MINA_APP ledger test apply --ledger-path $TEMP_FOLDER/genesis/ledger  --privkey-path $TEMP_FOLDER/alice  --num-txs 200

