#!/bin/sh

set -e

echo "Building heap usage app"
make heap_usage

echo "Running heap usage app"
./_build/default/src/app/heap_usage/heap_usage.exe


echo "Building zkapp limits app"
make zkapp_limits

echo "Running heap usage app"
./_build/default/src/app/zkapp_limits/zkapp_limits.exe