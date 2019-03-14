#!/bin/bash

set -e

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
MASTER_HASH=$(git merge-base origin/master HEAD)

if [ "${CURRENT_BRANCH}" -eq "master" ] ; then
  # always run master
  exec "$@"
elif git diff HEAD..${MASTER_HASH} --name-only | grep -E -q -v '^frontend'; then
  # if there is anything outside of frontend, run
  exec "$@"
else
  echo "Skipping step -- frontend-only detected"
fi

