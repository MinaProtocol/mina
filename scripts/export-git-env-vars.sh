#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

export BUILD_NUM="00"
export BUILD_URL="local development machine"
export RELEASE="experimental"
export MINA_BUILD_MAINNET="false"
export CODENAME="bullseye"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [options]"
  echo "  -n, --build-num           Build number which will be put in control file. Default: ${BUILD_NUM}"
  echo "  -u, --build-url           Build url which will be put in control file. Default ${BUILD_URL}"
  echo "  -r, --release             Debian release. Default ${RELEASE}"
  echo "  -m, --build-mainnet-sigs  Build mainnet and devnet packages too. Default ${MINA_BUILD_MAINNET}"
  echo "  -c, --codename            Debian Codename. Default ${MINA_DEB_CODENAME}"
  echo ""
  echo "Example: $0 --codename focal"
  exit 1
}

function find_most_recent_numeric_tag() {
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g; s!#!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--build-num) BUILD_NUM="$2"; shift;;
  -u|--build-url) BUILD_URL="$2"; shift;;
  -r|--release) RELEASE="$2"; shift;;
  -m|--build-mainnet-sigs) MINA_BUILD_MAINNET="true"; shift;;
  -c|--codename) MINA_DEB_CODENAME="$2"; shift;;
  -h|--help) usage; exit 1;;
  *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g; s!#!-!g' )

export THIS_COMMIT_TAG=$(git tag --points-at HEAD)
export PROJECT="mina"

export GITTAG=$(find_most_recent_numeric_tag HEAD)

if [[ -n "${THIS_COMMIT_TAG}" ]]; then # If the commit is tagged
    export MINA_DEB_VERSION="${GITTAG}-${GITHASH}"
else
    export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
fi

export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g; s!#!-!g')"
[[ -n ${THIS_COMMIT_TAG} ]] && export MINA_COMMIT_TAG="${THIS_COMMIT_TAG}"
export MINA_DEB_RELEASE="${RELEASE}"
