#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
ulimit -s unlimited
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js --profile=dev

echo "Running tests in Javascript"
node src/lib/snarky_js_bindings/tests/run-tests.mjs
