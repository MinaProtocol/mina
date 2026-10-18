#!/bin/bash

# Installs the coinbase rosetta-cli binary (with mina's stake-delegation patch)
# into /usr/local/bin/rosetta-cli on the host. Mirrors the install steps from
# dockerfiles/stages/rosetta/1-base-deps.
#
# Sources, in order:
#   1. an already installed rosetta-cli (no-op),
#   2. the CI cache: ${CI_CACHE_MOUNT}/tool-cache/rosetta-cli/<key>/rosetta-cli,
#   3. a build from the GitHub sources, whose result is then stored in the
#      CI cache for the next run.
#
# The cache keeps GitHub off the critical path: the fetch of the mesh-cli
# tarball from codeload.github.com is reset or stalls from the CI agents in
# episodes, and every run used to download it anew.

set -euo pipefail

ROSETTA_CLI_VERSION="${ROSETTA_CLI_VERSION:-v0.10.1}"
GO_VERSION="${GO_VERSION:-1.19.11}"
SDK_REPLACEMENT_TAG="${SDK_REPLACEMENT_TAG:-stake-delegation-v1}"
CI_CACHE_MOUNT="${CI_CACHE_MOUNT:-/var/storagebox}"
ROSETTA_CLI_CACHE_ROOT="${ROSETTA_CLI_CACHE_ROOT:-${CI_CACHE_MOUNT}/tool-cache/rosetta-cli}"
ROSETTA_CLI_INSTALL_PATH="${ROSETTA_CLI_INSTALL_PATH:-/usr/local/bin/rosetta-cli}"
SUDO="${SUDO-sudo}"
GO="${GO:-/usr/lib/go/bin/go}"

# Retry on every error, not only on timeouts and 5xx: the failure seen in CI is
# a connection reset during the TLS handshake (curl exit 35), which a plain
# --retry does not cover.
CURL=(curl -fsSL --retry 5 --retry-all-errors --retry-delay 15)

if command -v rosetta-cli >/dev/null 2>&1; then
  echo "rosetta-cli already installed: $(rosetta-cli version 2>&1 | head -1 || true)"
  exit 0
fi

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in amd64|arm64) ;; *) echo "Unsupported arch: $ARCH"; exit 1;; esac

CACHE_KEY="${ROSETTA_CLI_VERSION}-${SDK_REPLACEMENT_TAG}-${ARCH}"
CACHED="${ROSETTA_CLI_CACHE_ROOT}/${CACHE_KEY}/rosetta-cli"

if [ -f "$CACHED" ]; then
  $SUDO install -m 0755 "$CACHED" "$ROSETTA_CLI_INSTALL_PATH"
  echo "Installed rosetta-cli from CI cache: $CACHED"
  exit 0
fi
echo "rosetta-cli not in CI cache ($CACHED), building from sources"

if [ ! -x "$GO" ]; then
  echo "Installing go ${GO_VERSION}"
  "${CURL[@]}" "https://dl.google.com/go/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | $SUDO tar -xz -C /usr/lib/
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

"${CURL[@]}" "https://github.com/coinbase/mesh-cli/archive/refs/tags/${ROSETTA_CLI_VERSION}.tar.gz" \
  -o "${WORK}/mesh-cli.tar.gz"
tar -xzf "${WORK}/mesh-cli.tar.gz" -C "${WORK}"

cd "${WORK}/mesh-cli-${ROSETTA_CLI_VERSION#v}"
GOBIN="${WORK}/bin"
export GOBIN
mkdir -p "$GOBIN"

"$GO" mod edit -replace \
  "github.com/coinbase/rosetta-sdk-go@v0.8.1=github.com/MinaProtocol/rosetta-sdk-go@${SDK_REPLACEMENT_TAG}"
"$GO" mod tidy
"$GO" install

$SUDO install -m 0755 "${GOBIN}/rosetta-cli" "$ROSETTA_CLI_INSTALL_PATH"
echo "Installed rosetta-cli to $ROSETTA_CLI_INSTALL_PATH"

# Store for the next run. Write next to the final path and rename, so a reader
# never sees a partial file. A cache write failure must not fail the test.
if [ -d "$CI_CACHE_MOUNT" ]; then
  if mkdir -p "$(dirname "$CACHED")" \
     && tmp="$(mktemp "${CACHED}.new.XXXXXX")" \
     && cp "${GOBIN}/rosetta-cli" "$tmp" \
     && mv -f "$tmp" "$CACHED"; then
    echo "Stored rosetta-cli in CI cache: $CACHED"
  else
    echo "WARNING: could not store rosetta-cli in CI cache at $CACHED"
    rm -f "${tmp:-}"
  fi
else
  echo "CI cache not mounted, rosetta-cli not stored"
fi
