#!/bin/bash

BRANCH=$1
CURRENT=$(git branch --show-current)
echo 'Testing for conflicts between the current branch `'"${CURRENT}"'` and `'"${BRANCH}"'`...'

# Adapted from this stackoverflow answer: https://stackoverflow.com/a/10856937
# The git merge-tree command shows the content of a 3-way merge without
# touching the index, which we can then search for conflict markers.

# Tell git where to find ssl certs
git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt
# Fetch a fresh copy of the repo
git fetch origin
git config --global user.email "hello@ci.com"
git config --global user.name "It's me, CI"
# Check mergeability. We use flags so that
# * `--no-commit` stops us from updating the index with a merge commit,
# * `--no-ff` stops us from updating the index to the HEAD, if the merge is a
#   straightforward fast-forward
git merge --no-commit --no-ff origin/$BRANCH

RET=$?

if [ $RET -eq 0 ]; then
  echo "No conflicts found against upstream branch ${BRANCH}"
  exit 0
else
  # Found a conflict
  echo "[ERROR] This pull request conflicts with $BRANCH, please open a new pull request against $BRANCH at this link:"
  echo "https://github.com/MinaProtocol/mina/compare/${BRANCH}...${BUILDKITE_BRANCH}"
  exit 1
fi
