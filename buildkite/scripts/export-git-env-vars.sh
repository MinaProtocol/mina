#!/bin/bash

function find_most_recent_numeric_tag() {
    # We use the --prune flag because we've had problems with buildkite agents getting conflicting results here
    git fetch --tags --prune --prune-tags --force
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo "${TAG}"
}

export GITHASH=$(git rev-parse --short=7 HEAD)

export THIS_COMMIT_TAG=$(git tag --points-at HEAD)
export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}
if [[ -n "$BUILDKITE_BRANCH" ]]; then
   export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g; s!#!-!g')
else
   export GITBRANCH=$(git name-rev --name-only $GITHASH | sed "s/remotes\/origin\///g" | sed 's!/!-!g; s!_!-!g; s!#!-!g' )
fi

export RELEASE=unstable
# GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
export GITTAG=$(find_most_recent_numeric_tag HEAD)

export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"
export RELEASE=unstable

echo "Publishing on release channel \"${RELEASE}\""
[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"

export MINA_DEB_RELEASE="${RELEASE}"