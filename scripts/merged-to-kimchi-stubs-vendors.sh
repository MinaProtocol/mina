#!/bin/bash

set -eu

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <target-branch>"
  exit 1
fi

# CI agents do not always check out submodules. Init this one (not recursive,
# full history: the ancestry check below needs it).
git submodule update --init -- src/lib/crypto/kimchi_bindings/stubs/kimchi-stubs-vendors

cd src/lib/crypto/kimchi_bindings/stubs/kimchi-stubs-vendors

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
  if git rev-list origin/"$1" | grep -q "${CURR}"; then
    echo "kimchi-stubs-vendors submodule commit is an ancestor of $1"
    true
  else
    false
  fi
}

if (! in_branch "${BRANCH}"); then
  echo "kimchi-stubs-vendors submodule commit is NOT an ancestor of ${BRANCH} branch"
  exit 1
fi
