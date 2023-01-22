#!/bin/bash

# Base against origin/compatible by default, but use pull-request base otherwise
BASE=${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-compatible}
TAG=$(git tag --points-at HEAD)

[[ -n $TAG ]] && git ls-files && exit

# Finds the commit hash of HEAD of $BASE branch
BASECOMMIT=$(git log origin/$BASE -1 --pretty=format:%H)
# Finds the commit hash of HEAD of the current branch
COMMIT=$(git log -1 --pretty=format:%H)
# Use buildkite commit instead when its defined
[[ -n "$BUILDKITE_COMMIT" ]] && COMMIT=${BUILDKITE_COMMIT}

# Print it to stderr for logging/debugging
>&2 echo "Diffing current commit: ${COMMIT} against commit: ${BASECOMMIT} from branch: ${BASE} ."

# Compare base to the current commit
if [[ $BASECOMMIT != $COMMIT ]]; then
  # Get the files that have diverged from $BASE
  git diff $BASECOMMIT --name-only
else
  git ls-files
fi
