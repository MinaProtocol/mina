#!/bin/bash

# Stage .deb files this agent built itself into the docker build context.
#
# scripts/docker/build.sh picks up every *.deb sitting in the docker build
# context and stages it under _debs/, which the Dockerfiles COPY into the image
# for install-mina-debs.sh -- no apt repo involved. So an image can be built out
# of packages that never went to the CI cache, as long as the debian build ran
# on this agent first.
#
# This is the local-disk counterpart of read_all_from_cache.sh, which fills the
# same directory from the CI cache when the debs were built by another job on
# another agent.
#
# Usage: stage_local_debs.sh [<source-dir>]   (default source: _build)

set -eo pipefail

SOURCE_DIR="${1:-_build}"
DEB_STAGE="dockerfiles"

echo "--- Staging locally built debian packages into ${DEB_STAGE}"

shopt -s nullglob
built_debs=("${SOURCE_DIR}"/*.deb)
shopt -u nullglob

if [[ "${#built_debs[@]}" -eq 0 ]]; then
  echo "No .deb files found in ${SOURCE_DIR}/. The debian build must run first." >&2
  exit 1
fi

echo "Staging ${#built_debs[@]} locally built .deb file(s):"
printf '  %s\n' "${built_debs[@]}"
cp "${built_debs[@]}" "${DEB_STAGE}/"
