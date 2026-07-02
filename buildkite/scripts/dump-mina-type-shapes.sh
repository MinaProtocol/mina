#!/bin/bash

set -eo pipefail

buildkite/scripts/debian/update.sh --verbose

TESTNET_NAME="generic"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

# dump-type-shapes only reads the binary's compiled-in type registry, so the
# freshly-built bare binary from the apps cache is sufficient; no debian package
# (and its config/genesis payload) is required. Fall back to the .deb when the
# bare binary is unavailable. Either way `mina` ends up on PATH.
if ./buildkite/scripts/apps/restore_binary.sh devnet; then
  echo "Using bare mina from apps cache"
else
  echo "Using debian-installed mina"
  source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1
fi

MINA_COMMIT_SHA1=$(git log -n 1 --format=%h --abbrev=7)
export TYPE_SHAPE_FILE=${MINA_COMMIT_SHA1}-type_shape.txt

echo "--- Create type shapes git note for commit: ${MINA_COMMIT_SHA1}"
mina internal dump-type-shapes > "${TYPE_SHAPE_FILE}"

source buildkite/scripts/gsutil-upload.sh "${TYPE_SHAPE_FILE}" gs://mina-type-shapes
