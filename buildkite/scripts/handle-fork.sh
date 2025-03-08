#!/bin/bash

export MINA_REPO="https://github.com/MinaProtocol/mina.git"

if [ "${BUILDKITE_PULL_REQUEST_REPO}" ==  ${MINA_REPO} ]; then
    echo "This is not a Forked repo, skipping..."
    export REMOTE="origin"
    export FORK=0
else
    git remote add fork ${BUILDKITE_PULL_REQUEST_REPO} || true
    export REMOTE="fork"
    export FORK=1
fi