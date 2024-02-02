#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

TESTNET_NAME="${TESTNET_NAME:-berkeley}"

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl python3 python3-pip wget

git config --global --add safe.directory /workdir


source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

pip3 install sexpdata==1.0.0

base_branch=${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}
pr_branch=origin/${BUILDKITE_BRANCH}
release_branch=${REMOTE}/$1

echo "--- Run Python version linter with branches: ${pr_branch} ${base_branch} ${release_branch}"
./scripts/version-linter.py ${pr_branch} ${base_branch} ${release_branch}

echo "--- Install Mina"
source buildkite/scripts/export-git-env-vars.sh
TESTNET_NAME="berkeley"
echo "Installing mina daemon package: mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"
echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | tee /etc/apt/sources.list.d/mina.list
apt-get update --yes
apt-get install --yes --allow-downgrades "mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"

echo "--- Audit type shapes"
mina internal audit-type-shapes
