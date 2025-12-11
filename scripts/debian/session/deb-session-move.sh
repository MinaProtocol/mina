#!/usr/bin/env bash

set -euox pipefail

usage() {
  cat <<EOF
Usage: $0 <session-dir> <source-path> <dest-path>

Moves or renames a file within the package.

Arguments:
  <session-dir>   Session directory created by deb-session-open.sh
  <source-path>   Current path of file in package (absolute path)
  <dest-path>     New path for the file in package (absolute path)

Example:
  # Move devnet.json to devnet.old.json
  $0 ./my-session /var/lib/coda/devnet.json /var/lib/coda/devnet.old.json

  # Rename a config file
  $0 ./my-session /etc/mina/config.json /etc/mina/config.backup.json

Notes:
  - Both paths should be absolute as they appear when package is installed
  - Source file must exist
  - Destination directory will be created if it doesn't exist
  - This is equivalent to 'mv' within the package
EOF
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
SOURCE_PATH="$2"
DEST_PATH="$3"

# Validate inputs
if [[ ! -d "$SESSION_DIR" ]]; then
  echo "ERROR: Session directory not found: $SESSION_DIR" >&2
  exit 1
fi

SESSION_DIR_ABS=$(readlink -f "$SESSION_DIR")

# Validate session
if [[ ! -d "$SESSION_DIR_ABS/data" ]]; then
  echo "ERROR: Session data directory not found. Invalid session?" >&2
  exit 1
fi

# Strip leading slashes
SOURCE_PATH_STRIPPED="${SOURCE_PATH#/}"
DEST_PATH_STRIPPED="${DEST_PATH#/}"

echo "=== Moving File in Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "From:    $SOURCE_PATH"
echo "To:      $DEST_PATH"

cd "$SESSION_DIR_ABS/data"

# Check if source exists
if [[ ! -e "$SOURCE_PATH_STRIPPED" ]]; then
  echo "ERROR: Source file not found: $SOURCE_PATH" >&2
  echo "Available files in directory:" >&2
  SOURCE_DIR=$(dirname "$SOURCE_PATH_STRIPPED")
  if [[ -d "$SOURCE_DIR" ]]; then
    ls -la "$SOURCE_DIR" || true
  fi
  exit 1
fi

# Create destination directory if needed
DEST_DIR=$(dirname "$DEST_PATH_STRIPPED")
if [[ -n "$DEST_DIR" && "$DEST_DIR" != "." ]]; then
  mkdir -p "$DEST_DIR"
fi

# Check if destination already exists
if [[ -e "$DEST_PATH_STRIPPED" ]]; then
  echo "WARNING: Destination file already exists and will be overwritten: $DEST_PATH" >&2
fi

# Move the file
mv -f "$SOURCE_PATH_STRIPPED" "$DEST_PATH_STRIPPED"

# Verify the move
if [[ ! -e "$DEST_PATH_STRIPPED" ]]; then
  echo "ERROR: Move failed - destination file not found after move!" >&2
  exit 1
fi

if [[ -e "$SOURCE_PATH_STRIPPED" ]]; then
  echo "ERROR: Move failed - source file still exists after move!" >&2
  exit 1
fi

echo "✓ File moved successfully"
echo "  From: /$SOURCE_PATH_STRIPPED"
echo "  To:   /$DEST_PATH_STRIPPED"
