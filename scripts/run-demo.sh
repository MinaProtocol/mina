#!/bin/bash

set -e

genesis_time=$(date -d "$(coda advanced compile-time-constants | jq -r '.genesis_state_timestamp')" +%s)
now_time=$(date +%s)

export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export CODA_PRIVKEY_PASS=""
export CODA_CONFIG_FILE=/config.json

exec coda daemon -seed -demo-mode -block-producer-key /root/keys/demo-block-producer -run-snark-worker 4vsRCVMNTrCx4NpN6kKTkFKLcFN4vXUP5RB9PqSZe1qsyDs4AW5XeNgAf16WUPRBCakaPiXcxjp6JUpGNQ6fdU977x5LntvxrSg11xrmK6ZDaGSMEGj12dkeEpyKcEpkzcKwYWZ2Yf2vpwQP -insecure-rest-server $@
