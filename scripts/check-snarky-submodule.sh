#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)
# temporarily skip SSL verification (for CI)
git config http.sslVerify false
git fetch origin
git config http.sslVerify true

function in_branch {
  if git rev-list origin/"$1" | grep -q "${CURR}"; then
    echo "Snarky submodule commit is an ancestor of snarky/$1"
    true
  else
    false
  fi
}

if (! in_branch "master"); then
  exit 1
fi

