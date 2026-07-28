#!/usr/bin/env bash

# Reclaim docker disk on the CI agent when it is getting full, to avoid the
# "no space left on device" failures during `docker run`.
#
# Shared cleanup called by all the agent-side entry points before they run
# docker: the docker build job (DockerImage.dhall, forced), tests via
# RunInToolchain (load_from_cache.sh) and the postgres tests via RunWithPostgres.
#
# Two stages:
#
#   1. `docker system prune` (WITHOUT --all) removes dangling (<none>) images --
#      the ~24GB/build leftovers -- plus stopped containers and dangling build
#      cache. It never touches running containers and KEEPS tagged images.
#
#   2. `docker rmi -f` over the remaining TAGGED images. The prune alone is not
#      enough: the tagged toolchain / base / mina-* images left behind by earlier
#      jobs are what actually fill the disk. This stage skips
#        - images backing a running container (so a co-located job is not killed),
#        - anything matching KEEP_IMAGE_PATTERN (the buildkite-agent image).
#      Removal failures are non-fatal by design (an image may be in use, or a
#      concurrent job may have removed it already). Set SKIP_DOCKER_RMI=1 to
#      keep only stage 1.
#
# Evicting tagged images can force a co-located job to re-pull / re-load an image
# it had already fetched -- slower, but never fatal, and far cheaper than ENOSPC.
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

# Images we must never delete, as an extended regex matched against
# "<repository>:<tag>". The buildkite-agent image is the agent running this very
# job; removing it breaks the agent for every subsequent job on the host.
KEEP_IMAGE_PATTERN="${KEEP_IMAGE_PATTERN:-buildkite[-/]agent}"

USE=$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')
if [[ -z "$USE" ]]; then
  echo "disk-cleanup: could not read / usage, skipping"
  exit 0
fi

if [[ "$USE" -lt "$THRESHOLD" ]]; then
  echo "disk-cleanup: / at ${USE}% (< ${THRESHOLD}%), no cleanup needed"
  exit 0
fi

echo "disk-cleanup: / at ${USE}% (>= ${THRESHOLD}%), pruning dangling docker data"
docker system prune --force

if [[ "${SKIP_DOCKER_RMI:-0}" != "1" ]]; then
  echo "disk-cleanup: removing tagged images (keeping /${KEEP_IMAGE_PATTERN}/ and images of running containers)"

  listing=$(docker images -a --format '{{.ID}} {{.Repository}}:{{.Tag}}' 2>/dev/null)

  all_ids=$(awk '{print $1}' <<< "$listing" | sort -u)

  # Everything we must not touch, as short image IDs:
  #  - any ID carrying a KEEP_IMAGE_PATTERN tag. Filter by ID, NOT by line: the
  #    same ID shows up on several lines of `docker images -a` (extra tags, a
  #    <none>:<none> entry), so a line-level grep -v would let the agent's own
  #    ID back in through one of its other lines and delete it.
  #  - any ID backing a running container, so a co-located job is not killed.
  #    `docker inspect` reports full sha256 digests, `docker images` short IDs,
  #    hence the cut to 12 chars.
  keep_ids=$(
    {
      grep -E "$KEEP_IMAGE_PATTERN" <<< "$listing" | awk '{print $1}'
      docker ps -q \
        | xargs -r docker inspect --format '{{.Image}}' 2>/dev/null \
        | sed 's/^sha256://' \
        | cut -c1-12
    } | sort -u
  )

  candidates=$(comm -23 <(echo "$all_ids") <(echo "$keep_ids"))

  if [[ -n "$candidates" ]]; then
    # Errors here are normal and MUST NOT fail the job:
    #   "No such image: <id>:latest" -- the layer was already deleted as a
    #      dependency of an image removed earlier in the same batch;
    #   "conflict: ... image is being used by running container" -- a co-located
    #      job (or the agent itself) holds it; -f cannot override this.
    # Only the errors are echoed; the per-layer "Deleted:" spam is counted.
    # shellcheck disable=SC2086
    rmi_out=$(docker rmi -f $candidates 2>&1)
    echo "disk-cleanup: removed $(grep -c '^Untagged:' <<< "$rmi_out") tags, $(grep -c '^Deleted:' <<< "$rmi_out") layers"
    grep -E '^(Error|.*conflict)' <<< "$rmi_out" | sort -u | head -20
    echo "disk-cleanup: image removal finished (errors above are expected and ignored)"
  else
    echo "disk-cleanup: no removable images"
  fi

  # Sweep the build cache and anything the rmi pass turned into garbage.
  docker system prune --force
fi

echo "disk-cleanup: / usage after cleanup:"
df -h / 2>/dev/null

exit 0
