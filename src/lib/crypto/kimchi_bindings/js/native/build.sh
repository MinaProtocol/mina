#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CURRENT_DIRECTORY="${SCRIPT_DIR}"
PROOF_SYSTEMS_ROOT=$(cd "${SCRIPT_DIR}/../../../proof-systems" && pwd)

napi build \
    --manifest-path $PROOF_SYSTEMS_ROOT/Cargo.toml \
    --package kimchi-napi \
    --output-dir ./ \
    --release \
    --esm