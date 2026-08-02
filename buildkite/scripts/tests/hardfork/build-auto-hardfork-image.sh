#!/bin/bash

# Builds the mina-daemon-auto-hardfork docker image for AutoHardforkTest, on the
# test's own agent, from packages the test job built itself.
#
# This exists so AutoHardforkTest no longer depends on the artifact/packaging
# job. Two things differ from the artifact job's docker step
# (Command/DockerImage.dhall):
#
#   1. The postfork side's .deb files come from _build/*.deb -- packages built
#      in this same job by buildkite/scripts/debian/build-from-cache.sh out of
#      the app-build binaries -- instead of read_all_from_cache.sh pulling the
#      packaging job's cached debians out of ${BUILDKITE_BUILD_ID}/debians.
#   2. The image is only loaded into the agent's local docker daemon
#      (--load-only), never pushed. The dispatcher tests run on this same agent
#      in the same step, so a registry round-trip buys nothing.
#
# The legacy PREFORK .deb is still read from the cache's `legacy/debians` root.
# That one is a fixed pre-fork release artifact (deb_legacy_version), not
# something this build produces, so there is nothing to build it from.
#
# Requires MINA_DEB_CODENAME and a sourced export-git-env-vars.sh
# (MINA_DEB_VERSION / MINA_DOCKER_TAG).
#
# Usage: build-auto-hardfork-image.sh --legacy-version <v> --docker-registry <r>
#                                     [--network <n>] [--profile <p>]
#                                     [--base-image <img>]
#
# --docker-registry must match the registry the caller derives the image tag
# from (Constants/Docker/Package.dhall fullDockerTag), because that is what
# scripts/docker/helper.sh tags the built image with and what the dispatcher
# tests then `docker run`.

set -eo pipefail

NETWORK="devnet"
PROFILE="devnet"
LEGACY_VERSION=""
BASE_IMAGE=""
DOCKER_REGISTRY_ARG=""

while [[ "$#" -gt 0 ]]; do case $1 in
  --network) NETWORK="$2"; shift;;
  --profile) PROFILE="$2"; shift;;
  --legacy-version) LEGACY_VERSION="$2"; shift;;
  --base-image) BASE_IMAGE="$2"; shift;;
  --docker-registry) DOCKER_REGISTRY_ARG="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [[ -z "${MINA_DEB_CODENAME:-}" ]]; then
  echo "MINA_DEB_CODENAME is not set. Exiting."
  exit 1
fi

if [[ -z "$LEGACY_VERSION" ]]; then
  echo "--legacy-version is required (the prefork deb version to install)."
  exit 1
fi

if [[ -z "$DOCKER_REGISTRY_ARG" ]]; then
  echo "--docker-registry is required (it decides the tag the image is built under)."
  exit 1
fi

# The docker build context. scripts/docker/build.sh picks up every *.deb sitting
# here and stages it under _debs/, which the Dockerfile COPYs into the image for
# install-mina-debs.sh -- no apt repo involved.
DEB_STAGE="dockerfiles"

echo "--- Staging locally built debian packages into ${DEB_STAGE}"
shopt -s nullglob
built_debs=(_build/*.deb)
shopt -u nullglob

if [[ "${#built_debs[@]}" -eq 0 ]]; then
  echo "No .deb files found in _build/. The debian build step must run first." >&2
  exit 1
fi

echo "Staging ${#built_debs[@]} locally built .deb file(s):"
printf '  %s\n' "${built_debs[@]}"
cp "${built_debs[@]}" "${DEB_STAGE}/"

# The prefork package is a released artifact from before the fork; it is kept in
# the cache under its own root and is never rebuilt here.
echo "--- Reading legacy (prefork) debian packages from the CI cache"
./buildkite/scripts/cache/manager.sh read --root legacy/debians \
  "${MINA_DEB_CODENAME}/*" "${DEB_STAGE}"

# Same prune the artifact job's docker steps run: docker builds are the heavy
# disk consumers on an agent and this job now runs one.
DISK_PRUNE_THRESHOLD=0 ./buildkite/scripts/docker/disk-cleanup.sh

# Preload the published mina-base image so the staged build starts FROM it
# instead of re-running the base-deps stage. Non-fatal: build.sh inlines the
# base-deps fragment when the image is not available locally.
BASE_IMAGE_ARG=()
if [[ -n "$BASE_IMAGE" ]]; then
  ./buildkite/scripts/docker/load_from_cache.sh "$BASE_IMAGE" \
    || echo "mina-base-not-in-ci-cache-inlining-base-deps-stage"
  BASE_IMAGE_ARG=(--base-image "$BASE_IMAGE")
fi

echo "--- Building the auto-hardfork image locally (no push)"
./scripts/docker/build.sh \
  --service mina-daemon-auto-hardfork \
  --network "${NETWORK}" \
  --version "${MINA_DOCKER_TAG}" \
  --branch "${BUILDKITE_BRANCH}" \
  --deb-codename "${MINA_DEB_CODENAME}" \
  --deb-repo http://localhost:8080 \
  --deb-release unstable \
  --deb-version "${MINA_DEB_VERSION}" \
  --deb-profile "${PROFILE}" \
  --deb-build-flags none \
  --deb-legacy-version "${LEGACY_VERSION}" \
  "${BASE_IMAGE_ARG[@]}" \
  --repo "${BUILDKITE_REPO}" \
  --platform linux/amd64 \
  --docker-registry "${DOCKER_REGISTRY_ARG}" \
  --load-only
