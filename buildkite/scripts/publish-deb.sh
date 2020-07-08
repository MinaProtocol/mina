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

usage() {
    echo "Usage: $0 [-r REPONAME] [-d DEBNAME]" 1>&2;
    echo "eg:    $0 -r unstable -d my.deb" 1>&2;
    exit 1;
}

# command line options
while getopts ":r:d" o; do
    case "${o}" in
        r)
            CODENAME=${OPTARG} ;;
        d)
            DEBS=${OPTARG} ;;
        *)
            usage ;;
    esac
done
shift $((OPTIND-1))

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
fi

# Determine deb repo to use
#GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
case $BUILDKITE_BRANCH in
    master)
        CODENAME=${CODENAME:-release} ;;
#    develop)
#        CODENAME=${CODENAME:-develop} ;;
#    release*)
#        CODENAME=${CODENAME:-stable} ;;
    *)
        CODENAME=${CODENAME:-unstable} ;;
esac

echo "Publishing debs: ${DEBS}"
set -x
${DEBS3} --codename "${CODENAME}" "${DEBS}"
echo "Exporting Variables: "
# Export Variables for Downstream Steps
echo "export CODA_DEB_REPO=$CODENAME" >> /tmp/DOCKER_DEPLOY_ENV
echo "export CODA_WAS_PUBLISHED=true" >> /tmp/DOCKER_DEPLOY_ENV
set +x
