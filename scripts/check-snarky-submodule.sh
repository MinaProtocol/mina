#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)
git fetch origin

if ! git rev-list origin/coda | grep -q $CURR; then
  echo "Snarky submodule commit is not an ancestor of snarky/coda"
  exit 1
fi

