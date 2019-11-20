#!/bin/bash
set -eo pipefail

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3

GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!g' )

DEBS3='deb-s3 upload --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=max-age=120'

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
else
    # Determine deb repo to use
    case $GITBRANCH in
        master)
            CODENAME='release'
            ;;
        develop)
            CODENAME='develop'
            ;;
        release*)
            CODENAME='stable'
            ;;
        *)
            CODENAME='unstable'
            ;;
    esac

    # only publish wanted jobs
    if [[ "$CIRCLE_JOB" == "build-artifacts--testnet_postake_medium_curves"  ]]; then
          cd src/_build
          echo "Publishing debs:"
          ls coda-*.deb
          set -x
          ${DEBS3} --codename ${CODENAME} --component main coda-*.deb
          echo "Exporting Variables: "
          # Export Variables for Downstream Steps
          echo "export CODA_DEB_REPO=$CODENAME" >> /tmp/DOCKER_DEPLOY_ENV
          echo "export CODA_WAS_PUBLISHED=true" >> /tmp/DOCKER_DEPLOY_ENV
          set +x
    else
        echo "WARNING: Circle job: ${CIRCLE_JOB} not in publish list"
    fi
fi
