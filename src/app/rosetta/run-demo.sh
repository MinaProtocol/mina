#!/bin/bash

set -e

BIN=../../../_build/default/src/app/cli/src/coda.exe
BIN=/coda-bin/cli/src/coda.exe
PK=ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8

genesis_time=$(date -d '2019-01-30 20:00:00.000000Z' '+%s')
now_time=$(date +%s)

export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export CODA_PRIVKEY_PASS=""
export CODA_CONFIG_FILE=/tmp/config.json

exec $BIN daemon -seed -demo-mode -block-producer-key /tmp/keys/demo-block-producer -run-snark-worker $PK -config-file /tmp/config.json -insecure-rest-server $@
