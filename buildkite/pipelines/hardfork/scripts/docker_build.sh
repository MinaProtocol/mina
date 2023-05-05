#!/bin/bash
# this script builds the Mina docker containers used later for network deployment
# final docker container are published to Google Container Registry after the build completes

set -euo pipefail

echo "--- Cloning Mina repository"
git clone https://github.com/MinaProtocol/mina.git 

##############################################################
# Running Docker build script within Mina toolchain container
##############################################################

set -euo pipefail

export DUNE_PROFILE="devnet"
export BUILDKITE_BRANCH="fix/nonce-test-flake"

export MINA_DOCKER_TAG="steven-test-do-not-use"
export SERVICE="mina-daemon"

export NETWORK="berkeley"
export DEB_CODENAME="bullseye"
export IMAGE="debian:${DEB_CODENAME}-slim"
export IMAGE="--build-arg image=${IMAGE}"
export DEB_RELEASE="unstable"
export DEB_VERSION="2.0.0rampup1-fix-nonce-test-flake-ba692de"
export BRANCH="${BUILDKITE_BRANCH}"
export REPO=""
export VERSION="${DEB_VERSION}-${DEB_RELEASE}"
export extra_build_args=""
export DOCKER_CONTEXT="dockerfiles/"
export TAG="gcr.io/o1labs-192920/${SERVICE}:${VERSION}"
export DOCKERFILE_PATH="dockerfiles/Dockerfile-mina-daemon"

cd ./mina

##############################################################
# Building Mina Docker containers
##############################################################

pwd
ls -a

bash ./scripts/release-docker.sh --service mina-daemon --version ${VERSION} --network ${NETWORK} --branch ${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release ${DEB_RELEASE} --deb-version ${DEB_VERSION} --extra-args
# cat $DOCKERFILE_PATH | docker build $NETWORK $IMAGE $DEB_CODENAME $DEB_RELEASE $DEB_VERSION $BRANCH $REPO $extra_build_args -t "$TAG" -
