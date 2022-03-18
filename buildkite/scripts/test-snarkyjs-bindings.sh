#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
source ~/.profile
ulimit -s unlimited
touch src/lib/crypto/kimchi_bindings/js/node_js/node_backend.ml src/lib/crypto/kimchi_bindings/js/node_js/node_backend.mli
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js --profile=dev

echo "Running tests in Javascript"
node src/lib/snarky_js_bindings/tests/run-tests.mjs
