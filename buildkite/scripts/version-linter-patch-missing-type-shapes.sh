#!/bin/bash

set -eox pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

release_branch=${REMOTE}/$1

RELEASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 --no-merges $release_branch)

function checkout_and_dump() {
    local __commit=$1
    git checkout $__commit
    git submodule sync
    git submodule update --init --recursive
    source ~/.profile
    dune exec src/app/cli/src/mina.exe internal dump-type-shapes > ${__commit:0:7}-type-shapes.txt
}

if ! $(gsutil ls gs://mina-type-shapes/$BUILDKITE_COMMIT 2>/dev/null); then
    checkout_and_dump $BUILDKITE_COMMIT
fi

if ! $(gsutil ls gs://mina-type-shapes/$RELEASE_BRANCH_COMMIT 2>/dev/null); then
    checkout_and_dump $RELEASE_BRANCH_COMMIT
fi