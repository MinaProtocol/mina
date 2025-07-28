#!/usr/bin/env bash

#!/bin/bash

# Usage (in buildkite definition)

# steps:
#  - commands:
#      - "./buildkite/scripts/run_promote_build_job.sh | buildkite-agent pipeline upload"
#    label: ":pipeline: run promote dockers build job"
#    agents:
#       size: "generic"
#    plugins:
#      "docker#v3.5.0":
#        environment:
#          - BUILDKITE_AGENT_ACCESS_TOKEN
#          - "ARTIFACTS=Archive,Daemon"
#          - "REMOVE_PROFILE_FROM_NAME=1"
#          - "PROFILE=Hardfork"
#          - "NETWORK=Devnet"
#          - "FROM_VERSION=3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e"
#          - "NEW_VERSION=3.0.0fake-ddb6fc4"
#          - "CODENAMES=Focal,Bullseye"
#          - "FROM_CHANNEL=Unstable"
#          - "TO_CHANNEL=Experimental"
#        image: codaprotocol/ci-toolchain-base:v3
#        mount-buildkite-agent: true
#        propagate-environment: true


set -x

#codename : DebianVersions.DebVersion
#          , network : Network.Type
#          , genesis_timestamp : Optional Text
#          , config_json_gz_url : Text
#          , profile : Profiles.Type
#          , suffix : Text


DEBIAN_VERSION_DHALL_DEF="(./buildkite/src/Constants/DebianVersions.dhall)"
NETWORK_DHALL_DEF="(./buildkite/src/Constants/Network.dhall)"
GENERATE_HARDFORK_PACKAGE_DHALL_DEF="(./buildkite/src/Entrypoints/GenerateHardforkPackage.dhall)"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "  CODENAMES                   The Debian codenames (Bullseye, Focal etc.)"
  echo "  NETWORK                     The Docker and Debian network (Devnet, Mainnet)"
  echo "  GENESIS_TIMESTAMP           The Genesis timestamp in ISO format (e.g. 2024-04-07T11:45:00Z)"
  echo "  CONFIG_JSON_GZ_URL          The URL to the gzipped genesis config JSON file"
  echo "  VERSION                     The version of the hardfork package to generate (e.g. 3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e)"
  echo ""
  exit 1
}

function to_dhall_list() {
  local input_str="$1"
  local dhall_type="$2"
  local arr=(${input_str//,/ })
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

echo $GENERATE_HARDFORK_PACKAGE_DHALL_DEF'.generate_hardfork_package '"$DHALL_CODENAMES"' '$NETWORK_DHALL_DEF'.Type.'"${NETWORK}"' (None Text) "'"${CONFIG_JSON_GZ_URL}"'" "'"${VERSION}"'" ' | dhall-to-yaml --quoted