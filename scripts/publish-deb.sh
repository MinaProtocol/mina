#!/bin/bash
set -euo pipefail

# Needed to check variables
set +u

# utility for publishing deb repo with commons options
DEBS3='deb-s3 upload \
        --s3-region=us-west-2 \
        --bucket packages.o1test.net \
        --preserve-versions \
        --cache-control=max-age=120'

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then

    # master is 'stable'
    if [[ "$CIRCLE_BRANCH" == "master" ]]; then
        CODENAME='stable'
    else
        CODENAME='unstable'
    fi

    # only publish some jobs
    if [[ "$CIRCLE_JOB" == "build-artifacts--testnet_postake" || \
          "$CIRCLE_JOB" == "build-artifacts--testnet_postake_many_proposers" ]]; then
          pwd
          ls src/_build/*.deb
          ${DEBS3} --codename ${CODENAME} --component main src/_build/coda-*.deb
    else
        echo "WARNING: Circle job: ${CIRCLE_JOB} not in publish list"
    fi
else
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run" ; \
fi
