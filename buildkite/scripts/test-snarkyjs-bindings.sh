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
cd ../../../..

echo "Run additional SnarkyJS tests..."
node src/lib/snarkyjs/tests/integration/simple-zkapp-mock-apply.js
node src/lib/snarkyjs/tests/integration/inductive-proofs.js
