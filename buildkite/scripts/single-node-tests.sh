#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl wget

git config --global --add safe.directory $BUILDKITE_BUILD_CHECKOUT_PATH

source buildkite/scripts/export-git-env-vars.sh

TEST_SUITE_DOCKER=gcr.io/o1labs-192920/mina-test-suite:$MINA_DOCKER_TAG

docker run --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir \
    --entrypoint mina-command-line-tests \
    --env MINA_LIBP2P_PASS="naughty blue worm" \
    --env MINA_PRIVKEY_PASS="naughty blue worm" \
     $TEST_SUITE_DOCKER test --mina-path mina