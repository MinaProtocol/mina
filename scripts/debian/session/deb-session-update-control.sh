#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 <session-dir> <field-name> <new-value>

Updates a field in the Debian control file within a session.

Arguments:
  <session-dir>  Session directory created by deb-session-open.sh
  <field-name>   Name of the control field to update (e.g., Version, Package, Suite)
  <new-value>    New value for the field

Examples:
  # Update package version
  $0 ./my-session Version 2.0.0-rc1

  # Update package name
  $0 ./my-session Package mina-devnet-hardfork

  # Update suite
  $0 ./my-session Suite unstable

  # Update maintainer
  $0 ./my-session Maintainer "New Maintainer <email@example.com>"

  # Add or update custom field
  $0 ./my-session Custom-Field "custom value"

Notes:
  - Field names are case-sensitive (Version, not version)
  - If the field exists, it will be updated
  - If the field doesn't exist, it will be added at the end of the control file
  - Multi-line fields (like Description) are not fully supported by this script
  - For complex control file modifications, edit the control file directly
EOF
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
FIELD_NAME="$2"
NEW_VALUE="$3"

# Validate session
validate_session "$SESSION_DIR"

CONTROL_FILE="$SESSION_DIR_ABS/control/control"

if [[ ! -f "$CONTROL_FILE" ]]; then
  echo "ERROR: Control file not found: $CONTROL_FILE" >&2
  exit 1
fi

# Validate field name (should not contain colons, newlines, or other special chars)
if [[ "$FIELD_NAME" =~ [^a-zA-Z0-9_-] ]]; then
  echo "ERROR: Invalid field name: $FIELD_NAME" >&2
  echo "Field names should only contain letters, numbers, hyphens, and underscores" >&2
  exit 1
fi

echo "=== Updating Control File Field ==="
echo "Session: $SESSION_DIR_ABS"
echo "Field:   $FIELD_NAME"
echo "Value:   $NEW_VALUE"

# Check if the field exists in the control file
if grep -q "^${FIELD_NAME}: " "$CONTROL_FILE"; then
  # Field exists, update it
  # Use a more robust sed pattern that handles special characters in the new value
  # We need to escape the new value for sed
  ESCAPED_NEW_VALUE=$(printf '%s\n' "$NEW_VALUE" | sed -e 's/[\/&]/\\&/g')

  sed -i "s/^${FIELD_NAME}: .*$/${FIELD_NAME}: ${ESCAPED_NEW_VALUE}/" "$CONTROL_FILE"

  echo "✓ Updated existing field: $FIELD_NAME"
else
  # Field doesn't exist, add it at the end
  echo "${FIELD_NAME}: ${NEW_VALUE}" >> "$CONTROL_FILE"

  echo "✓ Added new field: $FIELD_NAME"
fi

echo ""
echo "=== Control File Updated Successfully ==="
