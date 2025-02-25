#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-d deb-name] [-v new-version] "
  echo "  -d, --deb         The Debian name"
  echo "  -c, --codename    The Debian codename"
  echo "  --release         The Current Debian release"
  echo "  --new-release     The New Debian release"
  echo "  --version         The Current Debian version"
  echo "  --new-version     The New Debian version"
  echo "  --suite           The Current Debian suite"
  echo "  --repo            The Source Debian repo"
  echo "  --new-repo        The Target Debian repo. By default equal to '--repo'"
  echo "  --new-suite       The New Debian suite"
  echo "  --sign            The Public Key id, which is used to sign package. Key must be stored locally"
  echo ""
  echo "Example: $0 --deb mina-archive --version 2.0.0-rc1-48efea4 --new-version 2.0.0-rc1 --codename bullseye --release unstable --new-release umt"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -d|--deb) DEB="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  --new-name) NEW_NAME="$2"; shift;;
  --new-release) NEW_RELEASE="$2"; shift;;
  --new-version) NEW_VERSION="$2"; shift;;
  --new-suite) NEW_SUITE="$2"; shift;;
  --new-repo) NEW_REPO="$2"; shift;;
  --suite) SUITE="$2"; shift;;
  --release) RELEASE="$2"; shift;;
  --version) VERSION="$2"; shift;;
  --repo) REPO="$2"; shift;;
  --sign) SIGN="$2"; shift;;
  *) echo "❌ Unknown parameter passed: $1"; usage exit 1;;
esac; shift; done

if [[ ! -v RELEASE && ! -v SUITE ]]; then echo "❌ No release nor suite specified"; echo ""; usage "$0" "$1" ; exit 1; fi
if [[ ! -v VERSION ]]; then echo "❌ No version specified"; echo ""; usage "$0" "$1" ; exit 1; fi
if [[ ! -v REPO ]]; then echo "❌ No repo specified"; echo ""; usage "$0" "$1" ; exit 1; fi
if [[ ! -v SUITE ]]; then SUITE=$RELEASE; fi;
if [[ ! -v RELEASE ]]; then RELEASE=$SUITE; fi;
if [[ ! -v NEW_NAME ]]; then NEW_NAME=$DEB; fi;
if [[ ! -v NEW_RELEASE ]]; then NEW_RELEASE=$RELEASE; fi;
if [[ ! -v NEW_VERSION ]]; then NEW_VERSION=$VERSION; fi;
if [[ ! -v NEW_SUITE ]]; then NEW_SUITE=$SUITE; fi;
if [[ ! -v NEW_REPO ]]; then NEW_REPO=$REPO; fi;
if [[ ! -v DEB ]]; then NEW_NAME=$DEB; fi;
if [[ ! -v SIGN ]]; then 
  SIGN_ARG=""
else 
  SIGN_ARG="--sign $SIGN"
fi

function rebuild_deb() {
  source scripts/debian/reversion-helper.sh

  wget https://s3.us-west-2.amazonaws.com/${REPO}/pool/${CODENAME}/m/mi/${DEB}_${VERSION}.deb
  reversion --deb ${DEB} \
            --package ${DEB} \
            --source-version ${VERSION} \
            --new-version ${NEW_VERSION} \
            --suite ${SUITE} \
            --new-suite ${NEW_SUITE} \
            --new-name ${NEW_NAME} \
            --new-release ${NEW_RELEASE} \
            --codename ${CODENAME}
}

rebuild_deb
source scripts/debian/publish.sh --names "${NEW_NAME}_${NEW_VERSION}.deb" --version "${NEW_VERSION}" --codename "${CODENAME}" --release "${NEW_RELEASE}" --bucket ${REPO} ${SIGN_ARG}
