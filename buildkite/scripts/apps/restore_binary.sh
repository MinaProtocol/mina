#!/bin/bash

# Restore the freshly-built mina daemon binary for a network from the namespaced
# apps CI cache (written by buildkite/scripts/apps/write_to_cache.sh) and install
# it as `mina` on PATH -- mirroring the .deb -- so callers invoke `mina`
# identically whether it came from the cache or a package.
#
# Usage: restore_binary.sh <network>      (network: devnet | mainnet | mesa)
#
# The cache location is derived from the build identity, so callers don't repeat
# the variant string:
#   apps/<codename>/<network>-<profile>[-instrumented][-arm64]/mina_<sig>_signatures.exe
# with
#   codename : $MINA_DEB_CODENAME (default bullseye)
#   profile  : $APPS_PROFILE      (default: devnet/mesa -> devnet, mainnet -> mainnet)
#   flag     : $APPS_BUILD_FLAG   ("instrumented" appends -instrumented; default none)
#   arch     : $APPS_ARCH         ("arm64" appends -arm64; default amd64)
#   sig      : devnet/mesa -> testnet, mainnet -> mainnet
# The signature-specific binary is installed as plain `mina`, so client scripts
# never deal with the variant or the signature name.
#
# Installs to ${MINA_BIN_DIR:-/usr/local/bin}/mina (using sudo when not root).
# Exits non-zero without side effects if not in Buildkite context or the binary
# is not cached, so callers can fall back to installing the .deb.

set -eo pipefail

NETWORK=$1

if [[ -z "$NETWORK" ]]; then
  echo "Usage: $0 <network>" >&2
  exit 1
fi

if [[ ! -v BUILDKITE_BUILD_ID ]]; then
  echo "restore_binary: not in Buildkite context" >&2
  exit 1
fi

case "$NETWORK" in
  devnet | mesa) sig=testnet ; default_profile=devnet ;;
  mainnet) sig=mainnet ; default_profile=mainnet ;;
  *)
    echo "restore_binary: unknown network '$NETWORK'" >&2
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
EXE="mina_${sig}_signatures.exe"
BIN_DIR="${MINA_BIN_DIR:-/usr/local/bin}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! ./buildkite/scripts/cache/manager.sh read "apps/${CODENAME}/${VARIANT}/${EXE}" "$TMP_DIR" >&2; then
  echo "restore_binary: apps/${CODENAME}/${VARIANT}/${EXE} not found in cache" >&2
  exit 1
fi

$SUDO install -D -m 0755 "${TMP_DIR}/${EXE}" "${BIN_DIR}/mina"
echo "restore_binary: installed ${EXE} as ${BIN_DIR}/mina" >&2
