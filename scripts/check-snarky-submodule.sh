#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)
# temporarily skip SSL verification (for CI)
git config http.sslVerify false
git fetch origin
git config http.sslVerify true

if ! git rev-list origin/mina | grep -q $CURR; then
  echo "Snarky submodule commit is not an ancestor of snarky/mina"
  exit 1
fi

