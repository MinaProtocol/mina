#!/usr/bin/env bash
set -euo pipefail

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
    --output-dir ./ \
    --release \
    --esm
