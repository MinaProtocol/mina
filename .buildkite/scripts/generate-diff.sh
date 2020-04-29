#!/bin/bash

BASE=${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-origin/develop}

COMMIT=$(diff -u <(git rev-list --first-parent HEAD) \
        <(git rev-list --first-parent $BASE) | \
        sed -ne 's/^ //p' | head -1)

if [[ $COMMIT != "" ]]; then
  git diff $COMMIT --name-only
else
  # TODO: Dump commits as artifacts when build succeeds so we can diff against
  # that on develop instead of always running
  git ls-files
fi

