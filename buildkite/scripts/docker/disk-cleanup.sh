#!/usr/bin/env bash

# Reclaim docker disk on the CI agent when it is getting full, to avoid the
# "no space left on device" failures during `docker run`.
#
# Shared cleanup called by all the agent-side entry points before they run
# docker: the docker build job (DockerImage.dhall, forced), tests via
# RunInToolchain (load_from_cache.sh) and the postgres tests via RunWithPostgres.
#
# CONCURRENCY-SAFE: agents (generic-multi) run several builds at once, so we must
# not disturb other jobs. `docker system prune` (WITHOUT --all) removes only
# dangling (<none>) images -- the ~24GB/build leftovers that fill the disk --
# plus stopped containers and dangling build cache. It never touches running
# containers, and it KEEPS all tagged images, so a concurrent job's toolchain /
# base images (which it may have pulled but not yet started a container from) are
# left intact. (We deliberately avoid --all, which would evict those.)
#
# Acts only when the docker graph's usage >= DISK_PRUNE_THRESHOLD (default 80)
# so healthy agents pay nothing; set DISK_PRUNE_THRESHOLD=0 to always prune
# (used by the build job). The graph is the daemon's /var/lib/docker, which on
# the CI agents is the DinD sidecar's own volume, not the agent's / (see
# graph-lib.sh). If its usage cannot be read -- no usable local image, or the
# graph is too full to start a container -- the dangling prune runs anyway.
#
# If the graph is still at or above DISK_PRUNE_TARGET (default 70) after that
# prune, orphan-layer-gc.sh reclaims what interrupted `docker load`s left
# behind, which no prune removes. 70 is the buildkite-janitor's watermark: a
# graph brought below it keeps its image cache through the janitor's
# `system prune --all`.
#
# Honours SKIP_DOCKER_PRUNE; never fatal.

set +e

if [[ -n "${SKIP_DOCKER_PRUNE:-}" ]]; then
  echo "disk-cleanup: SKIP_DOCKER_PRUNE set, skipping"
  exit 0
fi

# shellcheck source=buildkite/scripts/docker/graph-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/graph-lib.sh"

THRESHOLD="${DISK_PRUNE_THRESHOLD:-80}"
TARGET="${DISK_PRUNE_TARGET:-70}"

HELPER=$(graph_find_helper)
USE=""
[[ -n "$HELPER" ]] && USE=$(graph_usage "$HELPER" 2>/dev/null | tr -dc '0-9')
if [[ -z "$USE" ]]; then
  echo "disk-cleanup: could not read the docker graph's usage, pruning dangling docker data (concurrency-safe, no --all)"
  docker system prune --force
  exit 0
fi

if [[ "$USE" -lt "$THRESHOLD" ]]; then
  echo "disk-cleanup: docker graph at ${USE}% (< ${THRESHOLD}%), no cleanup needed"
  exit 0
fi

echo "disk-cleanup: docker graph at ${USE}% (>= ${THRESHOLD}%), pruning dangling docker data (concurrency-safe, no --all)"
docker system prune --force
USE=$(graph_usage "$HELPER" 2>/dev/null | tr -dc '0-9')

if [[ -n "$USE" && "$USE" -ge "$TARGET" ]]; then
  echo "disk-cleanup: docker graph at ${USE}% (>= ${TARGET}%) after the prune, reclaiming orphaned layers"
  "$(dirname "${BASH_SOURCE[0]}")/orphan-layer-gc.sh" "$HELPER"
  USE=$(graph_usage "$HELPER" 2>/dev/null | tr -dc '0-9')
fi

echo "disk-cleanup: docker graph at ${USE:-?}% after cleanup"

exit 0
