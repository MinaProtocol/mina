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

# ROOT arrives from the rendered command as this build's id. A build asked to
# take its packages from an earlier one says so in MINA_READ_CACHE_ROOT, and
# that wins: the .deb files it wants are under that build's root, not this
# build's, which holds nothing because no debian step ran.
ROOT="${MINA_READ_CACHE_ROOT:-$ROOT}"

mkdir -p "$LOCAL_DEB_FOLDER"
source ./buildkite/scripts/export-git-env-vars.sh
./buildkite/scripts/cache/manager.sh read --root legacy/debians "$MINA_DEB_CODENAME/*" "${LOCAL_DEB_FOLDER}"
./buildkite/scripts/cache/manager.sh read --root "${ROOT}" "debians/$MINA_DEB_CODENAME/*" "${LOCAL_DEB_FOLDER}"