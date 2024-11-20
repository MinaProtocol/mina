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

    # Abort if `BUILDKITE_REPO` doesn't have the expected format
    echo ${BUILDKITE_REPO} | grep -P '^.*github.com[:\/](.*)\.git$' > /dev/null || \
      (echo "BUILDKITE_REPO does not have the expected format" && false)

    # We don't want to allow some operations on fork repository which should be done on main repo only. 
    # Publish to docker hub or publish to unstable debian channel should be exclusive to main repo as it can override 
    # packages from main repo (by using the same commit and the same branch from forked repository)

    # We don't want to use tags (as this can replace our dockers/debian packages). Instead we are using repo name
    # For example: for given repo 'https://github.com/dkijania/mina.git' we convert it to 'dkijania_mina' 
    export GITTAG=1.0.0$(echo ${BUILDKITE_REPO} | sed -e 's/^.*github.com[:\/]\(.*\)\.git$/\1/' -e 's/\//-/')
    export THIS_COMMIT_TAG=""
    export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
fi