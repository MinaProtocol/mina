#!/bin/bash

set -e

BIN=../../../_build/default/src/app/cli/src/coda.exe
PK=B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g
SNARK_PK=B62qiWSQiF5Q9CsAHgjMHoEEyR2kJnnCvN9fxRps2NXULU15EeXbzPf

genesis_time=$(date -d '2019-01-30 20:00:00.000000Z' '+%s')
now_time=$(date +%s)

export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export CODA_PRIVKEY_PASS=""
export CODA_CONFIG_FILE=/tmp/config.json

exec $BIN daemon -seed -demo-mode -block-producer-key /tmp/keys/demo-block-producer -run-snark-worker $SNARK_PK -config-file /tmp/config.json -insecure-rest-server $@
