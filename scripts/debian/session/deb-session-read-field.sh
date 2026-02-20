#!/usr/bin/env bash

set -eux -o pipefail

# Source common functions
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/deb-session-common.sh"

usage() {
  cat <<EOF
Usage: $0 <session-dir> <field-name>

Reads a field value from the Debian package control file.

Arguments:
  <session-dir>         Session directory created by deb-session-open.sh
  <field-name>          Control file field name (e.g., "Package", "Version", "Architecture", "Suite")

Example:
  $0 ./my-session Package
  $0 ./my-session Version

Output:
  Prints the field value to stdout. Exits with error if field is not found.
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

SESSION_DIR="$1"
FIELD_NAME="$2"

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

VALUE=$(grep "^${FIELD_NAME}:" "$CONTROL_FILE" | head -1 | sed "s/^${FIELD_NAME}: *//" || true)

if [[ -z "$VALUE" ]]; then
  echo "ERROR: Field '$FIELD_NAME' not found in control file" >&2
  exit 1
fi

echo "$VALUE"
