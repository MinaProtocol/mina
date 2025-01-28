#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_NODEJS-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    wasm-pack build --target nodejs --out-dir ../js/node_js ../../wasm -- -Zbuild-std=std,panic_abort --features nodejs --offline
else
    cp "$PLONK_WASM_NODEJS"/* -R .
fi
