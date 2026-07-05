#!/bin/bash

# Restores the nested build-tree tarball written by
# apps/write_build_tree_to_cache.sh into the current workspace, recreating the
# dune _build/default/... layout plus the libp2p_helper / minimina binaries at
# the exact paths scripts/debian/builder-helpers.sh copies from.
#
# Used by the debian packaging job, which runs on a separate Buildkite agent
# from the app build and therefore has no _build tree of its own.
#
# Usage: restore_build_tree.sh <codename> <variant>

set -eo pipefail

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" || -z "$VARIANT" ]]; then
  echo "Usage: $0 <codename> <variant>" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CACHE_PATH="build-tree/${CODENAME}/${VARIANT}/build-tree.tar.gz"

echo "--- Restoring build tree from ${CACHE_PATH}"
if ! ./buildkite/scripts/cache/manager.sh read "$CACHE_PATH" "$TMP_DIR"; then
  echo "restore_build_tree: ${CACHE_PATH} not found in cache" >&2
  exit 1
fi

# Tarball paths are workspace-relative (_build/default/..., src/app/...); unpack
# at the repo root so binaries land exactly where the packaging step expects.
tar -xzf "${TMP_DIR}/build-tree.tar.gz" -C .

echo "restore_build_tree: restored build tree for ${CODENAME}/${VARIANT}"
