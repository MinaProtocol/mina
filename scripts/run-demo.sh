#!/bin/bash

set -e

genesis_time=$(date -d "$(mina advanced compile-time-constants | jq -r '.genesis_state_timestamp')" +%s)
now_time=$(date +%s)

export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export MINA_PRIVKEY_PASS=""
export CODA_CONFIG_FILE=/config.json

exec mina daemon -seed -demo-mode -block-producer-key /root/keys/demo-block-producer -run-snark-worker B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g -insecure-rest-server $@
