#!/bin/bash

# Base against origin/develop by default, but use pull-request base otherwise
BASE=${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-origin/develop}

# Finds the greatest common commit that is shared between these two branches
# Or nothing if there isn't one
COMMIT=$(diff -u <(git rev-list --first-parent HEAD) \
        <(git rev-list --first-parent $BASE) | \
        sed -ne 's/^ //p' | head -1)

if [[ $COMMIT != "" ]]; then
  # Get the files that have changed since that shared commit
  git diff $COMMIT --name-only
else
  # TODO: Dump commits as artifacts when build succeeds so we can diff against
  # that on develop instead of always running all the tests
  git ls-files
fi

