#!/bin/sh

set -e

echo "Building heap usage app"
make heap_usage

echo "Running heap usage app"
./_build/default/src/app/heap_usage/heap_usage.exe
