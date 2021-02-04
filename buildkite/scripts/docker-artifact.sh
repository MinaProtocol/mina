#!/bin/bash
set -eo pipefail
set +x

source DOCKER_DEPLOY_ENV

echo "--- Build/Release docker artifact for ${MINA_SERVICE}"
scripts/release-docker.sh --service "${MINA_SERVICE}" --version "${MINA_VERSION}" --commit "${MINA_GIT_HASH}" \
 --extra-args "--build-arg mina_deb_version=${MINA_DEB_VERSION} --build-arg deb_repo=${MINA_DEB_REPO}"
echo "--- Build/Release docker artifact for ${MINA_SERVICE}-puppeteered"
scripts/release-docker.sh --service "${MINA_SERVICE}-puppeteered" --version "${MINA_VERSION}" --commit "${MINA_GIT_HASH}" \
 --extra-args "--build-arg mina_deb_version=${MINA_DEB_VERSION} --build-arg MINA_VERSION=${MINA_VERSION} --build-arg MINA_BRANCH=${MINA_GIT_BRANCH} --build-arg deb_repo=${MINA_DEB_REPO}"

if [[ -n $CODA_BUILD_ROSETTA ]]; then
  echo "--- Build/Release coda-rosetta to docker hub"
  docker pull gcr.io/o1labs-192920/coda-rosetta-opam-deps:develop
  # Could also cache-from opam-deps but we would need to get that automatically building nightly or at least when src/opam.export changes
  # build-deps is updated by manually running scripts/build-rosetta-stages.sh which always builds + pushes each stage
  scripts/release-docker.sh --service "coda-rosetta" --version "dev-${MINA_VERSION}" --commit "${MINA_GIT_HASH}" \
    --extra-args "--build-arg DUNE_PROFILE=dev --build-arg MINA_BRANCH=${MINA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/mina-rosetta-opam-deps:develop"
  # Also build with the standard DUNE_PROFILE, and use the dev profile as a cache.
  # This means it will use the opam-deps stage from the previous step, but make a new builder stage because the DUNE_PROFILE arg changed
  scripts/release-docker.sh --service "coda-rosetta" --version "${MINA_VERSION}"  --commit "${MINA_GIT_HASH}" \
    --extra-args "--build-arg MINA_BRANCH=${MINA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/mina-rosetta-opam-deps:develop"
fi
