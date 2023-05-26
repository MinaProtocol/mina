#!/bin/bash

export NODE_OPTIONS="--enable-source-maps --stack-trace-limit=1000"

set -eo pipefail
source ~/.profile

echo "Node version:"
node --version

echo "Build SnarkyJS..."
make snarkyjs

echo "Run SnarkyJS unit tests..."
cd src/lib/snarkyjs
npm run test:unit

echo "Run additional SnarkyJS tests..."
./run-mina-integration-tests.sh
