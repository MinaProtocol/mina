#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <input.deb> <path/inside/package> <replacement-file> [output.deb]

Examples:

  # Mina: replace /var/lib/coda/config_devnet.json in mina-daemon.deb
  $0 mina-daemon.deb /var/lib/coda/config_devnet.json devnet-config.json mina-daemon-patched.deb

Notes:
  - <path/inside/package> should be the absolute path as it appears when the package is installed.
  - If [output.deb] is omitted, will create <input>-patched.deb next to input.
EOF
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage
  exit 1
fi

INPUT_DEB=$(readlink -f "$1")
PKG_PATH="$2"
REPLACEMENT=$(readlink -f "$3")
OUTPUT_DEB="${4:-}"

if [[ ! -f "$INPUT_DEB" ]]; then
  echo "ERROR: input .deb not found: $INPUT_DEB" >&2
  exit 1
fi

if [[ ! -f "$REPLACEMENT" ]]; then
  echo "ERROR: replacement file not found: $REPLACEMENT" >&2
  exit 1
fi

if [[ -z "$OUTPUT_DEB" ]]; then
  OUTPUT_DEB="${INPUT_DEB%.deb}-patched.deb"
fi

# Strip leading slash for inside-tar path
PKG_PATH_STRIPPED="${PKG_PATH#/}"

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

# 3. Replace the target file
TARGET_PATHS=( )
if [[ "$PKG_PATH_STRIPPED" == *"*"* ]]; then
  # Glob match inside data dir
  mapfile -t TARGET_PATHS < <(find data -path "data/$PKG_PATH_STRIPPED")
else
  TARGET_PATHS=("data/$PKG_PATH_STRIPPED")
fi

for TARGET_PATH in "${TARGET_PATHS[@]}"; do
  TARGET_DIR=$(dirname "$TARGET_PATH")
  mkdir -p "$TARGET_DIR"
  echo "Replacing $PKG_PATH with $REPLACEMENT at $TARGET_PATH"
  install -m 0644 "$REPLACEMENT" "$TARGET_PATH"
done

# 4. Create a new data.tar (uncompressed), normalizing owner to root
echo "Repacking data archive..."
rm -f data.tar
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
