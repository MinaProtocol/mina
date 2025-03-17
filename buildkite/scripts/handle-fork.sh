#!/bin/bash

set -xeo pipefail

export MINA_REPO="https://github.com/MinaProtocol/mina.git"

if [ -z "${BUILDKITE_PULL_REQUEST_REPO}" ]; then
    echo "This is not a Forked repo, skipping..."
    export REMOTE="origin"
    export FORK=0
    exit 0
fi

if [[ "${BUILDKITE_PULL_REQUEST_REPO}" ==  "${MINA_REPO}" ]]; then
    echo "This is not a Forked repo, skipping..."
    export REMOTE="origin"
    export FORK=0
else
    export REMOTE="fork"
    export FORK=1
    if ! git remote -v | grep "${BUILDKITE_PULL_REQUEST_REPO}"; then
        git remote add fork ${BUILDKITE_PULL_REQUEST_REPO}
        git fetch fork --recurse-submodules --tags
        # This is a workaround for missing git-lfs
        rm -f .git/hooks/post-checkout || true
        git switch -c ${BUILDKITE_BRANCH}
    else
        git remote set-url fork ${BUILDKITE_PULL_REQUEST_REPO}
        git fetch fork --recurse-submodules --tags
        # This is a workaround for missing git-lfs
        rm -f .git/hooks/post-checkout || true
        git switch ${BUILDKITE_BRANCH}
    fi
fi