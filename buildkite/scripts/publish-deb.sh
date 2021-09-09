#!/bin/bash
set -eo pipefail

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."
DEBS3='deb-s3 upload '\
'--s3-region=us-west-2 '\
'--bucket packages.o1test.net '\
'--preserve-versions '\
'--lock '\
'--cache-control=max-age=120 '\
'--component main'

DEBS='_build/mina-*.deb'

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
fi

# Determine deb repo to use
case $BUILDKITE_BRANCH in
    master)
        CODENAME=release ;;
    *)
        CODENAME=unstable ;;
esac

echo "Publishing debs: ${DEBS}"
set -x
# Upload the deb files to s3.
# If this fails, attempt to remove the lockfile and retry.
${DEBS3} --codename "${CODENAME}" "${DEBS}" \
|| (  scripts/clear-deb-s3-lockfile.sh \
   && ${DEBS3} --codename "${CODENAME}" "${DEBS}")
set +x
echo "Exporting Variables: "

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/export-git-env-vars.sh"

set -x
# Export variables for use with downstream steps
echo "export CODA_SERVICE=coda-daemon" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_VERSION=${DOCKER_TAG}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_DEB_VERSION=${VERSION}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_PROJECT=${PROJECT}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_GIT_HASH=${GITHASH}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_GIT_BRANCH=${BUILDKITE_BRANCH}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_GIT_TAG=${GITTAG}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_DEB_REPO=${CODENAME}" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_WAS_PUBLISHED=true" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_BUILD_ROSETTA=${BUILD_ROSETTA}" >> ./DOCKER_DEPLOY_ENV
set +x

