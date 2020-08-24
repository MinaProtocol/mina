#!/bin/sh

set -e

# run client SDK tests in node

export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

echo "Building client SDK..."
make client_sdk
echo "Running tests"
nodejs src/app/client_sdk/tests/run_unit_tests.js

echo "SUCCESS"
