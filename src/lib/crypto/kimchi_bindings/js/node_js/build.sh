#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_NODEJS-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    # The version should stay in line with the one in kimchi_bindings/wasm/rust-toolchain.toml
    rustup run nightly-2024-06-13 wasm-pack build --target nodejs --out-dir ../js/node_js ../../wasm -- -Z build-std=panic_abort,std --features nodejs
else
    cp "$PLONK_WASM_NODEJS"/* -R .
fi
