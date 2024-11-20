#!/bin/bash
set -euox pipefail

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
export GITBRANCH=$(git name-rev --name-only $GITHASH | sed "s/remotes\/origin\///g" | sed 's!/!-!g; s!_!-!g; s!#!-!g' )
export GITTAG=$(find_most_recent_numeric_tag HEAD)

export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DEB_RELEASE="unstable"
export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"