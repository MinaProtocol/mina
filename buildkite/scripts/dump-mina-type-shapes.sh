#!/bin/bash

set -eo pipefail

buildkite/scripts/debian/update.sh --verbose

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-base" 1

MINA_COMMIT_SHA1=$(git log -n 1 --format=%h --abbrev=7)
export TYPE_SHAPE_FILE=${MINA_COMMIT_SHA1}-type_shape.txt

echo "--- Create type shapes git note for commit: ${MINA_COMMIT_SHA1}"
mina internal dump-type-shapes > ${TYPE_SHAPE_FILE}

source buildkite/scripts/gsutil-upload.sh ${TYPE_SHAPE_FILE} gs://mina-type-shapes