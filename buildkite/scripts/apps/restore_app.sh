#!/bin/bash

# Restore a single freshly-built application binary from the namespaced apps CI
# cache (written by buildkite/scripts/apps/write_to_cache.sh) and install it on
# PATH under a chosen name -- mirroring the layout a .deb would provide, so
# callers invoke the tool identically whether it came from the cache or a
# package.
#
# Usage: restore_app.sh <exe> <install-as>
#   exe        : the .exe filename in the cache, e.g. runtime_genesis_ledger.exe
#   install-as : the name to install it under on PATH, e.g. mina-create-genesis
#
# The cache location is derived from the build identity, so callers don't repeat
# the variant string:
#   apps/<codename>[/<variant>]/<exe>
# with
#   codename : $MINA_DEB_CODENAME (default noble)
#   variant  : derived from $APPS_BUILD_FLAG ("instrumented") and $APPS_ARCH
#              ("arm64"). It names only what deviates from the default build, so
#              a standard amd64 build has NO variant segment and its binaries sit
#              directly in apps/<codename>/.
#
# There is deliberately no network or profile in the path. The daemon binary the
# cache holds is src/app/cli/src/mina.exe, which links no mina_signature_kind
# library (see src/app/cli/src/dune) -- signature kind and proof level are
# resolved at runtime from the config, so one binary serves every network and
# profile. Only the compile-time flags (instrumentation) and the target
# architecture actually change the bytes.
#
# Installs to ${MINA_BIN_DIR:-/usr/local/bin}/<install-as> (using sudo when not
# root). Exits non-zero without side effects if not in Buildkite context or the
# binary is not cached, so callers can fall back to installing the .deb.

set -eo pipefail

EXE=$1
INSTALL_AS=$2

if [[ -z "$EXE" || -z "$INSTALL_AS" ]]; then
  echo "Usage: $0 <exe> <install-as>" >&2
  exit 1
fi

if [[ ! -v BUILDKITE_BUILD_ID ]]; then
  echo "restore_app: not in Buildkite context" >&2
  exit 1
fi

CODENAME="${MINA_DEB_CODENAME:-noble}"

segments=()
[[ "${APPS_BUILD_FLAG:-}" == "instrumented" ]] && segments+=("instrumented")
[[ "${APPS_ARCH:-amd64}" == "arm64" ]] && segments+=("arm64")
VARIANT=$(IFS=-; echo "${segments[*]}")

SRC="apps/${CODENAME}${VARIANT:+/${VARIANT}}/${EXE}"
BIN_DIR="${MINA_BIN_DIR:-/usr/local/bin}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! ./buildkite/scripts/cache/manager.sh read "$SRC" "$TMP_DIR" >&2; then
  echo "restore_app: ${SRC} not found in cache" >&2
  exit 1
fi

$SUDO install -D -m 0755 "${TMP_DIR}/${EXE}" "${BIN_DIR}/${INSTALL_AS}"
echo "restore_app: installed ${EXE} as ${BIN_DIR}/${INSTALL_AS}" >&2
