#!/usr/bin/env bash

# Enable debug output only in CI environments
if [[ -n "$CI" || -n "$BUILDKITE" || -n "$GITHUB_ACTIONS" ]]; then
  set -x
fi

# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different.
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable.

CLEAR='\033[0m'
RED='\033[0;31m'

SCRIPTPATH="$( cd "$(dirname "$0")" || exit ; pwd -P )"
# shellcheck disable=SC1090
source "${SCRIPTPATH}"/helper.sh

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
  echo "      --deb-codename        The debian codename to build the docker image from. Default=bullseye"
  echo "      --deb-release         The debian package release channel to pull from (unstable,alpha,beta,stable). Default=unstable"
  echo "      --deb-version         The version string for the debian package to install"
  echo "      --deb-profile         The profile string for the debian package to install"
  echo "      --deb-build-flags     The build-flags string for the debian package to install"
  echo "      --deb-suffix          The debian suffix to use for the docker image"
  echo "  -p, --platform            The target platform for the docker build (e.g. linux/amd64). Default=linux/amd64"
  echo "  -l, --load-only           Load the built image into local docker daemon only, do not push to remote registry"
  echo ""
  echo "Example: $0 --service faucet --version v0.1.0"
  echo "Valid Services: ${VALID_SERVICES[*]}"
  exit 1
}

# Defines if build is for pushing to remote registry or loading locally only.
# Can be overridden with --load-only flag.
DOCKER_ACTION="push"
# By default we use cache
NO_CACHE=""

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -n|--network) INPUT_NETWORK="$2"; shift;;
  -b|--branch) INPUT_BRANCH="$2"; shift;;
  -c|--cache-from) INPUT_CACHE="$2"; shift;;
  -r|--repo) MINA_REPO="$2"; shift;;
  -p|--platform) INPUT_PLATFORM="$2"; shift;;
  -l|--load-only) DOCKER_ACTION="load" ;;
  --docker-registry) export DOCKER_REGISTRY="$2"; shift;;
  --no-cache) NO_CACHE="--no-cache"; ;;
  --deb-codename) INPUT_CODENAME="$2"; shift;;
  --deb-release) INPUT_RELEASE="$2"; shift;;
  --deb-version) INPUT_VERSION="$2"; shift;;
  --deb-legacy-version) INPUT_LEGACY_VERSION="$2"; shift;;
  --deb-profile) DEB_PROFILE="$2"; shift;;
  --deb-repo) INPUT_REPO="$2"; shift;;
  --deb-build-flags) DEB_BUILD_FLAGS="$2"; shift;;
  --deb-suffix)
      # shellcheck disable=SC2034
      DOCKER_DEB_SUFFIX="--build-arg deb_suffix=$2"; shift;;
  --deb-repo-key)
      # shellcheck disable=SC2034
      DEB_REPO_KEY="$2"; shift;;
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

if [[ -z "$INPUT_LEGACY_VERSION" ]]; then
  LEGACY_VERSION=""
else
  LEGACY_VERSION="--build-arg deb_legacy_version=$INPUT_LEGACY_VERSION"
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

if [[ -z "$INPUT_PLATFORM" ]]; then
  INPUT_PLATFORM="linux/amd64"
fi

PLATFORM="--platform ${INPUT_PLATFORM}"

# Unfortunately we cannot use the same naming convention for all architectures
# for all tooling in toolchain or mina docker
# therefore we need to define couple of naming conventions

# Canonical style naming convention : aarch/x86_64
# Debian style naming convention : arm64/amd64
case "${INPUT_PLATFORM}" in
      linux/amd64)
        CANONICAL_ARCH="x86_64"
        DEBIAN_ARCH="x86_64"
        ;;
      linux/arm64)
        CANONICAL_ARCH="aarch64"
        DEBIAN_ARCH="arm64"
        ;;
      *)
        echo "unsupported platform"; exit 1
        ;;
esac
CANONICAL_ARCH_ARG="--build-arg CANONICAL_ARCH=$CANONICAL_ARCH"
DEBIAN_ARCH_ARG="--build-arg DEBIAN_ARCH=$DEBIAN_ARCH"
DOCKER_REPO_ARG="--build-arg docker_repo=$DOCKER_REGISTRY"

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
  echo "Debian profile is not set. Using the default (devnet)"
  DEB_PROFILE="devnet"
fi

if [[ -z "$DEB_BUILD_FLAGS" ]]; then
  DEB_BUILD_FLAGS=""
fi


if [[ -z "${INPUT_CACHE:-}" ]]; then
  CACHE=""
else
  CACHE="--cache-from $INPUT_CACHE"
fi

DEB_REPO="--build-arg deb_repo=$INPUT_REPO"
GW=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')
LOCALHOST_REPLACEMENT=$GW
if [[ -z "$INPUT_REPO" ]]; then
  echo "Debian repository is not set. Using the default (http://$LOCALHOST_REPLACEMENT:8080)"
  DEB_REPO="--build-arg deb_repo=http://$LOCALHOST_REPLACEMENT:8080"
else
  echo "Converting localhost to $LOCALHOST_REPLACEMENT in repository URL"
  CONVERTED_REPO=$(echo "$INPUT_REPO" | sed "s/localhost/$LOCALHOST_REPLACEMENT/g")
  DEB_REPO="--build-arg deb_repo=$CONVERTED_REPO"
fi

if [[ $(echo "${VALID_SERVICES[@]}" | grep -o "$SERVICE" - | wc -w) -eq 0 ]]; then usage "Invalid service!"; fi

export_base_image

case "${SERVICE}" in
    mina-archive)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-archive"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
    mina-daemon)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
    mina-daemon-legacy-hardfork)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
    mina-daemon-auto-hardfork)
        if [[ -z "$INPUT_LEGACY_VERSION" ]]; then
          echo "Legacy version is not set for mina-daemon-auto-hardfork."
          echo "Please provide the --deb-legacy-version argument."
          exit 1
        fi
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon-hardfork"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
    mina-toolchain)
        DOCKERFILE_PATH_SCRIPT_1="dockerfiles/stages/1-build-deps"
        DOCKERFILE_PATH_SCRIPT_2_AND_MORE="dockerfiles/stages/2-opam-deps dockerfiles/stages/3-toolchain"
        case "${INPUT_CODENAME}" in
          bullseye)
            DOCKERFILE_PATH="$DOCKERFILE_PATH_SCRIPT_1 dockerfiles/stages/1-build-deps-bullseye $DOCKERFILE_PATH_SCRIPT_2_AND_MORE"
            ;;
          focal)
            DOCKERFILE_PATH="$DOCKERFILE_PATH_SCRIPT_1 dockerfiles/stages/1-build-deps-focal $DOCKERFILE_PATH_SCRIPT_2_AND_MORE"
            ;;
          jammy)
              DOCKERFILE_PATH="$DOCKERFILE_PATH_SCRIPT_1 dockerfiles/stages/1-build-deps-jammy $DOCKERFILE_PATH_SCRIPT_2_AND_MORE"
              ;;
          noble)
            DOCKERFILE_PATH="$DOCKERFILE_PATH_SCRIPT_1 dockerfiles/stages/1-build-deps-noble $DOCKERFILE_PATH_SCRIPT_2_AND_MORE"
            ;;
          bookworm)
            DOCKERFILE_PATH="$DOCKERFILE_PATH_SCRIPT_1 dockerfiles/stages/1-build-deps-bookworm $DOCKERFILE_PATH_SCRIPT_2_AND_MORE"
            ;;
          *)
            echo "Unsupported debian codename: $INPUT_CODENAME"
            echo "Supported codenames are: bullseye, focal, noble"
            exit 1
            ;;
        esac
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
    mina-delegation-verifier)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-delegation-stateless-verifier"
        ;;
    delegation-backend-toolchain)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-delegation-backend-toolchain"
        DOCKER_CONTEXT="src/app/delegation_backend"
        ;;
    mina-test-suite)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-test-suite"
        DOCKER_CONTEXT="dockerfiles/"
        ;;
esac

export_version
export_docker_tag

BUILD_NETWORK="--allow=network.host"

# If DOCKER_CONTEXT is not specified, assume none and just pipe the dockerfile into docker build
if [[ -z "${DOCKER_CONTEXT:-}" ]]; then
  cat $DOCKERFILE_PATH | docker buildx build  --network=host \
  --"$DOCKER_ACTION" --progress=plain $PLATFORM $DEBIAN_ARCH_ARG $CANONICAL_ARCH_ARG $DOCKER_REPO_ARG $NO_CACHE $BUILD_NETWORK $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $DOCKER_DEB_SUFFIX $DEB_REPO $BRANCH $REPO $LEGACY_VERSION -t "$TAG" -t "$HASHTAG" -
else
  docker buildx build --"$DOCKER_ACTION" --network=host --progress=plain $PLATFORM $DEBIAN_ARCH_ARG $CANONICAL_ARCH_ARG $DOCKER_REPO_ARG $NO_CACHE $BUILD_NETWORK $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $DOCKER_DEB_SUFFIX $DEB_REPO $BRANCH $REPO $LEGACY_VERSION "$DOCKER_CONTEXT" -t "$TAG" -t "$HASHTAG" -f $DOCKERFILE_PATH
fi

echo "✅ Docker image for service ${SERVICE} built successfully."
echo "🐳 Full image name: ${HASHTAG}"