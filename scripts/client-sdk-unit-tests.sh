#!/bin/bash

set -eo pipefail

# run client SDK tests in node

export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH

echo "Building client SDK..."
source ~/.profile
make client_sdk

echo "Running tests"
nodejs src/app/client_sdk/tests/run_unit_tests.js

echo "SUCCESS"
