#!/bin/bash

git branch -D "${BUILDKITE_BRANCH}" 2>/dev/null || true
git fetch origin "${BUILDKITE_PULL_REQUEST_BASE_BRANCH}"
git checkout -b "${BUILDKITE_BRANCH}"
git reset --hard "${BUILDKITE_COMMIT}"