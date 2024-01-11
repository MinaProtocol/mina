#!/bin/bash

set -eu

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <target-branch>"
  exit 1
fi

cd src/lib/crypto/proof-systems

CURR=$(git rev-parse HEAD)

# temporarily skip SSL verification (for CI)
if [ "${BUILDKITE:-false}" == true ]
then
    git config http.sslVerify false
    git fetch origin
    git config http.sslVerify true
fi


BRANCH=$1

function in_branch {
  if git rev-list origin/$1 | grep -q $CURR; then
    echo "Proof systems submodule commit is an ancestor of $1"
    true
  else
    false
  fi
}

if (! in_branch ${BRANCH}); then
  echo "Proof-systems submodule commit is NOT an ancestor of ${BRANCH} branch"
  exit 1
fi