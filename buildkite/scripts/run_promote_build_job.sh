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


ARTIFACTS_DHALL_DEF="(./buildkite/src/Constants/Artifacts.dhall)"
DEBIAN_VERSION_DHALL_DEF="(./buildkite/src/Constants/DebianVersions.dhall)"
PROMOTE_PACKAGE_DHALL_DEF="(./buildkite/src/Entrypoints/PromotePackage.dhall)"
PROFILES_DHALL_DEF="(./buildkite/src/Constants/Profiles.dhall)"
NETWORK_DHALL_DEF="(./buildkite/src/Constants/Network.dhall)"
DEBIAN_CHANNEL_DHALL_DEF="(./buildkite/src/Constants/DebianChannel.dhall)"
DEBIAN_REPO_DHALL_DEF="(./buildkite/src/Constants/DebianRepo.dhall)"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "  ARTIFACTS                   The comma delimitered artifacts names. For example: 'Daemon,Archive' "
  echo "  CODENAMES                   The Debian codenames (Bullseye, Focal etc.)"
  echo "  VERSION                     The new Debian version or new Docker tag"
  echo "  PROFILE                     The Docker and Debian profile (Standard, Lightnet)"
  echo "  NETWORK                     The Docker and Debian network (Devnet, Mainnet)"
  echo "  CHANNEL                     Target debian channel"
  echo "  REPO                        Source debian repository"
  echo "  BUILD_ID                    The Buildkite build ID. If defined, script will use it to generate debian package version"
  echo "  PUBLISH                     The Publish to docker.io flag. If defined, script will publish docker do docker.io. Otherwise it will still resides in gcr.io"
  echo "  VERIFY                      The Verify flag. If set, script will verify the artifacts before promoting them"
  echo ""
  exit 1
}

if [[ -z "$ARTIFACTS" ]]; then usage "No artifacts defined for promoting!"; exit 1; fi;
if [[ -z "$CODENAMES" ]]; then usage "Codenames is not set!"; exit 1; fi;
if [[ -z "$PROFILE" ]]; then PROFILE="Standard"; fi;
if [[ -z "$NETWORK" ]]; then NETWORK="Devnet"; fi;
if [[ -z "$PUBLISH" ]]; then PUBLISH=0; fi;
if [[ -z "$CHANNEL" ]]; then CHANNEL="Unstable"; fi;
if [[ -z "$REPO" ]]; then REPO="Nightly"; fi;
if [[ -z "$VERIFY" ]]; then VERIFY=0; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; exit 1; fi;
if [[ -z "$NEW_VERSION" ]];  then usage "New Version is not set!"; exit 1; fi;
if [[ -z "$BUILD_ID" ]]; then usage "Build ID is not set!"; exit 1; fi;

if [[ $PUBLISH -eq 1 ]]; then
    DHALL_PUBLISH="True"
  else 
    DHALL_PUBLISH="False"
fi

if [[ $VERIFY -eq 1 ]]; then
    DHALL_VERIFY="True"
  else 
    DHALL_VERIFY="False"
fi

arr_of_artifacts=(${ARTIFACTS//,/ })
if [[ ${#arr_of_artifacts[@]} -eq 0 || -z "${arr_of_artifacts[0]}" ]]; then
  DHALL_ARTIFACTS="([] : List $ARTIFACTS_DHALL_DEF.Type)"
else
  DHALL_ARTIFACTS=""
  for i in "${arr_of_artifacts[@]}"; do
    DHALL_ARTIFACTS="${DHALL_ARTIFACTS}, $ARTIFACTS_DHALL_DEF.Type.${i}"
  done
  DHALL_ARTIFACTS="[${DHALL_ARTIFACTS:1}]"
fi


CODENAMES=(${CODENAMES//,/ })
DHALL_CODENAMES=""
  for i in "${CODENAMES[@]}"; do
    DHALL_CODENAMES="${DHALL_CODENAMES}, $DEBIAN_VERSION_DHALL_DEF.DebVersion.${i}"
  done
  DHALL_CODENAMES="[${DHALL_CODENAMES:1}]"

echo $PROMOTE_PACKAGE_DHALL_DEF'.promote_artifacts '"$DHALL_ARTIFACTS"' "'"${VERSION}"'" "'"${NEW_VERSION}"'" "amd64" '$PROFILES_DHALL_DEF'.Type.'"${PROFILE}"' '$NETWORK_DHALL_DEF'.Type.'"${NETWORK}"' '"${DHALL_CODENAMES}"' '$DEBIAN_CHANNEL_DHALL_DEF'.Type.'"${CHANNEL}"' '$DEBIAN_REPO_DHALL_DEF'.Type.'"${REPO}"' '${REMOVE_PROFILE_FROM_NAME}' '${DHALL_PUBLISH}' '${DHALL_VERIFY}' '${BUILD_ID}' ' | dhall-to-yaml --quoted 