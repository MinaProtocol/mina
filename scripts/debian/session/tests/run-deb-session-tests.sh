#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# run-deb-session-tests.sh
# ------------------------------------------------------------------------------
# This script runs a suite of integration tests for the deb-session operations,
# which provide a session-based interface for manipulating Debian packages.
#
# The tests cover the following operations:
#   - Opening a Debian package into a session directory
#   - Inserting files into the session (directory and file targets)
#   - Moving files within the session
#   - Replacing files matching a glob pattern
#   - Removing files matching a glob pattern
#   - Replacing the version (reversion)
#   - Replacing the suite
#   - Renaming the package
#   - Saving the session back to a .deb file and verifying its contents
#
# Each test step uses assert functions to verify correctness, and the script
# will exit with an error if any assertion fails.
#
# The suite runs against one of two interchangeable engines, selected by the
# SESSION_ENGINE env var:
#
#   bash          (default) — the scripts/debian/session/deb-session-*.sh scripts
#   deb-toolkit             — `deb-toolkit session <verb>` (binary on PATH, or
#                             $DEB_TOOLKIT)
#
# Both engines expose the same verbs with the same argument order and produce
# the same session-directory layout, so the assertions below are shared. Run
# once per engine (in CI, bash in the toolchain image and deb-toolkit in the
# release-toolkit image), and identical conclusions == parity.
# ------------------------------------------------------------------------------

set -eux -o pipefail

# Determine the directory of this test script and the session scripts directory
TEST_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
SESSION_SCRIPTS_DIR="$(realpath "$TEST_DIR/..")"

SESSION_ENGINE="${SESSION_ENGINE:-bash}"
DEB_TOOLKIT="${DEB_TOOLKIT:-deb-toolkit}"

# Log a message with a test prefix
log() {
  echo "[deb-session-test][$SESSION_ENGINE] $*"
}

# Print an error message and exit
fail() {
  echo "[deb-session-test][$SESSION_ENGINE][ERROR] $*" >&2
  exit 1
}

# Dispatch a session verb to the selected engine. Both engines take the verb's
# arguments in the same order, so this is a straight pass-through.
session_verb() {
  local verb="$1"
  shift
  case "$SESSION_ENGINE" in
    bash)
      "$SESSION_SCRIPTS_DIR/deb-session-${verb}.sh" "$@"
      ;;
    deb-toolkit)
      "$DEB_TOOLKIT" session "$verb" "$@"
      ;;
    *)
      fail "Unknown SESSION_ENGINE '$SESSION_ENGINE' (expected 'bash' or 'deb-toolkit')"
      ;;
  esac
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

# Assert that a control field, with all spaces removed, contains a needle.
# Dependency constraints render with engine-specific spacing — the bash scripts
# emit `(>=X)` while deb-toolkit emits the canonical `(>= X)` — so the raw text
# differs even when the meaning is identical. Comparing with spaces stripped
# makes the assertion depend on the value, not the whitespace. Pass the needle
# already space-free.
assert_control_field_contains() {
  local field="$1" needle="$2" value
  value="$(grep "^${field}:" "$SESSION_DIR/control/control" || true)"
  if [[ "${value// /}" != *"$needle"* ]]; then
    fail "$field does not contain '$needle' (got: $value)"
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
mkdir -p "$PKG_DIR"/{DEBIAN,var/lib/coda,etc/mina}

cat > "$PKG_DIR/DEBIAN/control" <<'EOF'
Package: mina-devnet
Version: 1.0
Section: utils
Priority: optional
Architecture: amd64
Suite: unstable
Maintainer: Mina Protocol <test@example.com>
Depends: libssl1.1, libffi7, mina-devnet-config (>=1.0)
Replaces: mina-devnet (<< 1.0)
Breaks: mina-devnet (<< 1.0)
Conflicts: mina-devnet (<< 1.0)
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
dpkg-deb --build "$PKG_DIR" "$INPUT_DEB"

# ------------------------------------------------------------------------------
# Open the package into a session directory
# ------------------------------------------------------------------------------
SESSION_DIR="$WORKDIR/session"
session_verb open "$INPUT_DEB" "$SESSION_DIR"

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
log "Testing insert (directory target)"
INSERT_FILE1="$WORKDIR/new-ledger1.tar.gz"
INSERT_FILE2="$WORKDIR/new-ledger2.tar.gz"
echo "ledger-one" > "$INSERT_FILE1"
echo "ledger-two" > "$INSERT_FILE2"

# Insert two files into /var/lib/coda/ in the session.
#
# The destination directory is given explicitly with -d, which both engines
# accept. The original test relied on a trailing slash to signal "directory"
# — a bash-only convention; deb-toolkit does not infer it and requires -d for a
# multi-source insert, so -d is used here for both.
session_verb insert -d \
  "$SESSION_DIR" \
  "/var/lib/coda" \
  "$INSERT_FILE1" "$INSERT_FILE2"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz" "ledger-one"
assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz" "ledger-two"

# ------------------------------------------------------------------------------
# Test inserting a file into a file target
# ------------------------------------------------------------------------------
log "Testing insert (file target)"
FILE_DEST_SOURCE="$WORKDIR/new-config.json"
echo '{"inserted":true}' > "$FILE_DEST_SOURCE"
session_verb insert \
  "$SESSION_DIR" \
  "/etc/mina/override.json" \
  "$FILE_DEST_SOURCE"

assert_file_equals "$SESSION_DIR/data/etc/mina/override.json" '{"inserted":true}'

# ------------------------------------------------------------------------------
# Test moving a file within the session
# ------------------------------------------------------------------------------
log "Testing move"
session_verb move \
  "$SESSION_DIR" \
  "/var/lib/coda/new-ledger1.tar.gz" \
  "/var/lib/coda/moved-ledger.tar.gz"

assert_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz"

# ------------------------------------------------------------------------------
# Test replacing files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing replace"
REPLACEMENT_FILE="$WORKDIR/replacement.json"
echo 'replaced' > "$REPLACEMENT_FILE"
session_verb replace \
  "$SESSION_DIR" \
  "/var/lib/coda/config_*.json" \
  "$REPLACEMENT_FILE"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_2.json" 'replaced'

# ------------------------------------------------------------------------------
# Test removing files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing remove"
session_verb remove \
  "$SESSION_DIR" \
  "/var/lib/coda/*.tar.gz"

assert_not_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz"

# ------------------------------------------------------------------------------
# Test replacing the version (reversion)
# ------------------------------------------------------------------------------
log "Testing reversion"
session_verb reversion \
  "$SESSION_DIR" \
  "2.0.0-rc1"

# Verify the control file was updated
CURRENT_VERSION=$(awk '/^Version:/ {print $2}' "$SESSION_DIR/control/control")
if [[ "$CURRENT_VERSION" != "2.0.0-rc1" ]]; then
  fail "control file not updated with new version (got: $CURRENT_VERSION)"
fi

# Verify versioned dependencies were updated (spacing-insensitive; see
# assert_control_field_contains)
assert_control_field_contains Depends   "mina-devnet-config(>=2.0.0-rc1)"
assert_control_field_contains Replaces  "mina-devnet(<<2.0.0-rc1)"
assert_control_field_contains Breaks    "mina-devnet(<<2.0.0-rc1)"
assert_control_field_contains Conflicts "mina-devnet(<<2.0.0-rc1)"

# Verify non-versioned dependencies were NOT changed
CURRENT_DEPENDS=$(grep '^Depends:' "$SESSION_DIR/control/control")
if [[ "$CURRENT_DEPENDS" != *"libssl1.1"* ]] || [[ "$CURRENT_DEPENDS" != *"libffi7"* ]]; then
  fail "Non-versioned dependencies were corrupted (got: $CURRENT_DEPENDS)"
fi

# ------------------------------------------------------------------------------
# Test replacing the suite
# ------------------------------------------------------------------------------
log "Testing replace-suite"
session_verb replace-suite \
  "$SESSION_DIR" \
  "stable"

# Verify the control file was updated
CURRENT_SUITE=$(awk '/^Suite:/ {print $2}' "$SESSION_DIR/control/control")
if [[ "$CURRENT_SUITE" != "stable" ]]; then
  fail "control file not updated with new suite (got: $CURRENT_SUITE)"
fi

# ------------------------------------------------------------------------------
# Test renaming the package
# ------------------------------------------------------------------------------
log "Testing rename-package"
session_verb rename-package \
  "$SESSION_DIR" \
  "mina-devnet-hardfork"

# Verify the control file was updated
PACKAGE_NAME=$(awk '/^Package:/ {print $2}' "$SESSION_DIR/control/control")
if [[ "$PACKAGE_NAME" != "mina-devnet-hardfork" ]]; then
  fail "control file not updated with new package name (got: $PACKAGE_NAME)"
fi

# ------------------------------------------------------------------------------
# Test saving the session back to a .deb and verifying contents
# ------------------------------------------------------------------------------
log "Testing save"
OUTPUT_DEB="$WORKDIR/output.deb"
session_verb save "$SESSION_DIR" "$OUTPUT_DEB" --verify

NEW_PACKAGE_NAME="$(dpkg-deb --field "$OUTPUT_DEB" Package)"
if [[ "$NEW_PACKAGE_NAME" != "mina-devnet-hardfork" ]]; then
  fail "Saved package has unexpected name: $NEW_PACKAGE_NAME"
fi

NEW_VERSION="$(dpkg-deb --field "$OUTPUT_DEB" Version)"
if [[ "$NEW_VERSION" != "2.0.0-rc1" ]]; then
  fail "Saved package has unexpected version: $NEW_VERSION"
fi

NEW_SUITE="$(dpkg-deb --field "$OUTPUT_DEB" Suite)"
if [[ "$NEW_SUITE" != "stable" ]]; then
  fail "Saved package has unexpected suite: $NEW_SUITE"
fi

# Extract the resulting .deb and verify its contents
EXTRACT_DIR="$WORKDIR/extracted"
mkdir -p "$EXTRACT_DIR"
dpkg-deb -x "$OUTPUT_DEB" "$EXTRACT_DIR"

assert_file_equals "$EXTRACT_DIR/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$EXTRACT_DIR/etc/mina/override.json" '{"inserted":true}'
assert_not_exists "$EXTRACT_DIR/var/lib/coda/moved-ledger.tar.gz"

log "All deb-session operations executed and verified successfully"
