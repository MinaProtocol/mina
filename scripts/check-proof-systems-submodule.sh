#!/bin/bash

set -eu

cd src/lib/crypto/proof-systems

CURR=$(git rev-parse HEAD)
# temporarily skip SSL verification (for CI)
git config http.sslVerify false
git fetch origin
git config http.sslVerify true

function in_branch {
  if git rev-list origin/$1 | grep -q $CURR; then
    echo "Proof systems submodule commit is an ancestor of $1"
    true
  else
    false
  fi
}

if (! in_branch "berkeley"); then
  echo "Proof-systems submodule commit is NOT an ancestor of berkeley branch"
  exit 1
fi

