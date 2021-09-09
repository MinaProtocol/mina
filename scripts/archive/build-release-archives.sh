#!/bin/bash

# This script makes a .deb archive for the Coda Archive process
# and releases it to the AWS .deb repository packages.o1test.net

set -euo pipefail

# Set up variables for build
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../.."

source "buildkite/scripts/export-git-env-vars.sh"

PROJECT="mina-archive"
BUILD_DIR="deb_build"

mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libgomp1, libjemalloc1, libssl1.1, libpq-dev
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GIT_HASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./_build/default/src/app/archive/archive.exe "${BUILD_DIR}/usr/local/bin/coda-archive"
cp ./_build/default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./_build/default/src/app/missing_subchain/missing_subchain.exe "${BUILD_DIR}/usr/local/bin/mina-missing-subchain"
cp ./_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}_${VERSION}.deb
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
    # Determine deb repo to use
    case $GITBRANCH in
        master)
            CODENAME='release'
            ;;
        *)
            CODENAME='unstable'
            ;;
    esac

    echo "Publishing debs:"
    ls mina-*.deb
    set -x
    # Upload the deb files to s3.
    # If this fails, attempt to remove the lockfile and retry.
    ${DEBS3} --codename ${CODENAME} --component main mina-*.deb \
    || (  scripts/clear-deb-s3-lockfile.sh \
       && ${DEBS3} --codename main mina-*.deb)
fi

###
# Build and Publish Docker
###
if [ -n "${BUILDKITE+x}" ]; then
    set -x

    # Export variables for use with downstream steps
    echo "export CODA_SERVICE=coda-archive" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_VERSION=${DOCKER_TAG}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_DEB_VERSION=${VERSION}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_DEB_REPO=${CODENAME}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_GIT_HASH=${GITHASH}" >> ./ARCHIVE_DOCKER_DEPLOY

    set +x
else
    mkdir docker_build
    mv mina-*.deb docker_build/.

    echo "$DOCKER_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin

    docker build \
      -t codaprotocol/coda-archive:$DOCKER_TAG \
      -f $SCRIPTPATH/Dockerfile \
      --build-arg coda_deb_version=$VERSION \
      --build-arg deb_repo=$CODENAME \
      docker_build

    docker push codaprotocol/coda-archive:$DOCKER_TAG
fi
