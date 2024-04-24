#!/bin/bash

set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--name) NAME="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  -p|--publish) PUBLISH=1 ;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-n name] [-v version] [-t tag] [-c codename] "
  echo "  -n, --name      The Docker name (mina-berkeley, mina-archive etc.)"
  echo "  -v, --version   The Docker version"
  echo "  -t, --tag       The Additional tag"
  echo "  -p, --publish   The Publish to docker.io flag. If defined script will publish docker do docker.io. Otherwise it will still resides in gcr.io"
  echo ""
  echo "Example: $0 --name mina-archive --version 2.0.0berkeley-rc1-berkeley-48efea4 --tag berkeley-latest-nightly-bullseye "
  exit 1
}

if [[ -z "$NAME" ]]; then usage "Name is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$TAG" ]]; then usage "Tag is not set!"; fi;

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, promote commands won't run"
#    exit 0
fi

GCR_REPO=gcr.io/o1labs-192920

echo "Adding new tag ($TAG) for docker ${GCR_REPO}/${NAME}:${VERSION}"

docker pull ${GCR_REPO}/${NAME}:${VERSION}

if [[ "$PUBLISH" -eq 1 ]]; then
  TARGET_REPO=docker.io/minaprotocol
  docker tag ${GCR_REPO}/${NAME}:${VERSION} ${TARGET_REPO}/${NAME}:${TAG}
  docker push "${TARGET_REPO}/${NAME}:${TAG}"
else 
  TARGET_REPO=$GCR_REPO
  echo "retagging ${GCR_REPO}/${NAME}:${VERSION} as ${TARGET_REPO}/${NAME}:${TAG}"
  docker tag  "${GCR_REPO}/${NAME}:${VERSION}" "${TARGET_REPO}/${NAME}:${TAG}"
  echo "pushing ${TARGET_REPO}/${NAME}:${TAG}"
  docker push "${TARGET_REPO}/${NAME}:${TAG}"
fi