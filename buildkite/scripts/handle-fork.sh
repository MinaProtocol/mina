#!/bin/bash

export MINA_REPO="https://github.com/MinaProtocol/mina.git"

if [ "${BUILDKITE_REPO}" ==  ${MINA_REPO} ]; then
    echo "This is not a Forked repo, skipping..."
    export REMOTE="origin"
    export FORK=0
else
    git remote add mina ${MINA_REPO} || true
    git fetch mina
    export REMOTE="mina"
    export FORK=1
fi