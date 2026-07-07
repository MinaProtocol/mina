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

source "${SCRIPTPATH}"/../export-git-env-vars.sh

# shellcheck disable=SC1090
BUILD_DIR="${BUILD_DIR}" source "${SCRIPTPATH}/builder-helpers.sh"

resolve_and_build_package() {
  local package="$1"

  # Bash function names can't contain hyphens; normalize hyphenated network
  # names so downstream regex matches and function calls work uniformly.
  package="${package//mesa-mut/mesa_mut}"

  # TODO: consider further refactor on dhall's side so we can remove the name
  # resolving logic
  if [[ $(type -t "build_${package}_deb") == function ]]; then
    "build_${package}_deb"
    return
  fi

  if [[ "$package" =~ ^(archive|daemon|rosetta)_(mainnet|devnet|mesa|mesa_mut)$ ]]; then
    "build_${BASH_REMATCH[1]}_deb" "${BASH_REMATCH[2]}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet|mesa|mesa_mut)_(config|generic|hardfork_config|prefork|postfork|automode)$ ]]; then
    "build_daemon_${BASH_REMATCH[2]}_deb" "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^prefork_(mainnet|devnet|mesa|mesa_mut)_genesis_ledger$ ]]; then
    "build_prefork_${BASH_REMATCH[1]}_genesis_ledger_deb"
    return
  fi

  echo "Invalid debian package name '$package'"
  exit 1
}

default_targets=(
  logproc
  archive_devnet
  archive_mainnet
  batch_txn
  daemon_mainnet
  daemon_mainnet_config
  daemon_mainnet_generic
  daemon_devnet
  daemon_devnet_config
  daemon_devnet_generic
  rosetta_mainnet
  rosetta_devnet
  test_executive
  functional_test_suite
  zkapp_test_transaction
  delegation_verify
)

targets=("$@")
if [ $# -eq 0 ]; then
  echo "No arguments supplied. Building all known debian packages"
  targets=("${default_targets[@]}")
fi

for t in "${targets[@]}"; do
  resolve_and_build_package "$t"
done
