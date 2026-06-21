#!/usr/bin/env bash

# Load a docker image from the shared CI cache on the Hetzner storagebox.
#
# Usage: ./buildkite/scripts/docker/load_from_cache.sh <full-image>
#
# Example:
#   ./buildkite/scripts/docker/load_from_cache.sh \
#     docker.io/minaprotocol/mina-toolchain:4.0.0-rc1-dkijania-mina-toolchain-relief-169fd52-bullseye
#
# The cache layout (produced by scripts/docker/build.sh --save-to-ci-cache) is:
#   ${CACHE_ROOT}/<service>/<tag>.tar.zst
# where <service> is the image name (last path component before ':') and <tag>
# is the part after ':'. So for the example above the cached file is:
#   /var/storagebox/docker-cache/mina-toolchain/4.0.0-rc1-dkijania-mina-toolchain-relief-169fd52-bullseye.tar.zst

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <full-image>" >&2
  exit 1
fi

IMAGE="$1"
CACHE_ROOT="${CACHE_ROOT:-/var/storagebox/docker-cache}"

# Reclaim disk if the agent is getting full, before we run docker. Covers
# RunInToolchain jobs (which don't run a docker build, so the build-job prune
# never fires for them). Threshold-gated and non-fatal. Disable with DISK_CLEANUP=0.
if [[ "${DISK_CLEANUP:-1}" != "0" && -x ./buildkite/scripts/docker/disk-cleanup.sh ]]; then
  ./buildkite/scripts/docker/disk-cleanup.sh || true
fi

if [[ "$IMAGE" != *:* ]]; then
  echo "ERROR: image '$IMAGE' has no tag; expected <registry>/<service>:<tag>" >&2
  exit 1
fi

REPO="${IMAGE%:*}"
TAG="${IMAGE##*:}"
SERVICE="${REPO##*/}"

CACHE_FILE="${CACHE_ROOT}/${SERVICE}/${TAG}.tar.zst"

if [[ ! -f "$CACHE_FILE" ]]; then
  echo "ERROR: cached image not found at ${CACHE_FILE}" >&2
  exit 1
fi

echo "Loading ${IMAGE} from CI cache at ${CACHE_FILE}"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image ${IMAGE} already exists locally, skipping load"
  exit 0
fi

zstd -dc "$CACHE_FILE" | docker load
