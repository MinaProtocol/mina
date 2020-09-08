#!/bin/bash
set -eo pipefail
set +x

source DOCKER_DEPLOY_ENV

echo "--- Build/Release docker artifact for coda-daemon"
scripts/release-docker.sh --service "${CODA_SERVICE}" --version "${CODA_VERSION}"\
 --extra-args "--build-arg coda_version=${CODA_DEB_VERSION} --build-arg deb_repo=${CODA_DEB_REPO}"

if [[ -n $CODA_BUILD_ROSETTA ]]; then
  echo "--- Build/Release coda-rosetta to docker hub"
  docker pull gcr.io/o1labs-192920/coda-rosetta-opam-deps:develop
  # Could also cache-from opam-deps but we would need to get that automatically building nightly or at least when src/opam.export changes
  # build-deps is updated by manually running scripts/build-rosetta-stages.sh which always builds + pushes each stage
  scripts/release-docker.sh --service "coda-rosetta" --version "dev-${CODA_VERSION}"\
    --extra-args "--build-arg DUNE_PROFILE=dev --build-arg CODA_BRANCH=${CODA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:develop"
  # Also build with the standard DUNE_PROFILE, and use the dev profile as a cache.
  # This means it will use the opam-deps stage from the previous step, but make a new builder stage because the DUNE_PROFILE arg changed
  scripts/release-docker.sh --service "coda-rosetta" --version "${CODA_VERSION}"\
    --extra-args "--build-arg CODA_BRANCH=${CODA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:develop"
fi
