#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source ~/.profile

export BRANCH_NAME=$BUILDKITE_BRANCH

./scripts/hardfork/build-packages.sh "$@"

echo "--- Git diff after build is complete:"
git diff --exit-code -- .