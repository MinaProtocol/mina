#!/bin/bash
# Install one or more mina debian packages inside a Docker build, directly from
# the local build context (no apt repo / no apt index involved).
#
# scripts/docker/build.sh stages the freshly-built .deb files into the docker
# build context under _debs/, which the Dockerfiles COPY to ${LOCAL_DEB_DIR}
# (default /opt/mina-local-debs). This script resolves each requested mina
# package to its concrete .deb file in that directory and hands the explicit
# file paths to a single `apt-get install`. apt still resolves any non-mina
# dependencies (system libraries) from the image's normal OS apt sources.
#
# Because there is no apt repo serving the mina packages, EVERY mina dependency
# must be requested explicitly: the caller passes the full mina dependency
# closure for the image (e.g. the network metapackage plus mina-logproc and the
# mina-<network>-config package it depends on). Packages are selected by an
# explicit name (+optional version) glob, so unrelated debs that may also be
# present in the context (other networks/profiles) are never installed.
#
# Usage: install-mina-debs.sh "pkg1=version" ["pkg2" ...]
#   - "pkg=version"  resolves to ${LOCAL_DEB_DIR}/pkg_version_*.deb
#   - "pkg"          resolves to ${LOCAL_DEB_DIR}/pkg_*.deb
#
# Environment:
#   LOCAL_DEB_DIR    - directory the local debs were COPY'd to.
#                      Default: /opt/mina-local-debs
#   APT_NO_DOWNGRADE - if set to "1", omit --allow-downgrades

set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 'pkg1=version' ['pkg2' ...]"
  exit 1
fi

LOCAL_DEB_DIR="${LOCAL_DEB_DIR:-/opt/mina-local-debs}"

ALLOW_DOWNGRADES="--allow-downgrades"
if [[ "${APT_NO_DOWNGRADE:-0}" == "1" ]]; then
  ALLOW_DOWNGRADES=""
fi

shopt -s nullglob

# Resolve each requested item to a concrete .deb file in the local deb dir.
deb_files=()
for item in "$@"; do
  if [[ "$item" == *"="* ]]; then
    pkg="${item%%=*}"
    version="${item#*=}"
    matches=("${LOCAL_DEB_DIR}/${pkg}_${version}_"*.deb)
  else
    pkg="$item"
    matches=("${LOCAL_DEB_DIR}/${pkg}_"*.deb)
  fi

  if [[ "${#matches[@]}" -eq 0 ]]; then
    echo "ERROR: no local .deb file found for '${item}' in ${LOCAL_DEB_DIR}"
    echo "       (looked for ${LOCAL_DEB_DIR}/${pkg}_*.deb)"
    echo "Available .deb files in ${LOCAL_DEB_DIR}:"
    ls -1 "${LOCAL_DEB_DIR}"/*.deb 2>/dev/null || echo "  (none)"
    exit 1
  fi

  deb_files+=("${matches[@]}")
done

echo "Installing mina packages directly from local build context ${LOCAL_DEB_DIR}:"
printf '  %s\n' "${deb_files[@]}"

# One apt-get update so non-mina dependencies resolve from the OS apt sources,
# then a single local-file install of the resolved mina .deb files.
apt-get update --quiet --yes

# shellcheck disable=SC2086
apt-get install --no-install-recommends --quiet --yes ${ALLOW_DOWNGRADES} "${deb_files[@]}"

rm -rf /var/lib/apt/lists/*
