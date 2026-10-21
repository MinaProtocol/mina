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
# `system prune --all`. If that is still not enough, tagged images are removed,
# least recently used first, until the graph is below DISK_PRUNE_TARGET.
# Recency is the image's LastTagTime, which docker sets only on `docker tag`;
# images never tagged go first, oldest build first. An image a container uses
# is never removed (`docker rmi` without --force refuses), nor the helper
# image, nor the refs in DISK_CLEANUP_KEEP (space separated).
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

# Prints "<image-id> <tag> [<tag>...]" for every tagged image, least recently
# used first. LastTagTime and Created are RFC 3339 UTC strings, which sort as
# text; an unset LastTagTime is the zero time, so those images come first.
images_by_recency() {
  docker image ls -q 2>/dev/null | sort -u \
    | xargs -r docker image inspect \
        -f '{{or .Metadata.LastTagTime "0001-01-01T00:00:00Z"}} {{.Created}} {{.Id}} {{range .RepoTags}}{{.}} {{end}}' 2>/dev/null \
    | awk 'NF > 3' | sort -k1,1 -k2,2 | cut -d' ' -f3-
}

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

if [[ -n "$USE" && "$USE" -ge "$TARGET" ]]; then
  echo "disk-cleanup: docker graph at ${USE}% (>= ${TARGET}%), removing least recently used images"
  keep=" $HELPER ${DISK_CLEANUP_KEEP:-} "
  while read -r id tags; do
    skip=0
    for t in $tags; do [[ "$keep" == *" $t "* ]] && skip=1; done
    [[ "$skip" == 1 ]] && continue
    # shellcheck disable=SC2086 # one argument per tag
    docker rmi $tags >/dev/null 2>&1 || continue
    USE=$(graph_usage "$HELPER" 2>/dev/null | tr -dc '0-9')
    echo "disk-cleanup: removed ${tags} (${id:7:12}), docker graph at ${USE:-?}%"
    [[ -n "$USE" && "$USE" -lt "$TARGET" ]] && break
  done < <(images_by_recency)
fi

echo "disk-cleanup: docker graph at ${USE:-?}% after cleanup"

exit 0
