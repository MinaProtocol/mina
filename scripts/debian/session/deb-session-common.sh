#!/usr/bin/env bash

# Common functions for Debian package session scripts
# This library provides shared utilities for session validation and security checks.

# Validates that a session directory exists and has the correct structure
# Usage: validate_session_dir <session-dir-abs-path>
# Exits with code 1 if validation fails
validate_session_dir() {
  local session_dir_abs="$1"

  if [[ ! -d "$session_dir_abs/data" ]]; then
    echo "ERROR: Session data directory not found. Invalid session?" >&2
    exit 1
  fi
}

# Validates that a path doesn't contain '..' to prevent directory traversal attacks
# Usage: validate_path_no_traversal <path> [<path-description>]
# Exits with code 1 if validation fails
validate_path_no_traversal() {
  local path="$1"
  local description="${2:-Path}"

  if [[ "$path" == *".."* ]]; then
    echo "ERROR: $description contains '..' which is not allowed for security reasons" >&2
    exit 1
  fi
}

# Validates that a tar archive doesn't contain paths with '..' to prevent directory traversal
# Usage: validate_tar_archive <tar-file>
# Exits with code 1 if validation fails
validate_tar_archive() {
  local tar_file="$1"

  if tar -tf "$tar_file" | grep -q '\.\.'; then
    echo "ERROR: Archive contains paths with '..' which is a security risk" >&2
    exit 1
  fi
}

# Strips the leading slash from a path
# Usage: result=$(strip_leading_slash <path>)
strip_leading_slash() {
  local path="$1"
  echo "${path#/}"
}
