#!/bin/bash

# Script builds the debian package for the test_executive

BUILD_NUM=${BUILDKITE_BUILD_NUM}
BUILD_URL=${BUILDKITE_BUILD_URL}

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../_build"

# Alternative to BUILDKITE_BRANCH
if [[ -n "${MINA_BRANCH:=}" ]]; then
  BUILDKITE_BRANCH="${MINA_BRANCH}"
fi
# Load in env vars for githash/branch/etc.
source "${SCRIPTPATH}/../buildkite/scripts/export-git-env-vars.sh"
set +x
# Allow overriding the script env variables with docker build arguments
if [[ -n "${deb_codename:=}" ]]; then
  MINA_DEB_CODENAME="${deb_codename}"
fi
if [[ -n "${deb_version:=}" ]]; then
  MINA_DEB_VERSION="${deb_version}"
fi

set -euo pipefail

GITHASH=$(git rev-parse --short=7 HEAD)
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)

cd "${SCRIPTPATH}/../_build"

BUILDDIR="deb_build"

case "${MINA_DEB_CODENAME}" in
  bookworm|jammy|bullseye|focal|buster)
    DEPS="libjemalloc2"
    ;;
  stretch|bionic)
    DEPS="libjemalloc1"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

echo "--- Building test executive debian package"

rm -rf "${BUILDDIR}"

##################################### GENERATE TEST_EXECUTIVE PACKAGE #######################################

mkdir -p "${BUILDDIR}/DEBIAN"
cat << EOF > "${BUILDDIR}/DEBIAN/control"

Package: mina-test-executive
Version: ${MINA_DEB_VERSION}
License: Apache-2.0
Vendor: none
Architecture: amd64
Maintainer: o(1)Labs <build@o1labs.org>
Installed-Size:
Depends: mina-logproc, ${DEPS}, python3, nodejs, yarn, google-cloud-sdk, kubectl, google-cloud-sdk-gke-gcloud-auth-plugin, terraform, helm
Section: base
Priority: optional
Homepage: https://minaprotocol.com/
Description: Tool to run automated tests against a full mina testnet with multiple nodes.
 Built from ${GITHASH} by ${BUILD_URL}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILDDIR}/DEBIAN/control"

# Binaries
mkdir -p "${BUILDDIR}/usr/local/bin"
cp ./default/src/app/test_executive/test_executive.exe "${BUILDDIR}/usr/local/bin/mina-test-executive"


# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILDDIR}"

# Build the package
echo "------------------------------------------------------------"
fakeroot dpkg-deb --build "${BUILDDIR}" mina-test-executive_${MINA_DEB_VERSION}.deb
ls -lh mina*.deb

echo "--- Built mina-test-executive_${MINA_DEB_VERSION}.deb"
