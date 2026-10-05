#!/usr/bin/env bash

# Common functions for Debian package session scripts
set -eux -o pipefail

# Strips the leading slash from a path
# Usage: result=$(strip_leading_slash <path>)
strip_leading_slash() {
  local path="$1"
  echo "${path#/}"
}

# Validates that a session directory exists and is properly initialized
# Usage: validate_session <session-dir>
# Sets: SESSION_DIR_ABS (absolute path to session)
validate_session() {
  local session_dir="$1"

  if [[ ! -d "$session_dir" ]]; then
    echo "ERROR: Session directory not found: $session_dir" >&2
    echo "" >&2
    echo "You must first open a session using:" >&2
    echo "  deb-session-open.sh <input.deb> <session-dir>" >&2
    exit 1
  fi

  SESSION_DIR_ABS=$(readlink -f "$session_dir")

  if [[ ! -f "$SESSION_DIR_ABS/metadata.env" ]]; then
    echo "ERROR: Session metadata not found: $SESSION_DIR_ABS/metadata.env" >&2
    echo "" >&2
    echo "This doesn't appear to be a valid session directory." >&2
    echo "Open a session using:" >&2
    echo "  deb-session-open.sh <input.deb> <session-dir>" >&2
    exit 1
  fi

  if [[ ! -d "$SESSION_DIR_ABS/data" ]]; then
    echo "ERROR: Session data directory not found: $SESSION_DIR_ABS/data" >&2
    echo "Session appears to be corrupted." >&2
    exit 1
  fi
}

# Gets the data directory path for a session
# Usage: data_dir=$(get_session_data_dir <session-dir>)
get_session_data_dir() {
  local session_dir="$1"
  echo "$(readlink -f "$session_dir")/data"
}

# Gets the control directory path for a session
# Usage: control_dir=$(get_session_control_dir <session-dir>)
get_session_control_dir() {
  local session_dir="$1"
  echo "$(readlink -f "$session_dir")/control"
}

# Resolves a package path to the actual filesystem path in the session
# Usage: actual_path=$(resolve_package_path <session-dir> <package-path>)
# Example: resolve_package_path ./session /var/lib/coda/file.txt
#          Returns: /full/path/to/session/data/var/lib/coda/file.txt
resolve_package_path() {
  local session_dir="$1"
  local pkg_path="$2"
  local stripped
  stripped=$(strip_leading_slash "$pkg_path")
  echo "$(get_session_data_dir "$session_dir")/$stripped"
}

# Validates that a path stays within the session data directory
# Usage: validate_path_in_session <session-dir> <path> <path-description>
# Exits with error if path tries to escape session directory
validate_path_in_session() {
  local session_dir="$1"
  local path="$2"
  local description="${3:-path}"

  local data_dir
  data_dir=$(get_session_data_dir "$session_dir")

  local stripped
  stripped=$(strip_leading_slash "$path")

  # Build the full path
  local full_path="$data_dir/$stripped"

  # Normalize the path (resolve .., ., symlinks, etc.)
  # Note: realpath with -m doesn't require the path to exist
  local normalized
  normalized=$(realpath -m "$full_path")

  # Check if normalized path is within data directory
  # Use a trailing slash to prevent partial directory name matches
  if [[ "$normalized" != "$data_dir"* ]]; then
    echo "ERROR: $description escapes session data directory: $path" >&2
    echo "  Normalized: $normalized" >&2
    echo "  Expected within: $data_dir" >&2
    exit 1
  fi
}
