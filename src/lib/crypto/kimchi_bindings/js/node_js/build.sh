#!/usr/bin/env bash
set -euo pipefail

# When using nix this is already cached
if [[ -z "${PLONK_WASM_NODEJS-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    # The rust version should stay in line with the one in kimchi_bindings/wasm/rust-toolchain.toml
    # TODO: change out-dir to be relative to PWD when we upgrade to wasm-pack 0.13 (see https://github.com/rustwasm/wasm-pack/issues/704)
    rustup run 1.72 wasm-pack build --target nodejs --out-dir ../../kimchi_bindings/js/node_js ../../../proof-systems/plonk-wasm -- --features nodejs
else
    cp "$PLONK_WASM_NODEJS"/* -R .
fi
