#!/bin/bash
set -eo pipefail

set +x
echo "Exporting Variables: "

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
export GITTAG=$(git describe --always --abbrev=0 | sed 's!/!-!g; s!_!-!g')

# Identify All Artifacts by Branch and Git Hash
set +u

# Everything that uses this is doing a devnet build, and
# we generate packages with different signatures there. Instead of trying to
# infer a name and ending up with a silly mina-mainnet-testnet package, lets
# just call them mina.
export PROJECT="mina"
# export PROJECT="mina-$(echo "$DUNE_PROFILE" | tr _ -)"

export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g')

if [[ "$BUILDKITE_BRANCH" == "master" ]]; then
    export DEB_VERSION="${GITTAG}-${GITHASH}"
    export GENERATE_KEYPAIR_VERSION=${VERSION}
    export DOCKER_TAG="$(echo "${VERSION}" | sed 's!/!-!g; s!_!-!g')"
else
    export DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
    export DOCKER_TAG="$(echo "${GITTAG}-${GITBRANCH}" | sed 's!/!-!g; s!_!-!g')"
    export GENERATE_KEYPAIR_VERSION=${GITTAG}-${GITHASH}
fi

export MINA_DEB_VERSION=${VERSION}
export MINA_DEB_CODENAME=stretch

# Determine deb repo to use
case $BUILDKITE_BRANCH in
    master)
        RELEASE=stable ;;
    compatible|master|enable-alpha-builds|release/*)
        case "$(git tag --points-at HEAD)" in
          *alpha*)
            RELEASE=alpha ;;
          *beta*)
            RELEASE=beta ;;
          "")
            RELEASE=unstable ;;
          *)
            RELEASE=stable ;;
        esac ;;
    *)
        RELEASE=unstable ;;
esac

export MINA_DEB_RELEASE="${RELEASE}"

echo "${RELEASE} for tag $(git tag --points-at HEAD)"

case $BUILDKITE_BRANCH in master|compatible|develop|enable-alpha-builds|rosetta*)
  export BUILD_ROSETTA=true
esac

set -x
