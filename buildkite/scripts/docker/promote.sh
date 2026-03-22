#!/bin/bash

set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
PUBLISH=0
GCR_REPO=gcr.io/o1labs-192920
QUIET=""
ARCH=amd64
while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--name) NAME="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  -p|--publish) PUBLISH=1; ;;
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
  echo "  -p, --publish   The Publish to docker.io flag. If defined script will publish docker do docker.io. Otherwise it will still resides in gcr.io"
  echo "  -q, --quiet     The Quiet mode. If defined script will output limited logs"
  echo "  -a, --arch      The Architecture of docker (amd64, arm64)"
  echo ""
  echo "Example: $0 --name mina-archive --version 2.0.0-rc1-48efea4 --tag devnet-latest-nightly-bullseye "
  exit 1
}

if [[ -z "$NAME" ]]; then usage "Name is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$TAG" ]]; then usage "Tag is not set!"; fi;

# Sanitize the tag to ensure it is compliant with Docker tag format
TAG=$(echo "$TAG" | sed 's/[^a-zA-Z0-9_.-]/-/g')

case $ARCH in
  amd64) DOCKER_ARCH_SUFFIX="" ;;
  arm64) DOCKER_ARCH_SUFFIX="-arm64" ;;
  *) echo "❌  Unknown architecture passed: $ARCH"; exit 1 ;;
esac

SOURCE_TAG="${GCR_REPO}/${NAME}:${VERSION}${DOCKER_ARCH_SUFFIX}"

echo "📎 Adding new tag ($TAG) for docker ${SOURCE_TAG}"
echo "   📥 pulling ${SOURCE_TAG}"
docker pull $QUIET ${SOURCE_TAG}

if [[ $PUBLISH == 1 ]]; then
  TARGET_REPO=docker.io/minaprotocol
else
  TARGET_REPO=$GCR_REPO
fi

TARGET_TAG="${TARGET_REPO}/${NAME}:${TAG}${DOCKER_ARCH_SUFFIX}"

docker tag "${SOURCE_TAG}" "${TARGET_TAG}"
echo "   📤 pushing ${TARGET_TAG}"
docker push $QUIET "${TARGET_TAG}"
