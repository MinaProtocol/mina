#!/usr/bin/env bash

# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different.
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable.

set -eo pipefail
set +x

CLEAR='\033[0m'
RED='\033[0;31m'
# Array of valid service names
VALID_SERVICES=('mina-archive', 'mina-daemon' 'mina-rosetta' 'mina-zkapp-test-transaction' 'mina-toolchain' 'bot' 'leaderboard' 'delegation-backend' 'delegation-backend-toolchain')

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-s service-to-release] [-v service-version] [-n network]"
  echo "  -s, --service             The Service being released to Dockerhub"
  echo "  -v, --version             The version to be used in the docker image tag"
  echo "  -n, --network             The network configuration to use (devnet or mainnet). Default=devnet"
  echo "  -b, --branch              The branch of the mina repository to use for staged docker builds. Default=compatible"
  echo "      --deb-codename        The debian codename (stretch or buster) to build the docker image from. Default=stretch"
  echo "      --deb-release         The debian package release channel to pull from (unstable,alpha,beta,stable). Default=unstable"
  echo "      --deb-version         The version string for the debian package to install"
  echo ""
  echo "Example: $0 --service faucet --version v0.1.0"
  echo "Valid Services: ${VALID_SERVICES[*]}"
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  --no-upload) NOUPLOAD=1;;
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -n|--network) NETWORK="--build-arg network=$2"; shift;;
  -b|--branch) BRANCH="--build-arg MINA_BRANCH=$2"; shift;;
  -c|--cache-from) CACHE="--cache-from $2"; shift;;
  --deb-codename) DEB_CODENAME="--build-arg deb_codename=$2"; shift;;
  --deb-release) DEB_RELEASE="--build-arg deb_release=$2"; shift;;
  --deb-version) DEB_VERSION="--build-arg deb_version=$2"; shift;;
  --extra-args) EXTRA=${@:2}; shift $((${#}-1));;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# Determine the proper image for ubuntu or debian
case "${DEB_CODENAME##*=}" in
  bionic|focal|impish|jammy)
    IMAGE="ubuntu:${DEB_CODENAME##*=}"
  ;;
  stretch|buster|bullseye|sid)
    IMAGE="debian:${DEB_CODENAME##*=}-slim"
  ;;
esac
IMAGE="--build-arg image=${IMAGE}"

# Debug prints for visability
# Substring removal to cut the --build-arg arguments on the = so that the output is exactly the input flags https://wiki.bash-hackers.org/syntax/pe#substring_removal
echo "--service ${SERVICE} --version ${VERSION} --branch ${BRANCH##*=} --deb-version ${DEB_VERSION##*=} --deb-release ${DEB_RELEASE##*=} --deb-codename ${DEB_CODENAME##*=}"
echo ${EXTRA}
echo "docker image: ${IMAGE}"

# Verify Required Parameters are Present
if [[ -z "$SERVICE" ]]; then usage "Service is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$EXTRA" ]]; then EXTRA=""; fi;
if [[ $(echo ${VALID_SERVICES[@]} | grep -o "$SERVICE" - | wc -w) -eq 0 ]]; then usage "Invalid service!"; fi

case "${SERVICE}" in
mina-archive)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-archive"
  DOCKER_CONTEXT="dockerfiles/"
  ;;
bot)
  DOCKERFILE_PATH="frontend/bot/Dockerfile"
  DOCKER_CONTEXT="frontend/bot"
  ;;
mina-daemon)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"
  DOCKER_CONTEXT="dockerfiles/"
  VERSION="${VERSION}-${NETWORK##*=}"
  ;;
mina-toolchain)
  DOCKERFILE_PATH="dockerfiles/stages/1-build-deps dockerfiles/stages/2-opam-deps dockerfiles/stages/3-toolchain"
  ;;
mina-rosetta)
  DOCKERFILE_PATH="dockerfiles/stages/1-build-deps dockerfiles/stages/2-opam-deps dockerfiles/stages/3-builder dockerfiles/stages/4-production"
  ;;
mina-zkapp-test-transaction)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-zkapp-test-transaction"
  ;;
leaderboard)
  DOCKERFILE_PATH="frontend/leaderboard/Dockerfile"
  DOCKER_CONTEXT="frontend/leaderboard"
  ;;
delegation-backend)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-delegation-backend"
  DOCKER_CONTEXT="src/app/delegation_backend"
  ;;
delegation-backend-toolchain)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-delegation-backend-toolchain"
  DOCKER_CONTEXT="src/app/delegation_backend"
  ;;
esac


REPO="--build-arg MINA_REPO=${BUILDKITE_PULL_REQUEST_REPO}"
if [[ -z "${BUILDKITE_PULL_REQUEST_REPO}" ]]; then
  REPO="--build-arg MINA_REPO=https://github.com/MinaProtocol/mina"
fi

MINAPROTOCOL="minaprotocol"
TAG="$MINAPROTOCOL/$SERVICE:$VERSION"

GITHASH=$(git rev-parse --short=7 HEAD)
HASHTAG="$MINAPROTOCOL/$SERVICE:$GITHASH-${DEB_CODENAME##*=}-${NETWORK##*=}"

echo "HASHTAG IS" $HASHTAG

# If DOCKER_CONTEXT is not specified, assume none and just pipe the dockerfile into docker build
extra_build_args=$(echo ${EXTRA} | tr -d '"')
if [[ -z "${DOCKER_CONTEXT}" ]]; then
  cat $DOCKERFILE_PATH | docker build $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $BRANCH $REPO $extra_build_args -t "$TAG" -
else
  docker build $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $BRANCH $REPO $extra_build_args $DOCKER_CONTEXT -t "$TAG" -f $DOCKERFILE_PATH
fi

tag-and-push() {
  docker tag "${TAG}" "$1"
  docker tag "${TAG}" "${HASHTAG}"
  docker push "$1"
  docker push "${HASHTAG}"
}

if [ -z "$NOUPLOAD" ] || [ "$NOUPLOAD" -eq 0 ]; then
  docker push "${TAG}"
  tag-and-push "gcr.io/o1labs-192920/$SERVICE:$VERSION"
fi
