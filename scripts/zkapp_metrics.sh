#!/bin/sh

set -e

echo "Building heap usage app"
make heap_usage

# Looking at CI, this is built via the devnet profile
echo "Running heap usage app"
./_build/default/src/app/heap_usage/heap_usage.exe --config-file ./genesis_ledgers/devnet.json


echo "Building zkapp limits app"
make zkapp_limits

# Looking at CI, this is built via the devnet profile
echo "Running zkapp limits app"
./_build/default/src/app/zkapp_limits/zkapp_limits.exe --config-file ./genesis_ledgers/devnet.json