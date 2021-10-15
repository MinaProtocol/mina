#!/bin/bash

set -eo pipefail

# TODO: Should this be devnet or mainnet?
export DUNE_PROFILE=devnet

dune build --auto-promote @src/lib/snarky_js_bindings/output/node/build
dune build --auto-promote @src/lib/snarky_js_bindings/output/chrome/build

git diff --exit-code
