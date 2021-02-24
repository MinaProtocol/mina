#!/bin/bash

set -eo pipefail

if [ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" = "compatible" ]; then
  exit 0
fi

# Exports to let Buildkite run the CircleCI scripts
export CI=true
export BASE_BRANCH_NAME="$BUILDKITE_PULL_REQUEST_BASE_BRANCH"

./scripts/compare_ci_diff_types.sh
./scripts/compare_ci_diff_binables.sh
