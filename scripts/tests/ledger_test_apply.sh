#!/bin/bash

# test mina ledger test-apply
set -x

export MINA_PRIVKEY_PASS='naughty blue worm'

MINA_APP=_build/default/src/app/cli/src/mina.exe
RUNTIME_LEDGER_APP=_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe

TEMP_FOLDER=$(mktemp -d)
ACCOUNTS_FILE=$TEMP_FOLDER/accounts.json
GENESIS_LEDGER=$TEMP_FOLDER/genesis_ledger.config
SENDER_FOLDER=$TEMP_FOLDER/sender

while [[ "$#" -gt 0 ]]; do case $1 in
  -m|--mina-app) MINA_APP="$2"; shift;;
  -r|--runtime-ledger-app) RUNTIME_LEDGER_APP="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


echo "Exporting ledger to $TEMP_FOLDER"
$MINA_APP ledger test generate-accounts -n 2 --min-balance 100000 --max-balance 1000000 > $ACCOUNTS_FILE

jq  '{ ledger: { name:"random", accounts:( $inputs | .[] )  } }' $ACCOUNTS_FILE --slurpfile inputs $ACCOUNTS_FILE > $GENESIS_LEDGER

echo "creating runtime ledger in $TEMP_FOLDER"
$RUNTIME_LEDGER_APP --config-file $GENESIS_LEDGER --genesis-dir $TEMP_FOLDER/genesis --hash-output-file $TEMP_FOLDER/genesis/hash.out --ignore-missing

mkdir $SENDER_FOLDER
chmod 700 $SENDER_FOLDER

CODA_PRIVKEY=$(cat $ACCOUNTS_FILE | jq -r .[0].sk)

# Silently passing MINA_PRIVKEY_PASS & CODA_PRIVKEY
mina advanced wrap-key --privkey-path $SENDER_FOLDER

mkdir $TEMP_FOLDER/genesis/ledger

tar -zxf  $TEMP_FOLDER/genesis/genesis_ledger_*.tar.gz -C $TEMP_FOLDER/genesis/ledger

echo "running test:"
$MINA_APP ledger test apply --ledger-path $TEMP_FOLDER/genesis/ledger  --privkey-path $SENDER  --num-txs 200

