#!/bin/bash

BRANCH=$1
CURRENT=$(git branch --show-current)
echo 'Testing for conflicts between the current branch `'"${CURRENT}"'` and `'"${BRANCH}"'`...'

# Adapted from this stackoverflow answer: https://stackoverflow.com/a/10856937
# The git merge-tree command shows the content of a 3-way merge without
# touching the index, which we can then search for conflict markers.

# Fetch a fresh copy of the repo
git config http.sslVerify false
git fetch origin
git config http.sslVerify true
# Check mergeability
git merge-tree `git merge-base origin/$BRANCH HEAD` HEAD origin/$BRANCH \
    | awk -f buildkite/scripts/merges-cleanly.awk

RET=$?

if [ $RET -eq 0 ]; then
  echo "No conflicts found against upstream branch ${BRANCH}"
  exit 0
else
  # Found a conflict
  echo "[ERROR] This pull request conflicts with $BRANCH, please open a new pull request against $BRANCH at this link:"
  echo "https://github.com/MinaProtocol/mina/compare/${BRANCH}...${BUILDKITE_BRANCH}"
  exit $RET
fi
