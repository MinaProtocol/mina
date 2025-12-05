#!/usr/bin/env bash

set -euox pipefail

usage() {
  cat <<EOF
Usage: $0 <input.deb> <destination-path> <source-glob> [output.deb]

Examples:

  # Mina: insert all JSON files from /tmp/configs into /var/lib/coda/ in mina-daemon.deb
  $0 mina-daemon.deb /var/lib/coda/ '/tmp/configs/*.json' mina-daemon-patched.deb

  # Insert a single file
  $0 mina-daemon.deb /etc/mina/new-config.json ./new-config.json mina-daemon-patched.deb

Notes:
  - <destination-path> should be the absolute path (or directory) as it appears when the package is installed.
  - If destination-path is a directory (ends with /), files will be inserted into that directory.
  - If destination-path is a file path, the source-glob must match exactly one file.
  - <source-glob> can be a glob pattern (e.g., '*.json') or a single file path.
  - Quote the glob pattern to prevent shell expansion.
  - If [output.deb] is omitted, will create <input>-patched.deb next to input.
EOF
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage
  exit 1
fi

INPUT_DEB=$(readlink -f "$1")
DEST_PATH="$2"
SOURCE_GLOB="$3"
OUTPUT_DEB="${4:-}"

if [[ ! -f "$INPUT_DEB" ]]; then
  echo "ERROR: input .deb not found: $INPUT_DEB" >&2
  exit 1
fi

# Expand glob pattern
# If SOURCE_GLOB is a directory, append /* to it
if [[ -d "$SOURCE_GLOB" ]]; then
  SOURCE_GLOB="${SOURCE_GLOB%/}/*"
fi

SOURCE_FILES=()
for file in $SOURCE_GLOB; do
  if [[ -f "$file" ]]; then
    SOURCE_FILES+=("$(readlink -f "$file")")
  fi
done

if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no files matched source glob: $SOURCE_GLOB" >&2
  exit 1
fi

echo "Found ${#SOURCE_FILES[@]} file(s) to insert:"
for file in "${SOURCE_FILES[@]}"; do
  echo "  - $file"
done

if [[ -z "$OUTPUT_DEB" ]]; then
  OUTPUT_DEB="${INPUT_DEB%.deb}-patched.deb"
else
  # Ensure OUTPUT_DEB is an absolute path
  if [[ "$OUTPUT_DEB" != /* ]]; then
    OUTPUT_DEB="$(pwd)/$OUTPUT_DEB"
  fi
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "Working in: $WORKDIR"
cd "$WORKDIR"

# 1. Extract deb structure: debian-binary, control.tar.*, data.tar.*
cp "$INPUT_DEB" pkg.deb
ar x pkg.deb

CONTROL_TAR=$(echo control.tar.* 2>/dev/null || true)
DATA_TAR=$(echo data.tar.* 2>/dev/null || true)

if [[ -z "$CONTROL_TAR" || -z "$DATA_TAR" ]]; then
  echo "ERROR: Could not find control.tar.* or data.tar.* in $INPUT_DEB" >&2
  exit 1
fi

echo "Found control archive: $CONTROL_TAR"
echo "Found data archive:    $DATA_TAR"

# Detect compression for data tar
case "$DATA_TAR" in
  *.tar)   COMPRESS="none" ;;
  *.gz)    COMPRESS="gz" ;;
  *.xz)    COMPRESS="xz" ;;
  *.zst)   COMPRESS="zst" ;;
  *)
    echo "ERROR: Unknown data.tar compression for $DATA_TAR" >&2
    exit 1
    ;;
esac

# 2. Extract data.tar.* into ./data
mkdir data
echo "Extracting data archive..."
tar -xf "$DATA_TAR" -C data

# 3. Insert the files
DEST_PATH_STRIPPED="${DEST_PATH#/}"

# Check if destination is a directory (ends with /)
if [[ "$DEST_PATH" == */ ]]; then
  IS_DIR=true
else
  IS_DIR=false
  # If not a directory, we expect exactly one source file
  if [[ ${#SOURCE_FILES[@]} -ne 1 ]]; then
    echo "ERROR: destination is a file path but multiple source files matched: ${#SOURCE_FILES[@]}" >&2
    exit 1
  fi
fi

for SOURCE_FILE in "${SOURCE_FILES[@]}"; do
  SOURCE_BASENAME=$(basename "$SOURCE_FILE")

  if [[ "$IS_DIR" == true ]]; then
    # Destination is a directory, use source filename
    TARGET_PATH="data/${DEST_PATH_STRIPPED}${SOURCE_BASENAME}"
  else
    # Destination is a file path, use it directly
    TARGET_PATH="data/$DEST_PATH_STRIPPED"
  fi

  TARGET_DIR=$(dirname "$TARGET_PATH")
  mkdir -p "$TARGET_DIR"

  echo "Inserting $SOURCE_FILE -> $TARGET_PATH"
  install -m 0644 "$SOURCE_FILE" "$TARGET_PATH"
done

# 4. Create a new data.tar (uncompressed), normalizing owner to root
echo "Repacking data archive..."
rm -f data.tar data.tar.gz data.tar.xz data.tar.zst
tar --numeric-owner --owner=0 --group=0 -cf data.tar -C data .

# 5. Re-compress data.tar to original format
NEW_DATA_TAR="data.tar"
case "$COMPRESS" in
  none)
    NEW_DATA_TAR="data.tar"
    ;;
  gz)
    gzip -n data.tar   # -n = no original name/time in header (more reproducible)
    NEW_DATA_TAR="data.tar.gz"
    ;;
  xz)
    xz -z data.tar
    NEW_DATA_TAR="data.tar.xz"
    ;;
  zst)
    zstd -q data.tar
    NEW_DATA_TAR="data.tar.zst"
    ;;
esac

echo "New data archive: $NEW_DATA_TAR"

# 6. Rebuild .deb with original control.tar.* and debian-binary
echo "Reassembling .deb -> $OUTPUT_DEB"
rm -f "$OUTPUT_DEB"
ar rcs "$OUTPUT_DEB" debian-binary "$CONTROL_TAR" "$NEW_DATA_TAR"

echo "Done."
echo "Output package: $OUTPUT_DEB"
