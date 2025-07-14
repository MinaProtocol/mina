#!/bin/bash

# Mina Protocol Debian Package Build Script
# ========================================
#
# This script builds Debian packages for the Mina Protocol blockchain client
# and related tools. It collects binaries and keys from the build directory
# and creates .deb packages for distribution.
#
# OVERVIEW:
# This script orchestrates the building of various Debian packages by sourcing
# the builder-helpers.sh script and calling the appropriate build functions.
#
# USAGE:
# Build all packages:
#   ./scripts/debian/build.sh
#
# Build specific packages:
#   ./scripts/debian/build.sh <package1> <package2> ...
#
# AVAILABLE PACKAGES:
# - archive               - Archive node
# - batch_txn             - Batch transaction tool
# - daemon_berkeley       - Berkeley network daemon
# - daemon_devnet         - Devnet daemon
# - daemon_mainnet        - Mainnet daemon
# - functional_test_suite - Functional test suite
# - keypair               - Key generation utility
# - logproc               - Log processing utility
# - rosetta_berkeley      - Rosetta API for Berkeley
# - rosetta_mainnet       - Rosetta API for Mainnet
# - rosetta_devnet        - Rosetta API for Devnet
# - test_executive        - Test executive tool
# - zkapp_test_transaction - ZkApp test transaction tool
#
# PREREQUISITES:
# - Build artifacts must exist in _build/ directory
# - Git repository (for commit hash extraction)
# - dpkg-deb, fakeroot (for package building)
# - All required OCaml executables must be built
#
# ENVIRONMENT VARIABLES:
# Required/Used by build.sh and builder-helpers.sh:
# - BRANCH_NAME: Git branch name (optional, auto-detected if not set)
# - BUILD_URL: Build URL for tracking (default: BUILDKITE_BUILD_URL or local
#   hostname)
# - BUILDKITE_BUILD_URL: Build URL from BuildKite CI (optional)
# - DUNE_INSTRUMENT_WITH: Adds instrumentation suffix if set
# - DUNE_PROFILE: Build profile (affects package naming)
# - MINA_DEB_CODENAME: Debian codename (default: "bullseye")
# - MINA_DEB_RELEASE: Release channel (default: "unstable")
# - MINA_DEB_VERSION: Package version (default: "0.0.0-experimental")
#
# Variables exported by export-git-env-vars.sh:
# - GITHASH: Short Git commit hash (7 characters)
# - GITBRANCH: Git branch name (sanitized for package names)
# - GITTAG: Most recent numeric Git tag
# - MINA_DOCKER_TAG: Docker tag derived from version and codename
# - MINA_COMMIT_TAG: Git tag pointing to current commit (if any)
# - THIS_COMMIT_TAG: Same as MINA_COMMIT_TAG (internal use)
#
# OUTPUT:
# Debian packages are created in the _build directory with names like:
# - mina-archive_<version>.deb
# - mina-daemon_berkeley_<version>.deb
# - mina-logproc_<version>.deb
# etc.

set -eox pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# In case of running this script on detached head, script has difficulties in
# finding out what is the current branch.
if [[ -n "$BRANCH_NAME" ]]; then
  # shellcheck disable=SC1091
  BRANCH_NAME="$BRANCH_NAME" source "${SCRIPTPATH}/../export-git-env-vars.sh"
else
  # shellcheck disable=SC1091
  source "${SCRIPTPATH}"/../export-git-env-vars.sh
fi

# shellcheck disable=SC1091
source "${SCRIPTPATH}/builder-helpers.sh"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Building all known debian packages"
    build_archive_berkeley_deb
    build_archive_devnet_deb
    build_archive_mainnet_deb
    build_batch_txn_deb
    build_daemon_berkeley_deb
    build_daemon_devnet_deb
    build_daemon_mainnet_deb
    build_functional_test_suite_deb
    build_keypair_deb
    build_logproc_deb
    build_rosetta_berkeley_deb
    build_rosetta_devnet_deb
    build_rosetta_mainnet_deb
    build_test_executive_deb
    build_zkapp_test_transaction_deb

  else
    for i in "$@"; do
      if [[ $(type -t "build_${i}_deb") == function ]]
      then
          echo "Building $i debian package"
          "build_${i}_deb"
      else
        echo "invalid debian package name '$i'"
        exit 1
      fi
    done
fi
