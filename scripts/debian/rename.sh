#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <source-deb-file> <target-name>"
	exit 1
fi

SRC_DEB="$1"
TARGET_NAME="$2"

if [ ! -f "$SRC_DEB" ]; then
	echo "Source file '$SRC_DEB' does not exist."
	exit 2
fi

# Extract the debian package
WORKDIR=$(mktemp -d)
ar x "$SRC_DEB" --output "$WORKDIR"

# Extract control.tar.*
CONTROL_TAR=$(ls "$WORKDIR"/control.tar.*)
mkdir "$WORKDIR/control"
tar -xf "$CONTROL_TAR" -C "$WORKDIR/control"

# Update Package name in control file
CONTROL_FILE="$WORKDIR/control/control"
if grep -q '^Package:' "$CONTROL_FILE"; then
	sed -i "s/^Package: .*/Package: $TARGET_NAME/" "$CONTROL_FILE"
else
	echo "No Package field found in control file."
	rm -rf "$WORKDIR"
	exit 3
fi

# Repack control.tar.gz
tar -czf "$WORKDIR/control.tar.gz" -C "$WORKDIR/control" .

# Rebuild the deb file
DATA_TAR=$(ls "$WORKDIR"/data.tar.*)
DEBIAN_BINARY=$(ls "$WORKDIR"/debian-binary)
NEW_DEB="${TARGET_NAME}.deb"
ar r "$NEW_DEB" "$DEBIAN_BINARY" "$WORKDIR/control.tar.gz" "$DATA_TAR"

echo "Renamed package created: $NEW_DEB"

# Cleanup
rm -rf "$WORKDIR"
