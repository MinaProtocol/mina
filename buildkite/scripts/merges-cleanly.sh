#!/bin/bash

PR_BRANCH=${BUILDKITE_BRANCH}
BASE_BRANCH=${BUILDKITE_PULL_REQUEST_BASE_BRANCH}
SYNC_BRANCH=$1
echo "Checking conflicts: (${PR_BRANCH} -> ${BASE_BRANCH}) -> ${SYNC_BRANCH}"

# Only execute in the CI. If the script is run locally, it'll mess up user's git
# config
if [ "${BUILDKITE:-false}" == true ]
then
    # Tell git where to find ssl certs
    git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt
    git config --global user.email "hello@ci.com"
    git config --global user.name "It's me, CI"
fi

git fetch origin
git checkout ${BASE_BRANCH}
git reset --hard origin/${BASE_BRANCH}

if ! git merge origin/${PR_BRANCH}; then
    ret=$?
    echo "Merging from ${PR_BRANCH} -> ${BASE_BRANCH} failed (exit $ret)"
    exit $ret
fi

git checkout ${SYNC_BRANCH}
git reset --hard origin/${SYNC_BRANCH}

if ! git merge --no-ff --no-commit ${BASE_BRANCH}; then
  ret=$?
  echo "[ERROR] This pull request has merge conflicts, please open a new pull request against $SYNC_BRANCH at this link:"
  echo "https://github.com/MinaProtocol/mina/compare/${SYNC_BRANCH}...${PR_BRANCH}"
  exit $ret
fi

echo "No conflicts found"
exit 0
