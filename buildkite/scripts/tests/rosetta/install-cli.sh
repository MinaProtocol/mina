#!/bin/bash

# Installs the coinbase rosetta-cli binary (with mina's stake-delegation patch)
# into /usr/local/bin/rosetta-cli on the host. Mirrors the install steps from
# dockerfiles/stages/rosetta/1-base-deps.
#
# Idempotent: skips if rosetta-cli is already installed.

set -euo pipefail

ROSETTA_CLI_VERSION="${ROSETTA_CLI_VERSION:-v0.10.1}"
GO_VERSION="${GO_VERSION:-1.19.11}"

if command -v rosetta-cli >/dev/null 2>&1; then
  echo "rosetta-cli already installed: $(rosetta-cli version 2>&1 | head -1 || true)"
  exit 0
fi

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in amd64|arm64) ;; *) echo "Unsupported arch: $ARCH"; exit 1;; esac

if [ ! -x /usr/lib/go/bin/go ]; then
  echo "Installing go ${GO_VERSION}"
  curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | sudo tar -xz -C /usr/lib/
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "https://github.com/coinbase/mesh-cli/archive/refs/tags/${ROSETTA_CLI_VERSION}.tar.gz" \
  -o "${WORK}/mesh-cli.tar.gz"
tar -xzf "${WORK}/mesh-cli.tar.gz" -C "${WORK}"

cd "${WORK}/mesh-cli-${ROSETTA_CLI_VERSION#v}"
GOBIN="${WORK}/bin"
export GOBIN
mkdir -p "$GOBIN"

/usr/lib/go/bin/go mod edit -replace \
  github.com/coinbase/rosetta-sdk-go@v0.8.1=github.com/MinaProtocol/rosetta-sdk-go@stake-delegation-v1
/usr/lib/go/bin/go mod tidy
/usr/lib/go/bin/go install

sudo install -m 0755 "${GOBIN}/rosetta-cli" /usr/local/bin/rosetta-cli

echo "Installed rosetta-cli to /usr/local/bin/rosetta-cli"
