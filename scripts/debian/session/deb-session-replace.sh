#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <session-dir> <path-in-package> <replacement-file>

Replaces a file (or files matching a pattern) in the package with a new file.

Arguments:
  <session-dir>        Session directory created by deb-session-open.sh
  <path-in-package>    Path to file in package (supports wildcards like /var/lib/coda/config_*.json)
  <replacement-file>   Local file to replace it with

Example:
  # Replace config_*.json with new_config.json
  $0 ./my-session /var/lib/coda/config_*.json new_config.json

  # Replace specific config file
  $0 ./my-session /var/lib/coda/config_devnet.json new_config.json

Notes:
  - Path should be absolute as it appears when package is installed
  - Wildcards are supported (e.g., config_*.json will replace all matching files)
  - If multiple files match, they will all be replaced with the same replacement file
  - File permissions are set to 0644
EOF
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
PKG_PATH="$2"
REPLACEMENT="$3"

# Validate inputs
if [[ ! -d "$SESSION_DIR" ]]; then
  echo "ERROR: Session directory not found: $SESSION_DIR" >&2
  exit 1
fi

SESSION_DIR_ABS=$(readlink -f "$SESSION_DIR")

if [[ ! -f "$REPLACEMENT" ]]; then
  echo "ERROR: Replacement file not found: $REPLACEMENT" >&2
  exit 1
fi

REPLACEMENT_ABS=$(readlink -f "$REPLACEMENT")

# Validate session
if [[ ! -d "$SESSION_DIR_ABS/data" ]]; then
  echo "ERROR: Session data directory not found. Invalid session?" >&2
  exit 1
fi

# Strip leading slash for path inside data/
PKG_PATH_STRIPPED="${PKG_PATH#/}"

echo "=== Replacing File(s) in Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "Target:  $PKG_PATH"
echo "Source:  $REPLACEMENT_ABS"

cd "$SESSION_DIR_ABS/data"

# Find matching files
TARGET_PATHS=()
if [[ "$PKG_PATH_STRIPPED" == *"*"* ]]; then
  # Glob pattern - find all matching files
  while IFS= read -r -d '' file; do
    TARGET_PATHS+=("$file")
  done < <(find . -path "./$PKG_PATH_STRIPPED" -print0 2>/dev/null || true)
else
  # Exact path
  if [[ -f "$PKG_PATH_STRIPPED" ]]; then
    TARGET_PATHS=("$PKG_PATH_STRIPPED")
  fi
fi

if [[ ${#TARGET_PATHS[@]} -eq 0 ]]; then
  echo "ERROR: No files found matching: $PKG_PATH" >&2
  echo "Available files in /var/lib/coda/:" >&2
  find ./var/lib/coda -type f 2>/dev/null | head -20 || true
  exit 1
fi

echo "Found ${#TARGET_PATHS[@]} file(s) to replace:"

# Replace each matching file
for TARGET_PATH in "${TARGET_PATHS[@]}"; do
  # Remove leading ./ if present
  TARGET_PATH="${TARGET_PATH#./}"

  TARGET_DIR=$(dirname "$TARGET_PATH")
  mkdir -p "$TARGET_DIR"

  echo "  → Replacing: /$TARGET_PATH"
  install -m 0644 "$REPLACEMENT_ABS" "$TARGET_PATH"

  # Verify replacement
  if cmp -s "$REPLACEMENT_ABS" "$TARGET_PATH"; then
    echo "    ✓ Verified"
  else
    echo "    ERROR: Replacement verification failed for $TARGET_PATH" >&2
    exit 1
  fi
done

echo ""
echo "✓ Replacement complete: ${#TARGET_PATHS[@]} file(s) updated"
