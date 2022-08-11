#!/usr/bin/env bash
set -euo pipefail

if [[ "${PLONK_WASM_WEB-n}" == "n" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    rustup run nightly-2021-11-16 wasm-pack build --target web --out-dir ../js/chrome ../../wasm -- -Z build-std=panic_abort,std
else
    cp "$PLONK_WASM_WEB"/* -R .
fi
