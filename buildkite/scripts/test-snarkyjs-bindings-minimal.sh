#!/bin/bash

export NODE_OPTIONS="--enable-source-maps --stack-trace-limit=1000"

set -eo pipefail
source ~/.profile

echo "Node version:"
node --version

echo "Build SnarkyJS (w/o TS)..."
make snarkyjs_no_types

echo "Run bare minimum SnarkyJS tests..."
./run-mina-integration-tests.sh
