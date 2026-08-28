#!/usr/bin/env bash

# Push the docker images this build cached, without rebuilding them.
#
# The packaging jobs normally push each image as they finish, so images reach a
# registry before the packaging stage as a whole has succeeded. Debians do not
# work that way: they are written to a cache and published in one step after a
# gate. This script is the other half of making images behave the same, so a
# release publishes everything or nothing.
#
# It pairs with scripts/docker/build.sh --load-only --save-to-ci-cache, which
# builds the image, tags it exactly as it would have been published, and writes
# it to ${CACHE_ROOT}/<service>/<hashtag-version>.tar.zst. Nothing is retagged
# here: the tar already carries the tag the image is meant to have, so what is
# pushed is what was built.
#
# Images are found by this build's commit. HASHTAG_VERSION_PART begins with
# GITHASH (see scripts/docker/helper.sh), and the cache is shared between
# builds, so the hash is what separates this build's images from everyone
# else's.

set -euo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

CACHE_ROOT="${CACHE_ROOT:-/var/storagebox/docker-cache}"
DRY_RUN="${DRY_RUN:-0}"

# shellcheck disable=SC1090,SC1091
source ./buildkite/scripts/export-git-env-vars.sh

if [[ ! -d "$CACHE_ROOT" ]]; then
  echo -e "${RED}❌ No docker cache at ${CACHE_ROOT}.${CLEAR}" >&2
  exit 1
fi

echo "--- Looking for images built at ${GITHASH} under ${CACHE_ROOT}"

mapfile -t TARS < <(find "$CACHE_ROOT" -mindepth 2 -maxdepth 2 -name "${GITHASH}-*.tar.zst" | sort)

if [[ ${#TARS[@]} -eq 0 ]]; then
  echo -e "${RED}❌ No cached images for ${GITHASH}.${CLEAR}" >&2
  echo "   The packaging stage writes them with --save-to-ci-cache. Either it" >&2
  echo "   did not run, or it ran without deferring the push, in which case the" >&2
  echo "   images are already in the registry and this step is not wanted." >&2
  exit 1
fi

echo "--- ${#TARS[@]} cached image(s) to publish"

PUSHED=0
for tar in "${TARS[@]}"; do
  echo "--- Loading $(basename "$(dirname "$tar")")/$(basename "$tar")"

  # `docker load` names every tag the archive carries. build.sh saves the
  # published tag and the hash tag together, and both are meant to exist in
  # the registry, so both are pushed rather than one being recreated from the
  # other afterwards.
  mapfile -t TAGS < <(zstd -dc "$tar" | docker load | sed -n 's/^Loaded image: //p')

  if [[ ${#TAGS[@]} -eq 0 ]]; then
    echo -e "${RED}❌ ${tar} loaded no image.${CLEAR}" >&2
    exit 1
  fi

  for tag in "${TAGS[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "    would push ${tag}"
    else
      echo "    pushing ${tag}"
      docker push "$tag"
    fi
    PUSHED=$((PUSHED + 1))
  done
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo -e "${GREEN}✅ Dry run: ${PUSHED} tag(s) would be pushed.${CLEAR}"
else
  echo -e "${GREEN}✅ Pushed ${PUSHED} tag(s) from ${#TARS[@]} cached image(s).${CLEAR}"
fi
