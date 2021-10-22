#!/bin/bash

set -eo pipefail

# TODO: Should this be devnet or mainnet?
export DUNE_PROFILE=devnet

# Hack: if we don't do this, the snarkyjs bindings will always be out of date,
# because they contain the commit number of the commit while they were being
# built, but the current commit is later!
# NOTE: This isn't a 'reset --hard' because we don't want to modify the
# contents of the index!!
git reset $(git log -n 1 --pretty=format:%H -- src/lib/snarky_js_bindings/output/)

dune build --auto-promote @src/lib/snarky_js_bindings/output/node/build
dune build --auto-promote @src/lib/snarky_js_bindings/output/chrome/build

git diff --exit-code -- src/lib/snarky_js_bindings/output
