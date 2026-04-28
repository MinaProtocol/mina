#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

if [[ -z "${KIMCHI_WASM_NODEJS-}" ]]; then
    KIMCHI_WASM_NODEJS_OUTDIR=${CURRENT_DIRECTORY} make -C ../../../proof-systems build-nodejs
else
    cp "$KIMCHI_WASM_NODEJS"/* -R .
fi
