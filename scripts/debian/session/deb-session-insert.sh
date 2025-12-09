#!/usr/bin/env bash

set -euox pipefail

usage() {
  cat <<EOF
Usage: $0 <session-dir> <dest-path> <source-file> [<source-file2> ...]

Inserts one or more files into the package.

Arguments:
  <session-dir>    Session directory created by deb-session-open.sh
  <dest-path>      Destination path in package (directory or file path)
  <source-file>    Local file(s) to insert (supports multiple files)

Example:
  # Insert multiple ledger tarballs into /var/lib/coda/
  $0 ./my-session /var/lib/coda/ ledger1.tar.gz ledger2.tar.gz

  # Insert a single file with specific name
  $0 ./my-session /var/lib/coda/devnet.json ./new_config.json

  # Insert all tarballs from a directory
  $0 ./my-session /var/lib/coda/ ./ledgers/*.tar.gz

Notes:
  - If dest-path ends with /, it's treated as a directory (files keep their names)
  - If dest-path doesn't end with /, it's treated as a file (only one source allowed)
  - Destination directories are created automatically
  - File permissions are set to 0644
  - Supports glob patterns in source files (e.g., *.tar.gz)
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
DEST_PATH="$2"
shift 2
SOURCE_FILES=("$@")

# Validate session directory
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

# Resolve source files to absolute paths and validate
SOURCE_FILES_ABS=()
for file in "${SOURCE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Source file not found: $file" >&2
    exit 1
  fi
  SOURCE_FILES_ABS+=("$(readlink -f "$file")")
done

if [[ ${#SOURCE_FILES_ABS[@]} -eq 0 ]]; then
  echo "ERROR: No source files provided" >&2
  exit 1
fi

# Determine if destination is a directory or file
IS_DIR=false
if [[ "$DEST_PATH" == */ ]]; then
  IS_DIR=true
else
  # If not ending with /, check if we have only one source file
  if [[ ${#SOURCE_FILES_ABS[@]} -ne 1 ]]; then
    echo "ERROR: Destination is a file path but multiple source files provided" >&2
    echo "HINT: Add trailing / to destination to insert as directory" >&2
    exit 1
  fi
fi

echo "=== Inserting File(s) into Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "Destination: $DEST_PATH"
echo "Files to insert: ${#SOURCE_FILES_ABS[@]}"

# Strip leading slash
DEST_PATH_STRIPPED="${DEST_PATH#/}"

cd "$SESSION_DIR_ABS/data"

# Insert each file
INSERTED_COUNT=0
for SOURCE_FILE in "${SOURCE_FILES_ABS[@]}"; do
  SOURCE_BASENAME=$(basename "$SOURCE_FILE")

  if [[ "$IS_DIR" == true ]]; then
    # Destination is a directory
    TARGET_PATH="${DEST_PATH_STRIPPED}${SOURCE_BASENAME}"
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
  install -m 0644 "$SOURCE_FILE" "$TARGET_PATH"

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

  ((INSERTED_COUNT++))
done

echo ""
echo "✓ Insertion complete: $INSERTED_COUNT file(s) inserted"
