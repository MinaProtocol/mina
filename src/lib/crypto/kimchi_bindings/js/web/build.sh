#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

if [[ -z "${PLONK_WASM_WEB-}" ]]; then
    PLONK_WASM_WEB_OUTDIR=${CURRENT_DIRECTORY} make -C ../../../proof-systems build-web
else
    cp "$PLONK_WASM_WEB"/* -R .
fi
