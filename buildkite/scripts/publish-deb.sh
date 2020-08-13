#!/bin/bash
set -eo pipefail

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3

DEBS3='deb-s3 upload '\
'--s3-region=us-west-2 '\
'--bucket packages.o1test.net '\
'--preserve-versions '\
'--lock '\
'--cache-control=max-age=120 '\
'--component main'

DEBS='_build/coda-*.deb'

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
${DEBS3} --codename "${CODENAME}" "${DEBS}"
echo "Exporting Variables: "
# Export Variables for Downstream Steps

source ./DOCKER_DEPLOY_ENV
echo "export CODA_VERSION=$CODA_DEB_VERSION" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_DEB_REPO=$CODENAME" >> ./DOCKER_DEPLOY_ENV
echo "export CODA_WAS_PUBLISHED=true" >> ./DOCKER_DEPLOY_ENV
set +x
