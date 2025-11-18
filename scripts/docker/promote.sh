#!/bin/bash

set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
QUIET=""
ARCH=amd64
while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--name) NAME="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  --pull-registry) PULL_REGISTRY="$2"; shift;;
  --push-registry) PUSH_REGISTRY="$2"; shift;;
  -q|--quiet) QUIET="-q"; ;;
  -a|--arch) ARCH="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-n name] [-v version] [-t tag] [-c codename] "
  echo "  -n, --name      The Docker name (mina-devnet, mina-archive etc.)"
  echo "  -v, --version   The Docker version"
  echo "  -t, --tag       The Additional tag"
  echo "  --pull-registry The Docker pull registry (e.g. gcr.io/o1labs-192920)"
  echo "  --push-registry The Docker push registry (e.g. gcr.io/o1labs-192920)"
  echo "  -q, --quiet     The Quiet mode. If defined script will output limited logs"
  echo "  -a, --arch      The Architecture of docker (amd64, arm64)"
  echo ""
  echo "Example: $0 --name mina-archive --version 2.0.0-rc1-48efea4 --tag devnet-latest-nightly-bullseye "
  exit 1
}

if [[ -z "$NAME" ]]; then usage "Name is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$TAG" ]]; then usage "Tag is not set!"; fi;
if [[ -z "$PULL_REGISTRY" ]]; then usage "Pull registry is not set!"; fi;

# Sanitize the tag to ensure it is compliant with Docker tag format
TAG=$(echo "$TAG" | sed 's/[^a-zA-Z0-9_.-]/-/g')

case $ARCH in
  amd64) DOCKER_ARCH_SUFFIX="" ;;
  arm64) DOCKER_ARCH_SUFFIX="-arm64" ;;
  *) echo "❌  Unknown architecture passed: $ARCH"; exit 1 ;;
esac

SOURCE_TAG="${PULL_REGISTRY}/${NAME}:${VERSION}${DOCKER_ARCH_SUFFIX}"

echo "📎 Adding new tag ($TAG) for docker ${SOURCE_TAG}"
echo "   📥 pulling ${SOURCE_TAG}"
docker pull $QUIET ${SOURCE_TAG}

if [[ -z "$PUSH_REGISTRY" ]]; then
  PUSH_REGISTRY=$PULL_REGISTRY
fi

TARGET_TAG="${PUSH_REGISTRY}/${NAME}:${TAG}${DOCKER_ARCH_SUFFIX}"

docker tag "${SOURCE_TAG}" "${TARGET_TAG}"
echo "   📤 pushing ${TARGET_TAG}"
docker push $QUIET "${TARGET_TAG}"
