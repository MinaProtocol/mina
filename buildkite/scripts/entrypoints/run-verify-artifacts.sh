#!/bin/bash

set -euo pipefail

# Verify Artifacts Script
#
# Generates the Dhall pipeline for the artifact verification entrypoint. Both the
# hourly canary and the daily artifact test come from this one entrypoint; the
# mode picks which.
#
# USAGE:
#   ./run-verify-artifacts.sh | buildkite-agent pipeline upload
#
# REQUIRED ENVIRONMENT VARIABLES:
#   VERIFY_MODE  "infra" or "artifacts"
#
# The remaining variables are read by the step itself, not by this script, so a
# scheduled build can set them without a pipeline change. See
# buildkite/scripts/verify/run-verification.sh for the full list.
#
# EXAMPLES:
#   # hourly canary
#   export VERIFY_MODE="infra"
#   ./run-verify-artifacts.sh | buildkite-agent pipeline upload
#
#   # daily artifact test
#   export VERIFY_MODE="artifacts"
#   export DEBIAN_CHANNEL="alpha"
#   export PACKAGES="mina-devnet=3.5.0-devnet-stop-slot-98e7835"
#   export AUTOMODE="mina-devnet-automode=4.0.0-devnet-ca2ccb1"
#   ./run-verify-artifacts.sh | buildkite-agent pipeline upload

RED='\033[0;31m'
CLEAR='\033[0m'

VERIFY_ARTIFACTS_DHALL_DEF="(./buildkite/src/Entrypoints/VerifyArtifacts.dhall)"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}  $1${CLEAR}\n";
  fi
  cat << EOF
  VERIFY_MODE  Required. One of:
                 infra      hourly canary: is the apt repository serving and does
                            the registry answer
                 artifacts  daily test: install every package in a clean container
                            of each codename, pull every image, and install the
                            automode metapackage with no version pin

  In artifacts mode set at least one of PACKAGES, IMAGES or AUTOMODE on the build.
EOF
  exit 1
}

if [[ -z "${VERIFY_MODE:-}" ]]; then
  usage "VERIFY_MODE environment variable is required"
fi

case "${VERIFY_MODE}" in
  infra)     DHALL_MODE="Infra" ;;
  artifacts) DHALL_MODE="Artifacts" ;;
  *)         usage "VERIFY_MODE must be 'infra' or 'artifacts', got '${VERIFY_MODE}'" ;;
esac

printf '%s.verify %s.Mode.%s\n' \
  "$VERIFY_ARTIFACTS_DHALL_DEF" \
  "$VERIFY_ARTIFACTS_DHALL_DEF" \
  "$DHALL_MODE" \
  | dhall-to-yaml --quoted
