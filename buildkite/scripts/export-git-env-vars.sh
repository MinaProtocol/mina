#!/bin/bash
set -eo pipefail

set +x
echo "Exporting Variables: "

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
export GITTAG=$(git describe --abbrev=0)


# Identify All Artifacts by Branch and Git Hash
set +u

export PVKEYHASH=$(/workdir/_build/default/src/app/cli/src/coda.exe internal snark-hashes | sort | md5sum | cut -c1-8)

export PROJECT="coda-$(echo "$DUNE_PROFILE" | tr _ -)"

export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!; s!_!-!g')

if [[ "$BUILDKITE_BRANCH" == "master" ]]; then
    export VERSION="${GITTAG}-${GITHASH}"
    export DOCKER_TAG="$(echo "${VERSION}" | sed 's!/!-!; s!_!-!g')"
else
    export VERSION="${GITTAG}+${BUILD_NUM}-${GITBRANCH}-${GITHASH}-PV${PVKEYHASH}"
    export DOCKER_TAG="$(echo "${GITTAG}-${GITBRANCH}" | sed 's!/!-!g; s!_!-!g')"
fi

case $BUILDKITE_BRANCH in master|develop|rosetta*)
  export BUILD_ROSETTA=true
esac

set -x
