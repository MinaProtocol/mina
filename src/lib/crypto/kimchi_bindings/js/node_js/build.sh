#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_NODEJS-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    rustup run nightly-2022-09-12 wasm-pack build --target nodejs --out-dir ../js/node_js ../../wasm -- -Z build-std=panic_abort,std --features nodejs
else
    cp "$PLONK_WASM_NODEJS"/* -R .
fi
