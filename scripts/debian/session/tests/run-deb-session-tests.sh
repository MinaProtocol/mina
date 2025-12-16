#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# run-deb-session-tests.sh
# ------------------------------------------------------------------------------
# This script runs a suite of integration tests for the deb-session scripts,
# which provide a session-based interface for manipulating Debian packages.
#
# The tests cover the following operations:
#   - Opening a Debian package into a session directory
#   - Inserting files into the session (directory and file targets)
#   - Moving files within the session
#   - Replacing files matching a glob pattern
#   - Removing files matching a glob pattern
#   - Renaming the package
#   - Saving the session back to a .deb file and verifying its contents
#
# Each test step uses assert functions to verify correctness, and the script
# will exit with an error if any assertion fails.
# ------------------------------------------------------------------------------

set -euo pipefail

# Determine the directory of this test script and the session scripts directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_SCRIPTS_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Log a message with a test prefix
log() {
  echo "[deb-session-test] $*"
}

# Print an error message and exit
fail() {
  echo "[deb-session-test][ERROR] $*" >&2
  exit 1
}

# Assert that a file's contents match the expected string
assert_file_equals() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(cat "$path")"
  if [[ "$actual" != "$expected" ]]; then
    fail "File $path does not match expected contents. Got: '$actual'"
  fi
}

# Assert that a file or directory does not exist
assert_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    fail "Expected $path to be absent"
  fi
}

# Assert that a file or directory exists
assert_exists() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    fail "Expected $path to exist"
  fi
}

# Create a temporary working directory for the test session
WORKDIR="$(mktemp -d -t deb-session-test-XXXXXX)"
# Ensure cleanup on exit
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Create a sample Debian package for testing
# ------------------------------------------------------------------------------
log "Creating sample Debian package"
PKG_DIR="$WORKDIR/sample"
mkdir -p "$PKG_DIR/DEBIAN" "$PKG_DIR/var/lib/coda" "$PKG_DIR/etc/mina"

cat > "$PKG_DIR/DEBIAN/control" <<'EOF'
Package: mina-devnet
Version: 1.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Mina Protocol <test@example.com>
Description: Sample package for deb-session tests
EOF

# Populate the package with some files
echo "ledger-original" > "$PKG_DIR/var/lib/coda/ledger.dat"
echo "config-one" > "$PKG_DIR/var/lib/coda/config_1.json"
echo "config-two" > "$PKG_DIR/var/lib/coda/config_2.json"
echo "devnet-config" > "$PKG_DIR/var/lib/coda/devnet.json"
echo "node-config" > "$PKG_DIR/etc/mina/node.json"

# Build the .deb package
INPUT_DEB="$WORKDIR/input.deb"
dpkg-deb --build "$PKG_DIR" "$INPUT_DEB" >/dev/null

# ------------------------------------------------------------------------------
# Open the package into a session directory
# ------------------------------------------------------------------------------
SESSION_DIR="$WORKDIR/session"
"$SESSION_SCRIPTS_DIR/deb-session-open.sh" "$INPUT_DEB" "$SESSION_DIR"

assert_exists "$SESSION_DIR/metadata.env"
assert_exists "$SESSION_DIR/control/control"
assert_exists "$SESSION_DIR/data/var/lib/coda/ledger.dat"
assert_exists "$SESSION_DIR/data/etc/mina/node.json"
assert_exists "$SESSION_DIR/data/var/lib/coda/config_1.json"
assert_exists "$SESSION_DIR/data/var/lib/coda/config_2.json"
assert_exists "$SESSION_DIR/data/var/lib/coda/devnet.json"

# ------------------------------------------------------------------------------
# Test inserting files into a directory target
# ------------------------------------------------------------------------------
log "Testing deb-session-insert.sh (directory target)"
INSERT_FILE1="$WORKDIR/new-ledger1.tar.gz"
INSERT_FILE2="$WORKDIR/new-ledger2.tar.gz"
echo "ledger-one" > "$INSERT_FILE1"
echo "ledger-two" > "$INSERT_FILE2"

# Insert two files into /var/lib/coda/ in the session
"$SESSION_SCRIPTS_DIR/deb-session-insert.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/" \
  "$INSERT_FILE1" "$INSERT_FILE2"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz" "ledger-one"
assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz" "ledger-two"

# ------------------------------------------------------------------------------
# Test inserting a file into a file target
# ------------------------------------------------------------------------------
log "Testing deb-session-insert.sh (file target)"
FILE_DEST_SOURCE="$WORKDIR/new-config.json"
echo '{"inserted":true}' > "$FILE_DEST_SOURCE"
"$SESSION_SCRIPTS_DIR/deb-session-insert.sh" \
  "$SESSION_DIR" \
  "/etc/mina/override.json" \
  "$FILE_DEST_SOURCE"

assert_file_equals "$SESSION_DIR/data/etc/mina/override.json" '{"inserted":true}'

# ------------------------------------------------------------------------------
# Test moving a file within the session
# ------------------------------------------------------------------------------
log "Testing deb-session-move.sh"
"$SESSION_SCRIPTS_DIR/deb-session-move.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/new-ledger1.tar.gz" \
  "/var/lib/coda/moved-ledger.tar.gz"

assert_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz"

# ------------------------------------------------------------------------------
# Test replacing files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing deb-session-replace.sh"
REPLACEMENT_FILE="$WORKDIR/replacement.json"
echo 'replaced' > "$REPLACEMENT_FILE"
"$SESSION_SCRIPTS_DIR/deb-session-replace.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/config_*.json" \
  "$REPLACEMENT_FILE"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_2.json" 'replaced'

# ------------------------------------------------------------------------------
# Test removing files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing deb-session-remove.sh"
"$SESSION_SCRIPTS_DIR/deb-session-remove.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/*.tar.gz"

assert_not_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz"

# ------------------------------------------------------------------------------
# Test renaming the package
# ------------------------------------------------------------------------------
log "Testing deb-session-rename-package.sh"
"$SESSION_SCRIPTS_DIR/deb-session-rename-package.sh" \
  "$SESSION_DIR" \
  "mina-devnet-hardfork"

# Verify the control file was updated
grep -q '^Package: mina-devnet-hardfork$' "$SESSION_DIR/control/control" \
  || fail "control file not updated with new package name"

# ------------------------------------------------------------------------------
# Test saving the session back to a .deb and verifying contents
# ------------------------------------------------------------------------------
log "Testing deb-session-save.sh"
OUTPUT_DEB="$WORKDIR/output.deb"
"$SESSION_SCRIPTS_DIR/deb-session-save.sh" "$SESSION_DIR" "$OUTPUT_DEB" --verify

NEW_PACKAGE_NAME="$(dpkg-deb --field "$OUTPUT_DEB" Package)"
if [[ "$NEW_PACKAGE_NAME" != "mina-devnet-hardfork" ]]; then
  fail "Saved package has unexpected name: $NEW_PACKAGE_NAME"
fi

# Extract the resulting .deb and verify its contents
EXTRACT_DIR="$WORKDIR/extracted"
mkdir -p "$EXTRACT_DIR"
dpkg-deb -x "$OUTPUT_DEB" "$EXTRACT_DIR" >/dev/null

assert_file_equals "$EXTRACT_DIR/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$EXTRACT_DIR/etc/mina/override.json" '{"inserted":true}'
assert_not_exists "$EXTRACT_DIR/var/lib/coda/moved-ledger.tar.gz"

log "All deb-session scripts executed successfully"
