#!/bin/bash
set -euo pipefail
set -x


# In case of running this script on detached head, script has difficulties in finding out
# what is the current 
echo "Exporting Git Variables: "

git fetch

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
export THIS_COMMIT_TAG=$(git tag --points-at HEAD)

[[ -n "$BRANCH_NAME" ]] && export GITBRANCH=$(echo "$BRANCH_NAME" | sed 's!/!-!g; s!_!-!g; s!#!-!g') || export GITBRANCH=$(git name-rev --name-only $GITHASH | sed "s/remotes\/origin\///g" | sed 's!/!-!g; s!_!-!g; s!#!-!g' )

export GITTAG=$(find_most_recent_numeric_tag HEAD)

export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"

[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"

echo "after commit tag"