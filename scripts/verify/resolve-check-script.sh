#!/usr/bin/env bash
# Maps a package name to the corresponding check script.
# Usage: source resolve-check-script.sh <package>
# Sets: CHECK_SCRIPT (path to the check script to run)
set -euo pipefail

VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:?package name required}" in
  mina-archive*) CHECK_SCRIPT="$VERIFY_DIR/check-archive.sh" ;;
  mina-logproc)  CHECK_SCRIPT="$VERIFY_DIR/check-logproc.sh" ;;
  mina-rosetta*) CHECK_SCRIPT="$VERIFY_DIR/check-rosetta.sh" ;;
  mina-*)        CHECK_SCRIPT="$VERIFY_DIR/check-daemon.sh" ;;
  *) echo "Unknown package: $1"; exit 1 ;;
esac
