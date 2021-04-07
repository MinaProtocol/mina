#!/bin/bash
set -eo pipefail

set +x
echo "Exporting Variables: "

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
export GITTAG=$(git describe --abbrev=0 | sed 's!/!-!g; s!_!-!g')


# Identify All Artifacts by Branch and Git Hash
set +u



# Everything that uses this is doing a testnet_postake_medium_curves build, and
# we generate packages with different signatures there. Instead of trying to
# infer a name and ending up with a silly mina-mainnet-testnet package, lets
# just call them mina-dev.
export PROJECT="mina-dev"
# export PROJECT="mina-$(echo "$DUNE_PROFILE" | tr _ -)"

export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g')

if [[ "$BUILDKITE_BRANCH" == "master" ]]; then
    export VERSION="${GITTAG}-${GITHASH}"
    export GENERATE_KEYPAIR_VERSION=${VERSION}
    export DOCKER_TAG="$(echo "${VERSION}" | sed 's!/!-!g; s!_!-!g')"
else
    export VERSION="${GITTAG}+${BUILD_NUM}-${GITBRANCH}-${GITHASH}"
    export DOCKER_TAG="$(echo "${GITTAG}-${GITBRANCH}" | sed 's!/!-!g; s!_!-!g')"
    export GENERATE_KEYPAIR_VERSION=${GITTAG}-${GITHASH}
fi

case $BUILDKITE_BRANCH in master|develop|rosetta*)
  export BUILD_ROSETTA=true
esac

set -x
