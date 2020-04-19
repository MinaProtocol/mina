#!/bin/bash

set -e

genesis_constants_file=$(mktemp)

echo '{"txpool_max_size":3000,"genesis_state_timestamp":"'$(date '+%Y-%m-%d %H:%M:%S%z')'"}' > "$genesis_constants_file"

export CODA_PRIVKEY_PASS=""

exec coda daemon -seed -demo-mode -run-snark-worker 4vsRCVMNTrCx4NpN6kKTkFKLcFN4vXUP5RB9PqSZe1qsyDs4AW5XeNgAf16WUPRBCakaPiXcxjp6JUpGNQ6fdU977x5LntvxrSg11xrmK6ZDaGSMEGj12dkeEpyKcEpkzcKwYWZ2Yf2vpwQP -genesis-constants "$genesis_constants_file" -insecure-rest-server $@
