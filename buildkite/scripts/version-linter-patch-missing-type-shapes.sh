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

RELEASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 $release_branch)

function revert_checkout() {
    git checkout $BUILDKITE_COMMIT
    git submodule sync
    git submodule update --init --recursive
}

function checkout_and_dump() {
    local __commit=$1
    git checkout $__commit
    git submodule sync
    git submodule update --init --recursive
    eval $(opam config env)
    TYPE_SHAPE_FILE=${__commit:0:7}-type_shape.txt
    dune exec src/app/cli/src/mina.exe internal dump-type-shapes > /tmp/${TYPE_SHAPE_FILE}
    revert_checkout
    source buildkite/scripts/gsutil-upload.sh /tmp/${TYPE_SHAPE_FILE} gs://mina-type-shapes
}

if ! gsutil ls "gs://mina-type-shapes/${RELEASE_BRANCH_COMMIT}*" >/dev/null; then
    checkout_and_dump $RELEASE_BRANCH_COMMIT
fi

if [[ -n "${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-}" ]]; then 
    BUILDKITE_PULL_REQUEST_BASE_BRANCH_COMMIT=$(git log -n 1 --format="%h" --abbrev=7 ${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH} )
    if ! gsutil ls "gs://mina-type-shapes/${BUILDKITE_PULL_REQUEST_BASE_BRANCH_COMMIT}*"; then
        checkout_and_dump $BUILDKITE_PULL_REQUEST_BASE_BRANCH_COMMIT
    fi
fi