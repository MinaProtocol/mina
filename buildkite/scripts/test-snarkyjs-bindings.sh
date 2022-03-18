#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js || dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js

echo "Running tests in Javascript"
node src/lib/snarky_js_bindings/tests/run-tests.mjs
