#!/bin/bash
set -eo pipefail

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."

echo "NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails due to the lockfile, delete https://packages.o1test.net/dists/unstable/main/binary-/lockfile from our S3 bucket (https://s3.console.aws.amazon.com/s3/buckets/packages.o1test.net?region=us-west-2&prefix=dists/unstable/main/binary-/&showversions=false) and rebuild"

DEBS3='deb-s3 upload '\
'--s3-region=us-west-2 '\
'--bucket packages.o1test.net '\
'--preserve-versions '\
'--lock '\
'--cache-control=max-age=120 '\
'--component main'

DEBS='_build/mina-*.deb'

usage() {
    echo "Usage: $0 [-f] [-r REPONAME] [-d DEBNAME]" 1>&2;
    echo "eg:    $0 -f -r unstable -d my.deb" 1>&2;
    exit 1;
}

# command line options
while getopts ":r:d:f" o; do
    case "${o}" in
        r)
            CODENAME=${OPTARG} ;;
        d)
            DEBS=${OPTARG} ;;
        f)  # FORCE
            CIRCLE_JOB='FORCED' ;;
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
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )
case $GITBRANCH in
    master)
        CODENAME=${CODENAME:-release} ;;
    develop)
        CODENAME=${CODENAME:-develop} ;;
    release*)
        CODENAME=${CODENAME:-stable} ;;
    *)
        CODENAME=${CODENAME:-unstable} ;;
esac

# only publish wanted jobs
case "$CIRCLE_JOB" in
    build-artifacts--testnet_postake_medium_curves | FORCED)
        echo "Publishing debs: ${DEBS}"
        set -x
        # Upload the deb files to s3.
        # If this fails, attempt to remove the lockfile and retry.
        ${DEBS3} --codename "${CODENAME}" "${DEBS}" \
        || (  scripts/clear-deb-s3-lockfile.sh \
           && ${DEBS3} --codename "${CODENAME}" "${DEBS}")
        echo "Exporting Variables: "
        # Export Variables for Downstream Steps
        echo "export CODA_DEB_REPO=$CODENAME" >> /tmp/DOCKER_DEPLOY_ENV
        echo "export CODA_WAS_PUBLISHED=true" >> /tmp/DOCKER_DEPLOY_ENV
        set +x
        ;;
    *)
        echo "WARNING: Circle job: ${CIRCLE_JOB} not in publish list"
        ;;
esac
