#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

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
echo "deb [trusted=yes] http://packages.o1test.net $deb_codename $deb_release" > /etc/apt/sources.list.d/o1.list \
apt-get update --quiet --yes \
apt-get install --quiet --yes --allow-downgrades "${MINA_DEB}=$deb_version"

echo "--- Audit type shapes"
mina internal audit-type-shapes
