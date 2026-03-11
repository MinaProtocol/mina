#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

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

# Validate session directory
validate_session "$SESSION_DIR"

# Validate paths don't escape session
validate_path_in_session "$SESSION_DIR_ABS" "$SOURCE_PATH" "Source path"
validate_path_in_session "$SESSION_DIR_ABS" "$DEST_PATH" "Destination path"

echo "=== Moving File in Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "From:    $SOURCE_PATH"
echo "To:      $DEST_PATH"

# Navigate to session data directory
cd "$(get_session_data_dir "$SESSION_DIR_ABS")"

# Strip leading slashes
SOURCE_PATH_STRIPPED=$(strip_leading_slash "$SOURCE_PATH")
DEST_PATH_STRIPPED=$(strip_leading_slash "$DEST_PATH")

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
