#!/usr/bin/env bash

# Remove from the local docker daemon the images a docker job created.
#
# Usage: remove-owned-images.sh <owned-refs-file>
#
# scripts/docker/build.sh --owned-refs-file writes one ref on each line: the
# tags it built, and a base it loaded from the build cache. After the job these
# are in the cache archive and nobody on this agent needs them; left alone they
# fill the daemon, because disk-cleanup.sh only prunes dangling images.
#
# `docker rmi <tag>` only untags while another tag still holds the image, and
# refuses an image a container runs, so a concurrent job keeps what it uses.
# Never fatal.

set +e

REFS_FILE="${1:?Usage: $0 <owned-refs-file>}"

if [[ ! -f "$REFS_FILE" ]]; then
  exit 0
fi

sort -u "$REFS_FILE" | while read -r ref; do
  [[ -n "$ref" ]] || continue
  echo "remove-owned-images: ${ref}"
  docker rmi "$ref" >/dev/null || true
done

rm -f "$REFS_FILE"
exit 0
