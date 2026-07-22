#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# run-deb-session-tests.sh
# ------------------------------------------------------------------------------
# Integration tests for the deb-session operations, covering:
#   - Opening a Debian package into a session directory
#   - Inserting files (directory and file targets)
#   - Moving files within the session
#   - Replacing files matching a glob pattern
#   - Removing files matching a glob pattern
#   - Replacing the version (reversion)
#   - Replacing the suite
#   - Renaming the package
#   - Saving the session back to a .deb and verifying its contents
#
# The suite runs against one of two interchangeable engines, selected by the
# SESSION_ENGINE env var:
#
#   bash         (default) — the scripts/debian/session/deb-session-*.sh scripts
#   deb-toolkit            — `deb-toolkit session <verb>` (binary on PATH, or
#                            $DEB_TOOLKIT)
#
# Both engines expose the same verbs with the same argument order and produce
# the same session-directory layout, so the assertions below are shared. This
# is what makes the suite a parity gate: the same script, run once per engine
# (in CI, bash in the toolchain image and deb-toolkit in the release-toolkit
# image), must reach identical conclusions.
#
# Control-field assertions run against the *saved* .deb via `dpkg-deb --field`
# (which normalizes constraint spacing) rather than the raw session control
# file, so the two engines' cosmetic differences — e.g. `(>=X)` vs `(>= X)` —
# do not cause spurious failures.
# ------------------------------------------------------------------------------

set -eux -o pipefail

TEST_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
SESSION_SCRIPTS_DIR="$(realpath "$TEST_DIR/..")"

SESSION_ENGINE="${SESSION_ENGINE:-bash}"
DEB_TOOLKIT="${DEB_TOOLKIT:-deb-toolkit}"

log() {
  echo "[deb-session-test][$SESSION_ENGINE] $*"
}

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

assert_file_equals() {
  local path="$1" expected="$2" actual
  actual="$(cat "$path")"
  if [[ "$actual" != "$expected" ]]; then
    fail "File $path does not match expected contents. Got: '$actual'"
  fi
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "Expected $1 to be absent"
}

assert_exists() {
  [[ -e "$1" ]] || fail "Expected $1 to exist"
}

# Assert that a `dpkg-deb --field` value contains a substring. Reads the saved
# .deb, so constraint spacing is already normalized by dpkg.
assert_field_contains() {
  local deb="$1" field="$2" needle="$3" value
  value="$(dpkg-deb --field "$deb" "$field")"
  if [[ "$value" != *"$needle"* ]]; then
    fail "Field $field of $deb missing '$needle'. Got: '$value'"
  fi
}

assert_field_equals() {
  local deb="$1" field="$2" expected="$3" value
  value="$(dpkg-deb --field "$deb" "$field")"
  if [[ "$value" != "$expected" ]]; then
    fail "Field $field of $deb expected '$expected', got '$value'"
  fi
}

WORKDIR="$(mktemp -d -t deb-session-test-XXXXXX)"
cleanup() { rm -rf "$WORKDIR"; }
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

echo "ledger-original" > "$PKG_DIR/var/lib/coda/ledger.dat"
echo "config-one" > "$PKG_DIR/var/lib/coda/config_1.json"
echo "config-two" > "$PKG_DIR/var/lib/coda/config_2.json"
echo "devnet-config" > "$PKG_DIR/var/lib/coda/devnet.json"
echo "node-config" > "$PKG_DIR/etc/mina/node.json"

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
# Insert files into a directory target (explicit -d works on both engines)
# ------------------------------------------------------------------------------
log "Testing insert (directory target)"
INSERT_FILE1="$WORKDIR/new-ledger1.tar.gz"
INSERT_FILE2="$WORKDIR/new-ledger2.tar.gz"
echo "ledger-one" > "$INSERT_FILE1"
echo "ledger-two" > "$INSERT_FILE2"

session_verb insert -d "$SESSION_DIR" "/var/lib/coda" "$INSERT_FILE1" "$INSERT_FILE2"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz" "ledger-one"
assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz" "ledger-two"

# ------------------------------------------------------------------------------
# Insert a file into a file target
# ------------------------------------------------------------------------------
log "Testing insert (file target)"
FILE_DEST_SOURCE="$WORKDIR/new-config.json"
echo '{"inserted":true}' > "$FILE_DEST_SOURCE"
session_verb insert "$SESSION_DIR" "/etc/mina/override.json" "$FILE_DEST_SOURCE"

assert_file_equals "$SESSION_DIR/data/etc/mina/override.json" '{"inserted":true}'

# ------------------------------------------------------------------------------
# Move a file within the session
# ------------------------------------------------------------------------------
log "Testing move"
session_verb move "$SESSION_DIR" \
  "/var/lib/coda/new-ledger1.tar.gz" "/var/lib/coda/moved-ledger.tar.gz"

assert_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz"

# ------------------------------------------------------------------------------
# Replace files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing replace"
REPLACEMENT_FILE="$WORKDIR/replacement.json"
echo 'replaced' > "$REPLACEMENT_FILE"
session_verb replace "$SESSION_DIR" "/var/lib/coda/config_*.json" "$REPLACEMENT_FILE"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_2.json" 'replaced'

# ------------------------------------------------------------------------------
# Remove files matching a glob pattern
# ------------------------------------------------------------------------------
log "Testing remove"
session_verb remove "$SESSION_DIR" "/var/lib/coda/*.tar.gz"

assert_not_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz"

# ------------------------------------------------------------------------------
# Reversion (no flag): both engines rewrite the version everywhere it is pinned
# ------------------------------------------------------------------------------
log "Testing reversion"
session_verb reversion "$SESSION_DIR" "2.0.0-rc1"

# ------------------------------------------------------------------------------
# Replace the suite
# ------------------------------------------------------------------------------
log "Testing replace-suite"
session_verb replace-suite "$SESSION_DIR" "stable"

# ------------------------------------------------------------------------------
# Rename the package
# ------------------------------------------------------------------------------
log "Testing rename-package"
session_verb rename-package "$SESSION_DIR" "mina-devnet-hardfork"

# ------------------------------------------------------------------------------
# Save the session back to a .deb, then assert control + contents on the artifact
# ------------------------------------------------------------------------------
log "Testing save"
OUTPUT_DEB="$WORKDIR/output.deb"
session_verb save "$SESSION_DIR" "$OUTPUT_DEB" --verify

# Control fields — read from the saved .deb so constraint spacing is normalized.
assert_field_equals "$OUTPUT_DEB" Package "mina-devnet-hardfork"
assert_field_equals "$OUTPUT_DEB" Version "2.0.0-rc1"
assert_field_equals "$OUTPUT_DEB" Suite "stable"

# Every versioned constraint that pinned the old version now tracks the new one.
assert_field_contains "$OUTPUT_DEB" Depends "mina-devnet-config (>= 2.0.0-rc1)"
assert_field_contains "$OUTPUT_DEB" Replaces "mina-devnet (<< 2.0.0-rc1)"
assert_field_contains "$OUTPUT_DEB" Breaks "mina-devnet (<< 2.0.0-rc1)"
assert_field_contains "$OUTPUT_DEB" Conflicts "mina-devnet (<< 2.0.0-rc1)"

# Non-versioned dependencies are left untouched.
assert_field_contains "$OUTPUT_DEB" Depends "libssl1.1"
assert_field_contains "$OUTPUT_DEB" Depends "libffi7"

# Data contents survived the mutations.
EXTRACT_DIR="$WORKDIR/extracted"
mkdir -p "$EXTRACT_DIR"
dpkg-deb -x "$OUTPUT_DEB" "$EXTRACT_DIR"

assert_file_equals "$EXTRACT_DIR/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$EXTRACT_DIR/etc/mina/override.json" '{"inserted":true}'
assert_not_exists "$EXTRACT_DIR/var/lib/coda/moved-ledger.tar.gz"

log "All deb-session operations executed and verified successfully"
