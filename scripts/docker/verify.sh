#!/usr/bin/env bash

# Verify that the Docker image for a given package and version is working correctly.
# This script pulls the Docker image and runs the shared check scripts from scripts/verify/
# to ensure that the package dependencies are correctly resolved and binaries work.
# Usage: ./scripts/docker/verify.sh -p <package> -c <codename> [-s <suffix>] [-r <repo>] [-v <version>]

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPTS_DIR="$SCRIPT_DIR/../verify"

REPO=""
VERSION=3.0.0-f872d85
ARCH=amd64

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--package) PACKAGE="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  -s|--suffix) SUFFIX="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -a|--arch) ARCH="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [[ -z "$PACKAGE" ]]; then
  echo "Package is not set! Use -p or --package to set it."
  exit 1
fi

if [[ -z "$CODENAME" ]]; then
  echo "Codename is not set! Use -c or --codename to set it."
  exit 1
fi

if [[ -z "$REPO" ]]; then
  echo "Repo is not set! Use -r or --repo to set it."
  exit 1
fi

# Resolve which check script to run
source "$CHECK_SCRIPTS_DIR/resolve-check-script.sh" "$PACKAGE"
CHECK_SCRIPT_NAME=$(basename "$CHECK_SCRIPT")

case $ARCH in
  amd64)
    DOCKER_ARCH_SUFFIX=""
    ;;
  arm64)
    DOCKER_ARCH_SUFFIX="-arm64"
    ;;
  *) echo "Unknown architecture passed: $ARCH"; exit 1 ;;
esac

DOCKER_PLATFORM="--platform linux/$ARCH"

DOCKER_IMAGE="$REPO/$PACKAGE:$VERSION-${CODENAME}${SUFFIX}${DOCKER_ARCH_SUFFIX}"

if ! docker pull "$DOCKER_IMAGE" ; then
  echo "Docker verification for $CODENAME $PACKAGE $ARCH failed"
  echo "Please check if the image $DOCKER_IMAGE exists."
  exit 1
fi

echo "Running checks for $PACKAGE in $DOCKER_IMAGE"

# Mount the shared check scripts into the container and run the appropriate one.
# The check scripts assume binaries are already installed (which they are in the docker image).
# shellcheck disable=SC2086
if docker run $DOCKER_PLATFORM --rm \
  --entrypoint bash \
  -v "$CHECK_SCRIPTS_DIR:/checks:ro" \
  "$DOCKER_IMAGE" \
  /checks/"$CHECK_SCRIPT_NAME"; then
  echo 'OK: ALL WORKED FINE!'
else
  echo 'KO: ERROR!!!'
  exit 1
fi
