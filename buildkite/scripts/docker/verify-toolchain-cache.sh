#!/usr/bin/env bash

# Nightly validation that the mina-toolchain docker images cached on the Hetzner
# storagebox are byte-for-byte equivalent to the same images on docker.io.
#
# The toolchain image is produced infrequently and is the only artifact we host
# on docker.io directly. Build jobs save a copy of the freshly-built image to
# the shared CI cache so the rest of the pipeline can load it without paying
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

mismatched=()
missing_remote=()

if [[ ! -d "$CACHE_DIR" ]]; then
  echo "Cache directory ${CACHE_DIR} does not exist; nothing to validate."
  exit 0
fi

shopt -s nullglob
files=("$CACHE_DIR"/*.tar.zst)
if (( ${#files[@]} == 0 )); then
  echo "No cached toolchain images found in ${CACHE_DIR}."
  exit 0
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

for cached_file in "${files[@]}"; do
  base="$(basename "$cached_file")"
  tag="${base%.tar.zst}"
  remote_ref="${DOCKER_REGISTRY}/${SERVICE}:${tag}"

  echo "==> Verifying ${remote_ref} against ${cached_file}"

  if ! docker pull --quiet "$remote_ref" >/dev/null; then
    echo "WARNING: failed to pull ${remote_ref} from docker.io — skipping"
    missing_remote+=("$tag")
    continue
  fi
  remote_id="$(docker image inspect --format '{{.Id}}' "$remote_ref")"

  if ! cached_id="$(load_cached_image_id "$cached_file")"; then
    echo "WARNING: could not derive image id from ${cached_file}; treating as mismatch"
    cached_id=""
  fi

  if [[ -n "$remote_id" && "$cached_id" == "$remote_id" ]]; then
    echo "OK ${tag}"
    continue
  fi

  echo "MISMATCH ${tag} (cache=${cached_id:-<unknown>} docker.io=${remote_id})"
  mismatched+=("$tag")

  tmp="$(mktemp "${cached_file}.new.XXXXXX")"
  if docker save "$remote_ref" | zstd -T0 -3 > "$tmp"; then
    mv -f "$tmp" "$cached_file"
    echo "REPLACED ${cached_file} with copy from docker.io"
  else
    rm -f "$tmp"
    echo "ERROR: failed to save and replace ${cached_file}"
    exit 1
  fi
done

echo
echo "Summary: validated ${#files[@]} cached image(s); replaced ${#mismatched[@]}; ${#missing_remote[@]} not on docker.io."
if (( ${#mismatched[@]} > 0 )); then
  printf 'Replaced from docker.io:\n'
  printf ' - %s\n' "${mismatched[@]}"
fi
if (( ${#missing_remote[@]} > 0 )); then
  printf 'Cached but missing on docker.io (left untouched):\n'
  printf ' - %s\n' "${missing_remote[@]}"
fi
