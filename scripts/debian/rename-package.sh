#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <input.deb> <new-package-name> [output.deb]

Renames a Debian package by updating the Package field in the control file
and optionally the output filename. Preserves everything else including
version, architecture, and all file contents.

Arguments:
  <input.deb>         Path to the source .deb file
  <new-package-name>  The new package name (e.g., "mina-hardfork")
  [output.deb]        Optional output filename. If not provided, will use:
                      <new-package-name>_<version>_<arch>.deb

Examples:
  # Rename mina-devnet to mina-hardfork (auto-generate output name)
  $0 mina-devnet_3.3.0_amd64.deb mina-hardfork

  # Rename with explicit output filename
  $0 mina-devnet_3.3.0_amd64.deb mina-hardfork my-custom-output.deb

Notes:
  - Only the Package field in the control file is modified
  - Version, architecture, and all other metadata are preserved
  - All file contents remain unchanged
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

# Save original working directory
ORIG_DIR=$(pwd)

INPUT_DEB=$(readlink -f "$1")
NEW_PACKAGE_NAME="$2"
OUTPUT_DEB="${3:-}"

if [[ ! -f "$INPUT_DEB" ]]; then
  echo "ERROR: input .deb not found: $INPUT_DEB" >&2
  exit 1
fi

# Validate package name (basic check for valid Debian package name)
if [[ ! "$NEW_PACKAGE_NAME" =~ ^[a-z0-9][a-z0-9+.-]+$ ]]; then
  echo "ERROR: invalid package name: $NEW_PACKAGE_NAME" >&2
  echo "Package names must start with alphanumeric and contain only lowercase letters, digits, plus, minus, and dots" >&2
  exit 1
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

# 2. Extract control.tar.* into ./control
mkdir control
echo "Extracting control archive..."
tar -xf "$CONTROL_TAR" -C control

# 3. Modify the Package field in the control file
CONTROL_FILE="control/control"
if [[ ! -f "$CONTROL_FILE" ]]; then
  echo "ERROR: control file not found in control archive" >&2
  exit 1
fi

# Extract current package info for output filename generation
OLD_PACKAGE_NAME=$(grep '^Package:' "$CONTROL_FILE" | awk '{print $2}' || true)
VERSION=$(grep '^Version:' "$CONTROL_FILE" | awk '{print $2}' || true)
ARCH=$(grep '^Architecture:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ -z "$OLD_PACKAGE_NAME" ]]; then
  echo "ERROR: No Package field found in control file" >&2
  exit 1
fi

echo "Renaming package: $OLD_PACKAGE_NAME -> $NEW_PACKAGE_NAME"
if [[ -n "$VERSION" ]]; then
  echo "Version: $VERSION"
fi
if [[ -n "$ARCH" ]]; then
  echo "Architecture: $ARCH"
fi

# Update Package field
sed -i "s/^Package: .*/Package: $NEW_PACKAGE_NAME/" "$CONTROL_FILE"

# Verify the change
NEW_PKG_CHECK=$(grep '^Package:' "$CONTROL_FILE" | awk '{print $2}')
if [[ "$NEW_PKG_CHECK" != "$NEW_PACKAGE_NAME" ]]; then
  echo "ERROR: Failed to update Package field" >&2
  exit 1
fi

# 4. Repack control archive with original compression
echo "Repacking control archive..."
rm -f control.tar control.tar.gz control.tar.xz control.tar.zst

# Detect original compression
case "$CONTROL_TAR" in
  control.tar.gz)
    tar --numeric-owner --owner=0 --group=0 -czf control.tar.gz -C control .
    NEW_CONTROL_TAR="control.tar.gz"
    ;;
  control.tar.xz)
    tar --numeric-owner --owner=0 --group=0 -cJf control.tar.xz -C control .
    NEW_CONTROL_TAR="control.tar.xz"
    ;;
  control.tar.zst)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    zstd -q control.tar
    NEW_CONTROL_TAR="control.tar.zst"
    ;;
  control.tar)
    tar --numeric-owner --owner=0 --group=0 -cf control.tar -C control .
    NEW_CONTROL_TAR="control.tar"
    ;;
  *)
    echo "ERROR: Unknown control.tar compression: $CONTROL_TAR" >&2
    exit 1
    ;;
esac

echo "New control archive: $NEW_CONTROL_TAR"

# 5. Determine output filename
if [[ -z "$OUTPUT_DEB" ]]; then
  # Auto-generate output filename based on new package name
  if [[ -n "$VERSION" && -n "$ARCH" ]]; then
    OUTPUT_DEB="${NEW_PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
  else
    OUTPUT_DEB="${NEW_PACKAGE_NAME}.deb"
  fi

  # If output is relative, make it absolute relative to original working directory
  if [[ "$OUTPUT_DEB" != /* ]]; then
    OUTPUT_DEB="$(dirname "$INPUT_DEB")/$OUTPUT_DEB"
  fi
else
  # Ensure OUTPUT_DEB is an absolute path relative to original directory
  if [[ "$OUTPUT_DEB" != /* ]]; then
    OUTPUT_DEB="$ORIG_DIR/$OUTPUT_DEB"
  fi
fi

# 6. Rebuild .deb with new control archive and original data archive
echo "Reassembling .deb -> $OUTPUT_DEB"
rm -f "$OUTPUT_DEB"
ar rcs "$OUTPUT_DEB" debian-binary "$NEW_CONTROL_TAR" "$DATA_TAR"

# 7. Verify the rebuilt package
echo ""
echo "=== Verifying Package ==="

if [[ ! -f "$OUTPUT_DEB" ]]; then
  echo "ERROR: Output package not created: $OUTPUT_DEB" >&2
  exit 1
fi

echo "Package size: $(du -h "$OUTPUT_DEB" | awk '{print $1}')"

# Verify package info
echo ""
echo "Package information:"
dpkg-deb --info "$OUTPUT_DEB" | grep -E "^\s*(Package|Version|Architecture|Maintainer|Description):"

# Verify data archive integrity by comparing checksums
echo ""
echo "Verifying data archive integrity..."
ORIG_DATA_HASH=$(sha256sum "$DATA_TAR" | awk '{print $1}')
echo "Original data archive SHA256: $ORIG_DATA_HASH"

# Extract the rebuilt package and verify data archive
VERIFY_DIR=$(mktemp -d)
cd "$VERIFY_DIR"
ar x "$OUTPUT_DEB"
REBUILT_DATA_TAR=$(echo data.tar.* 2>/dev/null || true)
if [[ -z "$REBUILT_DATA_TAR" ]]; then
  echo "ERROR: Could not find data archive in rebuilt package" >&2
  cd "$WORKDIR"
  rm -rf "$VERIFY_DIR"
  exit 1
fi

REBUILT_DATA_HASH=$(sha256sum "$REBUILT_DATA_TAR" | awk '{print $1}')
echo "Rebuilt data archive SHA256:  $REBUILT_DATA_HASH"

if [[ "$ORIG_DATA_HASH" == "$REBUILT_DATA_HASH" ]]; then
  echo "✓ Data archive integrity verified (unchanged)"
else
  echo "ERROR: Data archive hash mismatch!" >&2
  cd "$WORKDIR"
  rm -rf "$VERIFY_DIR"
  exit 1
fi

# Verify control file was updated correctly
VERIFY_CONTROL_TAR=$(echo control.tar.* 2>/dev/null || true)
if [[ -n "$VERIFY_CONTROL_TAR" ]]; then
  mkdir verify-control
  tar -xf "$VERIFY_CONTROL_TAR" -C verify-control
  VERIFY_PKG=$(grep '^Package:' verify-control/control | awk '{print $2}' || true)
  if [[ "$VERIFY_PKG" == "$NEW_PACKAGE_NAME" ]]; then
    echo "✓ Control file Package field verified: $NEW_PACKAGE_NAME"
  else
    echo "ERROR: Control file Package field mismatch!" >&2
    echo "  Expected: $NEW_PACKAGE_NAME" >&2
    echo "  Got:      $VERIFY_PKG" >&2
    cd "$WORKDIR"
    rm -rf "$VERIFY_DIR"
    exit 1
  fi
fi

cd "$WORKDIR"
rm -rf "$VERIFY_DIR"

echo ""
echo "=== Success ==="
echo "Package renamed from '$OLD_PACKAGE_NAME' to '$NEW_PACKAGE_NAME'"
echo "Output: $OUTPUT_DEB"
echo "All verification checks passed!"