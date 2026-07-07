#!/bin/bash

# Reconstructs the nested dune build tree in the current workspace from the flat
# apps cache, using the manifest published by
# apps/write_build_manifest_to_cache.sh. No separate copy of the binaries is
# stored anywhere: the binaries come from the same flat apps cache the
# bare-binary tests use, and the manifest only supplies their paths.
#
# Used by the debian packaging job (a separate agent from the app build), so
# scripts/debian/builder-helpers.sh finds each binary at the dune path it
# copies from.
#
# Usage: restore_build_tree.sh <codename> <apps-variant> <build-variant>
#   apps-variant  : the apps-cache variant to pull binaries from (any network's
#                   variant works -- write_to_cache.sh flattens every binary
#                   into each one; the caller passes the build's primary net).
#   build-variant : the manifest variant (network-agnostic build identity).

set -eo pipefail

CODENAME=$1
APPS_VARIANT=$2
BUILD_VARIANT=$3

if [[ -z "$CODENAME" || -z "$APPS_VARIANT" || -z "$BUILD_VARIANT" ]]; then
  echo "Usage: $0 <codename> <apps-variant> <build-variant>" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "--- Restoring build manifest for ${CODENAME}/${BUILD_VARIANT}"
if ! ./buildkite/scripts/cache/manager.sh read \
  "build-manifest/${CODENAME}/${BUILD_VARIANT}/build-manifest.txt" "$TMP_DIR"; then
  echo "restore_build_tree: manifest for ${CODENAME}/${BUILD_VARIANT} not found in cache" >&2
  exit 1
fi

count=0
while IFS= read -r relpath; do
  [[ -z "$relpath" ]] && continue
  base="$(basename "$relpath")"
  fetch_dir="${TMP_DIR}/fetch"
  mkdir -p "$fetch_dir"
  if ! ./buildkite/scripts/cache/manager.sh read \
    "apps/${CODENAME}/${APPS_VARIANT}/${base}" "$fetch_dir" >/dev/null; then
    echo "restore_build_tree: ${base} not found in apps/${CODENAME}/${APPS_VARIANT}" >&2
    exit 1
  fi
  install -D -m 0755 "${fetch_dir}/${base}" "$relpath"
  rm -rf "$fetch_dir"
  count=$((count + 1))
done < "${TMP_DIR}/build-manifest.txt"

echo "restore_build_tree: restored ${count} binaries into the build tree"
