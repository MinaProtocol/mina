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
# All or nothing: every archive is loaded and every tag checked before the
# first push. A tag already in the registry is skipped when it holds this very
# image (a retried step), and refused otherwise unless FORCE_DOCKER_OVERWRITE
# is set, as in build.sh.
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

# 1. Load. Each archive's first tag is pushed; the others are added
#    registry-side, as build.sh does.
PRIMARY=()
EXTRA=()
IDS=()
for archive in "${ARCHIVES[@]}"; do
  echo "--- Loading ${archive}"
  mapfile -t tags < <(zstd -dc "$archive" | docker load | sed -n 's/^Loaded image: //p')
  if [[ ${#tags[@]} -eq 0 ]]; then
    echo "❌ ${archive} holds no tagged image" >&2
    exit 1
  fi
  PRIMARY+=("${tags[0]}")
  EXTRA+=("${tags[*]:1}")
  IDS+=("$(docker image inspect --format '{{.Id}}' "${tags[0]}")")
done

# 2. Check every tag before pushing any.
SKIP=()
for i in "${!PRIMARY[@]}"; do
  for tag in ${PRIMARY[$i]} ${EXTRA[$i]}; do
    if published=$(docker manifest inspect -v "$tag" 2>/dev/null); then
      if grep -q "${IDS[$i]}" <<< "$published"; then
        echo "    ${tag} already holds this image"
        SKIP+=("$tag")
      elif [[ -n "${FORCE_DOCKER_OVERWRITE:-}" ]]; then
        echo "⚠️  ${tag} holds another image; overwriting (FORCE_DOCKER_OVERWRITE)"
      else
        echo "❌ ${tag} already holds another image. Set FORCE_DOCKER_OVERWRITE=1 to replace it." >&2
        exit 1
      fi
    fi
  done
done

skipped () {
  local t
  for t in "${SKIP[@]}"; do [[ "$t" == "$1" ]] && return 0; done
  return 1
}

# 3. Push.
PUSHED=0
for i in "${!PRIMARY[@]}"; do
  primary="${PRIMARY[$i]}"
  for tag in ${primary} ${EXTRA[$i]}; do
    if skipped "$tag"; then
      continue
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "    would push ${tag}"
    elif [[ "$tag" == "$primary" ]]; then
      echo "    pushing ${tag}"
      docker push "$tag"
    else
      echo "    tagging ${tag} in the registry"
      docker buildx imagetools create --tag "$tag" "$primary"
    fi
    PUSHED=$((PUSHED + 1))
  done
done

echo "✅ ${PUSHED} tag(s) $([[ "$DRY_RUN" == "1" ]] && echo "would be " )published from ${#ARCHIVES[@]} image(s)."
