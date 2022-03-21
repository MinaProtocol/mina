#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
dune b src/lib/crypto/kimchi_bindings/js/node_js --profile=dev
dune b src/lib/snarky_js_bindings/lib --profile=dev
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js --profile=dev

echo "Running tests in Javascript"
node --version
node --experimental-wasm-threads src/lib/snarky_js_bindings/tests/run-tests.mjs
