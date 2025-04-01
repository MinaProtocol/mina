#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

if [[ -z "${PLONK_WASM_NODEJS-}" ]]; then
    PLONK_WASM_NODEJS_OUTDIR=${CURRENT_DIRECTORY} make -C ../../../proof-systems build-nodejs
else
    cp "$PLONK_WASM_NODEJS"/* -R .
fi
