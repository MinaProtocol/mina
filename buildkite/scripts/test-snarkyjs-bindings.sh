#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
make snarkyjs

echo "Running SnarkyJS unit tests"
node --version
node src/lib/snarky_js_bindings/tests/run-tests.mjs

echo "Building MinaSigner"
make mina_signer

echo "Running MinaSigner unit tests"
npm --prefix=frontend/mina-signer test
