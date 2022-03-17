#!/bin/bash

set -eo pipefail

# run snarkyjs tests in node

echo "Installing Rust dependencies..."
rustup toolchain install nightly-2021-11-16
rustup component add rust-src --toolchain nightly-2021-11-16

echo "Building SnarkyJS.."
source ~/.profile
dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js
echo "Running tests in Javascript"
node src/lib/snarky_js_bindings/tests/run-tests.mjs
