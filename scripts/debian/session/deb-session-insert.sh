#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 [-d] <session-dir> <dest-path> <source-file> [<source-file2> ...]

Inserts one or more files into the package.

Options:
  -d, --directory  Treat dest-path as a directory (files keep their names)

Arguments:
  <session-dir>    Session directory created by deb-session-open.sh
  <dest-path>      Destination path in package
  <source-file>    Local file(s) to insert (supports multiple files)

Example:
  # Insert multiple ledger tarballs into /var/lib/coda/ (explicit directory mode)
  $0 -d ./my-session /var/lib/coda ledger1.tar.gz ledger2.tar.gz

  # Insert a single file with specific name
  $0 ./my-session /var/lib/coda/devnet.json ./new_config.json

  # Insert all tarballs from a directory (trailing / also works)
  $0 ./my-session /var/lib/coda/ ./ledgers/*.tar.gz

Notes:
  - Use -d flag to explicitly treat destination as a directory
  - Without -d: trailing / indicates directory, otherwise file path
  - For file destination without -d, only one source file allowed
  - Destination directories are created automatically
  - File permissions and attributes are preserved from source
  - Supports glob patterns in source files (e.g., *.tar.gz)
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

# Parse optional -d flag
EXPLICIT_DIR_MODE=false
if [[ "$1" == "-d" || "$1" == "--directory" ]]; then
  EXPLICIT_DIR_MODE=true
  shift
fi

SESSION_DIR="$1"
DEST_PATH="$2"
shift 2
SOURCE_FILES=("$@")

# Validate session directory
validate_session "$SESSION_DIR"

# Validate destination path doesn't escape session
validate_path_in_session "$SESSION_DIR_ABS" "$DEST_PATH" "Destination path"

# Resolve source files to absolute paths and validate
SOURCE_FILES_ABS=()
for file in "${SOURCE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Source file not found: $file" >&2
    exit 1
  fi
  SOURCE_FILES_ABS+=("$(realpath "$file")")
done

if [[ ${#SOURCE_FILES_ABS[@]} -eq 0 ]]; then
  echo "ERROR: No source files provided" >&2
  exit 1
fi

# Determine if destination is a directory or file
DEST_IS_DIR=false
if [[ "$EXPLICIT_DIR_MODE" == true ]]; then
  # Explicit -d flag provided
  DEST_IS_DIR=true
elif [[ "$DEST_PATH" == */ ]]; then
  # Trailing slash indicates directory
  DEST_IS_DIR=true
else
  # No directory indicator - treat as file path
  # If not ending with / and no -d flag, check if we have only one source file
  if [[ ${#SOURCE_FILES_ABS[@]} -ne 1 ]]; then
    echo "ERROR: Destination is a file path but multiple source files provided" >&2
    echo "HINT: Add trailing / to destination or use -d flag to insert as directory" >&2
    exit 1
  fi
fi

echo "=== Inserting File(s) into Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "Destination: $DEST_PATH"
echo "Files to insert: ${#SOURCE_FILES_ABS[@]}"

# Navigate to session data directory
cd "$(get_session_data_dir "$SESSION_DIR_ABS")"

# Strip leading slash from destination
DEST_PATH_STRIPPED=$(strip_leading_slash "$DEST_PATH")

# Insert each file
INSERTED_COUNT=0
for SOURCE_FILE in "${SOURCE_FILES_ABS[@]}"; do
  SOURCE_BASENAME=$(basename "$SOURCE_FILE")

  if [[ "$DEST_IS_DIR" == true ]]; then
    # Destination is a directory - ensure trailing slash for proper concatenation
    TARGET_PATH="${DEST_PATH_STRIPPED%/}/${SOURCE_BASENAME}"
  else
    # Destination is a file path
    TARGET_PATH="$DEST_PATH_STRIPPED"
  fi

  # Create destination directory
  TARGET_DIR=$(dirname "$TARGET_PATH")
  if [[ -n "$TARGET_DIR" && "$TARGET_DIR" != "." ]]; then
    mkdir -p "$TARGET_DIR"
  fi

  echo "  → Inserting: $(basename "$SOURCE_FILE") -> /$TARGET_PATH"
  cp -p "$SOURCE_FILE" "$TARGET_PATH"

  # Verify insertion
  if [[ ! -f "$TARGET_PATH" ]]; then
    echo "    ERROR: File not found after insertion!" >&2
    exit 1
  fi

  # Verify content matches
  if cmp -s "$SOURCE_FILE" "$TARGET_PATH"; then
    echo "    ✓ Verified"
  else
    echo "    ERROR: Content verification failed!" >&2
    exit 1
  fi

  INSERTED_COUNT=$((INSERTED_COUNT + 1))
done

echo ""
echo "✓ Insertion complete: $INSERTED_COUNT file(s) inserted"
