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
  echo "  -i, --image-name          (Optional) Custom image name for the built docker image. Default is based on service name and version (e.g. mina-daemon:3.3.0-devnet)"
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
  echo "  -c, --cache-from          Docker cache source image(s) to use for build caching"
  echo "      --custom-suffix       A custom suffix to append to the docker tag (e.g. -instrumented)"
  echo "      --custom-arg          Custom build arg to pass to docker build (e.g. --build-arg my_arg=value)"
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
CUSTOM_ARG=""

# Default build context are the dockerfiles of the repo, but some images require a different context
#(e.g. if their Dockerfile uses COPY to pull in files from the same directory)
DOCKER_CONTEXT="dockerfiles/"


while [[ "$#" -gt 0 ]]; do case $1 in
  -i|--image-name) IMAGE_NAME="$2"; shift;;
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -n|--network) INPUT_NETWORK="$2"; shift;;
  -b|--branch) INPUT_BRANCH="$2"; shift;;
  -c|--cache-from) INPUT_CACHE="$2"; shift;;
  -r|--repo) MINA_REPO="$2"; shift;;
  -p|--platform) INPUT_PLATFORM="$2"; shift;;
  -l|--load-only) DOCKER_ACTION="load" ;;
  --docker-registry) export DOCKER_REGISTRY="$2"; shift;;
  --save-to-ci-cache) export SAVE_TO_CI_CACHE_ROOT="$2"; shift;;
  --no-cache) NO_CACHE="--no-cache"; ;;
  --custom-suffix) export CUSTOM_SUFFIX="$2"; shift;;
  --deb-codename) INPUT_CODENAME="$2"; shift;;
  --deb-release) INPUT_RELEASE="$2"; shift;;
  --deb-version) DEB_VERSION="$2"; shift;;
  --deb-legacy-version) INPUT_LEGACY_VERSION="$2"; shift;;
  --deb-storage-repair-version) INPUT_STORAGE_REPAIR_VERSION="$2"; shift;;
  --deb-profile) DEB_PROFILE="$2"; shift;;
  --deb-repo) INPUT_REPO="$2"; shift;;
  --deb-arch) DEB_ARCH="$2"; shift;;
  --deb-build-flags) DEB_BUILD_FLAGS="$2"; shift;;
  --deb-suffix) export DOCKER_DEB_SUFFIX="$2"; shift;;
  --deb-repo-key)
      # shellcheck disable=SC2034
      DEB_REPO_KEY="$2"; shift;;
  --custom-arg) CUSTOM_ARG="$2"; shift;;
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

LEGACY_VERSION=""
if [[ -n "${INPUT_LEGACY_VERSION:-}" ]]; then
  LEGACY_VERSION="--build-arg deb_legacy_version=$INPUT_LEGACY_VERSION"
fi

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME_ARG=""
else
  IMAGE_NAME_ARG="--build-arg image_name=$IMAGE_NAME"
fi

if [[ -z "${INPUT_BRANCH:-}" ]]; then
  echo "Branch is not set. Using the default (compatible)"
  BRANCH="--build-arg MINA_BRANCH=compatible"
else
  BRANCH="--build-arg MINA_BRANCH=$INPUT_BRANCH"
fi

if [[ -z "${INPUT_STORAGE_REPAIR_VERSION:-}" ]]; then
  echo "Debian storage repair version is not set. Using the default (unset)"
  DEB_STORAGE_REPAIR_VERSION=""
else
  DEB_STORAGE_REPAIR_VERSION="--build-arg deb_storage_repair_version=$INPUT_STORAGE_REPAIR_VERSION"
fi

if [[ -z "${MINA_REPO:-}" ]]; then
  echo "Repository is not set. Using the default (https://github.com/MinaProtocol/mina)"
  REPO="--build-arg MINA_REPO=https://github.com/MinaProtocol/mina"
else
  REPO="--build-arg MINA_REPO=$MINA_REPO"
fi

if [[ -z "${DEB_ARCH:-}" ]]; then
  echo "Debian architecture is not set. Using the default (all)"
  DEB_ARCH="--build-arg deb_arch=all"
else
  DEB_ARCH="--build-arg deb_arch=$DEB_ARCH"
fi

if [[ -z "${INPUT_CODENAME:-}" ]]; then
  echo "Debian codename is not set. Using the default (bullseye)"
  DEB_CODENAME="--build-arg deb_codename=bullseye"
else
  DEB_CODENAME="--build-arg deb_codename=$INPUT_CODENAME"
fi

if [[ -z "${INPUT_PLATFORM:-}" ]]; then
  INPUT_PLATFORM="linux/amd64"
fi

PLATFORM="--platform ${INPUT_PLATFORM}"

HOST_PLATFORM="linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
if [[ "${INPUT_PLATFORM}" != "${HOST_PLATFORM}" ]]; then
  echo "Cross-building ${INPUT_PLATFORM} on host ${HOST_PLATFORM}; setting up buildx + QEMU"
  ARCHS="${INPUT_PLATFORM##*/}" "${SCRIPTPATH}/setup_buildx.sh"
fi

if [[ -z "${DOCKER_REGISTRY:-}" ]]; then
  echo "Docker registry is not set. Using the default ($USER/mina-protocol)"
  DOCKER_REGISTRY="$USER/mina-protocol"
fi

# Set the upstream prefix here; for services that use Dockerfile-install-config
# (mina-daemon-configured / mina-rosetta-configured) we may re-set this AFTER
# export_docker_tag below, once the dependency tag is fully resolved and we can
# probe the cache for its specific manifest. Output TAGs are always built from
# the upstream $DOCKER_REGISTRY so push lands on the real registry.
DOCKER_REPO_ARG="--build-arg docker_repo=$DOCKER_REGISTRY"

if [[ -z "${INPUT_RELEASE:-}" ]]; then
  echo "Debian release is not set. Using the default (unstable)"
  DEB_RELEASE="--build-arg deb_release=unstable"
else
  DEB_RELEASE="--build-arg deb_release=$INPUT_RELEASE"
fi

if [[ -z "${DEB_VERSION:-}" ]]; then
  echo "Debian version is not set. Using the default ($VERSION)"
  DEB_VERSION="--build-arg deb_version=$VERSION"
else
  DEB_VERSION="--build-arg deb_version=$DEB_VERSION"
fi

VERSION_ARG="--build-arg version=$VERSION"


if [[ -z "${DEB_PROFILE:-}" ]]; then
  echo "Debian profile is not set. Using the default (devnet)"
  DEB_PROFILE="devnet"
fi

if [[ -z "${DEB_BUILD_FLAGS:-}" ]]; then
  DEB_BUILD_FLAGS=""
fi


if [[ -z "${INPUT_CACHE:-}" ]]; then
  CACHE=""
else
  CACHE="--cache-from $INPUT_CACHE"
fi

if [[ -z "${INPUT_REPO:-}" ]]; then
  echo "Debian repository is not set. Using the default (http://localhost:8080)"
  DEB_REPO="--build-arg deb_repo=http://localhost:8080"
else
  echo "Using provided Debian repository: $INPUT_REPO"
  DEB_REPO="--build-arg deb_repo=$INPUT_REPO"
fi

GW=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')
LOCALHOST_REPLACEMENT=$GW
if [[ -z "${INPUT_REPO:-}" ]]; then
  echo "Debian repository is not set. Using the default (http://$LOCALHOST_REPLACEMENT:8080)"
  DEB_REPO="--build-arg deb_repo=http://$LOCALHOST_REPLACEMENT:8080"
else
  echo "Converting localhost to $LOCALHOST_REPLACEMENT in repository URL"
  CONVERTED_REPO=$(echo "$INPUT_REPO" | sed "s/localhost/$LOCALHOST_REPLACEMENT/g")
  DEB_REPO="--build-arg deb_repo=$CONVERTED_REPO"
fi

APT_CACHE_ARG=""
if [[ -n "${APT_CACHE_PROXY:-}" ]]; then
  CONVERTED_PROXY=$(echo "$APT_CACHE_PROXY" | sed "s/localhost/$LOCALHOST_REPLACEMENT/g")
  # Probe proxy reachability before passing to Docker build; fall back to direct if unreachable
  if curl -so /dev/null --connect-timeout 2 --max-time 4 "$CONVERTED_PROXY" 2>/dev/null; then
    APT_CACHE_ARG="--build-arg apt_cache_url=$CONVERTED_PROXY"
  else
    echo "WARNING: APT cache proxy ($CONVERTED_PROXY) is unreachable, building without proxy"
  fi
fi

if [[ $(echo "${VALID_SERVICES[@]}" | grep -o "$SERVICE" - | wc -w) -eq 0 ]]; then usage "Invalid service!"; fi

export_base_image

CUSTOM_ARG=${CUSTOM_ARG:-""}

case "${SERVICE}" in
    mina-archive)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-archive"
        ;;
    mina-daemon)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"
        ;;
    mina-daemon-configured)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-install-config"
        SERVICE="mina-daemon"
        # The --version arg points to the base generic image for the Dockerfile FROM.
        # Override VERSION_ARG to keep it, then set VERSION to current commit for output tags.
        VERSION_ARG_OVERRIDE="--build-arg version=$VERSION"
        ;;
    mina-daemon-legacy-hardfork)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"
        ;;
    mina-daemon-auto-hardfork)
        if [[ -z "$INPUT_LEGACY_VERSION" ]]; then
          echo "Legacy version is not set for mina-daemon-auto-hardfork."
          echo "Please provide the --deb-legacy-version argument."
          exit 1
        fi
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon-auto-hardfork"
        ;;
    mina-toolchain)
        # Create temp combined Dockerfile so we can use a build context (needed for COPY)
        TEMP_DOCKERFILE=$(mktemp /tmp/Dockerfile-toolchain.XXXXXX)
        cat dockerfiles/toolchain/1-build-deps dockerfiles/toolchain/2-opam-deps dockerfiles/toolchain/3-toolchain > "$TEMP_DOCKERFILE"
        DOCKERFILE_PATH="$TEMP_DOCKERFILE"
        ;;
    mina-batch-txn)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-txn-burst"
        ;;
    mina-rosetta)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-rosetta"
        ;;
    mina-rosetta-configured)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-install-config"
        SERVICE="mina-rosetta"
        VERSION_ARG_OVERRIDE="--build-arg version=$VERSION"
        ;;
    mina-zkapp-test-transaction)
        DOCKERFILE_PATH="dockerfiles/Dockerfile-zkapp-test-transaction"
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
        ;;
    *)
        echo "Unsupported service: $SERVICE"
        exit 1
        ;;
esac

if [[ -n "${VERSION_ARG_OVERRIDE:-}" ]]; then
  # For services like mina-daemon-configured, the build arg version (base image)
  # differs from the output tag version (current commit).
  VERSION_ARG="$VERSION_ARG_OVERRIDE"
  VERSION="$MINA_DOCKER_TAG"
fi

export_version
export_docker_tag

# gar-cache (Phase 2): for Dockerfile-install-config services, probe the
# cache for the specific dependency manifest the FROM line will pull, and
# only rewrite docker_repo to use the cache when that manifest is present.
# Without this probe, a cache miss on the dep image fails the entire build
# (buildx doesn't fall back like the agent-side docker-pull shim does).
#
# Dockerfile-install-config:16 is
#   FROM ${docker_repo}/${image_name}:${version}-${network}-generic${build_flags_suffix}${custom_suffix}
# so we reconstruct that ref from build-args available here.
if [[ "${DOCKERFILE_PATH}" == "dockerfiles/Dockerfile-install-config" ]]; then
    _dep_image_name="${IMAGE_NAME:-mina-daemon}"
    _dep_version="${VERSION_ARG#--build-arg version=}"
    _dep_network="${INPUT_NETWORK:-devnet}"
    # BUILD_FLAGS_SUFFIX_ARG is set by export_suffixes (called inside
    # export_docker_tag) and looks like "--build-arg build_flags_suffix=-instrumented".
    _dep_build_flags="${BUILD_FLAGS_SUFFIX_ARG#--build-arg build_flags_suffix=}"
    _dep_custom="${CUSTOM_SUFFIX_ARG#--build-arg custom_suffix=}"
    _dep_tag="${_dep_version}-${_dep_network}-generic${_dep_build_flags}${_dep_custom}"
    _rewritten_repo="$(rewrite_docker_repo_via_gar_cache "${DOCKER_REGISTRY}" "${_dep_image_name}" "${_dep_tag}")"
    DOCKER_REPO_ARG="--build-arg docker_repo=${_rewritten_repo}"
    unset _dep_image_name _dep_version _dep_network _dep_build_flags _dep_custom _dep_tag _rewritten_repo
fi

BUILD_NETWORK="--allow=network.host"

docker buildx build --load --network=host --progress=plain $PLATFORM $DOCKER_REPO_ARG $NO_CACHE $BUILD_NETWORK $CACHE $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $DOCKER_DEB_SUFFIX_ARG $BUILD_FLAGS_SUFFIX_ARG $DEB_REPO $APT_CACHE_ARG $BRANCH $REPO $LEGACY_VERSION $CUSTOM_SUFFIX_ARG $CUSTOM_ARG $DEB_ARCH $DEB_STORAGE_REPAIR_VERSION $IMAGE_NAME_ARG $VERSION_ARG "$DOCKER_CONTEXT" -t "$TAG" -t "$HASHTAG" -f $DOCKERFILE_PATH

if [[ -n "${SAVE_TO_CI_CACHE_ROOT:-}" ]]; then

  FULL_IMAGE_PATH="${SAVE_TO_CI_CACHE_ROOT}/${SERVICE}/${HASHTAG_VERSION_PART}.tar.zst"

  if ! command -v zstd >/dev/null 2>&1; then
    echo "zstd not found on host; installing (required for --save-to-ci-cache)"
    if command -v apt-get >/dev/null 2>&1; then
      ${SUDO:-sudo} apt-get update -qq
      ${SUDO:-sudo} apt-get install -y --no-install-recommends zstd
    else
      echo "ERROR: zstd missing and no apt-get available to install it"
      exit 1
    fi
  fi

  # Hard sanity check: fail if --load did not produce the expected local image.
  docker image inspect "$TAG"

  mkdir -p "$(dirname "${FULL_IMAGE_PATH}")"
  echo "Saving built image to CI cache at ${FULL_IMAGE_PATH}"
  docker save "$TAG" "$HASHTAG" | zstd -T0 -3 > "${FULL_IMAGE_PATH}"
fi

if [[ "$DOCKER_ACTION" == "push" ]]; then
  docker push "$TAG"
  docker push "$HASHTAG"
else
  echo "Skipping push to remote registry, image loaded to local docker daemon only."
fi

# Clean up temp Dockerfile if one was created
if [[ -n "${TEMP_DOCKERFILE:-}" ]]; then
  rm -f "$TEMP_DOCKERFILE"
fi

echo "✅ Docker image for service ${SERVICE} built successfully."
echo "🐳 Full image name: ${HASHTAG}"
