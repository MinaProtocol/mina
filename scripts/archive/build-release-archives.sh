#!/bin/bash

# This script makes a .deb archive for the Coda Archive process
# and releases it to the AWS .deb repository packages.o1test.net

set -euo pipefail

# Set up variables for build
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

<<<<<<< HEAD
cd "${SCRIPTPATH}/../.."

# Load in env vars for githash/branch/etc.
source "./buildkite/scripts/export-git-env-vars.sh"
||||||| b7eeee4b3
GIT_HASH=$(git rev-parse --short=7 HEAD)
GIT_BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
GIT_TAG=$(git describe --abbrev=0)

PROJECT="coda-archive"
=======
PROJECT="coda-archive"
>>>>>>> origin/buildkite/artifact_release_refactor

<<<<<<< HEAD
PROJECT="coda-archive"
||||||| b7eeee4b3
if [ "$GIT_BRANCH" == "master" ]; then
    VERSION="${GIT_TAG}"
else
    VERSION="${GIT_TAG}-${GIT_BRANCH}-${GIT_HASH}"
fi
=======
source ".././buildkite/scripts/export-git-env-vars.sh"
>>>>>>> origin/buildkite/artifact_release_refactor

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
Homepage: https://codaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Coda Archive Process
 Compatible with Coda Daemon
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


# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}_${VERSION}.deb
ls -lh coda*.deb

###
# Release the .deb
###

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3

DEBS3='deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=max-age=120'

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
    ls coda-*.deb
    set -x
    ${DEBS3} --codename ${CODENAME} --component main coda-*.deb
fi

###
# Build and Publish Docker
###
if [ -n "${BUILDKITE+x}" ]; then
    set -x
    # Export variables for use with downstream steps
<<<<<<< HEAD
    echo "export CODA_SERVICE=coda-archive" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_VERSION=${DOCKER_TAG}" >> ./ARCHIVE_DOCKER_DEPLOY
||||||| b7eeee4b3
    echo "export CODA_SERVICE=archive-node" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_VERSION=${VERSION}" >> ./ARCHIVE_DOCKER_DEPLOY
=======
    echo "export CODA_SERVICE=coda-archive" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_VERSION=${VERSION}" >> ./ARCHIVE_DOCKER_DEPLOY
>>>>>>> origin/buildkite/artifact_release_refactor
    echo "export CODA_DEB_VERSION=${VERSION}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_DEB_REPO=${CODENAME}" >> ./ARCHIVE_DOCKER_DEPLOY
    echo "export CODA_GIT_HASH=${GITHASH}" >> ./ARCHIVE_DOCKER_DEPLOY

    set +x
else
    mkdir docker_build 
    mv coda-*.deb docker_build/.

    echo "$DOCKER_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin

    docker build -t codaprotocol/coda-archive:$VERSION -f $SCRIPTPATH/Dockerfile docker_build

    docker push codaprotocol/coda-archive:$VERSION
fi
