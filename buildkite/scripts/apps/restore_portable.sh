#!/bin/bash

# Restores the portable bundle published by apps/write_portable_to_cache.sh into
# the current workspace, for a docker or debian job running on a different agent
# than the build.
#
# Usage: restore_portable.sh <codename> [<variant>]
#   codename : the Debian codename the bundle was built on
#   variant  : the apps-cache variant, empty for a standard amd64 build
#
# Unpacks to $MINA_PORTABLE_ROOT (default _build_portable) in the current
# directory, replacing anything already there.
#
# A missing cache entry is a HARD failure. This is a consumer of the app build:
# if the bundle is absent, either the build job did not run for this variant or
# it did not have MINA_BUILD_PORTABLE set, and continuing would produce an
# artifact silently missing the very thing it is supposed to ship.

set -eo pipefail

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" ]]; then
  echo "Usage: $0 <codename> [<variant>]" >&2
  exit 1
fi

SRC_DIR="portable/${CODENAME}${VARIANT:+/${VARIANT}}"
TARBALL="mina-portable.tar.gz"
PORTABLE_ROOT="${MINA_PORTABLE_ROOT:-_build_portable}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "--- Restoring portable bundle from ${SRC_DIR}"
if ! ./buildkite/scripts/cache/manager.sh read "${SRC_DIR}/${TARBALL}" "$TMP_DIR"; then
  echo "restore_portable: ${SRC_DIR}/${TARBALL} not found in cache" >&2
  echo "restore_portable: the app-build job for ${CODENAME} must run with" >&2
  echo "  MINA_BUILD_PORTABLE=1 and publish the bundle BEFORE this job." >&2
  echo "  See buildkite/scripts/apps/write_portable_to_cache.sh." >&2
  exit 1
fi

rm -rf "$PORTABLE_ROOT"
# The tarball carries its own top-level directory name, which is not necessarily
# the name we want here, so unpack to a staging dir and move the single entry.
STAGE="${TMP_DIR}/stage"
mkdir -p "$STAGE"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "$STAGE"

unpacked="$(find "$STAGE" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [[ -z "$unpacked" ]]; then
  echo "restore_portable: tarball contained no directory" >&2
  exit 1
fi
mv "$unpacked" "$PORTABLE_ROOT"

loader_count=$(find "${PORTABLE_ROOT}/lib" -maxdepth 1 -name 'ld-linux*.so*' 2>/dev/null | wc -l)
if [[ "$loader_count" -eq 0 ]]; then
  echo "restore_portable: the bundle has no dynamic loader in lib/" >&2
  echo "  Its wrappers cannot run without one; refusing a broken bundle." >&2
  exit 1
fi

echo "restore_portable: restored $(find "${PORTABLE_ROOT}/bin" -type f 2>/dev/null | wc -l) wrappers, \
$(find "${PORTABLE_ROOT}/lib" -type f 2>/dev/null | wc -l) libraries into ${PORTABLE_ROOT}"
