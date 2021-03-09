#!/bin/bash

set -e

genesis_time=$(date -d "$(mina advanced compile-time-constants | jq -r '.genesis_state_timestamp')" +%s)
now_time=$(date +%s)

export CODA_TIME_OFFSET=0
export CODA_PRIVKEY_PASS=""
export CODA_CONFIG_FILE=/config.json

exec mina daemon --generate-genesis-proof true --seed --demo-mode --block-producer-key /root/keys/demo-block-producer --run-snark-worker $(cat /root/keys/demo-block-producer.pub) -insecure-rest-server $@
