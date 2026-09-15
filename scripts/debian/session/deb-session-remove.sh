#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 <session-dir> <path-pattern>

Removes file(s) matching a pattern from the package.

Arguments:
  <session-dir>    Session directory created by deb-session-open.sh
  <path-pattern>   Path or glob pattern to match files for removal (absolute path)

Example:
  # Remove all config_*.json files
  $0 ./my-session /var/lib/coda/config_*.json

  # Remove specific file
  $0 ./my-session /var/lib/coda/devnet.json

  # Remove all files in a directory
  $0 ./my-session /var/lib/coda/old_configs/*

  # Remove all .log files in a directory tree
  $0 ./my-session /var/log/mina/**/*.log

Notes:
  - Path should be absolute as it appears when package is installed
  - Glob patterns are supported (e.g., config_*.json, **/*.log)
  - If no files match the pattern, an error will be reported
  - Directories are not removed, only files
  - Use with caution - removed files cannot be recovered from the session
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
PATH_PATTERN="$2"

# Validate session directory
validate_session "$SESSION_DIR"

# Validate path pattern doesn't escape session (handles wildcards)
validate_path_in_session "$SESSION_DIR_ABS" "${PATH_PATTERN%%\**}" "Path pattern"

echo "=== Removing File(s) from Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "Pattern: $PATH_PATTERN"

# Navigate to session data directory
cd "$(get_session_data_dir "$SESSION_DIR_ABS")"

# Strip leading slash for path inside data/
PATH_PATTERN_STRIPPED=$(strip_leading_slash "$PATH_PATTERN")

# Find matching files
MATCHED_FILES=()
# NOTE: globstar requires Bash 4.0+. The ** pattern allows matching files recursively.
shopt -s globstar nullglob
if [[ "$PATH_PATTERN_STRIPPED" == *"*"* ]] || [[ "$PATH_PATTERN_STRIPPED" == *"?"* ]]; then
  # Glob pattern - find all matching files
  for file in $PATH_PATTERN_STRIPPED; do
    if [[ -f "$file" ]]; then
      MATCHED_FILES+=("$file")
    fi
  done
else
  # Exact path
  if [[ -f "$PATH_PATTERN_STRIPPED" ]]; then
    MATCHED_FILES=("$PATH_PATTERN_STRIPPED")
  fi
fi
shopt -u globstar nullglob

if [[ ${#MATCHED_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No files found matching: $PATH_PATTERN" >&2
  echo "" >&2
  echo "Available files in parent directory:" >&2
  PARENT_DIR=$(dirname "$PATH_PATTERN_STRIPPED")
  if [[ -d "$PARENT_DIR" ]]; then
    find "$PARENT_DIR" -type f 2>/dev/null | head -20 || true
  else
    echo "  (parent directory does not exist)" >&2
  fi
  exit 1
fi

echo "Found ${#MATCHED_FILES[@]} file(s) to remove:"
echo ""

# Remove each matching file
REMOVED_COUNT=0
for FILE in "${MATCHED_FILES[@]}"; do
  # Remove leading ./ if present
  FILE="${FILE#./}"

  echo "  → Removing: /$FILE"
  rm -f "$FILE"

  # Verify removal
  if [[ -f "$FILE" ]]; then
    echo "    ERROR: Failed to remove $FILE" >&2
    exit 1
  fi

  REMOVED_COUNT=$((REMOVED_COUNT + 1))
done

echo ""
echo "✓ Removal complete: $REMOVED_COUNT file(s) removed"
