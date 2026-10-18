#!/bin/bash

set -eo pipefail

# Sourcing profile as this is where the environment variables are set in toolchain container
# Thus, this script should be ran only in buildkite context using toolchain docker
# shellcheck disable=SC1090
source ~/.profile

export BRANCH_NAME=$BUILDKITE_BRANCH

./scripts/hardfork/release/build-packages.sh "$@"

echo "--- Git diff after build is complete:"
git diff --exit-code -- .