#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_WEB-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    # The version should stay in line with the one in kimchi/wasm/rust-toolchain.toml
    rustup run nightly-2023-09-01 wasm-pack build --target web --out-dir ../js/web ../../wasm -- -Z build-std=panic_abort,std
else
    cp "$PLONK_WASM_WEB"/* -R .
fi
