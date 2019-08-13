#!/bin/bash
set -euo pipefail

# Needed to check variables
set +u

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3

DEBS3='deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=max-age=120'

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
else
    # release is 'stable'
    if echo "$CIRCLE_BRANCH" | grep -qE "^release/"; then
        CODENAME='stable'
    else # develop is 'unstable'
        CODENAME='unstable'
    fi

    # only publish some jobs
    if [[ "$CIRCLE_JOB" == "build-artifacts--testnet_postake_many_proposers_medium_curves" || \
          "$CIRCLE_JOB" == "build-artifacts--testnet_postake_medium_curves"  ]]; then
          cd src/_build
          echo "Publishing debs:"
          ls coda-*.deb
          set -x
          ${DEBS3} --codename ${CODENAME} --component main coda-*.deb
          set +x
    else
        echo "WARNING: Circle job: ${CIRCLE_JOB} not in publish list"
    fi
fi
