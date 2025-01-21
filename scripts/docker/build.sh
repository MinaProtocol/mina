#!/usr/bin/env bash


set -x 
# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different.
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable.

CLEAR='\033[0m'
RED='\033[0;31m'

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source ${SCRIPTPATH}/helper.sh

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
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
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -n|--network) INPUT_NETWORK="$2"; shift;;
  -b|--branch) INPUT_BRANCH="$2"; shift;;
  -c|--cache-from) INPUT_CACHE="$2"; shift;;
  -r|--repo) MINA_REPO="$2"; shift;;
  --no-cache) NO_CACHE="--no-cache"; ;;
  --deb-codename) INPUT_CODENAME="$2"; shift;;
  --deb-release) INPUT_RELEASE="$2"; shift;;
  --deb-version) INPUT_VERSION="$2"; shift;;
  --deb-profile) DEB_PROFILE="$2"; shift;;
  --deb-repo) INPUT_REPO="$2"; shift;;
  --deb-build-flags) DEB_BUILD_FLAGS="$2"; shift;;
  --deb-repo-key) DEB_REPO_KEY="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# Verify Required Parameters are Present
if [[ -z "$SERVICE" ]]; then usage "Service is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;

NETWORK="--build-arg network=$INPUT_NETWORK"
if [[ -z "$INPUT_NETWORK" ]]; then 
  echo "Network is not set. Using the default (devnet)"
  NETWORK="--build-arg network=devnet"
fi

BRANCH="--build-arg MINA_BRANCH=$INPUT_BRANCH"
if [[ -z "$INPUT_BRANCH" ]]; then 
  echo "Branch is not set. Using the default (compatible)"
  BRANCH="--build-arg MINA_BRANCH=compatible"
fi

REPO="--build-arg MINA_REPO=${MINA_REPO}"
if [[ -z "${MINA_REPO}" ]]; then
  echo "Repository is not set. Using the default (https://github.com/MinaProtocol/mina)"
  REPO="--build-arg MINA_REPO=https://github.com/MinaProtocol/mina"
fi

DEB_CODENAME="--build-arg deb_codename=$INPUT_CODENAME"
if [[ -z "$INPUT_CODENAME" ]]; then 
  echo "Debian codename is not set. Using the default (bullseye)"
  DEB_CODENAME="--build-arg deb_codename=bullseye"
fi

DEB_RELEASE="--build-arg deb_release=$INPUT_RELEASE"
if [[ -z "$INPUT_RELEASE" ]]; then 
  echo "Debian release is not set. Using the default (unstable)"
  DEB_RELEASE="--build-arg deb_release=unstable"
fi

DEB_VERSION="--build-arg deb_version=$INPUT_VERSION"
if [[ -z "$INPUT_VERSION" ]]; then 
  echo "Debian version is not set. Using the default ($VERSION)"
  DEB_VERSION="--build-arg deb_version=$VERSION"
fi

if [[ -z "$DEB_PROFILE" ]]; then 
  echo "Debian profile is not set. Using the default (standard)"
  DEB_PROFILE="standard"
fi

if [[ -z "$DEB_BUILD_FLAGS" ]]; then 
  DEB_BUILD_FLAGS=""
fi

CACHE="--cache-from $INPUT_CACHE"
if [[ -z "$INPUT_CACHE" ]]; then 
  CACHE=""
fi

DEB_REPO="--build-arg deb_repo=$INPUT_REPO"
if [[ -z "$INPUT_REPO" ]]; then 
  echo "Debian repository is not set. Using the default (http://localhost:8080)"
  DEB_REPO="--build-arg deb_repo=http://localhost:8080"
fi

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
        ;;
    mina-toolchain)
        DOCKERFILE_PATH="dockerfiles/stages/1-build-deps dockerfiles/stages/2-opam-deps dockerfiles/stages/3-toolchain"
        ;;
    mina-batch-txn)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-txn-burst"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
    mina-rosetta)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-rosetta"
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
    itn-orchestrator)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-itn-orchestrator"
        DOCKER_CONTEXT="src/app/itn_orchestrator"
        ;;
    mina-test-suite)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-test-suite"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
esac

export_version
export_base_image
export_docker_tag

BUILD_NETWORK="--network=host"

# If DOCKER_CONTEXT is not specified, assume none and just pipe the dockerfile into docker build
if [[ -z "${DOCKER_CONTEXT}" ]]; then
  cat $DOCKERFILE_PATH | docker build $NO_CACHE $BUILD_NETWORK $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $DOCKER_DEB_SUFFIX $DEB_REPO $BRANCH $REPO -t "$TAG" -
else
  docker build $NO_CACHE $BUILD_NETWORK $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $DOCKER_DEB_SUFFIX $DEB_REPO $BRANCH $REPO "$DOCKER_CONTEXT" -t "$TAG" -f $DOCKERFILE_PATH
fi
