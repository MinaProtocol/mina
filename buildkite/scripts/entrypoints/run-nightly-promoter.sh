#!/bin/bash

set -euox pipefail

# Promote Nightly Build Script
#
# Generates Dhall configuration for the nightly promoter pipeline. This pipeline
# runs independently (e.g. 5 hours after nightly builds) to promote artifacts
# from the latest successful nightly build.
#
# USAGE:
#   ./run-nightly-promoter.sh | buildkite-agent pipeline upload
#
# REQUIRED ENVIRONMENT VARIABLES:
#   BRANCH   - Target branch (e.g., "compatible", "develop", "master")
#   PROFILE  - Dune profile (e.g., "lightnet", "devnet")
#
# OPTIONAL ENVIRONMENT VARIABLES:
#   CHANNEL  - Debian channel (default: same as BRANCH)
#   FORCE    - Set to "true" to promote even if build is not from today (default: false)
#
# EXAMPLE:
#   export BRANCH="compatible"
#   export PROFILE="lightnet"
#   ./run-nightly-promoter.sh | buildkite-agent pipeline upload

RED='\033[0;31m'
CLEAR='\033[0m'

PROMOTE_NIGHTLY_DHALL_DEF="(./buildkite/src/Entrypoints/PromoteNightly.dhall)"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}  $1${CLEAR}\n";
  fi
  cat << EOF
  BRANCH   Target branch (required, e.g., "compatible", "develop", "master")
  PROFILE  Dune profile (required, e.g., "lightnet", "devnet")
  CHANNEL  Debian channel (optional, defaults to BRANCH)
  FORCE    Set to "true" to promote even if build is not from today (optional)
EOF
  exit 1
}

if [[ -z "${BRANCH:-}" ]]; then
  usage "BRANCH environment variable is required"
fi

if [[ -z "${PROFILE:-}" ]]; then
  usage "PROFILE environment variable is required"
fi

if [[ -z "${CHANNEL:-}" ]]; then
  CHANNEL="${BRANCH}"
fi

if [[ "${FORCE:-false}" == "true" ]]; then
  DHALL_FORCE="True"
else
  DHALL_FORCE="False"
fi

printf '%s.promote_nightly "%s" "%s" "%s" %s\n' \
  "$PROMOTE_NIGHTLY_DHALL_DEF" \
  "$BRANCH" \
  "$PROFILE" \
  "$CHANNEL" \
  "$DHALL_FORCE" \
  | dhall-to-yaml --quoted
