#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 <session-dir> <new-suite>

Replaces the Suite field in the Debian package control file.

Arguments:
  <session-dir>         Session directory created by deb-session-open.sh
  <new-suite>           New suite string (e.g., "stable", "unstable", "alpha")

Example:
  # Change package suite from unstable to stable
  $0 ./my-session stable

Notes:
  - Only modifies the Suite: field in the control file
  - If no Suite field exists, one will be added
  - Package name, version, and all other metadata remain unchanged
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
NEW_SUITE="$2"

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

echo "=== Replacing Suite ==="
echo "Session: $SESSION_DIR_ABS"

# Get current suite
OLD_SUITE=$(grep '^Suite:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ -z "$OLD_SUITE" ]]; then
  echo "No Suite field found in control file. Adding one."
  echo "Suite: $NEW_SUITE" >> "$CONTROL_FILE"
else
  echo "Current: $OLD_SUITE"
  echo "New:     $NEW_SUITE"

  # Check if already has the target suite
  if [[ "$OLD_SUITE" == "$NEW_SUITE" ]]; then
    echo "Package already has the target suite. Nothing to do."
    exit 0
  fi

  # Update the Suite field
  sed -i "s/^Suite: .*$/Suite: $NEW_SUITE/" "$CONTROL_FILE"
fi

# Verify the change
UPDATED_SUITE=$(grep '^Suite:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ "$UPDATED_SUITE" != "$NEW_SUITE" ]]; then
  echo "ERROR: Failed to update Suite field in control file" >&2
  echo "Expected: $NEW_SUITE" >&2
  echo "Got:      $UPDATED_SUITE" >&2
  exit 1
fi

echo "✓ Suite replaced successfully"
echo ""
echo "Updated control file:"
grep -E "^(Package|Version|Suite|Architecture):" "$CONTROL_FILE" || true
