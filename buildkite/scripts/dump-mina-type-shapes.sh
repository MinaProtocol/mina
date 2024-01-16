#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl

TESTNET_NAME="berkeley"

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

echo "Installing mina daemon package: mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"
echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | tee /etc/apt/sources.list.d/mina.list

apt-get update
apt-get install --allow-downgrades -y "mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"

MINA_COMMIT_SHA1=$(git log -n 1 --format=%h --abbrev=7 --no-merges)
export TYPE_SHAPE_FILE=${MINA_COMMIT_SHA1}-type_shape.txt

echo "--- Create type shapes git note for commit: ${MINA_COMMIT_SHA1}"
mina internal dump-type-shapes > ${TYPE_SHAPE_FILE}