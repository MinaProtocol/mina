#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_SCRIPTS_DIR="$(cd "$TEST_DIR/.." && pwd)"

log() {
  echo "[deb-session-test] $*"
}

fail() {
  echo "[deb-session-test][ERROR] $*" >&2
  exit 1
}

assert_file_equals() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(cat "$path")"
  if [[ "$actual" != "$expected" ]]; then
    fail "File $path does not match expected contents. Got: '$actual'"
  fi
}

assert_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    fail "Expected $path to be absent"
  fi
}

assert_exists() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    fail "Expected $path to exist"
  fi
}

WORKDIR="$(mktemp -d -t deb-session-test-XXXXXX)"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

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

echo "ledger-original" > "$PKG_DIR/var/lib/coda/ledger.dat"
echo "config-one" > "$PKG_DIR/var/lib/coda/config_1.json"
echo "config-two" > "$PKG_DIR/var/lib/coda/config_2.json"
echo "devnet-config" > "$PKG_DIR/var/lib/coda/devnet.json"
echo "node-config" > "$PKG_DIR/etc/mina/node.json"

INPUT_DEB="$WORKDIR/input.deb"
dpkg-deb --build "$PKG_DIR" "$INPUT_DEB" >/dev/null

SESSION_DIR="$WORKDIR/session"
"$SESSION_SCRIPTS_DIR/deb-session-open.sh" "$INPUT_DEB" "$SESSION_DIR"

assert_exists "$SESSION_DIR/metadata.env"
assert_exists "$SESSION_DIR/control/control"
assert_exists "$SESSION_DIR/data/var/lib/coda/ledger.dat"

log "Testing deb-session-insert.sh (directory target)"
INSERT_FILE1="$WORKDIR/new-ledger1.tar.gz"
INSERT_FILE2="$WORKDIR/new-ledger2.tar.gz"
echo "ledger-one" > "$INSERT_FILE1"
echo "ledger-two" > "$INSERT_FILE2"

"$SESSION_SCRIPTS_DIR/deb-session-insert.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/" \
  "$INSERT_FILE1" "$INSERT_FILE2"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz" "ledger-one"
assert_file_equals "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz" "ledger-two"

log "Testing deb-session-insert.sh (file target)"
FILE_DEST_SOURCE="$WORKDIR/new-config.json"
echo '{"inserted":true}' > "$FILE_DEST_SOURCE"
"$SESSION_SCRIPTS_DIR/deb-session-insert.sh" \
  "$SESSION_DIR" \
  "/etc/mina/override.json" \
  "$FILE_DEST_SOURCE"

assert_file_equals "$SESSION_DIR/data/etc/mina/override.json" '{"inserted":true}'

log "Testing deb-session-move.sh"
"$SESSION_SCRIPTS_DIR/deb-session-move.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/new-ledger1.tar.gz" \
  "/var/lib/coda/moved-ledger.tar.gz"

assert_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger1.tar.gz"

log "Testing deb-session-replace.sh"
REPLACEMENT_FILE="$WORKDIR/replacement.json"
echo 'replaced' > "$REPLACEMENT_FILE"
"$SESSION_SCRIPTS_DIR/deb-session-replace.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/config_*.json" \
  "$REPLACEMENT_FILE"

assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$SESSION_DIR/data/var/lib/coda/config_2.json" 'replaced'

log "Testing deb-session-remove.sh"
"$SESSION_SCRIPTS_DIR/deb-session-remove.sh" \
  "$SESSION_DIR" \
  "/var/lib/coda/*.tar.gz"

assert_not_exists "$SESSION_DIR/data/var/lib/coda/moved-ledger.tar.gz"
assert_not_exists "$SESSION_DIR/data/var/lib/coda/new-ledger2.tar.gz"

log "Testing deb-session-rename-package.sh"
"$SESSION_SCRIPTS_DIR/deb-session-rename-package.sh" \
  "$SESSION_DIR" \
  "mina-devnet-hardfork"

grep -q '^Package: mina-devnet-hardfork$' "$SESSION_DIR/control/control" \
  || fail "control file not updated with new package name"

log "Testing deb-session-save.sh"
OUTPUT_DEB="$WORKDIR/output.deb"
"$SESSION_SCRIPTS_DIR/deb-session-save.sh" "$SESSION_DIR" "$OUTPUT_DEB" --verify

NEW_PACKAGE_NAME="$(dpkg-deb --field "$OUTPUT_DEB" Package)"
if [[ "$NEW_PACKAGE_NAME" != "mina-devnet-hardfork" ]]; then
  fail "Saved package has unexpected name: $NEW_PACKAGE_NAME"
fi

EXTRACT_DIR="$WORKDIR/extracted"
mkdir -p "$EXTRACT_DIR"
dpkg-deb -x "$OUTPUT_DEB" "$EXTRACT_DIR" >/dev/null

assert_file_equals "$EXTRACT_DIR/var/lib/coda/config_1.json" 'replaced'
assert_file_equals "$EXTRACT_DIR/etc/mina/override.json" '{"inserted":true}'
assert_not_exists "$EXTRACT_DIR/var/lib/coda/moved-ledger.tar.gz"

log "All deb-session scripts executed successfully"
