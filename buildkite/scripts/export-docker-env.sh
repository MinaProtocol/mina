#!/bin/bash

set -euo pipefail

CODA_GIT_TAG=$(git describe --abbrev=0)
CODA_GIT_BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref  HEAD  | sed 's!/!-!; s!_!-!g')
CODA_GIT_HASH=$(git rev-parse --short=7 HEAD)

VERSION="${CODA_GIT_TAG}-${CODA_GIT_BRANCH}-${CODA_GIT_HASH}"

echo "export CODA_VERSION=$VERSION" >> DOCKER_DEPLOY_ENV
echo "export CODA_DEB_VERSION=$VERSION" >> DOCKER_DEPLOY_ENV
echo "export CODA_DEB_REPO=develop" >> DOCKER_DEPLOY_ENV
echo "export NOUPLOAD=0" >> DOCKER_DEPLOY_ENV
echo "export CODA_SERVICE=coda-daemon" >> DOCKER_DEPLOY_ENV