#!/usr/bin/env bash
set -euo pipefail

# Builds the wasm32-wasip1-threads target of kimchi-napi — the same crate that
# build.sh compiles to a native .node — producing a wasm binary plus generated
# Node/browser loaders backed by @napi-rs/wasm-runtime.
#
# Requires the `wasm32-wasip1-threads` rust target:
#   rustup target add wasm32-wasip1-threads

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CURRENT_DIRECTORY="${SCRIPT_DIR}"
PROOF_SYSTEMS_ROOT=$(cd "${SCRIPT_DIR}/../../../proof-systems" && pwd)

# In Nix sandboxes HOME is often /homeless-shelter (not writable).
# Ensure cargo git checkouts and index/cache writes go to a writable directory.
export CARGO_HOME="${CARGO_HOME:-$CURRENT_DIRECTORY/.cargo}"
mkdir -p "$CARGO_HOME"
if [ ! -w "${HOME:-}" ]; then
    export HOME="$CURRENT_DIRECTORY"
fi

napi build \
    --manifest-path $PROOF_SYSTEMS_ROOT/Cargo.toml \
    --package kimchi-napi \
    --target wasm32-wasip1-threads \
    --output-dir ./artifacts-wasm \
    --release \
    --platform
