#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

while [[ "$#" -gt 0 ]]; do case $1 in
  -d|--deb) DEB="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  --new-name) NEW_NAME="$2"; shift;;
  --new-release) NEW_RELEASE="$2"; shift;;
  --release) RELEASE="$2"; shift;;
  --version) VERSION="$2"; shift;;
  --new-version) NEW_VERSION="$2"; shift;;
  --suite) SUITE="$2"; shift;;
  --new-suite) NEW_SUITE="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

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
  echo "  --new-suite       The New Debian suite"
  echo ""
  echo "Example: $0 --deb mina-archive --version 2.0.0berkeley-rc1-berkeley-48efea4 --new-version 2.0.0berkeley-rc1 --codename bullseye --release unstable --new-release umt"
  exit 1
}

if [[ -z "$NEW_NAME" ]]; then NEW_NAME=$DEB; fi;
if [[ -z "$NEW_RELEASE" ]]; then NEW_RELEASE=$RELEASE; fi;
if [[ -z "$NEW_VERSION" ]]; then NEW_VERSION=$VERSION; fi;
if [[ -z "$NEW_SUITE" ]]; then NEW_SUITE=$SUITE; fi;

if [[ -z "$DEB" ]]; then NEW_NAME=$DEB; fi;
if [[ -z "$RELEASE" ]]; then NEW_RELEASE=$RELEASE; fi;
if [[ -z "$VERSION" ]]; then NEW_VERSION=$VERSION; fi;
if [[ -z "$SUITE" ]]; then NEW_SUITE=$SUITE; fi;


function rebuild_deb() {
  rm -f "${DEB}_${VERSION}.deb"
  rm -rf "${NEW_NAME}_${NEW_VERSION}"
    
  wget https://s3.us-west-2.amazonaws.com/packages.o1test.net/pool/${CODENAME}/m/mi/${DEB}_${VERSION}.deb
  dpkg-deb -R "${DEB}_${VERSION}.deb" "${NEW_NAME}_${NEW_VERSION}"
  sed -i 's/Version: '"${VERSION}"'/Version: '"${NEW_VERSION}"'/g' "${NEW_NAME}_${NEW_VERSION}/DEBIAN/control"
  sed -i 's/Package: '"${DEB}"'/Package: '"${NEW_NAME}"'/g' "${NEW_NAME}_${NEW_VERSION}/DEBIAN/control"
  sed -i 's/Suite: '"${SUITE}"'/Suite: '"${NEW_SUITE}"'/g' "${NEW_NAME}_${NEW_VERSION}/DEBIAN/control"
  dpkg-deb --build "${NEW_NAME}_${NEW_VERSION}" "${NEW_NAME}_${NEW_VERSION}.deb"
}

rebuild_deb

source scripts/publish-deb.sh --names "${NEW_NAME}_${NEW_VERSION}.deb" --version ${NEW_VERSION} --codename ${CODENAME} --release ${NEW_RELEASE}
