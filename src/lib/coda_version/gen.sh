#!/bin/sh
set -e

branch=$(git rev-parse --verify --abbrev-ref HEAD || echo "<none found>")
commit_id_short=$(git rev-parse --short=8 --verify HEAD)
marlin_submodule_dir=$(git submodule | grep marlin | cut -d' ' -f3)
marlin_repo_sha=$(cd $marlin_submodule_dir && git rev-parse --short=8 --verify HEAD)

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
echo "let commit_id_short = \"$commit_id_short\"" >> "$1"
echo "let branch = \"$branch\"" >> "$1"
echo "let marlin_repo_sha = \"$marlin_repo_sha\"" >> "$1"
