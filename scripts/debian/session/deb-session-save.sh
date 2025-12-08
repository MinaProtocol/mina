#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <session-dir> <output.deb> [--verify]

Saves a Debian package session by repacking the modified files into a .deb.

Arguments:
  <session-dir>  Session directory created by deb-session-open.sh
  <output.deb>   Output path for the generated .deb file
  --verify       Optional: verify data archive integrity (recommended)

Example:
  $0 ./my-session mina-devnet-hardfork_3.3.0_amd64.deb --verify

Notes:
  - Reads compression settings from metadata.env
  - Preserves original compression formats
  - Normalizes file ownership to root:root
  - Creates reproducible archives (no timestamps in gzip)
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
OUTPUT_DEB="$2"
VERIFY_MODE="false"

if [[ $# -eq 3 ]]; then
  if [[ "$3" == "--verify" ]]; then
    VERIFY_MODE="true"
  else
    echo "ERROR: Unknown option: $3" >&2
    usage
    exit 1
  fi
fi

# Validate session directory
if [[ ! -d "$SESSION_DIR" ]]; then
  echo "ERROR: Session directory not found: $SESSION_DIR" >&2
  exit 1
fi

SESSION_DIR_ABS=$(readlink -f "$SESSION_DIR")
METADATA_FILE="$SESSION_DIR_ABS/metadata.env"

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: Session metadata not found: $METADATA_FILE" >&2
  echo "This doesn't appear to be a valid session directory." >&2
  exit 1
fi

# Source metadata
source "$METADATA_FILE"

# Validate required directories
if [[ ! -d "$SESSION_DIR_ABS/control" || ! -d "$SESSION_DIR_ABS/data" ]]; then
  echo "ERROR: Session missing required directories (control/ or data/)" >&2
  exit 1
fi

# Make output path absolute
if [[ "$OUTPUT_DEB" != /* ]]; then
  OUTPUT_DEB="$(pwd)/$OUTPUT_DEB"
fi

echo "=== Saving Debian Package ==="
echo "Session: $SESSION_DIR_ABS"
echo "Output:  $OUTPUT_DEB"

cd "$SESSION_DIR_ABS"

# Repack control archive
echo "Repacking control archive (compression: $CONTROL_COMPRESS)..."
rm -f control.tar control.tar.gz control.tar.xz control.tar.zst

case "$CONTROL_COMPRESS" in
  none)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    CONTROL_TAR="control.tar"
    ;;
  gz)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    gzip -nf control.tar  # -n = no timestamp for reproducibility
    CONTROL_TAR="control.tar.gz"
    ;;
  xz)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    xz -z control.tar
    CONTROL_TAR="control.tar.xz"
    ;;
  zst)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    zstd -q control.tar
    rm -f control.tar
    CONTROL_TAR="control.tar.zst"
    ;;
  *)
    echo "ERROR: Unknown control compression type: $CONTROL_COMPRESS" >&2
    exit 1
    ;;
esac

# Repack data archive
echo "Repacking data archive (compression: $DATA_COMPRESS)..."
rm -f data.tar data.tar.gz data.tar.xz data.tar.zst

case "$DATA_COMPRESS" in
  none)
    tar --numeric-owner --owner=0 --group=0 -cf data.tar -C data .
    DATA_TAR="data.tar"
    ;;
  gz)
    tar --numeric-owner --owner=0 --group=0 -cf data.tar -C data .
    gzip -nf data.tar  # -n = no timestamp for reproducibility
    DATA_TAR="data.tar.gz"
    ;;
  xz)
    tar --numeric-owner --owner=0 --group=0 -cf data.tar -C data .
    xz -z data.tar
    DATA_TAR="data.tar.xz"
    ;;
  zst)
    tar --numeric-owner --owner=0 --group=0 -cf data.tar -C data .
    zstd -q data.tar
    rm -f data.tar
    DATA_TAR="data.tar.zst"
    ;;
  *)
    echo "ERROR: Unknown data compression type: $DATA_COMPRESS" >&2
    exit 1
    ;;
esac

# Rebuild .deb package
echo "Assembling .deb package..."
rm -f "$OUTPUT_DEB"
ar rcs "$OUTPUT_DEB" debian-binary "$CONTROL_TAR" "$DATA_TAR"

# Verification
if [[ "$VERIFY_MODE" == "true" ]]; then
  echo ""
  echo "=== Verifying Package ==="

  if [[ ! -f "$OUTPUT_DEB" ]]; then
    echo "ERROR: Output package was not created!" >&2
    exit 1
  fi

  # Verify package can be read
  if ! dpkg-deb --info "$OUTPUT_DEB" > /dev/null 2>&1; then
    echo "ERROR: Generated package is not a valid .deb file!" >&2
    exit 1
  fi

  # Show package info
  echo "Package size: $(du -h "$OUTPUT_DEB" | awk '{print $1}')"
  echo ""
  echo "Package information:"
  dpkg-deb --info "$OUTPUT_DEB" | grep -E "^\s*(Package|Version|Architecture):" || true

  # Count files
  FILE_COUNT=$(dpkg-deb -c "$OUTPUT_DEB" | wc -l)
  echo "Total files in package: $FILE_COUNT"

  echo "✓ Package verification passed"
fi

echo ""
echo "=== Package Saved Successfully ==="
echo "Output: $OUTPUT_DEB"

# Clean up temporary tar files
rm -f control.tar control.tar.gz control.tar.xz control.tar.zst
rm -f data.tar data.tar.gz data.tar.xz data.tar.zst
