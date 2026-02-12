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

  # TODO: consider further refactor on dhall's side so we can remove the name 
  # resolving logic
  if [[ $(type -t "build_${package}_deb") == function ]]; then
    "build_${package}_deb"
    return
  fi

  if [[ "$package" =~ ^(archive|daemon|rosetta)_(mainnet|devnet|testnet_generic)$ ]]; then
    local network_name
    case "${BASH_REMATCH[2]}" in
      testnet_generic)
        network_name="testnet-generic"
        ;;
      *)
        network_name="${BASH_REMATCH[2]}"
        ;;
    esac
    "build_${BASH_REMATCH[1]}_deb" "${network_name}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet)_config$ ]]; then
    build_daemon_config_deb "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet)_pre_hardfork$ ]]; then
    build_daemon_pre_hardfork_deb "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$package" =~ ^daemon_(mainnet|devnet)_hardfork_config$ ]]; then
    build_daemon_hardfork_config_deb "${BASH_REMATCH[1]}"
    return
  fi

  echo "Invalid debian package name '$package'"
  exit 1
}

default_targets=(
  logproc
  archive_testnet_generic
  archive_devnet
  archive_mainnet
  batch_txn
  daemon_testnet_generic
  daemon_mainnet
  daemon_mainnet_config
  daemon_devnet
  daemon_devnet_config
  rosetta_testnet_generic
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
