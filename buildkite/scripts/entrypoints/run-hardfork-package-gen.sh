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
#   CODENAMES_CONFIG                   - Comma-separated list of Debian codenames to include in the package generation. Fist one will be used for validations
#   NETWORK                            - Target network name (e.g., "Devnet", "Mainnet")
#   GENESIS_TIMESTAMP                  - Genesis timestamp in ISO format (e.g., "2024-04-07T11:45:00Z")
#   CONFIG_JSON_GZ_URL                 - URL to the gzipped genesis config JSON file
#   VERSION                            - Version string for the hardfork package (optional, if not set, defaults to calculated from git)
#   PRECOMPUTED_FORK_BLOCK_PREFIX      - (Optional) Prefix for precomputed fork block URLs (e.g., "gs://mina_network_block_data/mainnet")
#   USE_ARTIFACTS_FROM_BUILDKITE_BUILD - (Optional) Buildkite build number to use artifacts from (e.g., "1234")
#   USE_GENERIC_DOCKERS_FROM_VERSION   - (Optional) Docker version to build config docker on top of (e.g., "3.3.0-compatible-aa34232")
#   HARDFORK_CONFIG_URL                - (Optional) URL of a ready hardfork config archive, as
#                                        scripts/hardfork/release/publish-hardfork-config.sh uploads it from a node's
#                                        `mina advanced generate-hardfork-config` directory. The packages are then built
#                                        from it at once, and the ledgers are still rebuilt from CONFIG_JSON_GZ_URL
#                                        beside it, as a check that must agree. Without it the ledgers are built from
#                                        CONFIG_JSON_GZ_URL and the packaging waits for them.
#
# READ BY THE RENDER, SHARED WITH THE RELEASE PIPELINES:
#   MINA_RELEASE_CHANNEL               - (Optional) The channel the packages are built for (their Suite), which is
#                                        the channel the fork-day publish must be pointed at. Default: unstable
#
# What this pipeline publishes: the docker images, to the internal euro
# registry only, so that a hardfork candidate can be run before the fork
# without reaching a user. The packages are published by nothing here. Every
# image is also written to this build's cache
# (/var/storagebox/<build id>/docker-images) and every package to
# debians/<codename>/ of the same cache, which is the layout the publish
# pipelines read. On fork day, run mina-<network>-publish with
# MINA_READ_CACHE_ROOT set to this build's id and the MINA_RELEASE_* targets
# of that pipeline (see buildkite/src/Jobs/Release/PublishDockers.dhall and
# PublishDebians.dhall): it retags the cached images for docker.io and
# publishes the packages to the channel they were built for. A build that is
# never published that way is a candidate, and nothing in the build needs to
# know which.
#
# EXAMPLE:
#   export CODENAMES_CONFIG="Bullseye_Amd64,Focal_Arm64"
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

# Colors for output
RED='\033[0;31m'
CLEAR='\033[0m'

DEBIAN_VERSION_DHALL_DEF="(./buildkite/src/Constants/DebianVersions.dhall)"
ARCH_DHALL_DEF="(./buildkite/src/Constants/Arch.dhall)"
NETWORK_DHALL_DEF="(./buildkite/src/Constants/Network.dhall)"
GENERATE_HARDFORK_PACKAGE_DHALL_DEF="(./buildkite/src/Entrypoints/GenerateHardforkPackage.dhall)"

# A release variable spelled so that Dhall would quietly ignore it is an error
# here, as it is in Prepare.dhall. The YAML goes to stdout, so the gate's
# report goes to stderr.
./buildkite/scripts/pipeline/validate-release-env.sh >&2

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  cat << EOF
  CODENAMES_CONFIG                   The Debian codenames config (Bullseye_Amd64, Focal_Arm64 etc.)
  NETWORK                            The Docker and Debian network (Devnet, Mainnet)
  GENESIS_TIMESTAMP                  The Genesis timestamp in ISO format (e.g. 2024-04-07T11:45:00Z)
  CONFIG_JSON_GZ_URL                 The URL to the gzipped genesis config JSON file
  VERSION                            (Optional) The version of the hardfork package to generate (e.g. 3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e)
  PRECOMPUTED_FORK_BLOCK_PREFIX      (Optional) The prefix for precomputed fork block URLs (e.g. gs://mina_network_block_data/mainnet)
  USE_ARTIFACTS_FROM_BUILDKITE_BUILD (Optional) The Buildkite build number to use artifacts from (e.g. 1234)
  USE_GENERIC_DOCKERS_FROM_VERSION   (Optional) Docker version to build config docker on top of (e.g. 3.3.0-compatible-aa34232)
  HARDFORK_CONFIG_URL                (Optional) URL of a ready hardfork config archive; the state dump is then only a check
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

if [[ -z "${CODENAMES_CONFIG:-}" ]]; then
  usage "CODENAMES_CONFIG environment variable is required"
fi

if [[ -z "${NETWORK:-}" ]]; then
  usage "NETWORK environment variable is required"
fi

if [[ -z "${CONFIG_JSON_GZ_URL:-}" ]]; then
  usage "CONFIG_JSON_GZ_URL environment variable is required"
fi

# Validate GENESIS_TIMESTAMP is in UTC (must end with 'Z') to avoid
# inconsistencies between auto hardfork mode (UTC) and legacy pipeline (local time)
if [[ -n "${GENESIS_TIMESTAMP:-}" && ! "${GENESIS_TIMESTAMP}" =~ Z$ ]]; then
  usage "GENESIS_TIMESTAMP must be in UTC format (ending with 'Z'), got: ${GENESIS_TIMESTAMP}"
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

# Format USE_GENERIC_DOCKERS_FROM_VERSION as Optional Text for Dhall
if [[ -z "${USE_GENERIC_DOCKERS_FROM_VERSION:-}" ]]; then
  USE_GENERIC_DOCKERS_FROM_VERSION="(None Text)"
else
  # shellcheck disable=SC2089
  USE_GENERIC_DOCKERS_FROM_VERSION="(Some \"${USE_GENERIC_DOCKERS_FROM_VERSION}\")"
fi


# Format HARDFORK_CONFIG_URL as Optional Text for Dhall
if [[ -z "${HARDFORK_CONFIG_URL:-}" ]]; then
  HARDFORK_CONFIG_URL="(None Text)"
else
  # shellcheck disable=SC2089
  HARDFORK_CONFIG_URL="(Some \"${HARDFORK_CONFIG_URL}\")"
fi

# Format PRECOMPUTED_FORK_BLOCK_PREFIX as Optional Text for Dhall
if [[ -z "${PRECOMPUTED_FORK_BLOCK_PREFIX:-}" ]]; then
  PRECOMPUTED_FORK_BLOCK_PREFIX="(None Text)"
else
  # shellcheck disable=SC2089
  PRECOMPUTED_FORK_BLOCK_PREFIX="(Some \"${PRECOMPUTED_FORK_BLOCK_PREFIX}\")"
fi

codenames_array=()
for codename_config in ${CODENAMES_CONFIG//,/ }; do
  codename="${codename_config%_*}"
  arch="${codename_config#*_}"
  codenames_array+=("{ DebVersion = ${DEBIAN_VERSION_DHALL_DEF}.DebVersion.${codename}, Arch = ${ARCH_DHALL_DEF}.Type.${arch} }")
done

# Build Dhall list directly (cannot use to_dhall_list because records contain commas)
if [[ ${#codenames_array[@]} -eq 0 ]]; then
  DHALL_CODENAMES="([] : List { DebVersion : ${DEBIAN_VERSION_DHALL_DEF}.DebVersion, Arch : ${ARCH_DHALL_DEF}.Type })"
else
  DHALL_CODENAMES="[ ${codenames_array[0]}"
  for ((i=1; i<${#codenames_array[@]}; i++)); do
    DHALL_CODENAMES="${DHALL_CODENAMES}, ${codenames_array[$i]}"
  done
  DHALL_CODENAMES="${DHALL_CODENAMES} ]"
fi

# shellcheck disable=SC2089
printf '%s.generate_hardfork_package %s %s.Type.%s %s "%s" "%s" %s %s %s %s %s\n' \
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
  "$USE_GENERIC_DOCKERS_FROM_VERSION" \
  "$HARDFORK_CONFIG_URL" \
   | dhall-to-yaml --quoted