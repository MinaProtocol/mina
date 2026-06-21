#!/bin/bash

# Restore a single freshly-built application binary from the namespaced apps CI
# cache (written by buildkite/scripts/apps/write_to_cache.sh) and install it on
# PATH under a chosen name -- mirroring the layout a .deb would provide, so
# callers invoke the tool identically whether it came from the cache or a
# package.
#
# Usage: restore_app.sh <network> <exe> <install-as>
#   network    : devnet | mainnet | mesa  (selects the default build profile)
#   exe        : the .exe filename in the cache, e.g. runtime_genesis_ledger.exe
#   install-as : the name to install it under on PATH, e.g. mina-create-genesis
#
# The cache location is derived from the build identity, so callers don't repeat
# the variant string:
#   apps/<codename>/<network>-<profile>[-instrumented][-arm64]/<exe>
# with
#   codename : $MINA_DEB_CODENAME (default bullseye)
#   profile  : $APPS_PROFILE      (default: devnet/mesa -> devnet, mainnet -> mainnet)
#   flag     : $APPS_BUILD_FLAG   ("instrumented" appends -instrumented; default none)
#   arch     : $APPS_ARCH         ("arm64" appends -arm64; default amd64)
#
# Installs to ${MINA_BIN_DIR:-/usr/local/bin}/<install-as> (using sudo when not
# root). Exits non-zero without side effects if not in Buildkite context or the
# binary is not cached, so callers can fall back to installing the .deb.

set -eo pipefail

NETWORK=$1
EXE=$2
INSTALL_AS=$3

if [[ -z "$NETWORK" || -z "$EXE" || -z "$INSTALL_AS" ]]; then
  echo "Usage: $0 <network> <exe> <install-as>" >&2
  exit 1
fi

if [[ ! -v BUILDKITE_BUILD_ID ]]; then
  echo "restore_app: not in Buildkite context" >&2
  exit 1
fi

case "$NETWORK" in
  devnet | mesa) default_profile=devnet ;;
  mainnet) default_profile=mainnet ;;
  *)
    echo "restore_app: unknown network '$NETWORK'" >&2
    exit 1
    ;;
esac

CODENAME="${MINA_DEB_CODENAME:-bullseye}"
PROFILE="${APPS_PROFILE:-$default_profile}"

flag_seg=""
[[ "${APPS_BUILD_FLAG:-}" == "instrumented" ]] && flag_seg="-instrumented"
arch_seg=""
[[ "${APPS_ARCH:-amd64}" == "arm64" ]] && arch_seg="-arm64"

VARIANT="${NETWORK}-${PROFILE}${flag_seg}${arch_seg}"
BIN_DIR="${MINA_BIN_DIR:-/usr/local/bin}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! ./buildkite/scripts/cache/manager.sh read "apps/${CODENAME}/${VARIANT}/${EXE}" "$TMP_DIR" >&2; then
  echo "restore_app: apps/${CODENAME}/${VARIANT}/${EXE} not found in cache" >&2
  exit 1
fi

$SUDO install -D -m 0755 "${TMP_DIR}/${EXE}" "${BIN_DIR}/${INSTALL_AS}"
echo "restore_app: installed ${EXE} as ${BIN_DIR}/${INSTALL_AS}" >&2
