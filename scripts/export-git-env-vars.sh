#!/bin/bash
set -euo pipefail

# If enabled, keep my tags intact, it won't run git fetch --prune
KEEP_MY_TAGS_INTACT=${KEEP_MY_TAGS_INTACT:-1}

function find_most_recent_numeric_tag() {

    local keep_tags_values=("1" "true" "t" "T" "y" "yes" "Y" "YES")
    if [[ ! " ${keep_tags_values[*]} " =~  ${KEEP_MY_TAGS_INTACT}  ]]; then
        # We use the --prune flag because we've had problems with buildkite agents getting conflicting results here
        git fetch --tags --prune --prune-tags --force
    else
        git fetch --tags --force
    fi
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

GITHASH_CONFIG=${OVERRIDE_GITHASH:-$(git rev-parse --short=8 --verify HEAD)}
# Remove last character to get 7-character short hash
GITHASH=${GITHASH_CONFIG%?}
THIS_COMMIT_TAG=${OVERRIDE_TAG:-$(git tag --points-at HEAD)}
REPO_ROOT="$(git rev-parse --show-toplevel)"

if [[ -v BRANCH_NAME ]]; then
   GITBRANCH=$(echo "$BRANCH_NAME" | sed 's!/!-!g; s!_!-!g; s!#!-!g')
else
   GITBRANCH=$(git name-rev --name-only $GITHASH | sed "s/remotes\/origin\///g" | sed 's!/!-!g; s!_!-!g; s!#!-!g' )
fi

GITTAG=${OVERRIDE_TAG:-$(find_most_recent_numeric_tag HEAD)}


if [[ "${SKIP_GITBRANCH:-0}" == "1" ]]; then
    MINA_DEB_VERSION="${GITTAG}-${GITHASH}"
else
    MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
fi

MINA_DOCKER_TAG=$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')

[[ -v THIS_COMMIT_TAG ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"

export GITTAG
export GITHASH
export GITHASH_CONFIG
export GITBRANCH
export MINA_DEB_VERSION
export MINA_DOCKER_TAG
export THIS_COMMIT_TAG
export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}
export REPO_ROOT