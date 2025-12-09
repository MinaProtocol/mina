#!/bin/bash

set -ex

usage() {
	echo "Usage: $0 -d <deb_file> -c <runtime_config_json> -l <ledger_tarballs> -n <network_name>"
	echo "  -d <deb_file>            Path to mina-daemon.deb file"
	echo "  -c <runtime_config_json> Path to runtime config JSON file"
	echo "  -l <ledger_tarballs>     Path to ledger tarballs directory"
	echo "  -n <network_name>        Network name (e.g., devnet, testnet, mainnet)"
	exit 1
}

while getopts "d:c:l:n:" opt; do
	case $opt in
		d) DEB_FILE="$OPTARG" ;;
		c) RUNTIME_CONFIG_JSON="$OPTARG" ;;
		l) LEDGER_TARBALLS="$OPTARG" ;;
		n) NETWORK_NAME="$OPTARG" ;;
		*) usage ;;
	esac
done

if [[ -z "$DEB_FILE" || -z "$RUNTIME_CONFIG_JSON" || -z "$LEDGER_TARBALLS" || -z "$NETWORK_NAME" ]]; then
    usage
fi

# Resolve absolute paths
DEB_FILE_ABS=$(readlink -f "$DEB_FILE")
RUNTIME_CONFIG_JSON_ABS=$(readlink -f "$RUNTIME_CONFIG_JSON")
LEDGER_TARBALLS_FULL=$(readlink -f "$LEDGER_TARBALLS")

# Get directory and base name
DEB_DIR=$(dirname "$DEB_FILE_ABS")
DEB_BASE=$(basename "$DEB_FILE_ABS" .deb)

# Extract the original package name from the deb file
ORIGINAL_PACKAGE_NAME=$(dpkg-deb --field "$DEB_FILE_ABS" Package)

# Extract version and architecture from the filename
VERSION=$(dpkg-deb --field "$DEB_FILE_ABS" Version)
ARCH=$(dpkg-deb --field "$DEB_FILE_ABS" Architecture)

# Get the base name without version and arch (everything before the first underscore)
if [[ "$DEB_BASE" =~ ^(.+)_${VERSION}_${ARCH}$ ]]; then
	FILE_BASE_NAME="${BASH_REMATCH[1]}"
else
	# Fallback if pattern doesn't match - just use the base
	FILE_BASE_NAME="${DEB_BASE%%_*}"
fi

# Remove any existing -hardfork suffixes from the base name
while [[ "$FILE_BASE_NAME" == *-hardfork ]]; do
	FILE_BASE_NAME="${FILE_BASE_NAME%-hardfork}"
done

# Construct the output filename: <base-name>-hardfork_<version>_<arch>.deb
OUTPUT_DEB_FILE="${DEB_DIR}/${FILE_BASE_NAME}-hardfork_${VERSION}_${ARCH}.deb"

# Fail if LEDGER_TARBALLS_FULL does not exist
if [[ ! -e "$LEDGER_TARBALLS_FULL" ]]; then
	echo "Error: Ledger tarballs path '$LEDGER_TARBALLS_FULL' does not exist." >&2
	exit 1
fi

# Create temporary session directory
SESSION_DIR=$(mktemp -d)
trap 'rm -rf "$SESSION_DIR"' EXIT

echo ""
echo "=== Converting Debian Package to Hardfork Package ==="
echo "Input:   $DEB_FILE_ABS"
echo "Network: $NETWORK_NAME"
echo "Output:  $OUTPUT_DEB_FILE"
echo ""

# Open the debian package for modifications
echo "=== Step 1: Opening Debian Package ==="
./scripts/debian/session/deb-session-open.sh "$DEB_FILE_ABS" "$SESSION_DIR"

# Move existing network config to backup
echo ""
echo "=== Step 2: Backing up existing network config ==="
./scripts/debian/session/deb-session-move.sh "$SESSION_DIR" \
    "/var/lib/coda/${NETWORK_NAME}.json" \
    "/var/lib/coda/${NETWORK_NAME}.old.json"

# Insert new runtime config as the network config
echo ""
echo "=== Step 3: Inserting new runtime config ==="
./scripts/debian/session/deb-session-insert.sh "$SESSION_DIR" \
    "/var/lib/coda/${NETWORK_NAME}.json" \
    "$RUNTIME_CONFIG_JSON_ABS"

# Replace config_*.json with runtime config
echo ""
echo "=== Step 4: Replacing config_*.json ==="
./scripts/debian/session/deb-session-replace.sh "$SESSION_DIR" \
    "/var/lib/coda/config_*.json" \
    "$RUNTIME_CONFIG_JSON_ABS"

# Insert ledger tarballs
echo ""
echo "=== Step 5: Inserting ledger tarballs ==="
if [[ -d "$LEDGER_TARBALLS_FULL" ]]; then
    # Directory of tarballs
    TARBALL_FILES=("$LEDGER_TARBALLS_FULL"/*.tar.gz)
    if [[ ! -e "${TARBALL_FILES[0]}" ]]; then
        echo "ERROR: No .tar.gz files found in $LEDGER_TARBALLS_FULL" >&2
        exit 1
    fi
    ./scripts/debian/session/deb-session-insert.sh "$SESSION_DIR" \
        "/var/lib/coda/" \
        "${TARBALL_FILES[@]}"
else
    # Single tarball file
    ./scripts/debian/session/deb-session-insert.sh "$SESSION_DIR" \
        "/var/lib/coda/" \
        "$LEDGER_TARBALLS_FULL"
fi

# Rename package to add -hardfork suffix
echo ""
echo "=== Step 6: Renaming package ==="
BASE_PACKAGE_NAME="$ORIGINAL_PACKAGE_NAME"
while [[ "$BASE_PACKAGE_NAME" == *-hardfork ]]; do
	BASE_PACKAGE_NAME="${BASE_PACKAGE_NAME%-hardfork}"
done
NEW_PACKAGE_NAME="${BASE_PACKAGE_NAME}-hardfork"

./scripts/debian/session/deb-session-rename-package.sh "$SESSION_DIR" "$NEW_PACKAGE_NAME"

# Save the modified package
echo ""
echo "=== Step 7: Saving modified package ==="
./scripts/debian/session/deb-session-save.sh "$SESSION_DIR" "$OUTPUT_DEB_FILE" --verify

# Verify the final package contents
echo ""
echo "=== Step 8: Final Verification ==="

FINAL_DEB_ABS=$(readlink -f "$OUTPUT_DEB_FILE")
LEDGER_TARBALLS_ABS=$(readlink -f "$LEDGER_TARBALLS_FULL")

echo "Package size: $(ls -lh "$FINAL_DEB_ABS" | awk '{print $5}')"

# Quick file count check
FILE_COUNT=$(dpkg-deb -c "$FINAL_DEB_ABS" | grep -E "(config_.*\.json|${NETWORK_NAME}|.*ledger.*\.tar\.gz)" | wc -l)
echo "Files found (configs + network + ledgers): $FILE_COUNT"

# Count source ledger files
if [[ -d "$LEDGER_TARBALLS_ABS" ]]; then
	SOURCE_LEDGER_COUNT=$(ls -1 "$LEDGER_TARBALLS_ABS"/*.tar.gz 2>/dev/null | wc -l)
else
	SOURCE_LEDGER_COUNT=1
fi

# Expected: ledgers + config_*.json + network.json + network.old.json = at least SOURCE_LEDGER_COUNT + 3
EXPECTED_MIN=$((SOURCE_LEDGER_COUNT + 3))

if [[ $FILE_COUNT -lt $EXPECTED_MIN ]]; then
	echo "ERROR: Expected at least $EXPECTED_MIN files (${SOURCE_LEDGER_COUNT} ledgers + 3 configs), but found $FILE_COUNT" >&2
	echo "Listing package contents:" >&2
	dpkg-deb -c "$FINAL_DEB_ABS" | grep -E "(config_|ledger|${NETWORK_NAME})" >&2
	exit 1
fi

# Full SHA256 verification
echo ""
echo "=== SHA256 Verification ==="

VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_DIR"' EXIT

cd "$VERIFY_DIR"
ar x "$FINAL_DEB_ABS"
mkdir data
tar -xzf data.tar.gz -C data

# Verify runtime config file (config_*.json)
RUNTIME_CONFIG_HASH=$(sha256sum "$RUNTIME_CONFIG_JSON_ABS" | awk '{print $1}')

PKG_CONFIG=$(ls data/var/lib/coda/config_*.json 2>/dev/null | head -1)
if [[ -n "$PKG_CONFIG" ]]; then
	PKG_CONFIG_HASH=$(sha256sum "$PKG_CONFIG" | awk '{print $1}')
	if [[ "$PKG_CONFIG_HASH" == "$RUNTIME_CONFIG_HASH" ]]; then
		echo "✓ Config file verified: $(basename "$PKG_CONFIG")"
	else
		echo "ERROR: Config file hash mismatch!" >&2
		echo "  Expected: $RUNTIME_CONFIG_HASH" >&2
		echo "  Got:      $PKG_CONFIG_HASH" >&2
		exit 1
	fi
else
	echo "ERROR: No config file found in package!" >&2
	exit 1
fi

# Verify network config file
PKG_NETWORK_CONFIG="data/var/lib/coda/${NETWORK_NAME}.json"
if [[ -f "$PKG_NETWORK_CONFIG" ]]; then
	PKG_NETWORK_HASH=$(sha256sum "$PKG_NETWORK_CONFIG" | awk '{print $1}')
	if [[ "$PKG_NETWORK_HASH" == "$RUNTIME_CONFIG_HASH" ]]; then
		echo "✓ Network config verified: ${NETWORK_NAME}.json"
	else
		echo "ERROR: Network config hash mismatch!" >&2
		echo "  Expected: $RUNTIME_CONFIG_HASH" >&2
		echo "  Got:      $PKG_NETWORK_HASH" >&2
		exit 1
	fi
else
	echo "ERROR: Network config file not found: ${NETWORK_NAME}.json" >&2
	exit 1
fi

# Verify old network config exists
PKG_OLD_NETWORK_CONFIG="data/var/lib/coda/${NETWORK_NAME}.old.json"
if [[ -f "$PKG_OLD_NETWORK_CONFIG" ]]; then
	echo "✓ Backup network config verified: ${NETWORK_NAME}.old.json"
else
	echo "ERROR: Backup network config file not found: ${NETWORK_NAME}.old.json" >&2
	exit 1
fi

# Verify ledger files
LEDGER_ERROR=0
if [[ -d "$LEDGER_TARBALLS_ABS" ]]; then
	for SOURCE_LEDGER in "$LEDGER_TARBALLS_ABS"/*.tar.gz; do
		LEDGER_NAME=$(basename "$SOURCE_LEDGER")
		PKG_LEDGER="data/var/lib/coda/$LEDGER_NAME"

		if [[ ! -f "$PKG_LEDGER" ]]; then
			echo "ERROR: Ledger file missing in package: $LEDGER_NAME" >&2
			LEDGER_ERROR=1
			continue
		fi

		SOURCE_HASH=$(sha256sum "$SOURCE_LEDGER" | awk '{print $1}')
		PKG_HASH=$(sha256sum "$PKG_LEDGER" | awk '{print $1}')

		if [[ "$SOURCE_HASH" == "$PKG_HASH" ]]; then
			echo "✓ Ledger verified: $LEDGER_NAME"
		else
			echo "ERROR: Ledger file hash mismatch: $LEDGER_NAME" >&2
			echo "  Expected: $SOURCE_HASH" >&2
			echo "  Got:      $PKG_HASH" >&2
			LEDGER_ERROR=1
		fi
	done
else
	# Single file passed
	LEDGER_NAME=$(basename "$LEDGER_TARBALLS_ABS")
	PKG_LEDGER="data/var/lib/coda/$LEDGER_NAME"

	if [[ ! -f "$PKG_LEDGER" ]]; then
		echo "ERROR: Ledger file missing in package: $LEDGER_NAME" >&2
		LEDGER_ERROR=1
	else
		SOURCE_HASH=$(sha256sum "$LEDGER_TARBALLS_ABS" | awk '{print $1}')
		PKG_HASH=$(sha256sum "$PKG_LEDGER" | awk '{print $1}')

		if [[ "$SOURCE_HASH" == "$PKG_HASH" ]]; then
			echo "✓ Ledger verified: $LEDGER_NAME"
		else
			echo "ERROR: Ledger file hash mismatch: $LEDGER_NAME" >&2
			echo "  Expected: $SOURCE_HASH" >&2
			echo "  Got:      $PKG_HASH" >&2
			LEDGER_ERROR=1
		fi
	fi
fi

cd - > /dev/null

if [[ $LEDGER_ERROR -ne 0 ]]; then
	exit 1
fi

echo ""
echo "=== Verification Complete ==="
echo "All files verified successfully!"

echo ""
echo "=== Hardfork Package Creation Complete ==="
echo "Output: $OUTPUT_DEB_FILE"
echo "Package name: $NEW_PACKAGE_NAME"
