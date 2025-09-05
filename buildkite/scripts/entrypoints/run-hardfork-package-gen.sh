#!/bin/bash

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
#   CODENAMES           - Comma-separated list of Debian codenames (e.g., "Bullseye,Focal")
#   NETWORK             - Target network name (e.g., "Devnet", "Mainnet")
#   GENESIS_TIMESTAMP   - Genesis timestamp in ISO format (e.g., "2024-04-07T11:45:00Z")
#   CONFIG_JSON_GZ_URL  - URL to the gzipped genesis config JSON file
#   VERSION             - Version string for the hardfork package
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
  CODENAMES                   The Debian codenames (Bullseye, Focal etc.)
  NETWORK                     The Docker and Debian network (Devnet, Mainnet)
  GENESIS_TIMESTAMP           The Genesis timestamp in ISO format (e.g. 2024-04-07T11:45:00Z)
  CONFIG_JSON_GZ_URL          The URL to the gzipped genesis config JSON file
  VERSION                     The version of the hardfork package to generate (e.g. 3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e)

EOF
  exit 1
}

function to_dhall_list() {
  local input_str="$1"
  local dhall_type="$2"
  local arr=("${input_str//,/ }")
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

DHALL_CODENAMES=$(to_dhall_list "$CODENAMES" "$DEBIAN_VERSION_DHALL_DEF.DebVersion")

echo $GENERATE_HARDFORK_PACKAGE_DHALL_DEF'.generate_hardfork_package '"$DHALL_CODENAMES"' '$NETWORK_DHALL_DEF'.Type.'"${NETWORK}"' (None Text) "'"${CONFIG_JSON_GZ_URL}"'" "'""'" ' | dhall-to-yaml --quoted