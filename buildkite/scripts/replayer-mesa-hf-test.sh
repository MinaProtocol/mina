#!/bin/bash

# test replayer on mesa hard fork database starting from the hardfork checkpoint
set -euo pipefail

REPLAYER_APP=mina-replayer
PG_CONN=postgres://postgres:postgres@localhost:5432/archive
INPUT_FILE=src/test/archive/sample_mesa_hf_db/expected-mesa-hf-replayer-output.json
MINA_LEDGER_S3_BUCKET=${MINA_LEDGER_S3_BUCKET:=https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net}

while [[ "$#" -gt 0 ]]; do case $1 in
  -a|--app) REPLAYER_APP="$2"; shift;;
  -p|--pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

echo "Installing mina-devnet-config package"

CONFIG_DEB=$(find src/test/archive/sample_mesa_hf_db -name 'mina-devnet-config_*.deb' | head -1)
if [[ -z "$CONFIG_DEB" ]]; then
  echo "ERROR: mina-devnet-config deb not found in src/test/archive/sample_mesa_hf_db/"
  exit 1
fi
sudo dpkg -i "$CONFIG_DEB"

echo "Running replayer from mesa hard fork checkpoint"

export MINA_LEDGER_S3_BUCKET

$REPLAYER_APP \
  --archive-uri "$PG_CONN" \
  --input-file "$INPUT_FILE"

RESULT=$?

if [[ $RESULT == 0 ]]; then
  echo "SUCCEEDED"
else
  echo "FAILED"
fi

exit $RESULT
