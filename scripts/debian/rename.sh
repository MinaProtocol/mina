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

# Get absolute path of source deb
SRC_DEB_ABS=$(readlink -f "$SRC_DEB")

# Extract the debian package
WORKDIR=$(mktemp -d)
cd "$WORKDIR"
ar x "$SRC_DEB_ABS"

# Extract control.tar.*
CONTROL_TAR=$(ls control.tar.*)
mkdir control
tar -xf "$CONTROL_TAR" -C control

# Update Package name in control file
CONTROL_FILE="control/control"
if grep -q '^Package:' "$CONTROL_FILE"; then
	sed -i "s/^Package: .*/Package: $TARGET_NAME/" "$CONTROL_FILE"
else
	echo "No Package field found in control file."
	cd /
	rm -rf "$WORKDIR"
	exit 3
fi

# Repack control.tar.gz
rm -f control.tar.gz
tar -czf control.tar.gz -C control .

# Rebuild the deb file
DATA_TAR=$(ls data.tar.*)
NEW_DEB="${TARGET_NAME}.deb"

# Return to original directory to write output
cd - > /dev/null
ar r "$NEW_DEB" "$WORKDIR/debian-binary" "$WORKDIR/control.tar.gz" "$WORKDIR/$DATA_TAR"

echo "Renamed package created: $NEW_DEB"

# Cleanup
rm -rf "$WORKDIR"
