#!/usr/bin/env bash

# Verify that the Docker image for a given package and version is working correctly.
# This script pulls the Docker image and runs a set of simplest commands (fetch help and version) 
# to ensure that the package dependencies are correctly resolved.
# Usage: ./scripts/docker/verify.sh -p <package> -c <codename> [-s <suffix>] [-r <repo>] [-v <version>]

set -eo pipefail

REPO=gcr.io/o1labs-192920
VERSION=3.0.0-f872d85

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--package) PACKAGE="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  -s|--suffix) SUFFIX="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

COMMANDS=(--version --help)

case $PACKAGE in
  mina-archive) APPS=mina-archive ;;
  mina-logproc) APPS=(); echo "skipped execution for mina-logproc" ;;
  mina-rosetta*) APPS=("mina" "mina-archive" "mina-rosetta") ;;
  mina-*) APPS=("mina");;
  *) echo "❌  Unknown package passed: $PACKAGE"; exit 1;;
esac

DOCKER_IMAGE="$REPO/$PACKAGE:$VERSION-${CODENAME}${SUFFIX}"

if ! docker pull "$DOCKER_IMAGE" ; then
  echo "❌ Docker verification for $CODENAME $PACKAGE failed"
  echo "❌ Please check if the image $DOCKER_IMAGE exists."
  exit 1
fi

for APP in "${APPS[@]}"; do
  for COMMAND in "${COMMANDS[@]}"; do
    echo "📋  Testing $APP $COMMAND in $DOCKER_IMAGE"
    # Do not quote $COMMAND, because it may contain spaces or other special characters
    # shellcheck disable=SC2086
    if ! docker run --entrypoint "$APP" --rm "$DOCKER_IMAGE" $COMMAND; then
      echo "❌  KO: ERROR running $APP $COMMAND"
      exit 1
    fi
  done
done

echo '✅  OK: ALL WORKED FINE!'