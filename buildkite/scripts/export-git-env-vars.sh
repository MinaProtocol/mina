#!/bin/bash
set -eo pipefail

set +x
echo "Exporting Variables: "

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
# GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
export GITTAG=$(git describe --always --abbrev=0 | sed 's!/!-!g; s!_!-!g')
export THIS_COMMIT_TAG=$(git tag --points-at HEAD)
export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g')

export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"
RELEASE=unstable

echo "Publishing on release channel \"${RELEASE}\" based on branch \"${GITBRANCH}\" and tag \"${THIS_COMMIT_TAG}\""
[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"
export MINA_DEB_RELEASE="${RELEASE}"