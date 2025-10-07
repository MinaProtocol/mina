#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

pip3 install sexpdata==1.0.0

source ./buildkite/scripts/refresh_code.sh

base_branch=origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-compatible}
pr_branch=${BUILDKITE_BRANCH}
release_branch=origin/$1

echo "--- Run Python version linter with branches: ${pr_branch} ${base_branch} ${release_branch}"
./scripts/version-linter.py ${pr_branch} ${base_branch} ${release_branch}

echo "--- Install Mina"
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-base" 1

echo "--- Audit type shapes"
mina internal audit-type-shapes
