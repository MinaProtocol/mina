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
# Usage: APPS_VARIANT=<variant> restore_build_tree.sh <codename> <build-variant>
#   APPS_VARIANT  : the apps-cache variant to pull binaries from, empty for the
#                   default (standard amd64) build -- see apps/write_to_cache.sh.
#   build-variant : the manifest variant (the same build identity, prefixed with
#                   the codename).

set -eo pipefail

CODENAME=$1
BUILD_VARIANT=$2

if [[ -z "$CODENAME" || -z "$BUILD_VARIANT" ]]; then
  echo "Usage: APPS_VARIANT=<variant> $0 <codename> <build-variant>" >&2
  exit 1
fi

APPS_DIR="apps/${CODENAME}${APPS_VARIANT:+/${APPS_VARIANT}}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# A missing cache entry is a HARD failure, never a fallback to building from
# source. Packaging is a consumer of the app build: if the binaries are not
# there, the app-build job did not run (or did not run for this variant), and
# silently recompiling here would hide that the pipeline is wired wrong.
fail_missing() {
  echo "restore_build_tree: $1" >&2
  echo "restore_build_tree: the app-build job for ${CODENAME} must run and write" >&2
  echo "  the apps cache BEFORE this packaging job. Expected binaries in" >&2
  echo "  ${APPS_DIR}/ and the manifest in" >&2
  echo "  build-manifest/${CODENAME}/${BUILD_VARIANT}/build-manifest.txt" >&2
  echo "  (written by buildkite/scripts/apps/write_to_cache.sh and" >&2
  echo "  buildkite/scripts/apps/write_build_manifest_to_cache.sh)." >&2
  exit 1
}

echo "--- Restoring build manifest for ${CODENAME}/${BUILD_VARIANT}"
if ! ./buildkite/scripts/cache/manager.sh read \
  "build-manifest/${CODENAME}/${BUILD_VARIANT}/build-manifest.txt" "$TMP_DIR"; then
  fail_missing "manifest for ${CODENAME}/${BUILD_VARIANT} not found in cache"
fi

count=0
while IFS= read -r relpath; do
  [[ -z "$relpath" ]] && continue
  base="$(basename "$relpath")"
  fetch_dir="${TMP_DIR}/fetch"
  mkdir -p "$fetch_dir"
  if ! ./buildkite/scripts/cache/manager.sh read \
    "${APPS_DIR}/${base}" "$fetch_dir" >/dev/null; then
    fail_missing "${base} not found in ${APPS_DIR}"
  fi
  install -D -m 0755 "${fetch_dir}/${base}" "$relpath"
  rm -rf "$fetch_dir"
  count=$((count + 1))
done < "${TMP_DIR}/build-manifest.txt"

echo "restore_build_tree: restored ${count} binaries into the build tree"
