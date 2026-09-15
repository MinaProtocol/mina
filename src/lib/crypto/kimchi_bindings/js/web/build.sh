#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

if [[ -z "${KIMCHI_WASM_WEB-}" ]]; then
    KIMCHI_WASM_WEB_OUTDIR=${CURRENT_DIRECTORY} make -C ../../../proof-systems build-web
else
    cp "$KIMCHI_WASM_WEB"/* -R .
fi
