#!/bin/bash

# DEPRECATED: This script is deprecated and maintained only for backwards compatibility.
# Please use rename-package.sh instead, which provides:
#   - Proper compression format preservation (gz/xz/zst/tar)
#   - SHA256 verification of package contents
#   - Flexible output naming (auto-generated or custom)
#   - Package name validation
#   - Better error handling and reporting

set -e

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <source-deb-file> <target-name>"
	echo ""
	echo "⚠️  DEPRECATION WARNING: This script is deprecated."
	echo "   Please use 'scripts/debian/rename-package.sh' instead for better reliability."
	exit 1
fi

SRC_DEB="$1"
TARGET_NAME="$2"

echo "⚠️  WARNING: rename.sh is deprecated. Forwarding to rename-package.sh..."
echo ""

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call the new script with the same arguments
# Output will be ${TARGET_NAME}_${VERSION}_${ARCH}.deb instead of just ${TARGET_NAME}.deb
exec "$SCRIPT_DIR/rename-package.sh" "$SRC_DEB" "$TARGET_NAME"
