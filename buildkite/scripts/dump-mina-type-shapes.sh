#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl

TESTNET_NAME="berkeley"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1

MINA_COMMIT_SHA1=$(git log -n 1 --format=%h --abbrev=7)
export TYPE_SHAPE_FILE=${MINA_COMMIT_SHA1}-type_shape.txt

echo "--- Create type shapes git note for commit: ${MINA_COMMIT_SHA1}"
mina internal dump-type-shapes > ${TYPE_SHAPE_FILE}
