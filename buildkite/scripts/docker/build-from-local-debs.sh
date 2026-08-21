#!/bin/bash

# Build a docker image bottom-to-top: from .deb files this job produced itself,
# rather than from the packaging job's cached debians and a registry-published
# base image.
#
# WHY THIS EXISTS
#
# The default CI path is top-down. The packaging job builds every .deb, writes
# them to the build's cache, builds every docker image and pushes it; a test
# then declares a dependency on those steps and consumes the results. That
# coupling is the reason the Debian and Docker builds run on ordinary PRs at
# all: selecting a test pulls its dependency in, even when the test only needs
# one image out of the dozen the packaging job produces.
#
# The bottom-to-top path a caller assembles instead is two steps:
#
#   1. buildkite/scripts/debian/build-from-cache.sh <apps-variant> <tree-variant> <tokens...>
#        packages ONLY the debs the image installs, out of the binaries the
#        app-build job left in the apps cache;
#   2. this script, once per image, which stages those .deb files into the
#        docker build context and builds the image --load-only.
#
# The image is never pushed. Callers run their assertions in the same step, on
# the same agent, so a registry round-trip would buy nothing -- and pushing is
# what makes an image a shared artifact that has to be built by the packaging
# pipeline in the first place.
#
# CALLERS
#   buildkite/src/Command/DockerFromLocalDebs.dhall renders the invocation;
#   see AutoHardforkTest.dhall and IntegrationTestDockerImages.dhall.
#
# ENVIRONMENT
#   MINA_DEB_CODENAME  -- required
#   MINA_DEB_VERSION / MINA_DOCKER_TAG -- from a sourced export-git-env-vars.sh
#
# Usage:
#   build-from-local-debs.sh --service <s> --docker-registry <r> [options]

set -eo pipefail

SERVICE=""
NETWORK="devnet"
PROFILE="devnet"
DEB_SUFFIX=""
LEGACY_VERSION=""
BASE_IMAGE=""
DOCKER_REGISTRY_ARG=""
SAVE_TO_CI_CACHE=""

while [[ "$#" -gt 0 ]]; do case $1 in
  --service) SERVICE="$2"; shift;;
  --network) NETWORK="$2"; shift;;
  --profile) PROFILE="$2"; shift;;
  --deb-suffix) DEB_SUFFIX="$2"; shift;;
  --legacy-version) LEGACY_VERSION="$2"; shift;;
  --base-image) BASE_IMAGE="$2"; shift;;
  --docker-registry) DOCKER_REGISTRY_ARG="$2"; shift;;
  --save-to-ci-cache) SAVE_TO_CI_CACHE="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [[ -z "${MINA_DEB_CODENAME:-}" ]]; then
  echo "MINA_DEB_CODENAME is not set. Exiting."
  exit 1
fi

if [[ -z "$SERVICE" ]]; then
  echo "--service is required."
  exit 1
fi

# The registry decides the tag the image is built under, and callers derive the
# tag they run independently (Constants/Docker/Package.dhall fullDockerTag), so
# the two have to agree.
if [[ -z "$DOCKER_REGISTRY_ARG" ]]; then
  echo "--docker-registry is required (it decides the tag the image is built under)."
  exit 1
fi

# The docker build context. Must match the directory stage_local_debs.sh copies
# into, because the legacy packages below land next to the freshly built ones.
DEB_STAGE="dockerfiles"

./buildkite/scripts/debian/stage_local_debs.sh

# Only images that install a package from before the fork need this: it is a
# released artifact pinned at --legacy-version, not something this build can
# produce, so it comes from the cache's own persistent root.
LEGACY_ARG=()
if [[ -n "$LEGACY_VERSION" ]]; then
  echo "--- Reading legacy (prefork) debian packages from the CI cache"
  ./buildkite/scripts/cache/manager.sh read --root legacy/debians \
    "${MINA_DEB_CODENAME}/*" "${DEB_STAGE}"
  LEGACY_ARG=(--deb-legacy-version "$LEGACY_VERSION")
fi

# The same prune the packaging job's docker steps run: docker builds are the
# heavy disk consumers on an agent, and a job calling this script runs one.
DISK_PRUNE_THRESHOLD=0 ./buildkite/scripts/docker/disk-cleanup.sh

# Preload the published mina-base image so a staged build starts FROM it instead
# of re-running the base-deps stage. Non-fatal: build.sh inlines the base-deps
# fragment when the image is not available locally.
BASE_IMAGE_ARG=()
if [[ -n "$BASE_IMAGE" ]]; then
  ./buildkite/scripts/docker/load_from_cache.sh "$BASE_IMAGE" \
    || echo "mina-base-not-in-ci-cache-inlining-base-deps-stage"
  BASE_IMAGE_ARG=(--base-image "$BASE_IMAGE")
fi

SUFFIX_ARG=()
[[ -n "$DEB_SUFFIX" ]] && SUFFIX_ARG=(--deb-suffix "$DEB_SUFFIX")

CACHE_ARG=()
[[ -n "$SAVE_TO_CI_CACHE" ]] && CACHE_ARG=(--save-to-ci-cache "$SAVE_TO_CI_CACHE")

echo "--- Building ${SERVICE} locally (no push)"
./scripts/docker/build.sh \
  --service "${SERVICE}" \
  --network "${NETWORK}" \
  --version "${MINA_DOCKER_TAG}" \
  --branch "${BUILDKITE_BRANCH}" \
  --deb-codename "${MINA_DEB_CODENAME}" \
  --deb-release unstable \
  --deb-version "${MINA_DEB_VERSION}" \
  --deb-profile "${PROFILE}" \
  --deb-build-flags none \
  "${LEGACY_ARG[@]}" \
  "${BASE_IMAGE_ARG[@]}" \
  "${SUFFIX_ARG[@]}" \
  "${CACHE_ARG[@]}" \
  --repo "${BUILDKITE_REPO}" \
  --platform linux/amd64 \
  --docker-registry "${DOCKER_REGISTRY_ARG}" \
  --load-only
