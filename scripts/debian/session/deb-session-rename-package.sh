#!/usr/bin/env bash

set -euox pipefail

usage() {
  cat <<EOF
Usage: $0 <session-dir> <new-package-name>

Renames the Debian package by updating the Package field in the control file.

Arguments:
  <session-dir>         Session directory created by deb-session-open.sh
  <new-package-name>    New package name (e.g., "mina-devnet-hardfork")

Example:
  # Rename package to add -hardfork suffix
  $0 ./my-session mina-devnet-hardfork

Notes:
  - Only modifies the Package: field in the control file
  - Version, architecture, and all other metadata remain unchanged
  - Package name must follow Debian naming conventions
  - Must start with lowercase letter or digit
  - Can contain lowercase letters, digits, plus, minus, and dots
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
NEW_PACKAGE_NAME="$2"

# Validate session directory
if [[ ! -d "$SESSION_DIR" ]]; then
  echo "ERROR: Session directory not found: $SESSION_DIR" >&2
  exit 1
fi

SESSION_DIR_ABS=$(readlink -f "$SESSION_DIR")

# Validate session
if [[ ! -d "$SESSION_DIR_ABS/control" ]]; then
  echo "ERROR: Session control directory not found. Invalid session?" >&2
  exit 1
fi

CONTROL_FILE="$SESSION_DIR_ABS/control/control"
if [[ ! -f "$CONTROL_FILE" ]]; then
  echo "ERROR: Control file not found: $CONTROL_FILE" >&2
  exit 1
fi

# Validate package name (Debian naming conventions)
if [[ ! "$NEW_PACKAGE_NAME" =~ ^[a-z0-9][a-z0-9+.-]+$ ]]; then
  echo "ERROR: Invalid package name: $NEW_PACKAGE_NAME" >&2
  echo "Package names must:" >&2
  echo "  - Start with a lowercase letter or digit" >&2
  echo "  - Contain only lowercase letters, digits, plus (+), minus (-), and dots (.)" >&2
  exit 1
fi

echo "=== Renaming Package ==="
echo "Session: $SESSION_DIR_ABS"

# Get current package name
OLD_PACKAGE_NAME=$(grep '^Package:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ -z "$OLD_PACKAGE_NAME" ]]; then
  echo "ERROR: No Package field found in control file" >&2
  exit 1
fi

echo "Current: $OLD_PACKAGE_NAME"
echo "New:     $NEW_PACKAGE_NAME"

# Check if already has the target name
if [[ "$OLD_PACKAGE_NAME" == "$NEW_PACKAGE_NAME" ]]; then
  echo "Package already has the target name. Nothing to do."
  exit 0
fi

# Update the Package field
sed -i "s/^Package: .*/Package: $NEW_PACKAGE_NAME/" "$CONTROL_FILE"

# Verify the change
UPDATED_PACKAGE_NAME=$(grep '^Package:' "$CONTROL_FILE" | awk '{print $2}' || true)

if [[ "$UPDATED_PACKAGE_NAME" != "$NEW_PACKAGE_NAME" ]]; then
  echo "ERROR: Failed to update Package field in control file" >&2
  echo "Expected: $NEW_PACKAGE_NAME" >&2
  echo "Got:      $UPDATED_PACKAGE_NAME" >&2
  exit 1
fi

echo "✓ Package renamed successfully"
echo ""
echo "Updated control file:"
grep -E "^(Package|Version|Architecture):" "$CONTROL_FILE" || true
