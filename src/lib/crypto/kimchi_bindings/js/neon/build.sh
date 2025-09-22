#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIRECTORY=$(pwd)

# Option 1: use a prebuilt addon (CI or local)
# - Set PLONK_NEON_NODE to a DIR containing plonk_neon.node, or to the FILE itself.
if [[ -n "${PLONK_NEON_NODE-}" ]]; then
  if [[ -d "$PLONK_NEON_NODE" ]]; then
    cp "$PLONK_NEON_NODE"/plonk_neon.node "$CURRENT_DIRECTORY"/plonk_neon.node
  elif [[ -f "$PLONK_NEON_NODE" ]]; then
    cp "$PLONK_NEON_NODE" "$CURRENT_DIRECTORY"/plonk_neon.node
  else
    echo "PLONK_NEON_NODE set but not a file/dir: $PLONK_NEON_NODE" >&2
    exit 1
  fi
  exit 0
fi

# Otherwise, build it from the proof-systems submodule.
PROOF_SYSTEMS_DIR=../../../proof-systems
pushd $PROOF_SYSTEMS_DIR/plonk-neon >/dev/null
cargo build --release -p plonk_neon

# Map OS -> artifact; rename to .node
UNAME=$(uname -s)
if [[ "$UNAME" == "Darwin" ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/libplonk_neon.dylib
elif [[ "$UNAME" == "Linux" ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/libplonk_neon.so
elif [[ "$UNAME" == MINGW* || "$UNAME" == MSYS* || "$UNAME" == CYGWIN* ]]; then
  SRC=$PROOF_SYSTEMS_DIR/target/release/plonk_neon.dll
else
  echo "Unsupported OS: $UNAME" >&2
  exit 1
fi
popd >/dev/null

cp "$SRC" "$CURRENT_DIRECTORY"/plonk_neon.node
