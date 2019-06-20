#!/bin/sh
set -e

if [ -n "$CODA_COMMIT_SHA1" ]; then
  # pull from env var if set
  id="$CODA_COMMIT_SHA1"
else
  id=$(git rev-parse --verify HEAD)
  if [ -n "$(git diff --stat)" ]; then id="[DIRTY]$id"; fi
fi

echo "let commit_id = \"$id\"" > "$1"
