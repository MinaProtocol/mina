#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CURRENT_DIRECTORY="${SCRIPT_DIR}"
PROOF_SYSTEMS_ROOT=$(cd "${SCRIPT_DIR}/../../../proof-systems" && pwd)
PLONK_NAPI_ROOT="${PROOF_SYSTEMS_ROOT}/plonk-napi"

TARGET_ROOT="${CARGO_TARGET_DIR:-"${PROOF_SYSTEMS_ROOT}/target"}"
export CARGO_TARGET_DIR="${TARGET_ROOT}"

JS_BINDINGS_NAME="plonk_napi.js"
DTS_BINDINGS_NAME="plonk_napi.d.ts"

napi build \
    --platform \
    --js "${JS_BINDINGS_NAME}" \
    --dts "${DTS_BINDINGS_NAME}" \
    --manifest-path "${PLONK_NAPI_ROOT}/Cargo.toml" \
    --output-dir "${CURRENT_DIRECTORY}"

echo $CURRENT_DIRECTORY;
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

cp "${ARTIFACT}" "${CURRENT_DIRECTORY}/plonk_napi.node"
