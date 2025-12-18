#!/usr/bin/env bash

# Common functions for Debian package session scripts
set -eux -o pipefail

# Strips the leading slash from a path
# Usage: result=$(strip_leading_slash <path>)
strip_leading_slash() {
  local path="$1"
  echo "${path#/}"
}
