#!/bin/bash
set -eo pipefail

set +x
echo "Exporting Variables: "

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
# GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
export GITTAG=$(git describe --always --abbrev=0 | sed 's!/!-!g; s!_!-!g')
export PROJECT="mina"

set +u
export BUILD_NUM=1
export BUILD_URL="local"
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=stretch}
export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DEB_RELEASE="unstable"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}" | sed 's!/!-!g; s!_!-!g')-${MINA_DEB_CODENAME}"

