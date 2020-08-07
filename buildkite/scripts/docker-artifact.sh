#!/bin/bash
set -eo pipefail

source DOCKER_DEPLOY_ENV

extra_args="--build-arg coda_version=${CODA_DEB_VERSION} --build-arg deb_repo=${CODA_DEB_REPO}"

echo "--- Build/Release docker artifact"
scripts/release-docker.sh --service $CODA_SERVICE --version $CODA_VERSION --extra-args "${extra_args}"
