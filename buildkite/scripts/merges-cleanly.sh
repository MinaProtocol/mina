#!/bin/bash

BRANCH=$1
CURRENT=$(git branch --show-current)
echo 'Testing for conflicts between the current branch `'"${CURRENT}"'` and `'"${BRANCH}"'`...'

# Adapted from this stackoverflow answer: https://stackoverflow.com/a/10856937
# The git merge-tree command shows the content of a 3-way merge without
# touching the index, which we can then search for conflict markers.

# Only execute in the CI. If the script is run locally, it messes us the user
# config
if [ "${BUILDKITE:-false}" == true ]
then
    # Tell git where to find ssl certs
    git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt
fi

# Fetch a fresh copy of the repo
git fetch origin
# Check mergeability
git merge-tree `git merge-base origin/$BRANCH HEAD` HEAD origin/$BRANCH | grep -A 25 "^+<<<<<<<"

RET=$?

if [ $RET -eq 0 ]; then
  # Found a conflict
  echo "[ERROR] This pull request conflicts with $BRANCH, please open a new pull request against $BRANCH at this link:"
  echo "https://github.com/MinaProtocol/mina/compare/${BRANCH}...${BUILDKITE_BRANCH}"
  exit 1
else
  echo "No conflicts found against upstream branch ${BRANCH}"
  exit 0
fi
