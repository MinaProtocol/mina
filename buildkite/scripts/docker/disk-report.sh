#!/usr/bin/env bash

# Read-only disk diagnostics for the CI agent, to investigate the recurring
# "no space left on device" failures during `docker run`. Prints filesystem
# usage, docker's own disk accounting (images / containers / volumes / build
# cache, incl. how much is reclaimable) and the largest local images.
#
# This is intentionally fast (docker-native accounting, no `du` over the
# overlay2 tree or the SSHFS cache mount) and NEVER fails its caller -- it is a
# diagnostic, so any error here must not abort the job.

set +e

echo "--- disk-report: df -h ---"
df -h 2>/dev/null

echo "--- disk-report: df -h /var/lib/docker ---"
df -h /var/lib/docker 2>/dev/null

echo "--- disk-report: docker system df ---"
docker system df 2>/dev/null

echo "--- disk-report: largest local images (top 25) ---"
docker images --format '{{.Size}}\t{{.CreatedSince}}\t{{.Repository}}:{{.Tag}}' 2>/dev/null \
  | sort -rh | head -25

echo "--- disk-report: image / container / volume counts ---"
printf 'images=%s containers(all)=%s volumes=%s\n' \
  "$(docker images -aq 2>/dev/null | wc -l)" \
  "$(docker ps -aq 2>/dev/null | wc -l)" \
  "$(docker volume ls -q 2>/dev/null | wc -l)"

echo "--- disk-report: end ---"

exit 0
