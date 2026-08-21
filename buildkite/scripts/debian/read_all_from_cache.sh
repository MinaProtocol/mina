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

mkdir -p "$LOCAL_DEB_FOLDER"
source ./buildkite/scripts/export-git-env-vars.sh
./buildkite/scripts/cache/manager.sh read --root legacy/debians "$MINA_DEB_CODENAME/*" "${LOCAL_DEB_FOLDER}"
./buildkite/scripts/cache/manager.sh read --root "${ROOT}" "debians/$MINA_DEB_CODENAME/*" "${LOCAL_DEB_FOLDER}"