#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_WEB-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    wasm-pack build --target web --out-dir ../js/web ../../wasm -- --offline
else
    cp "$PLONK_WASM_WEB"/* -R .
fi
