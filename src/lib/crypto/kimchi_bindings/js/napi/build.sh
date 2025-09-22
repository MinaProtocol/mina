#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

# Optionally reuse a prebuilt addon by setting PLONK_NAPI_NODE to a dir or file
if [[ -n "${PLONK_NAPI_NODE-}" ]]; then
  if [[ -d "$PLONK_NAPI_NODE" ]]; then
    cp "$PLONK_NAPI_NODE"/plonk_napi.node "$CURRENT_DIRECTORY"/plonk_napi.node
  elif [[ -f "$PLONK_NAPI_NODE" ]]; then
    cp "$PLONK_NAPI_NODE" "$CURRENT_DIRECTORY"/plonk_napi.node
  else
    echo "PLONK_NAPI_NODE set but not a file/dir: $PLONK_NAPI_NODE" >&2
    exit 1
  fi
  exit 0
fi

PROOF_SYSTEMS_DIR=../../../proof-systems
pushd $PROOF_SYSTEMS_DIR/plonk-napi >/dev/null
cargo build --release -p plonk_napi

UNAME=$(uname -s)
if [[ "$UNAME" == "Darwin" ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/libplonk_napi.dylib
elif [[ "$UNAME" == "Linux" ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/libplonk_napi.so
elif [[ "$UNAME" == MINGW* || "$UNAME" == MSYS* || "$UNAME" == CYGWIN* ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/plonk_napi.dll
else
  echo "Unsupported OS: $UNAME" >&2
  exit 1
fi
popd >/dev/null

cp "$SRC" "$CURRENT_DIRECTORY"/plonk_napi.node
