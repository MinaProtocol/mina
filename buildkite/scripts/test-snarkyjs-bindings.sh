#!/bin/bash

export NODE_OPTIONS="--enable-source-maps --stack-trace-limit=1000"

set -eo pipefail
source ~/.profile

echo "Node version:"
node --version

echo "Build SnarkyJS..."
make snarkyjs

echo "Run SnarkyJS bindings unit tests..."
node src/lib/snarky_js_bindings/tests/run-tests.mjs

echo "Run SnarkyJS unit tests..."
cd src/lib/snarky_js_bindings/snarkyjs
npm run test:unit
cd ../../../..

echo "Build MinaSigner..."
make mina_signer

echo "Run MinaSigner unit tests..."
npm --prefix=frontend/mina-signer test

echo "Prepare SnarkyJS + MinaSigner tests..."
cd src/lib/snarky_js_bindings/test_module
npm i
cd ../../../..

echo "Run SnarkyJS + MinaSigner tests..."
node src/lib/snarky_js_bindings/test_module/simple-zkapp-mina-signer.js
node src/lib/snarky_js_bindings/test_module/simple-zkapp-mock-apply.js
node src/lib/snarky_js_bindings/test_module/inductive-proofs.js
