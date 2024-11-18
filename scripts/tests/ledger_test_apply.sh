#!/bin/bash

# executes mina ledger test-apply command which is a
# Benchmark-like tool that:
# 1. Creates a set number of 9-account-updates transactions 
# 2. Applies these transactions to the ledger by calling update_coinbase_stack_and_get_data (which from runs on whale-1-1 seemed to be the major cost center), 
#    using empty scan state and pending coinbase collections
# Tool might be useful for detecting regression related to mentioned areas

export MINA_PRIVKEY_PASS='naughty blue worm'

MINA_APP=_build/default/src/app/cli/src/mina.exe
RUNTIME_LEDGER_APP=_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe

TEMP_FOLDER=$(mktemp -d)
ACCOUNTS_FILE=$TEMP_FOLDER/accounts.json
GENESIS_LEDGER=$TEMP_FOLDER/genesis_ledger.config
SENDER=$TEMP_FOLDER/sender

while [[ "$#" -gt 0 ]]; do case $1 in
  -m|--mina-app) MINA_APP="$2"; shift;;
  -r|--runtime-ledger-app) RUNTIME_LEDGER_APP="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


echo "Exporting ledger to $TEMP_FOLDER"
$MINA_APP ledger test generate-accounts -n 200000 --min-balance 100000 --max-balance 1000000 > $ACCOUNTS_FILE

jq  '{ ledger: { accounts:( $inputs | .[] ) , "add_genesis_winner": false } }' $ACCOUNTS_FILE --slurpfile inputs $ACCOUNTS_FILE > $GENESIS_LEDGER

echo "creating runtime ledger in $TEMP_FOLDER"
$RUNTIME_LEDGER_APP --config-file $GENESIS_LEDGER --genesis-dir $TEMP_FOLDER/genesis --hash-output-file $TEMP_FOLDER/genesis/hash.out --ignore-missing


# Silently passing MINA_PRIVKEY_PASS & CODA_PRIVKEY
CODA_PRIVKEY=$(cat $ACCOUNTS_FILE | jq -r .[0].sk) MINA_PRIVKEY_PASS=$MINA_PRIVKEY_PASS mina advanced wrap-key --privkey-path $SENDER
chmod 700 $SENDER

mkdir $TEMP_FOLDER/genesis/ledger

tar -zxf  $TEMP_FOLDER/genesis/genesis_ledger_*.tar.gz -C $TEMP_FOLDER/genesis/ledger

echo "running test:"
time $MINA_APP ledger test apply --ledger-path $TEMP_FOLDER/genesis/ledger  --privkey-path $SENDER --num-txs 200

