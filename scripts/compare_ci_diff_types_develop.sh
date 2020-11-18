#!/bin/bash

set -eo pipefail

if [ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" = "develop" ]; then
  exit 0
fi

./scripts/compare_ci_diff_types.sh
./scripts/compare_ci_diff_binables.sh
