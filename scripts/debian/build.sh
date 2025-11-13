#!/bin/bash

# Script collects binaries and keys and builds deb archives.

set -eou pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BUILD_DIR=${BUILD_DIR:-"${SCRIPTPATH}/../../_build"}

# Check if BUILD_DIR exists
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "Error: BUILD_DIR '$BUILD_DIR' does not exist."
  echo "This means the build process has not been completed successfully or the directory is incorrect."
  echo "Please ensure you have built the applications first, or check if:"
  echo "  - You are running this script from the correct directory (if not using BUILD_DIR, run it from the root of the project)"
  echo "  - BUILD_DIR environment variable is set correctly (if using BUILD_DIR)"
  echo "  - The build process completed successfully"
  exit 1
fi

# In case of running this script on detached head, script has difficulties in finding out
# what is the current branch.
if [[ -n "$BRANCH_NAME" ]]; then
  # shellcheck disable=SC1090
  BRANCH_NAME="$BRANCH_NAME" source "${SCRIPTPATH}/../export-git-env-vars.sh"
else
  # shellcheck disable=SC1090
  source "${SCRIPTPATH}"/../export-git-env-vars.sh
fi

# shellcheck disable=SC1090
BUILD_DIR="${BUILD_DIR}" source "${SCRIPTPATH}/builder-helpers.sh"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Building all known debian packages"
    build_logproc_deb
    build_archive_testnet_generic_deb
    build_archive_devnet_deb
    build_archive_mainnet_deb
    build_batch_txn_deb
    build_daemon_testnet_generic_deb
    build_daemon_mainnet_deb
    build_daemon_devnet_deb
    build_rosetta_testnet_generic_deb
    build_rosetta_mainnet_deb
    build_rosetta_devnet_deb
    build_test_executive_deb
    build_functional_test_suite_deb
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
