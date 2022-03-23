#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
make snarkyjs

echo "Running tests in Javascript"
node --version
node src/lib/snarky_js_bindings/tests/run-tests.mjs
