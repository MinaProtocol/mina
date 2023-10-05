#!/bin/bash

TAG=$(git tag --points-at HEAD)

# If this is not a PR build, or the HEAD is tagged, the entire build is dirty
if [ -z "${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" ]; then
  echo "This is not a PR build; considering all files dirty" >&2
  git ls-files
elif [ -n "${TAG}" ]; then
  echo "This commit has been tagged (${TAG}); considering all files dirty" >&2
  git ls-files
else
  COMMIT=$(git log -1 --pretty=format:%H)
  BASE_COMMIT=$(git log "origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" -1 --pretty=format:%H)
  echo "Diffing current commit: ${COMMIT} against branch: ${BUILDKITE_PULL_REQUEST_BASE_BRANCH} (${BASE_COMMIT})" >&2 
  git diff "origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" --name-only
fi
