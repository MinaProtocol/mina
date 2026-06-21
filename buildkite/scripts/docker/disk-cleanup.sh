#!/usr/bin/env bash

# Reclaim docker disk on the CI agent when it is getting full, to avoid the
# "no space left on device" failures during `docker run`.
#
# The prune in the docker *build* job (DockerImage.dhall) only runs on build
# steps. Jobs that do NOT build docker images -- tests via RunInToolchain
# (load_from_cache.sh) and the postgres tests via RunWithPostgres -- can still
# land on an agent left full by an earlier build's dangling images. This is the
# shared cleanup those agent-side entry points call before running docker.
#
# Acts only when / usage >= DISK_PRUNE_THRESHOLD (default 80) so healthy agents
# pay nothing; honours SKIP_DOCKER_PRUNE; never fatal. When it does prune it
# removes ALL unused docker data (any age) -- needed images are re-fetched.

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

echo "disk-cleanup: / at ${USE}% (>= ${THRESHOLD}%), pruning all unused docker data"
docker system prune --all --force

echo "disk-cleanup: / usage after cleanup:"
df -h / 2>/dev/null

exit 0
