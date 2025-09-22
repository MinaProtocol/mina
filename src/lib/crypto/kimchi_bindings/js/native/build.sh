#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)
PROOF_SYSTEMS_ROOT=$(cd ../../../proof-systems && pwd)

cargo build \
    --manifest-path "${PROOF_SYSTEMS_ROOT}/Cargo.toml" \
    --release \
    -p plonk-napi

TARGET_ROOT=${CARGO_TARGET_DIR:-"${PROOF_SYSTEMS_ROOT}/target"}

case "$(uname -s)" in
    Darwin*) LIB_NAME="libplonk_napi.dylib" ;;
    MINGW*|MSYS*|CYGWIN*) LIB_NAME="plonk_napi.dll" ;;
    *) LIB_NAME="libplonk_napi.so" ;;
 esac

ARTIFACT="${TARGET_ROOT}/release/${LIB_NAME}"

if [[ ! -f "${ARTIFACT}" ]]; then
    echo "Failed to locate plonk-napi artifact at ${ARTIFACT}" >&2
    exit 1
fi

rm -f "${CURRENT_DIRECTORY}/plonk_napi.node"
cp "${ARTIFACT}" "${CURRENT_DIRECTORY}/plonk_napi.node"
