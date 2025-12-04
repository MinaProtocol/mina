#!/bin/bash

set -e

usage() {
	echo "Usage: $0 -d <deb_file> -c <runtime_config_json> -l <ledger_tarballs>"
	echo "  -d <deb_file>            Path to mina-daemon.deb file"
	echo "  -c <runtime_config_json> Path to runtime config JSON file"
	echo "  -l <ledger_tarballs>     Path to ledger tarballs"
	exit 1
}

while getopts "d:c:l:" opt; do
	case $opt in
		d) DEB_FILE="$OPTARG" ;;
		c) RUNTIME_CONFIG_JSON="$OPTARG" ;;
		l) LEDGER_TARBALLS="$OPTARG" ;;
		*) usage ;;
	esac
done


if [[ -z "$DEB_FILE" || -z "$RUNTIME_CONFIG_JSON" || -z "$LEDGER_TARBALLS" ]]; then
    usage
fi

# Evaluate full path to LEDGER_TARBALLS
LEDGER_TARBALLS_FULL=$(readlink -f "$LEDGER_TARBALLS")

# Fail if LEDGER_TARBALLS_FULL does not exist
if [[ ! -e "$LEDGER_TARBALLS_FULL" ]]; then
	echo "Error: Ledger tarballs path '$LEDGER_TARBALLS_FULL' does not exist." >&2
	exit 1
fi

# Step 1: Replace runtime config
./scripts/debian/replace-entry.sh "$DEB_FILE" /var/lib/coda/config_*.json "$RUNTIME_CONFIG_JSON"

# Step 2: Insert ledger tarballs (operates on the patched deb from step 1)
PATCHED_DEB="${DEB_FILE%.deb}-patched.deb"
./scripts/debian/insert-entries.sh "$PATCHED_DEB" /var/lib/coda/ "$LEDGER_TARBALLS_FULL"

# Step 3: Rename the package (operates on the patched deb from step 2)
# insert-entries.sh creates another -patched.deb, so we have -patched-patched.deb
PATCHED_DEB2="${PATCHED_DEB%.deb}-patched.deb"
./scripts/debian/rename.sh "$PATCHED_DEB2" "mina-daemon-hardfork"

# Step 4: Verify the final package
echo ""
echo "=== Verifying Final Package ==="

FINAL_DEB="mina-daemon-hardfork.deb"

if [[ ! -f "$FINAL_DEB" ]]; then
	echo "ERROR: Final package '$FINAL_DEB' not found" >&2
	exit 1
fi

# Resolve absolute paths BEFORE changing directories
ORIG_DIR=$(pwd)
FINAL_DEB_ABS=$(readlink -f "$FINAL_DEB")
RUNTIME_CONFIG_ABS=$(readlink -f "$RUNTIME_CONFIG_JSON")
LEDGER_TARBALLS_ABS=$(readlink -f "$LEDGER_TARBALLS_FULL")

echo "Package size: $(ls -lh "$FINAL_DEB" | awk '{print $5}')"

# Quick file count check
FILE_COUNT=$(dpkg-deb -c "$FINAL_DEB_ABS" | grep -E "(config_.*\.json|.*ledger.*\.tar\.gz)" | wc -l)
echo "Files found (config + ledgers): $FILE_COUNT"

# Count source ledger files
if [[ -d "$LEDGER_TARBALLS_ABS" ]]; then
	SOURCE_LEDGER_COUNT=$(ls -1 "$LEDGER_TARBALLS_ABS"/*.tar.gz 2>/dev/null | wc -l)
else
	SOURCE_LEDGER_COUNT=$(ls -1 "$LEDGER_TARBALLS_ABS" 2>/dev/null | wc -l)
fi

EXPECTED_MIN=$((SOURCE_LEDGER_COUNT + 1))  # ledgers + at least 1 config

if [[ $FILE_COUNT -lt $EXPECTED_MIN ]]; then
	echo "ERROR: Expected at least $EXPECTED_MIN files (${SOURCE_LEDGER_COUNT} ledgers + configs), but found $FILE_COUNT" >&2
	echo "Listing package contents:" >&2
	dpkg-deb -c "$FINAL_DEB_ABS" | grep -E "(config_|ledger)" >&2
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

# Verify config file
RUNTIME_CONFIG_HASH=$(sha256sum "$RUNTIME_CONFIG_ABS" | awk '{print $1}')

# Find the config file in the package (it may have been renamed)
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

cd "$ORIG_DIR"

if [[ $LEDGER_ERROR -ne 0 ]]; then
	exit 1
fi

echo ""
echo "=== Verification Complete ==="
echo "All files verified successfully!"
echo "Output: $FINAL_DEB"

mv "$FINAL_DEB" "$DEB_FILE"