#!/bin/bash

if [ -z "$MINA_DEB_CODENAME" ]; then
  echo "MINA_DEB_CODENAME is not set. Exiting."
  exit 1
fi

if [ -z "$ROOT" ]; then
  echo "ROOT is not set. Exiting."
  exit 1
fi

if [ -z "$LOCAL_DEB_FOLDER" ]; then
  echo "LOCAL_DEB_FOLDER is not set. Exiting."
  exit 1
fi

# MINA_READ_CACHE_ROOT overrides ROOT, so the packages can be read from a cache
# root other than this build's own. Use it when the .deb files are kept in a non
# standard location, for example the root of a different build.
ROOT="${MINA_READ_CACHE_ROOT:-$ROOT}"

# DEB_VARIANT names the build variant whose packages to read, as
# write_to_cache.sh stores them: empty for a standard amd64 build, else
# "instrumented", "arm64" or "instrumented-arm64". DEB_PATTERN narrows the
# files read from that folder. With DEB_OPTIONAL set, a root that has no
# folder for the variant is skipped instead of failing the read.
DEB_DIR="debians/${MINA_DEB_CODENAME}${DEB_VARIANT:+/${DEB_VARIANT}}"
DEB_PATTERN="${DEB_PATTERN:-*.deb}"

read_debs() {
  local root=$1
  if [[ -n "${DEB_OPTIONAL:-}" ]] \
    && ! buildkite-cache-manager list "${root}/${DEB_DIR}" >/dev/null 2>&1; then
    echo "No ${DEB_DIR} in ${root}, skipping"
    return 0
  fi
  buildkite-cache-manager read --root "${root}" "${DEB_DIR}/${DEB_PATTERN}" "${LOCAL_DEB_FOLDER}"
}

mkdir -p "$LOCAL_DEB_FOLDER"
source ./buildkite/scripts/export-git-env-vars.sh
buildkite-cache-manager read --root legacy/debians "$MINA_DEB_CODENAME/*" "${LOCAL_DEB_FOLDER}"
read_debs "${ROOT}"

# MINA_GENERIC_CACHE_ROOT names the build that made the network-less packages
# (mina-generic, *-generic, logproc). A network packaging run built without
# them, so their .debs come from that build.
if [[ -n "${MINA_GENERIC_CACHE_ROOT:-}" ]]; then
  read_debs "${MINA_GENERIC_CACHE_ROOT}"
fi
