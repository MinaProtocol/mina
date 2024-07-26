#!/bin/bash
set -euo pipefail

echo "Exporting Variables: "

export MINA_REPO="https://github.com/MinaProtocol/mina.git"

function find_most_recent_numeric_tag() {
    # We use the --prune flag because we've had problems with buildkite agents getting conflicting results here
    git fetch --tags --prune --prune-tags --force
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g; s!#!-!g' )

export THIS_COMMIT_TAG=$(git tag --points-at HEAD)
export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}
[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g; s!#!-!g')
 
export RELEASE=unstable

if [ "${BUILDKITE_REPO}" != "${MINA_REPO}" ]; then 
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

else
  # GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
  export GITTAG=$(find_most_recent_numeric_tag HEAD)
fi


export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"
export RELEASE=unstable

echo "Publishing on release channel \"${RELEASE}\""
[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"
export MINA_DEB_RELEASE="${RELEASE}"