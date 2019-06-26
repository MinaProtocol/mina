#!/bin/sh
set -e

if [ -n "$CODA_COMMIT_SHA1" ]; then
  # pull from env var if set
  id="$CODA_COMMIT_SHA1"
else
  # otherwise, query from git repository
  # we are nested five directories deep (_build/<context>/src/lib/coda_version)
  cd ../../../../..
  if [ ! -e .git ]; then echo 'Error: git repository not found'; exit 1; fi
  id=$(git rev-parse --verify HEAD)
  if [ -n "$(git diff --stat)" ]; then id="[DIRTY]$id"; fi
  cd -
fi

echo "let commit_id = \"$id\"" > "$1"
