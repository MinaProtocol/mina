#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PLONK_WASM_WEB-}" ]]; then
    export RUSTFLAGS="-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-arg=--no-check-features -C link-arg=--max-memory=4294967296"
    # FIXME: reintroduce --offline
    # The stdlib must be vendored
    # Hoping for now that wasm-pack uses Cargo.lock to get reproducible builds
    wasm-pack build --target web --out-dir ../js/web ../../wasm -- -Zbuild-std=std,panic_abort
else
    cp "$PLONK_WASM_WEB"/* -R .
fi
