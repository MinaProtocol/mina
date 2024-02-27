#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

while [[ "$#" -gt 0 ]]; do case $1 in
  -d|--deb) DEB="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  --new-release) NEW_RELEASE="$2"; shift;;
  --old-release) OLD_RELEASE="$2"; shift;;
  --old-version) OLD_VERSION="$2"; shift;;
  --new-version) NEW_VERSION="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-d deb-name] [-v new-version] "
  echo "  -d, --deb         The Debian name"
  echo "  -c, --codename    The Debian codename"
  echo "  --old-release     The Old Debian release"
  echo "  --new-release     The New Debian release"
  echo "  --old-version     The Old Debian version"
  echo "  --new-version     The New Debian version"
  echo ""
  echo "Example: $0 --deb mina-archive --old-version 2.0.0berkeley-rc1-berkeley-48efea4 --new-version 2.0.0berkeley-rc1 --codename bullseye --old-release unstable --new-release umt"
  exit 1
}

function rebuild_deb() {
  wget https://s3.us-west-2.amazonaws.com/packages.o1test.net/pool/${CODENAME}/m/mi/${DEB}_${VERSION}.deb
  dpkg-deb -R "${DEB}_${VERSION}.deb" "${DEB}_${NEW_VERSION}"
  sed -i 's/Version: '"${VERSION}"'/Version: '"${NEW_VERSION}"'/g' "${DEB}_${NEW_VERSION}"/DEBIAN/control
  dpkg-deb --build "${DEB}_${NEW_VERSION}" "${DEB}_${NEW_VERSION}.deb"
}

rebuild_deb

source scripts/publish-deb.sh --name "${DEB}_${NEW_VERSION}.deb" --version ${NEW_VERSION} --codename ${CODENAME} --release ${NEW_RELEASE}