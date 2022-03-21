#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Building SnarkyJS.."
cat ~/.profile
source ~/.profile
ulimit -s unlimited
#touch src/lib/crypto/kimchi_bindings/js/node_js/node_backend.ml src/lib/crypto/kimchi_bindings/js/node_js/node_backend.mli
dune b --build-info
dune b src/lib/crypto/kimchi_bindings/stubs/kimchi.ml --profile=dev --verbose
dune b src/lib/crypto/kimchi_bindings/js/node_js --profile=dev --verbose
dune b src/lib/snarky_js_bindings/lib --profile=dev --verbose
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js --profile=dev --verbose

echo "Running tests in Javascript"
node src/lib/snarky_js_bindings/tests/run-tests.mjs
