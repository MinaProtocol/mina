#!/usr/bin/env bash

set -eux -o pipefail

SESSION_DIR_SCRIPTS="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/session"

usage() {
  cat <<EOF
Usage: $0 <input.deb> <new-version> [options]

Reversion a Debian package: changes version, and optionally suite and package name.
Orchestrates the deb-session-* scripts into a single pipeline.

Arguments:
  <input.deb>           Path to the input .deb file
  <new-version>         New version string (e.g., "2.0.0-rc1")

Options:
  --suite <suite>       Replace suite (e.g., "stable", "unstable")
  --name <name>         Rename the package (e.g., "mina-devnet-hardfork")
  --output <path>       Output .deb path. If omitted, generates
                        {dir}/{package}_{version}_{arch}.deb next to input

Example:
  $0 ./mina-devnet_1.0.0_amd64.deb 2.0.0-rc1 --suite stable --name mina-devnet-hardfork
  $0 ./input.deb 3.0.0 --output /tmp/output.deb
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

INPUT_DEB="$1"
NEW_VERSION="$2"
shift 2

NEW_SUITE=""
NEW_NAME=""
OUTPUT=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --suite)
      NEW_SUITE="$2"
      shift 2
      ;;
    --name)
      NEW_NAME="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$INPUT_DEB" ]]; then
  echo "ERROR: Input file not found: $INPUT_DEB" >&2
  exit 1
fi

# Create a temporary session directory with cleanup
SESSION_DIR=$(mktemp -d -t deb-session-XXXXXX)
cleanup() {
  rm -rf "$SESSION_DIR"
}
trap cleanup EXIT

# Open session
"$SESSION_DIR_SCRIPTS/deb-session-open.sh" "$INPUT_DEB" "$SESSION_DIR"

# Always reversion
"$SESSION_DIR_SCRIPTS/deb-session-reversion.sh" "$SESSION_DIR" "$NEW_VERSION"

# Optionally replace suite
if [[ -n "$NEW_SUITE" ]]; then
  "$SESSION_DIR_SCRIPTS/deb-session-replace-suite.sh" "$SESSION_DIR" "$NEW_SUITE"
fi

# Optionally rename package
if [[ -n "$NEW_NAME" ]]; then
  "$SESSION_DIR_SCRIPTS/deb-session-rename-package.sh" "$SESSION_DIR" "$NEW_NAME"
fi

# Determine output path
if [[ -n "$OUTPUT" ]]; then
  OUT="$OUTPUT"
else
  PKG=$("$SESSION_DIR_SCRIPTS/deb-session-read-field.sh" "$SESSION_DIR" Package)
  ARCH=$("$SESSION_DIR_SCRIPTS/deb-session-read-field.sh" "$SESSION_DIR" Architecture)
  OUT="$(dirname "$INPUT_DEB")/${PKG}_${NEW_VERSION}_${ARCH}.deb"
fi

# Save
"$SESSION_DIR_SCRIPTS/deb-session-save.sh" "$SESSION_DIR" "$OUT"

echo "✅ Reversioned package written to $OUT"
