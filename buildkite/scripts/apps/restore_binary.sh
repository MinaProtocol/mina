#!/bin/bash

# Restore a single freshly-built executable from the namespaced apps CI cache
# (written by buildkite/scripts/apps/write_to_cache.sh) into a local directory.
#
# Usage: restore_binary.sh <codename> <variant> <exe_name> <dest_dir>
#   <variant> is the build identity: network-profile[-instrumented][-arm64].
#
# On success prints the path to the restored, executable binary on stdout and
# exits 0. Exits non-zero if not in Buildkite context or the binary is absent,
# so callers can fall back to installing the debian package.

set -eo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <codename> <variant> <exe_name> <dest_dir>" >&2
  exit 1
fi

CODENAME=$1
VARIANT=$2
EXE=$3
DEST=$4

if [[ ! -v BUILDKITE_BUILD_ID ]]; then
  echo "restore_binary: not in Buildkite context" >&2
  exit 1
fi

mkdir -p "$DEST"

# Send the cache manager's own stdout to stderr so the only thing on our stdout
# is the resolved binary path.
if ! ./buildkite/scripts/cache/manager.sh read "apps/${CODENAME}/${VARIANT}/${EXE}" "$DEST" >&2; then
  echo "restore_binary: apps/${CODENAME}/${VARIANT}/${EXE} not found in cache" >&2
  exit 1
fi

chmod +x "${DEST}/${EXE}" 2>/dev/null || true
echo "${DEST}/${EXE}"
