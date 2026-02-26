#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 <session-dir> <new-version>

Replaces the Version field in the Debian package control file.

Arguments:
  <session-dir>         Session directory created by deb-session-open.sh
  <new-version>         New version string (e.g., "2.0.0-rc1")

Example:
  # Change package version
  $0 ./my-session 2.0.0-rc1

Notes:
  - Only modifies the Version: field in the control file
  - Package name, architecture, and all other metadata remain unchanged
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
NEW_VERSION="$2"

# Validate session directory
validate_session "$SESSION_DIR"

# Validate control directory
CONTROL_DIR=$(get_session_control_dir "$SESSION_DIR_ABS")
if [[ ! -d "$CONTROL_DIR" ]]; then
  echo "ERROR: Session control directory not found. Session corrupted?" >&2
  exit 1
fi

CONTROL_FILE="$CONTROL_DIR/control"
if [[ ! -f "$CONTROL_FILE" ]]; then
  echo "ERROR: Control file not found: $CONTROL_FILE" >&2
  exit 1
fi

echo "=== Replacing Version ==="
echo "Session: $SESSION_DIR_ABS"

# Get current version
OLD_VERSION=$(grep '^Version:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ -z "$OLD_VERSION" ]]; then
  echo "ERROR: No Version field found in control file" >&2
  exit 1
fi

echo "Current: $OLD_VERSION"
echo "New:     $NEW_VERSION"

# Check if already has the target version
if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
  echo "Package already has the target version. Nothing to do."
  exit 0
fi

# Update the Version field
sed -i "s/^Version: .*$/Version: $NEW_VERSION/" "$CONTROL_FILE"

# Verify the change
UPDATED_VERSION=$(grep '^Version:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ "$UPDATED_VERSION" != "$NEW_VERSION" ]]; then
  echo "ERROR: Failed to update Version field in control file" >&2
  echo "Expected: $NEW_VERSION" >&2
  echo "Got:      $UPDATED_VERSION" >&2
  exit 1
fi

echo "✓ Version replaced successfully"
echo ""
echo "Updated control file:"
grep -E "^(Package|Version|Architecture):" "$CONTROL_FILE" || true
