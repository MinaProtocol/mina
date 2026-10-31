#!/usr/bin/env bash

# Push the docker images a release built, after the gate, as the debians are.
#
# Packaging builds every image with scripts/docker/build.sh --load-only
# --build-cache-dir, which writes it to
#   <cache>/<build>/docker-images/<service>/<tag>.tar.zst
# holding exactly the tags it is published under. Nothing is retagged here.
#
# Builds read, like read_all_from_cache.sh:
#   MINA_READ_CACHE_ROOT (else BUILDKITE_BUILD_ID)  the packaging build
#   MINA_GENERIC_CACHE_ROOT                         the generic stage, if separate
#
# One archive at a time: load, check its tags against the registry, push, then
# drop it from the local store. A tag already in the registry is skipped when it
# holds this very image (a retried step), and refused otherwise unless
# FORCE_DOCKER_OVERWRITE is set, as in build.sh; a refusal stops the run there.
#
# It used to load every archive and check every tag before the first push. On
# the shared agents the local image store is not stable: an image that is not
# in use is evicted while a job still holds it (see the hash tag note in
# scripts/docker/build.sh). Loading a release's forty-odd images took over an
# hour, and the first push then failed with "An image does not exist locally".
# Holding one image for the minutes it takes to push it keeps that window small,
# and the store small for the other jobs on the agent.
#
# Optional:
#   MINA_PUBLISH_CODENAMES        comma separated; publish only the images whose
#                                 tag names one of these codenames
#   MINA_PUBLISH_TARGET_REGISTRY  push to this registry instead of the one the
#                                 images are tagged for: same name, same tag,
#                                 other registry. Unset, or the registry the
#                                 images already carry, pushes them as tagged.
#
# DRY_RUN=1 lists what would be pushed.

set -euo pipefail

CACHE_BASE="${CACHE_BASE:-/var/storagebox}"
DRY_RUN="${DRY_RUN:-0}"

ROOTS=("${MINA_READ_CACHE_ROOT:-${BUILDKITE_BUILD_ID:?BUILDKITE_BUILD_ID is not set}}")
if [[ -n "${MINA_GENERIC_CACHE_ROOT:-}" && "${MINA_GENERIC_CACHE_ROOT}" != "${ROOTS[0]}" ]]; then
  ROOTS+=("${MINA_GENERIC_CACHE_ROOT}")
fi

ARCHIVES=()
for root in "${ROOTS[@]}"; do
  dir="${CACHE_BASE}/${root}/docker-images"
  echo "--- Images of build ${root} in ${dir}"
  if [[ -d "$dir" ]]; then
    mapfile -t -O "${#ARCHIVES[@]}" ARCHIVES < <(find "$dir" -mindepth 2 -maxdepth 2 -name '*.tar.zst' | sort)
  fi
done

if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
  echo "❌ No images to publish under ${ROOTS[*]}: did the packaging stage run?" >&2
  exit 1
fi

if [[ -n "${MINA_PUBLISH_CODENAMES:-}" ]]; then
  # An archive is named by its tag, and the codename is one dash-separated
  # segment of it (<version>-<codename>-<network>..., or last).
  IFS=',' read -ra WANTED <<< "${MINA_PUBLISH_CODENAMES// /}"
  SELECTED=()
  for archive in "${ARCHIVES[@]}"; do
    tag="$(basename "$archive" .tar.zst)"
    for codename in "${WANTED[@]}"; do
      if [[ "-${tag}-" == *"-${codename}-"* ]]; then
        SELECTED+=("$archive")
        break
      fi
    done
  done
  if [[ ${#SELECTED[@]} -eq 0 ]]; then
    echo "❌ None of the ${#ARCHIVES[@]} image(s) under ${ROOTS[*]} is tagged for ${MINA_PUBLISH_CODENAMES}" >&2
    exit 1
  fi
  echo "--- ${#SELECTED[@]} of ${#ARCHIVES[@]} image(s) are tagged for ${MINA_PUBLISH_CODENAMES}"
  ARCHIVES=("${SELECTED[@]}")
fi

# retag_for_registry <tag>: the same image name and tag in the target registry.
retag_for_registry () {
  echo "${MINA_PUBLISH_TARGET_REGISTRY}/${1##*/}"
}

publish_tag () {
  # publish_tag <tag> <primary> <image id>: push, or alias registry-side.
  local tag="$1" primary="$2" id="$3" published
  if published=$(docker manifest inspect -v "$tag" 2>/dev/null); then
    if grep -q "$id" <<< "$published"; then
      echo "    ${tag} already holds this image"
      return 0
    elif [[ -n "${FORCE_DOCKER_OVERWRITE:-}" ]]; then
      echo "⚠️  ${tag} holds another image; overwriting (FORCE_DOCKER_OVERWRITE)"
    else
      echo "❌ ${tag} already holds another image. Set FORCE_DOCKER_OVERWRITE=1 to replace it." >&2
      return 1
    fi
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "    would push ${tag}"
  elif [[ "$tag" == "$primary" ]]; then
    echo "    pushing ${tag}"
    docker push "$tag"
  else
    # An alias for a manifest that is now in the registry: add it there rather
    # than push the local tag again (build.sh does the same, and for the same
    # reason: the local tag may be gone by now).
    echo "    tagging ${tag} in the registry"
    docker buildx imagetools create --tag "$tag" "$primary"
  fi
  PUSHED=$((PUSHED + 1))
}

PUSHED=0
for archive in "${ARCHIVES[@]}"; do
  echo "--- Loading ${archive}"
  mapfile -t tags < <(zstd -dc "$archive" | docker load | sed -n 's/^Loaded image: //p')
  if [[ ${#tags[@]} -eq 0 ]]; then
    echo "❌ ${archive} holds no tagged image" >&2
    exit 1
  fi
  loaded=("${tags[@]}")
  if [[ -n "${MINA_PUBLISH_TARGET_REGISTRY:-}" ]]; then
    # The archive holds the tags of the registry it was built for. Give the
    # image the same tags in the target registry and publish those instead.
    tags=()
    for tag in "${loaded[@]}"; do
      target="$(retag_for_registry "$tag")"
      if [[ "$target" != "$tag" ]]; then
        docker tag "$tag" "$target"
      fi
      tags+=("$target")
    done
  fi
  primary="${tags[0]}"
  id="$(docker image inspect --format '{{.Id}}' "$primary")"
  for tag in "${tags[@]}"; do
    publish_tag "$tag" "$primary" "$id"
  done
  # Done with it: free the store for the next archive and for the other jobs.
  # Best effort, and only an image this run loaded or tagged.
  remove=("${loaded[@]}")
  if [[ "${tags[*]}" != "${loaded[*]}" ]]; then
    remove+=("${tags[@]}")
  fi
  docker image rm --no-prune "${remove[@]}" > /dev/null 2>&1 || true
done

echo "✅ ${PUSHED} tag(s) $([[ "$DRY_RUN" == "1" ]] && echo "would be " )published from ${#ARCHIVES[@]} image(s)."
