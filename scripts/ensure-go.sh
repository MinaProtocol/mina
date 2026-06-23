#!/bin/bash

# Ensures a Go toolchain >= 1.21 is available and prints the path to its `go`
# binary on stdout.
#
# WHY THIS EXISTS:
#   The mina-bootstrap Go CLI imports the standard library `log/slog` package
#   (added in Go 1.21) and depends on modules (cloud.google.com/go/storage,
#   google.golang.org/api) that require Go >= 1.20/1.21. Its go.mod declares
#   `go 1.21`.
#
#   In CI the artifact step `make build-mina-bootstrap` runs inside the Bullseye
#   Debian builder image, which ships Go 1.19. Go 1.19 cannot build this code
#   ("package log/slog is not in GOROOT"), which broke all Bullseye Debian
#   builds and the downstream Docker jobs.
#
#   Rather than downgrading the SDK or dropping slog, this script provisions a
#   pinned Go >= 1.21 when the system `go` is too old, mirroring the existing
#   repo precedent in buildkite/scripts/tests/rosetta/install-cli.sh (download a
#   pinned Go tarball from dl.google.com).
#
# USAGE:
#   GO_BIN="$(scripts/ensure-go.sh)"
#   "$GO_BIN" build ...
#
# Idempotent: a downloaded toolchain is cached under GO_CACHE_DIR and reused.

set -euo pipefail

# Minimum required Go minor version (major is 1). slog landed in 1.21.
REQUIRED_MINOR=21

# Pinned Go version to download when the system go is too old. Keep this in sync
# with the GO_IMAGE pin in dockerfiles/Dockerfile-mina-bootstrap so both build
# paths use the same toolchain.
GO_VERSION="${GO_VERSION:-1.21.13}"

# Cache directory for the downloaded toolchain (override in CI if desired).
GO_CACHE_DIR="${GO_CACHE_DIR:-${TMPDIR:-/tmp}/mina-go-toolchains}"

# Returns success if "$1 go version" reports >= 1.REQUIRED_MINOR.
go_is_new_enough() {
  local go_bin="$1"
  local ver minor major
  # `go version` => "go version go1.21.13 linux/amd64"
  ver="$("$go_bin" version 2>/dev/null | awk '{print $3}' | sed 's/^go//')" || return 1
  [ -n "$ver" ] || return 1
  major="$(echo "$ver" | cut -d. -f1)"
  minor="$(echo "$ver" | cut -d. -f2)"
  [ -n "$minor" ] || return 1
  # Any future major > 1 is treated as new enough.
  if [ "$major" -gt 1 ] 2>/dev/null; then
    return 0
  fi
  [ "$minor" -ge "$REQUIRED_MINOR" ] 2>/dev/null
}

# 1) If the system `go` is already new enough, use it as-is.
if command -v go >/dev/null 2>&1 && go_is_new_enough "$(command -v go)"; then
  command -v go
  exit 0
fi

# 2) Otherwise provision the pinned Go into the cache (reuse if present).
ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
if [ -z "$ARCH" ]; then
  # Fallback for environments without dpkg.
  case "$(uname -m)" in
    x86_64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) echo "ensure-go: cannot determine architecture" >&2; exit 1 ;;
  esac
fi
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "ensure-go: unsupported arch: $ARCH" >&2; exit 1 ;;
esac

GO_ROOT="${GO_CACHE_DIR}/go${GO_VERSION}.${ARCH}"
GO_BIN="${GO_ROOT}/go/bin/go"

if [ ! -x "$GO_BIN" ]; then
  echo "ensure-go: system go is older than 1.${REQUIRED_MINOR}; installing go ${GO_VERSION} (${ARCH}) into ${GO_ROOT}" >&2
  mkdir -p "$GO_ROOT"
  curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | tar -xz -C "$GO_ROOT"
fi

if ! go_is_new_enough "$GO_BIN"; then
  echo "ensure-go: provisioned go at ${GO_BIN} is not >= 1.${REQUIRED_MINOR}" >&2
  exit 1
fi

echo "$GO_BIN"
