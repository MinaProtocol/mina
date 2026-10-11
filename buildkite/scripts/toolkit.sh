#!/usr/bin/env bash

# Run a mina-release-toolkit binary (release-manager, buildkite-cache-manager,
# deb-toolkit, mina-bench-upload) on the agent host or in any CI container:
#
#   ./buildkite/scripts/toolkit.sh <tool> [args...]
#
# The version is ContainerImages.minaReleaseToolkitVersion, so the binaries and
# the toolkit image never drift. Its release .deb is fetched once per agent
# (the host's /var/buildkite/shared is /shared in containers), checked against
# the sha256 below, and unpacked. The binaries are static musl builds.

set -euo pipefail

declare -A SHA256=(
  [0.0.7-amd64]=TODO_AFTER_0_0_7_RELEASE
  [0.0.7-arm64]=TODO_AFTER_0_0_7_RELEASE
)

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <tool> [args...]" >&2
  exit 1
fi
TOOL="$1"
shift

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(sed -n 's/^, minaReleaseToolkitVersion = "\(.*\)"$/\1/p' \
  "$REPO_ROOT/buildkite/src/Constants/ContainerImages.dhall")"
if [[ -z "$VERSION" ]]; then
  echo "toolkit.sh: minaReleaseToolkitVersion not found in ContainerImages.dhall" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) echo "toolkit.sh: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

writable_dir() { [[ -d "$1" && -w "$1" ]]; }

if [[ -n "${MINA_RELEASE_TOOLKIT_DIR:-}" ]]; then
  BASE="$MINA_RELEASE_TOOLKIT_DIR"
elif writable_dir /shared; then
  BASE=/shared/mina-release-toolkit
elif writable_dir /var/buildkite/shared; then
  BASE=/var/buildkite/shared/mina-release-toolkit
else
  BASE="${XDG_CACHE_HOME:-$HOME/.cache}/mina-release-toolkit"
fi

DIR="$BASE/$VERSION-$ARCH"
BIN="$DIR/usr/bin/$TOOL"

if [[ ! -x "$BIN" ]]; then
  SUM="${SHA256[$VERSION-$ARCH]:-}"
  if [[ -z "$SUM" ]]; then
    echo "toolkit.sh: no sha256 pinned for $VERSION-$ARCH" >&2
    exit 1
  fi
  mkdir -p "$BASE"
  TMP="$(mktemp -d "$BASE/.fetch.XXXXXX")"
  trap 'rm -rf "$TMP"' EXIT
  DEB="mina-release-toolkit_${VERSION}_${ARCH}.deb"
  curl -fsSL --retry 5 --retry-delay 2 -o "$TMP/$DEB" \
    "https://github.com/MinaProtocol/mina-release-toolkit/releases/download/v${VERSION}/${DEB}"
  echo "$SUM  $TMP/$DEB" | sha256sum -c --quiet - >&2
  dpkg-deb -x "$TMP/$DEB" "$TMP/root"
  # A directory rename is atomic: if a concurrent job got there first, its
  # complete copy is used and ours is dropped.
  mv -T "$TMP/root" "$DIR" 2>/dev/null || true
  rm -rf "$TMP"
  trap - EXIT
  if [[ ! -x "$BIN" ]]; then
    echo "toolkit.sh: $TOOL is not in mina-release-toolkit $VERSION" >&2
    exit 1
  fi
fi

exec "$BIN" "$@"
