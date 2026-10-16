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

# Everything this script prints that is not the pipeline itself must go to stderr.
# Standard output is piped straight into "buildkite-agent pipeline upload", so a
# stray message there is uploaded as pipeline YAML and the build fails with a
# confusing "Config file is empty" instead of the real reason.
function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}  $1${CLEAR}\n" >&2;
  fi
  cat >&2 << EOF
  VERIFY_MODE  Optional, defaults to "infra". One of:
                 infra      hourly canary: is the apt repository serving and does
                            the registry answer
                 artifacts  daily test: install every package in a clean container
                            of each codename, pull every image, and install the
                            automode metapackage with no version pin

  In artifacts mode set at least one of PACKAGES, IMAGES or AUTOMODE on the build.
EOF
  exit 1
}

# The canary is the safe default: it needs no other variable and no credentials,
# so a schedule that sets nothing still does something useful.
VERIFY_MODE="${VERIFY_MODE:-infra}"

if ! command -v dhall-to-yaml > /dev/null; then
  usage "dhall-to-yaml is not on PATH. This script must run inside the toolchain image."
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
