#!/bin/bash

# Base against origin/develop by default, but use pull-request base otherwise
BASE=${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-origin/develop}

# Finds the greatest common commit that is shared between these two branches
# Or nothing if there isn't one
# COMMIT=$(diff -u <(git rev-list --first-parent HEAD) \
#        <(git rev-list --first-parent $BASE) | \
#        sed -ne 's/^ //p' | head -1)

BASECOMMIT=$(git log $BASE -1 --pretty=format:%H) # Finds the commit hash of HEAD of $BASE branch

# Print it for logging/debugging
echo "Diffing current commit: ${BUILDKITE_COMMIT} against commit: ${BASECOMMIT} from branch: ${BASE} ."

# Compare base to the current commit
if [[ $BASECOMMIT != $BUILDKITE_COMMIT ]]; then
  # Get the files that have diverged from $BASE
  git diff $BASECOMMIT --name-only
else
  # TODO: Dump commits as artifacts when build succeeds so we can diff against
  # that on develop instead of always running all the tests
  git ls-files
fi

