#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)
# temporarily skip SSL verification (for CI)
git config http.sslVerify false
git fetch origin
git config http.sslVerify true

function in_branch {
  if git rev-list origin/$1 | grep -q $CURR; then
    echo "Snarky submodule commit is an ancestor of snarky/$1"
    true
  else
    false
  fi
}

if (! in_branch "coda") && (! in_branch "compatible"); then
  echo "Snarky submodule commit is an ancestor of neither snarky/coda or snarky/compatible"
  exit 1
fi

