#!/bin/bash

set -euox pipefail

# Generate Hardfork Package Build Script
#
# This script generates Dhall configuration for creating hardfork packages in the Mina protocol
# build system. It converts input parameters to Dhall format and outputs YAML configuration
# for the buildkite pipeline.
#
# USAGE:
#   ./run-hardfork-package-gen.sh
#
# REQUIRED ENVIRONMENT VARIABLES:
#   CODENAMES                          - Comma-separated list of Debian codenames (e.g., "Bullseye,Focal")
#   NETWORK                            - Target network name (e.g., "Devnet", "Mainnet")
#   GENESIS_TIMESTAMP                  - Genesis timestamp in ISO format (e.g., "2024-04-07T11:45:00Z")
#   CONFIG_JSON_GZ_URL                 - URL to the gzipped genesis config JSON file
#   VERSION                            - Version string for the hardfork package (optional, if not set, defaults to calculated from git)
#   PRECOMPUTED_FORK_BLOCK_PREFIX      - (Optional) Prefix for precomputed fork block URLs (e.g., "gs://mina_network_block_data/mainnet")
#   USE_ARTIFACTS_FROM_BUILDKITE_BUILD - (Optional) Buildkite build number to use artifacts from (e.g., "1234")
#   HARDFORK_GENESIS_SLOT_DELTA        - (Optional) Number of slots to delay the hard fork genesis slot by (e.g., "0" for no delay)
#
# EXAMPLE:
#   export CODENAMES="Bullseye,Focal"
#   export NETWORK="Devnet"
#   export GENESIS_TIMESTAMP="2024-04-07T11:45:00Z"
#   export CONFIG_JSON_GZ_URL="https://example.com/config.json.gz"
#   export VERSION="3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e"
#   ./run-hardfork-package-gen.sh
#
# OUTPUT:
#   YAML configuration for buildkite pipeline generation
#
# DEPENDENCIES:
#   - dhall-to-yaml command-line tool
#   - Dhall configuration files in buildkite/src/
#


DEBIAN_VERSION_DHALL_DEF="(./buildkite/src/Constants/DebianVersions.dhall)"
NETWORK_DHALL_DEF="(./buildkite/src/Constants/Network.dhall)"
GENERATE_HARDFORK_PACKAGE_DHALL_DEF="(./buildkite/src/Entrypoints/GenerateHardforkPackage.dhall)"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  cat << EOF
  CODENAMES                     The Debian codenames (Bullseye, Focal etc.)
  NETWORK                       The Docker and Debian network (Devnet, Mainnet)
  GENESIS_TIMESTAMP             The Genesis timestamp in ISO format (e.g. 2024-04-07T11:45:00Z)
  CONFIG_JSON_GZ_URL            The URL to the gzipped genesis config JSON file
  VERSION                       (Optional) The version of the hardfork package to generate (e.g. 3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e)
  PRECOMPUTED_FORK_BLOCK_PREFIX (Optional) The prefix for precomputed fork block URLs (e.g. gs://mina_network_block_data/mainnet)
  USE_ARTIFACTS_FROM_BUILDKITE_BUILD (Optional) The Buildkite build number to use artifacts from (e.g. 1234)
  HARDFORK_GENESIS_SLOT_DELTA   (Optional) Number of slots to delay the hard fork genesis slot by (e.g. 0 for no delay)
EOF
  exit 1
}

function to_dhall_list() {
  local input_str="$1"
  local dhall_type="$2"
  local arr
  IFS=',' read -ra arr <<< "$input_str"
  local dhall_list=""

  if [[ ${#arr[@]} -eq 0 || -z "${arr[0]}" ]]; then
    dhall_list="([] : List $dhall_type)"
  elif [[ ${#arr[@]} -eq 1 ]]; then
    dhall_list="[$dhall_type.${arr[0]}]"
  else
    for i in "${arr[@]}"; do
      dhall_list="${dhall_list}, $dhall_type.${i}"
    done
    dhall_list="[${dhall_list:1}]"
  fi

  echo "$dhall_list"
}

if [[ -z "${CODENAMES:-}" ]]; then
  usage "CODENAMES environment variable is required"
fi

if [[ -z "${NETWORK:-}" ]]; then
  usage "NETWORK environment variable is required"
fi

if [[ -z "${CONFIG_JSON_GZ_URL:-}" ]]; then
  usage "CONFIG_JSON_GZ_URL environment variable is required"
fi

# Format GENESIS_TIMESTAMP as Optional Text for Dhall
if [[ -z "${GENESIS_TIMESTAMP:-}" ]]; then
  GENESIS_TIMESTAMP="(None Text)"
else
  # shellcheck disable=SC2089
  GENESIS_TIMESTAMP="(Some \"${GENESIS_TIMESTAMP}\")"
fi

# Format VERSION as Optional Text for Dhall
if [[ -z "${VERSION:-}" ]]; then
  VERSION="(None Text)"
else
  # shellcheck disable=SC2089
  VERSION="(Some \"${VERSION}\")"
fi

# Format USE_ARTIFACTS_FROM_BUILDKITE_BUILD as Optional Text for Dhall
if [[ -z "${USE_ARTIFACTS_FROM_BUILDKITE_BUILD:-}" ]]; then
  USE_ARTIFACTS_FROM_BUILDKITE_BUILD="(None Text)"
else
  # shellcheck disable=SC2089
  USE_ARTIFACTS_FROM_BUILDKITE_BUILD="(Some \"${USE_ARTIFACTS_FROM_BUILDKITE_BUILD}\")"
fi

# Format HARDFORK_GENESIS_SLOT_DELTA as Optional Natural for Dhall
if [[ -z "${HARDFORK_GENESIS_SLOT_DELTA:-}" ]]; then
  HARDFORK_GENESIS_SLOT_DELTA="(None Natural)"
else
  # shellcheck disable=SC2089
  HARDFORK_GENESIS_SLOT_DELTA="(Some ${HARDFORK_GENESIS_SLOT_DELTA})"
fi


# Format PRECOMPUTED_FORK_BLOCK_PREFIX as Optional Text for Dhall
if [[ -z "${PRECOMPUTED_FORK_BLOCK_PREFIX:-}" ]]; then
  PRECOMPUTED_FORK_BLOCK_PREFIX="(None Text)"
else
  # shellcheck disable=SC2089
  PRECOMPUTED_FORK_BLOCK_PREFIX="(Some \"${PRECOMPUTED_FORK_BLOCK_PREFIX}\")"
fi

DHALL_CODENAMES=$(to_dhall_list "${CODENAMES:-}" "$DEBIAN_VERSION_DHALL_DEF.DebVersion")

# shellcheck disable=SC2089
printf '%s.generate_hardfork_package %s %s.Type.%s %s "%s" "%s" %s %s %s %s\n' \
  "$GENERATE_HARDFORK_PACKAGE_DHALL_DEF" \
  "$DHALL_CODENAMES" \
  "$NETWORK_DHALL_DEF" \
  "$NETWORK" \
  "$GENESIS_TIMESTAMP" \
  "$CONFIG_JSON_GZ_URL" \
  "" \
  "$VERSION" \
  "$PRECOMPUTED_FORK_BLOCK_PREFIX" \
  "$USE_ARTIFACTS_FROM_BUILDKITE_BUILD" \
  "$HARDFORK_GENESIS_SLOT_DELTA" | dhall-to-yaml --quoted