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
# Acts only when / usage >= DISK_PRUNE_THRESHOLD (default 80) so healthy agents
# pay nothing; set DISK_PRUNE_THRESHOLD=0 to always prune (used by the build
# job). Honours SKIP_DOCKER_PRUNE; never fatal.

set +e

if [[ -n "${SKIP_DOCKER_PRUNE:-}" ]]; then
  echo "disk-cleanup: SKIP_DOCKER_PRUNE set, skipping"
  exit 0
fi

THRESHOLD="${DISK_PRUNE_THRESHOLD:-80}"

USE=$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')
if [[ -z "$USE" ]]; then
  echo "disk-cleanup: could not read / usage, skipping"
  exit 0
fi

if [[ "$USE" -lt "$THRESHOLD" ]]; then
  echo "disk-cleanup: / at ${USE}% (< ${THRESHOLD}%), no cleanup needed"
  exit 0
fi

echo "disk-cleanup: / at ${USE}% (>= ${THRESHOLD}%), pruning dangling docker data (concurrency-safe, no --all)"
docker system prune --force

echo "disk-cleanup: / usage after cleanup:"
df -h / 2>/dev/null

exit 0
