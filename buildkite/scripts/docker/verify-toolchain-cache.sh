#!/usr/bin/env bash

# Nightly validation that long-lived docker images cached on the Hetzner
# storagebox are byte-for-byte equivalent to the same images on docker.io.
#
# By default this validates every cached mina-toolchain image, but callers may
# pass IMAGE_REFS to validate only the image refs that are still in use. It is
# generic over the SERVICE env var for callers that pass tags instead of refs:
# set SERVICE=mina-base to validate the shared common base layer instead.
#
# These images are produced infrequently and are the artifacts we host on
# docker.io directly. Build jobs save a copy of the freshly-built image to the
# shared CI cache so the rest of the pipeline can load it without paying
# docker.io pull cost. This script keeps the two in sync: if a cached image
# diverges from docker.io (corruption, manual overwrite, partial upload,
# missing entry), we pull from docker.io and replace the cache entry.
#
# Comparison uses docker image IDs (sha256 of the image config), which are
# content-addressed and stable across tag renames, save/load cycles and
# compression.

set -euo pipefail

CACHE_ROOT="${CACHE_ROOT:-/var/storagebox/docker-cache}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io/minaprotocol}"
SERVICE="${SERVICE:-mina-toolchain}"
CACHE_DIR="${CACHE_ROOT}/${SERVICE}"
IMAGE_REFS="${IMAGE_REFS:-}"
TAGS="${TAGS:-}"

mismatched=()
missing_remote=()
checks=()

function add_check() {
  local remote_ref="$1"
  local cache_file="$2"
  local tag="$3"
  checks+=("${remote_ref}|${cache_file}|${tag}")
}

function add_ref_check() {
  local ref="$1"
  local repo tag service cache_file

  if [[ "$ref" != *:* ]]; then
    echo "ERROR: image ref '${ref}' has no tag; expected <registry>/<service>:<tag>" >&2
    exit 1
  fi

  repo="${ref%:*}"
  tag="${ref##*:}"
  service="${repo##*/}"
  cache_file="${CACHE_ROOT}/${service}/${tag}.tar.zst"

  add_check "$ref" "$cache_file" "$tag"
}

function add_tag_check() {
  local tag="$1"
  add_check "${DOCKER_REGISTRY}/${SERVICE}:${tag}" "${CACHE_DIR}/${tag}.tar.zst" "$tag"
}

if [[ -n "$IMAGE_REFS" ]]; then
  for ref in $IMAGE_REFS; do
    add_ref_check "$ref"
  done
elif [[ -n "$TAGS" ]]; then
  for tag in $TAGS; do
    add_tag_check "$tag"
  done
else
  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "Cache directory ${CACHE_DIR} does not exist; nothing to validate."
    exit 0
  fi

  shopt -s nullglob
  files=("$CACHE_DIR"/*.tar.zst)
  if (( ${#files[@]} == 0 )); then
    echo "No cached ${SERVICE} images found in ${CACHE_DIR}."
    exit 0
  fi

  for cached_file in "${files[@]}"; do
    base="$(basename "$cached_file")"
    tag="${base%.tar.zst}"
    add_tag_check "$tag"
  done
fi

# Returns the image ID (sha256:...) loaded from a zstd-compressed docker save tar.
# Loads into the local docker daemon as a side effect.
function load_cached_image_id() {
  local tar_file="$1"
  local output image_id
  output="$(zstd -dc "$tar_file" | docker load 2>/dev/null)"
  # docker load prints lines like:
  #   Loaded image: docker.io/minaprotocol/mina-toolchain:<tag>
  # or "Loaded image ID: sha256:..." for untagged tarballs.
  image_id="$(echo "$output" | sed -n 's/^Loaded image[^:]*: //p' | head -n 1)"
  if [[ -z "$image_id" ]]; then
    return 1
  fi
  docker image inspect --format '{{.Id}}' "$image_id" 2>/dev/null
}

for check in "${checks[@]}"; do
  IFS='|' read -r remote_ref cached_file tag <<< "$check"

  echo "==> Verifying ${remote_ref} against ${cached_file}"

  if ! docker pull --quiet "$remote_ref" >/dev/null; then
    echo "WARNING: failed to pull ${remote_ref} from docker.io — skipping"
    missing_remote+=("$tag")
    continue
  fi
  remote_id="$(docker image inspect --format '{{.Id}}' "$remote_ref")"

  if [[ ! -f "$cached_file" ]]; then
    echo "MISSING ${cached_file}; will populate it from ${remote_ref}"
    cached_id=""
  elif ! cached_id="$(load_cached_image_id "$cached_file")"; then
    echo "WARNING: could not derive image id from ${cached_file}; treating as mismatch"
    cached_id=""
  fi

  if [[ -n "$remote_id" && "$cached_id" == "$remote_id" ]]; then
    echo "OK ${tag}"
    continue
  fi

  echo "MISMATCH ${tag} (cache=${cached_id:-<unknown>} docker.io=${remote_id})"
  mismatched+=("$tag")

  # Save by image ID rather than tag: load_cached_image_id above ran
  # `docker load`, which reassigns the local tag to the cached image's
  # content. Using $remote_id pins to the docker.io image inspected
  # before the load, regardless of the current local tag state.
  mkdir -p "$(dirname "$cached_file")"
  tmp="$(mktemp "${cached_file}.new.XXXXXX")"
  if docker save "$remote_id" | zstd -T0 -3 > "$tmp"; then
    mv -f "$tmp" "$cached_file"
    echo "REPLACED ${cached_file} with copy from docker.io"
  else
    rm -f "$tmp"
    echo "ERROR: failed to save and replace ${cached_file}"
    exit 1
  fi
done

echo
echo "Summary: validated ${#checks[@]} cached image(s); replaced ${#mismatched[@]}; ${#missing_remote[@]} not on docker.io."
if (( ${#mismatched[@]} > 0 )); then
  printf 'Replaced from docker.io:\n'
  printf ' - %s\n' "${mismatched[@]}"
fi
if (( ${#missing_remote[@]} > 0 )); then
  printf 'Cached but missing on docker.io (left untouched):\n'
  printf ' - %s\n' "${missing_remote[@]}"
fi
