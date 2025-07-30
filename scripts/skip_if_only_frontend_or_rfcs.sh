#!/bin/bash

set -e

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEVELOP_HASH=$(git merge-base origin/develop HEAD)

if [ "${CURRENT_BRANCH}" = "master" ] || [ "${CURRENT_BRANCH}" = "develop" ] || (echo "${CURRENT_BRANCH}" | grep -qE "^release/|^docs/") ; then
  # always run develop
  exec "$@"
elif git diff HEAD..${DEVELOP_HASH} --name-only | grep -E -q -v '^frontend|^rfcs'; then
  # if there is anything outside of frontend or rfcs, run
  exec "$@"
else
  echo "Skipping step -- frontend-or-rfcs-only detected"
fi
