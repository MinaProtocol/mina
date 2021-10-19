#!/bin/bash

# This script makes a .deb archive for the Mina Archive process
# and releases it to the AWS .deb repository packages.o1test.net

set -euo pipefail

# Set up variables for build
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../.."

source "buildkite/scripts/export-git-env-vars.sh"

cd _build

# Set dependencies based on debian release
SHARED_DEPS="libssl1.1, libgomp1, libpq-dev, "
case "${MINA_DEB_CODENAME}" in
  buster)
    ARCHIVE_DEPS="libjemalloc2"
    ;;
  stretch)
    ARCHIVE_DEPS="libjemalloc1"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

PROJECT="mina-archive"
BUILD_DIR="deb_build"

###### archiver deb

mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${MINA_DEB_VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: ${SHARED_DEPS}${ARCHIVE_DEPS}
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GITHASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./default/src/app/archive/archive.exe "${BUILD_DIR}/usr/local/bin/mina-archive"
cp ./default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./default/src/app/extract_blocks/extract_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-extract-blocks"
cp ./default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
cp ./default/src/app/replayer/replayer.exe "${BUILD_DIR}/usr/local/bin/mina-replayer"
cp ./default/src/app/swap_bad_balances/swap_bad_balances.exe "${BUILD_DIR}/usr/local/bin/mina-swap-bad-balances"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}_${MINA_DEB_VERSION}.deb
ls -lh mina*.deb

###
# Release the .deb
###

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."
DEBS3='deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions
--lock
--cache-control=max-age=120'

# check for AWS Creds
set +u
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
else
    set -u

    echo "Publishing debs:"
    ls mina-*.deb
    set -x
    # Upload the deb files to s3.
    # If this fails, attempt to remove the lockfile and retry.
    ${DEBS3} --component "${MINA_DEB_RELEASE}" --codename "${MINA_DEB_CODENAME}" mina-*.deb \
    || (  scripts/clear-deb-s3-lockfile.sh \
       && ${DEBS3} --component "${MINA_DEB_RELEASE}" --codename "${MINA_DEB_CODENAME}" mina-*.deb)
fi

###
# Build and Publish Docker
###
if [ -n "${BUILDKITE+x}" ]; then
    set -x

    # Export variables for use with downstream steps
    echo "export MINA_SERVICE=mina-archive" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export MINA_VERSION=${MINA_DOCKER_TAG}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export MINA_DEB_VERSION=${MINA_DEB_VERSION}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export MINA_DEB_RELEASE=${MINA_DEB_RELEASE}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export MINA_DEB_CODENAME=${MINA_DEB_CODENAME}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export MINA_GIT_HASH=${GITHASH}" >> ./ARCHIVE_DOCKER_DEPLOY

    set +x
else
    mkdir docker_build
    mv mina-*.deb docker_build/.

    echo "$DOCKER_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin

    docker build \
      -t minaprotocol/mina-archive:$MINA_DOCKER_TAG \
      -f "../../dockerfiles/Dockerfile-mina-archive" \
      --build-arg deb_version=$MINA_DEB_VERSION \
      --build-arg deb_codename=$MINA_DEB_CODENAME \
      --build-arg deb_release=$MINA_DEB_RELEASE \
      docker_build

    docker push minaprotocol/mina-archive:$MINA_DOCKER_TAG
fi
