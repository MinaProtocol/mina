#!/bin/bash

# Writes the freshly-built application binaries to the CI cache PRESERVING their
# nested build-tree layout, under
#   build-tree/<codename>/<variant>/build-tree.tar.gz
# where <variant> identifies the build (network-profile[-instrumented][-arm64]).
#
# This differs from apps/write_to_cache.sh, which flattens every .exe into a
# single directory for bare-binary test consumers. The debian packaging step
# (scripts/debian/builder-helpers.sh) copies binaries from their exact dune
# paths (e.g. _build/default/src/app/cli/src/mina.exe), so once the debian build
# runs in a separate Buildkite job from the app build it needs the tree restored
# verbatim. This script captures exactly the build artifacts the packaging step
# consumes; every other file it copies (scripts, genesis_ledgers, rosetta
# configs, ...) is repo source present in any checkout.
#
# Captured artifacts:
#   - _build/default/**/*.exe   (dune binaries; *ppx.exe excluded)
#   - src/app/libp2p_helper/result/bin/libp2p_helper   (Go binary)
#   - src/app/minimina/target/release/minimina         (Rust binary)
#
# Usage: write_build_tree_to_cache.sh <codename> <variant>

set -eo pipefail

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" || -z "$VARIANT" ]]; then
  echo "Usage: $0 <codename> <variant>" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARBALL="${TMP_DIR}/build-tree.tar.gz"
FILE_LIST="${TMP_DIR}/files.txt"

# Collect the dune binaries, excluding the ppx driver exes (not shipped).
find _build/default -type f -name "*.exe" ! -name "*ppx.exe" > "$FILE_LIST"

# The libp2p_helper (Go) and minimina (Rust) binaries live outside _build but
# are required by the daemon and the minimina package respectively.
for extra in \
  "src/app/libp2p_helper/result/bin/libp2p_helper" \
  "src/app/minimina/target/release/minimina"; do
  if [[ -f "$extra" ]]; then
    echo "$extra" >> "$FILE_LIST"
  else
    echo "write_build_tree_to_cache: warning: $extra not found, skipping" >&2
  fi
done

echo "--- Packing $(wc -l < "$FILE_LIST") build artifacts into ${TARBALL}"
tar -czf "$TARBALL" -T "$FILE_LIST"

./buildkite/scripts/cache/manager.sh write-to-dir "$TARBALL" "build-tree/${CODENAME}/${VARIANT}"
