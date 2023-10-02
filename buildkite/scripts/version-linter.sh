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

source buildkite/scripts/export-git-env-vars.sh

pip3 install sexpdata

base_branch=origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}
pr_branch=origin/${BUILDKITE_BRANCH}
release_branch=origin/$1

echo "--- Run Python version linter with branches: ${pr_branch} ${base_branch} ${release_branch}"
./scripts/version-linter.py ${pr_branch} ${base_branch} ${release_branch}