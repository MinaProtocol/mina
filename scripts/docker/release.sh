#!/usr/bin/env bash

# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different.
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable.

set -eo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source ${SCRIPTPATH}/helper.sh

function usage() {
  echo "Usage: $0 [-s service-to-release] [-v service-version] [-n network]"
  echo "  -s, --service             The Service being released to Dockerhub"
  echo "  -v, --version             The version to be used in the docker image tag"
  echo "  -n, --network             The network configuration to use (devnet or mainnet). Default=devnet"
  echo "  -b, --branch              The branch of the mina repository to use for staged docker builds. Default=compatible"
  echo "  -r, --repo                The currently used mina repository"
  echo "      --deb-codename        The debian codename (stretch or buster) to build the docker image from. Default=stretch"
  echo "      --deb-release         The debian package release channel to pull from (unstable,alpha,beta,stable). Default=unstable"
  echo "      --deb-version         The version string for the debian package to install"
  echo "      --deb-profile         The profile string for the debian package to install"
  echo "      --deb-build-flags     The build-flags string for the debian package to install"
  echo ""
  echo "Example: $0 --service faucet --version v0.1.0"
  echo "Valid Services: ${VALID_SERVICES[*]}"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--service) export SERVICE="$2"; shift;;
  -v|--version) export VERSION="$2"; shift;;
  -n|--network) export NETWORK="--build-arg network=$2"; shift;;
  --deb-codename) export DEB_CODENAME="--build-arg deb_codename=$2"; shift;;
  --deb-version) export DEB_VERSION="--build-arg deb_version=$2"; shift;;
  --deb-profile) export DEB_PROFILE="$2"; shift;;
  --deb-build-flags) export DEB_BUILD_FLAGS="$2"; shift;;
  --help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

export_version
export_base_image
export_docker_tag

echo tag "${TAG}"
echo hash "${HASHTAG}"

# push to GCR
docker push "${TAG}"

# retag and push again to GCR
docker tag "${TAG}" "${HASHTAG}"
docker push "${HASHTAG}"

