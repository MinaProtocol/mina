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
#          - "DOCKERS=Archive,Daemon"
#          - "REMOVE_PROFILE_FROM_NAME=1"
#          - "PROFILE=Hardfork"
#          - "NETWORK=Devnet"
#          - "FROM_VERSION=3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e"
#          - "NEW_VERSION=3.0.0fake-ddb6fc4"
#          - "CODENAMES=Focal,Buster,Bullseye"
#          - "FROM_CHANNEL=Unstable"
#          - "TO_CHANNEL=Experimental"
#        image: codaprotocol/ci-toolchain-base:v3
#        mount-buildkite-agent: true
#        propagate-environment: true


DEBIAN_DHALL_DEF="(./buildkite/src/Constants/DebianPackage.dhall)"
DOCKER_DHALL_DEF="(./buildkite/src/Constants/Artifacts.dhall)"
DEBIAN_VERSION_DHALL_DEF="(./buildkite/src/Constants/DebianVersions.dhall)"
PROMOTE_PACKAGE_DHALL_DEF="(./buildkite/src/Entrypoints/PromotePackage.dhall)"
PROFILES_DHALL_DEF="(./buildkite/src/Constants/Profiles.dhall)"
NETWORK_DHALL_DEF="(./buildkite/src/Constants/Network.dhall)"
DEBIAN_CHANNEL_DHALL_DEF="(./buildkite/src/Constants/DebianChannel.dhall)"


function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "  DEBIANS                     The comma delimitered debian names. For example: 'Daemon,Archive' "
  echo "  DOCKERS                     The comma delimitered docker names. For example: 'Daemon,Archive' "
  echo "  CODENAMES                   The Debian codenames (Bullseye, Buster etc.)"
  echo "  FROM_VERSION                The Source Docker or Debian version "
  echo "  NEW_VERSION                 The new Debian version or new Docker tag"
  echo "  REMOVE_PROFILE_FROM_NAME    Should we remove profile suffix from debian name"
  echo "  PROFILE                     The Docker and Debian profile (Standard, Lightnet)"
  echo "  NETWORK                     The Docker and Debian network (Devnet, Mainnet, Berkeley)"
  echo "  FROM_CHANNEL                Source debian channel"
  echo "  TO_CHANNEL                  Target debian channel"
  echo "  PUBLISH                     The Publish to docker.io flag. If defined, script will publish docker do docker.io. Otherwise it will still resides in gcr.io"
  echo ""
  exit 1
}

if [ -z "$DEBIANS" ] && [ -z "$DOCKERS" ]; then usage "No Debians nor Dockers defined for promoting!"; exit 1; fi;

DHALL_DEBIANS="([] : List $DEBIAN_DHALL_DEF.Type)"

if [[ -n "$DEBIANS" ]]; then 
    if [[ -z "$CODENAMES" ]]; then usage "Codenames is not set!"; exit 1; fi;
    if [[ -z "$PROFILE" ]]; then PROFILE="Standard"; exit 1;  fi;
    if [[ -z "$NETWORK" ]]; then NETWORK="Berkeley"; exit 1; fi;
    if [[ -z "$REMOVE_PROFILE_FROM_NAME" ]]; then REMOVE_PROFILE_FROM_NAME=0; fi;
    if [[ -z "$FROM_CHANNEL" ]]; then usage "'From channel' arg is not set!"; exit 1;  fi;
    if [[ -z "$TO_CHANNEL" ]]; then usage "'To channel' arg is not set!"; exit 1; fi;
    if [[ -z "$FROM_VERSION" ]]; then usage "Version is not set!"; exit 1; fi;
    if [[ -z "$NEW_VERSION" ]]; then NEW_VERSION=$FROM_VERSION; fi;
    

  arr_of_debians=(${DEBIANS//,/ })
  for i in "${arr_of_debians[@]}"; do
    DHALL_DEBIANS="${DHALL_DEBIANS}, $DEBIAN_DHALL_DEF.Type.${i}"
  done
  DHALL_DEBIANS="[${DHALL_DEBIANS:1}]"
fi


DHALL_DOCKERS="([] : List $DOCKER_DHALL_DEF.Type)"

if [[ -n "$DOCKERS" ]]; then 
    if [[ -z "$NEW_VERSION" ]]; then usage "New Tag is not set!"; fi;
    if [[ -z "$FROM_VERSION" ]]; then usage "Version is not set!"; fi;
    if [[ -z "$PROFILE" ]]; then PROFILE="Standard"; fi;
  
  arr_of_dockers=(${DOCKERS//,/ })
  DHALL_DOCKERS=""
  for i in "${arr_of_dockers[@]}"; do
    DHALL_DOCKERS="${DHALL_DOCKERS}, $DOCKER_DHALL_DEF.Type.${i}"
  done
  DHALL_DOCKERS="[${DHALL_DOCKERS:1}]"
fi

CODENAMES=(${CODENAMES//,/ })
DHALL_CODENAMES=""
  for i in "${CODENAMES[@]}"; do
    DHALL_CODENAMES="${DHALL_CODENAMES}, $DEBIAN_VERSION_DHALL_DEF.DebVersion.${i}"
  done
  DHALL_CODENAMES="[${DHALL_CODENAMES:1}]"

if [[ "${REMOVE_PROFILE_FROM_NAME}" -eq 0 ]]; then 
  REMOVE_PROFILE_FROM_NAME="False"
else 
  REMOVE_PROFILE_FROM_NAME="True"
fi 
echo $PROMOTE_PACKAGE_DHALL_DEF'.promote_artifacts '"$DHALL_DEBIANS"' '"$DHALL_DOCKERS"' "'"${FROM_VERSION}"'" "'"${NEW_VERSION}"'" "amd64" '$PROFILES_DHALL_DEF'.Type.'"${PROFILE}"' '$NETWORK_DHALL_DEF'.Type.'"${NETWORK}"' '"${DHALL_CODENAMES}"' '$DEBIAN_CHANNEL_DHALL_DEF'.Type.'"${FROM_CHANNEL}"' '$DEBIAN_CHANNEL_DHALL_DEF'.Type.'"${TO_CHANNEL}"' "'"${TAG}"'" '${REMOVE_PROFILE_FROM_NAME}'  ' | dhall-to-yaml --quoted 
