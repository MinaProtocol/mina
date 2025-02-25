#!/bin/bash

set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
PUBLISH=0
GCR_REPO=gcr.io/o1labs-192920
QUIET=""
while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--name) NAME="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  -p|--publish) PUBLISH=1; ;;
  -q|--quiet) QUIET="-q"; ;;
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
  echo ""
  echo "Example: $0 --name mina-archive --version 2.0.0-rc1-48efea4 --tag devnet-latest-nightly-bullseye "
  exit 1
}

if [[ -z "$NAME" ]]; then usage "Name is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$TAG" ]]; then usage "Tag is not set!"; fi;

echo "📎 Adding new tag ($TAG) for docker ${GCR_REPO}/${NAME}:${VERSION}"
echo "   📥 pulling ${GCR_REPO}/${NAME}:${VERSION}"

docker pull $QUIET ${GCR_REPO}/${NAME}:${VERSION}

if [[ $PUBLISH == 1 ]]; then
  TARGET_REPO=docker.io/minaprotocol
  
  echo "   📎 tagging ${GCR_REPO}/${NAME}:${VERSION} as ${TARGET_REPO}/${NAME}:${TAG}"

  docker tag ${GCR_REPO}/${NAME}:${VERSION} ${TARGET_REPO}/${NAME}:${TAG}
  echo "   📤 pushing ${TARGET_REPO}/${NAME}:${TAG}"
  docker push $QUIET "${TARGET_REPO}/${NAME}:${TAG}"
else 
  TARGET_REPO=$GCR_REPO
  echo "   📎 retagging ${GCR_REPO}/${NAME}:${VERSION} as ${TARGET_REPO}/${NAME}:${TAG}"
  docker tag "${GCR_REPO}/${NAME}:${VERSION}" "${TARGET_REPO}/${NAME}:${TAG}"
  echo "   📤 pushing ${TARGET_REPO}/${NAME}:${TAG}"
  docker push $QUIET "${TARGET_REPO}/${NAME}:${TAG}"
fi