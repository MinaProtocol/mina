#!/bin/bash

if [ "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" != "compatible" ]; then exit 0; fi

# Adapted from this stackoverflow answer: https://stackoverflow.com/a/10856937
# The git merge-tree command shows the content of a 3-way merge without
# touching the index, which we can then search for conflict markers.
git merge-tree `git merge-base origin/develop HEAD` origin/develop HEAD | grep "^<<<<<<<"

RET=$?

if [ $RET -eq 0 ]; then
  # Found a conflict
  exit 1
else
  # No conflicts were found
  exit 0
fi
