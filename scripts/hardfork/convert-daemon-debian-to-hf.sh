#!/bin/bash

# Script to convert an existing mina-daemon Debian package into a hardfork-specific package
# by replacing its runtime configuration and ledger files.
#
# Debian naming scheme for mina daemon packages:
#   mina-${NETWORK}-${PROFILE_OR_GENERAL_SUFFIX}
#
# Where:
#   NETWORK: mainnet, devnet, berkeley, testnet-agnostic
#   PROFILE: devnet, mainnet, dev, lightnet
#   SUFFIX:  hardfork (used to differentiate from standard daemon)

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
FILE_BASE_NAME="${DEB_BASE%%_*}"

# Remove any existing -hardfork suffixes from the base name
if [[ "$FILE_BASE_NAME" == *-hardfork ]]; then
	echo "Note: Input package is a hardfork package already. Removing existing -hardfork suffix from base name"
	FILE_BASE_NAME="${FILE_BASE_NAME%-hardfork}"
fi

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
echo "=== Step 1: Opening Debian Package for modification ==="
./scripts/debian/session/deb-session-open.sh "$DEB_FILE_ABS" "$SESSION_DIR"

# Insert new runtime config as the network config
echo ""
echo "=== Step 2: Inserting new runtime config as ${NETWORK_NAME}.json ==="
./scripts/debian/session/deb-session-insert.sh "$SESSION_DIR" \
    "/var/lib/coda/${NETWORK_NAME}.json" \
    "$RUNTIME_CONFIG_JSON_ABS"

# Replace config_*.json with runtime config
echo ""
echo "=== Step 3: Replacing config_*.json with new runtime config ==="
./scripts/debian/session/deb-session-replace.sh "$SESSION_DIR" \
    "/var/lib/coda/config_*.json" \
    "$RUNTIME_CONFIG_JSON_ABS"

# Remove existing ledger tarballs before adding new ones
echo ""
echo "=== Step 4: Removing existing ledger tarballs ==="
./scripts/debian/session/deb-session-remove.sh "$SESSION_DIR" \
    "/var/lib/coda/*.tar.gz" || echo "No existing ledger tarballs to remove"

# Insert ledger tarballs
echo ""
echo "=== Step 5: Inserting new ledger tarballs ==="

if [[ ! -d "$LEDGER_TARBALLS_FULL" ]]; then
	echo "ERROR: Ledger tarballs path must be a directory containing exactly 3 files: genesis_ledger, and two epoch ledgers" >&2
	exit 1
fi

# Check for required ledgers: genesis_ledger (1), epoch (2)

# Check genesis_ledger
GENESIS_MATCHES=("$LEDGER_TARBALLS_FULL/genesis_ledger"*.tar.gz)
if [[ ! -f "${GENESIS_MATCHES[0]}" ]]; then
    echo "ERROR: Missing required ledger tarball with prefix: genesis_ledger in $LEDGER_TARBALLS_FULL" >&2
    exit 1
fi
# Check epoch (must have 2)
EPOCH_MATCHES=("$LEDGER_TARBALLS_FULL/epoch"*.tar.gz)
if [[ ${#EPOCH_MATCHES[@]} -ne 2 ]]; then
    echo "ERROR: Expected 2 ledger tarballs with prefix: epoch in $LEDGER_TARBALLS_FULL, found ${#EPOCH_MATCHES[@]}" >&2
    exit 1
fi

# Use the actual matched filenames for genesis_ledger and epoch tarballs
TARBALL_FILES=("${GENESIS_MATCHES[0]}" "${EPOCH_MATCHES[0]}" "${EPOCH_MATCHES[1]}")
./scripts/debian/session/deb-session-insert.sh "$SESSION_DIR" "/var/lib/coda/" "${TARBALL_FILES[@]}"

# Rename package to add -hardfork suffix
echo ""
echo "=== Step 6: Renaming package to add -hardfork suffix ==="
NEW_PACKAGE_NAME="${FILE_BASE_NAME}-hardfork"

./scripts/debian/session/deb-session-rename-package.sh "$SESSION_DIR" "$NEW_PACKAGE_NAME"

# Save the modified package
echo ""
echo "=== Step 7: Saving modified package ==="
./scripts/debian/session/deb-session-save.sh "$SESSION_DIR" "$OUTPUT_DEB_FILE" --verify

# Verify the final package contents
echo ""
echo "=== Step 8: Final Verification (SHA256 checksums and file counts) ==="

FINAL_DEB_ABS=$(readlink -f "$OUTPUT_DEB_FILE")
LEDGER_TARBALLS_ABS=$(readlink -f "$LEDGER_TARBALLS_FULL")

echo "Package size: $(ls -lh "$FINAL_DEB_ABS" | awk '{print $5}')"

# List all files in the package for debuggability
echo "Listing all files in the package:"
dpkg-deb -c "$FINAL_DEB_ABS"

# Full file content verification
echo ""
echo "=== File Content Verification ==="

VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$SESSION_DIR" "$VERIFY_DIR"' EXIT

pushd "$VERIFY_DIR" > /dev/null
ar x "$FINAL_DEB_ABS"
mkdir data
tar -xzf data.tar.gz -C data

# Verify runtime config file (config_*.json)
PKG_CONFIG=$(ls data/var/lib/coda/config_*.json 2>/dev/null | head -1)
if [[ -n "$PKG_CONFIG" ]]; then
	if cmp -s "$PKG_CONFIG" "$RUNTIME_CONFIG_JSON_ABS"; then
		echo "✓ Config file verified: $(basename "$PKG_CONFIG")"
	else
		echo "ERROR: Config file content mismatch!" >&2
		exit 1
	fi
else
	echo "ERROR: No config file found in package!" >&2
	exit 1
fi

# Verify network config file
PKG_NETWORK_CONFIG="data/var/lib/coda/${NETWORK_NAME}.json"
if [[ -f "$PKG_NETWORK_CONFIG" ]]; then
	if cmp -s "$PKG_NETWORK_CONFIG" "$RUNTIME_CONFIG_JSON_ABS"; then
		echo "✓ Network config verified: ${NETWORK_NAME}.json"
	else
		echo "ERROR: Network config content mismatch!" >&2
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

		if cmp -s "$SOURCE_LEDGER" "$PKG_LEDGER"; then
			echo "✓ Ledger verified: $LEDGER_NAME"
		else
			echo "ERROR: Ledger file content mismatch: $LEDGER_NAME" >&2
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
		if cmp -s "$LEDGER_TARBALLS_ABS" "$PKG_LEDGER"; then
			echo "✓ Ledger verified: $LEDGER_NAME"
		else
			echo "ERROR: Ledger file content mismatch: $LEDGER_NAME" >&2
			LEDGER_ERROR=1
		fi
	fi
fi

popd > /dev/null

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
